let
  // ========= SOURCE =========
  // Using the cleaner source from dim_PIQ_TAGS that already filters to active students only
  Source = Table.NestedJoin(src_PIQ_StudentAssignedTags_csv, {"*StudentID"}, #"src_PIQ-StudentTemplate_csv", {"*StudentID"}, "src_PIQ-StudentTemplate_csv", JoinKind.Inner),
  #"Removed columns" = Table.RemoveColumns(Source, {"src_PIQ-StudentTemplate_csv"}),
  #"Reordered columns" = Table.ReorderColumns(#"Removed columns", {"*StudentID", "Action (Delete)", "Notes", "EndDate", "StartDate", "*Tag(path example: campus||southern or status||academic||active)", "AdmittedClass", "Class", "FirstName", "LastName"}),

  // Since source now only includes active students, we can skip class filtering if not needed
  // Keep only Classes 2025–2029 if still required
  ToText = Table.TransformColumnTypes(#"Reordered columns", {{"Class", type text}}),
  FilteredClasses = Table.SelectRows(
      ToText,
      each [Class] = "2025" or [Class] = "2026" or [Class] = "2027" or [Class] = "2028" or [Class] = "2029"
  ),

  // Type assignment (preserve Start/End dates for status history)
  Typed = Table.TransformColumnTypes(
      FilteredClasses,
      {
        {"*StudentID", type text},
        {"LastName", type text},
        {"FirstName", type text},
        {"Class", Int64.Type},
        {"AdmittedClass", Int64.Type},
        {"*Tag(path example: campus||southern or status||academic||active)", type text},
        {"StartDate", type date},
        {"EndDate", type date},
        {"Notes", type text},
        {"Action (Delete)", type text}
      }
  ),

  // Remove the unneeded columns; we don't need names/dates here for tags,
  // but we WILL keep StartDate/EndDate for status history.
  DroppedUnneeded = Table.RemoveColumns(Typed, {"AdmittedClass", "LastName", "FirstName", "Action (Delete)"}),

  // ========= SPLIT TAG INTO NAME / VALUE =========
  // Expect Tag like: "Academic Status||Active" or "Campus||Pre-Clerkship||Bryan/CS"
  SplitMain = Table.SplitColumn(
      DroppedUnneeded,
      "*Tag(path example: campus||southern or status||academic||active)",
      Splitter.SplitTextByEachDelimiter({"||"}, QuoteStyle.Csv, false),
      2
  ),
  Renamed = Table.RenameColumns(SplitMain, {{"*Tag(path example: campus||southern or status||academic||active).1", "TagBase"}, {"*Tag(path example: campus||southern or status||academic||active).2", "TagRest"}}),

  SplitRest = Table.SplitColumn(
      Renamed,
      "TagRest",
      Splitter.SplitTextByDelimiter("||", QuoteStyle.Csv),
      {"TagPart1","TagPart2"}
  ),

  // Build Tag Name / Tag Value
  WithTagValue = Table.AddColumn(
      SplitRest, "Tag Value",
      each if [TagPart2] = null then [TagPart1] else [TagPart2],
      type text
  ),
  WithTagName = Table.AddColumn(
      WithTagValue, "Tag Name",
      each if [TagPart2] = null then [TagBase] else [TagBase] & " " & [TagPart1],
      type text
  ),

  // Keep standardized columns (keep Start/End dates!)
  Selected = Table.SelectColumns(WithTagName, {"*StudentID","Class","StartDate","EndDate","Notes","Tag Name","Tag Value"}),
  
  // Rename StudentID column to remove the asterisk for cleaner downstream usage
  RenamedStudentID = Table.RenameColumns(Selected, {{"*StudentID", "StudentID"}}),

  // ========= CLEAN / NORMALIZE =========
  Clean1 = Table.TransformColumns(RenamedStudentID, {{"Tag Name", each Text.Clean(_), type text}}),
  Trim1  = Table.TransformColumns(Clean1, {{"Tag Name", each Text.Trim(_), type text}}),
  Clean2 = Table.TransformColumns(Trim1,  {{"Tag Value", each Text.Clean(_), type text}}),
  Trim2  = Table.TransformColumns(Clean2, {{"Tag Value", each Text.Trim(_), type text}}),

  // Normalize to UPPER for stable matching/pivoting
  UpperNames  = Table.TransformColumns(Trim2, {{"Tag Name", each Text.Upper(_), type text}}),
  UpperValues = Table.TransformColumns(UpperNames, {{"Tag Value", each Text.Upper(_), type text}}),

  // Drop blank/null tag rows
  NonBlank = Table.SelectRows(
      UpperValues,
      each [Tag Name] <> null and [Tag Name] <> "" and [Tag Value] <> null and [Tag Value] <> ""
  ),

  // De-dupe identical tag/value rows (still keep dates)
  Dedup = Table.Distinct(NonBlank, {"StudentID","Class","Tag Name","Tag Value","StartDate","EndDate","Notes"})
in
  Dedup