let
  Source = fact_AcademicStatusHistory,

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

            // Trump checks
            HasWithdrawn = List.AnyTrue(List.Transform(T0[Status], each Text.Contains(_, "WITHDRAWN"))),
            HasGraduated = List.AnyTrue(List.Transform(T0[Status], each Text.Contains(_, "GRADUATED"))),

            TrumpStatus =
              if HasWithdrawn then "WITHDRAWN"
              else if HasGraduated then "GRADUATED"
              else null,

            // Date for trump (latest non-null StartDate for the chosen trump)
            TrumpRows     = if TrumpStatus <> null then Table.SelectRows(T0, each [Status] = TrumpStatus and [StartDate] <> null) else #table({},{}),
            TrumpRowsSort = if TrumpStatus <> null and Table.RowCount(TrumpRows) > 0 then Table.Sort(TrumpRows, {{"StartDate", Order.Descending}}) else TrumpRows,
            TrumpDate     = if TrumpStatus <> null and Table.RowCount(TrumpRowsSort) > 0 then TrumpRowsSort{0}[StartDate] else null,

            // Non-trump (e.g., ACTIVE, LOA, etc.)
            NonTrump = if TrumpStatus = null then Table.SelectRows(T0, each not List.Contains({"WITHDRAWN","GRADUATED"}, [Status])) else #table({},{}),
            DatedNT  = if TrumpStatus = null then Table.SelectRows(NonTrump, each [StartDate] <> null) else #table({},{}),
            DatedNTSort = if TrumpStatus = null and Table.RowCount(DatedNT) > 0 then Table.Sort(DatedNT, {{"StartDate", Order.Descending}}) else DatedNT,

            LatestNonTrumpStatus = if TrumpStatus = null and Table.RowCount(DatedNTSort) > 0 then DatedNTSort{0}[Status] else null,
            LatestNonTrumpDate   = if TrumpStatus = null and Table.RowCount(DatedNTSort) > 0 then DatedNTSort{0}[StartDate] else null,

            // If no dated non-trump, fallback: prefer ACTIVE, else LOA, else concat all non-trump statuses
            FallbackStatus =
              if TrumpStatus <> null then null else
              let vals = if Table.RowCount(NonTrump) > 0 then List.Distinct(NonTrump[Status]) else {}
              in if List.Contains(vals, "ACTIVE") then "ACTIVE"
                 else if List.Contains(vals, "LOA") then "LOA"
                 else if List.Count(vals) > 0 then Text.Combine(List.Sort(vals, Order.Ascending), "; ")
                 else null,

            FinalStatus = if TrumpStatus <> null then TrumpStatus else ( if LatestNonTrumpStatus <> null then LatestNonTrumpStatus else FallbackStatus ),
            FinalDate   = if TrumpStatus <> null then TrumpDate else LatestNonTrumpDate
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