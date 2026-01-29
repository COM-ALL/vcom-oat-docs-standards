let
  Source = Table.NestedJoin(src_PIQ_StudentAssignedTags_csv, {"*StudentID"}, #"src_PIQ-StudentTemplate_csv", {"*StudentID"}, "src_PIQ-StudentTemplate_csv", JoinKind.Inner),
  #"Removed columns" = Table.RemoveColumns(Source, {"src_PIQ-StudentTemplate_csv"}),
  #"Reordered columns" = Table.ReorderColumns(#"Removed columns", {"*StudentID", "Action (Delete)", "Notes", "EndDate", "StartDate", "*Tag(path example: campus||southern or status||academic||active)", "AdmittedClass", "Class", "FirstName", "LastName"})
in
  #"Reordered columns"