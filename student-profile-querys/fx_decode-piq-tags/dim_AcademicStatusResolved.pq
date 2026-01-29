// dim_AcademicStatusResolved

let
  Source = fact_AcademicStatusHistory,

  // Since source now only includes active students, simplify the resolution logic
  // Group per StudentID + Class and resolve a single status + date
  Grouped = Table.Group(
    Source,
    {"StudentID","Class"},
    {
      {
        "Resolved",
        (t as table) as record =>
          let
            // Ensure upper (defensive)
            T0 = Table.TransformColumns(t, {{"Status", each Text.Upper(_), type text}}),

            // Since graduated/withdrawn are already filtered out, focus on current status resolution
            // Get the most recent status entry
            DatedRows = Table.SelectRows(T0, each [StartDate] <> null),
            SortedByDate = if Table.RowCount(DatedRows) > 0 then Table.Sort(DatedRows, {{"StartDate", Order.Descending}}) else DatedRows,
            
            LatestStatus = if Table.RowCount(SortedByDate) > 0 then SortedByDate{0}[Status] else null,
            LatestDate = if Table.RowCount(SortedByDate) > 0 then SortedByDate{0}[StartDate] else null,

            // If no dated entries, fallback: prefer ACTIVE, else LOA, else concatenate all statuses
            FallbackStatus =
              if LatestStatus <> null then null else
              let vals = if Table.RowCount(T0) > 0 then List.Distinct(T0[Status]) else {}
              in if List.Contains(vals, "ACTIVE") then "ACTIVE"
                 else if List.Contains(vals, "LOA") then "LOA"
                 else if List.Count(vals) > 0 then Text.Combine(List.Sort(vals, Order.Ascending), "; ")
                 else null,

            FinalStatus = if LatestStatus <> null then LatestStatus else FallbackStatus,
            FinalDate = LatestDate
          in
            [ResolvedAcademicStatus = FinalStatus, ResolvedStatusDate = FinalDate],
        type record
      }
    }
  ),

  Expanded = Table.ExpandRecordColumn(
    Grouped, "Resolved",
    {"ResolvedAcademicStatus","ResolvedStatusDate"},
    {"RESOLVED ACADEMIC STATUS","RESOLVED STATUS DATE"}
  )
in
  Expanded