let
  Source = stg_StudentTags_Long,
  OnlyAcademic = Table.SelectRows(Source, each [Tag Name] = "ACADEMIC STATUS"),

  // Keep relevant cols; rename for clarity
  Selected = Table.SelectColumns(OnlyAcademic, {"StudentID","Class","StartDate","EndDate","Notes","Tag Value"}),
  Renamed  = Table.RenameColumns(Selected, {{"Tag Value","Status"}}),

  // De-dupe exact repeats
  Dedup    = Table.Distinct(Renamed, {"StudentID","Class","Status","StartDate","EndDate","Notes"})
in
  Dedup