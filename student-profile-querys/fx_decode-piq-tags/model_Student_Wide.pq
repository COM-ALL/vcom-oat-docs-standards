let
  TagsWide = dim_Tags_Wide,
  Resolved = dim_AcademicStatusResolved,

  // Join the resolved academic status onto the wide table
  Merged = Table.NestedJoin(
      TagsWide, {"StudentID","Class"},
      Resolved, {"StudentID","Class"},
      "StatusTable",
      JoinKind.LeftOuter
  ),

  Expanded = Table.ExpandTableColumn(
      Merged, "StatusTable",
      {"RESOLVED ACADEMIC STATUS","RESOLVED STATUS DATE"},
      {"RESOLVED ACADEMIC STATUS","RESOLVED STATUS DATE"}
  ),
  #"Inserted conditional column" = Table.AddColumn(Expanded, "ACASTATUS_TF", each if [RESOLVED ACADEMIC STATUS] = "ACTIVE" then true else false),
  #"Changed column type" = Table.TransformColumnTypes(#"Inserted conditional column", {{"ACASTATUS_TF", type logical}, {"Class", type text}, {"RESOLVED ACADEMIC STATUS", type text}, {"RESOLVED STATUS DATE", type date}})

in
  #"Changed column type"