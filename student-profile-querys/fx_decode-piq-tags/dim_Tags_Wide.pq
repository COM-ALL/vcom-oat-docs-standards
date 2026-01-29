// dim_Tags_Wide

let
  Source = stg_StudentTags_Long,

  // Exclude Academic Status from the pivoted tags — it will come from the resolved table
  NoAcad = Table.SelectRows(Source, each [Tag Name] <> "ACADEMIC STATUS"),

  // De-dupe
  Dedup = Table.Distinct(NoAcad, {"StudentID","Class","Tag Name","Tag Value"}),

  // Concatenate Tag Values per (StudentID, Class, Tag Name)
  Grouped = Table.Group(
      Dedup,
      {"StudentID","Class","Tag Name"},
      {
        {
          "CatValue",
          (t as table) as text =>
            let
              vals    = List.Distinct(Table.Column(t, "Tag Value")),
              trimmed = List.Select(List.Transform(vals, each Text.Trim(_)), each _ <> ""),
              sorted  = List.Sort(trimmed, Order.Ascending),
              joined  = Text.Combine(sorted, "; ")
            in
              joined,
          type text
        }
      }
  ),

  // Pivot Tag Name -> columns
  Pivoted = Table.Pivot(
      Table.TransformColumnTypes(Grouped, {{"Tag Name", type text}}),
      List.Distinct(Grouped[Tag Name]),
      "Tag Name",
      "CatValue"
  )
in
  Pivoted