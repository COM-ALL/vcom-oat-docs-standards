// DASHBOARD-MATCH-ANALYSIS - Non-AIM match analysis counts
let
    // 1) Load utility table from published datalake (already processed and optimized)
    UtilityRaw = 
        let
            Source = Lakehouse.Contents(null),
            Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
            #"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
            #"Navigation 2" = #"Navigation 1"{[Id = "MDCO-ENROLL-ROTATIONS-UTILITY", ItemKind = "Table"]}[Data]
        in
            #"Navigation 2",
    
    // 2) Deduplicate utility table on ROTATION_UID
    UtilityDedup = Table.Distinct(UtilityRaw, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    
    // 3) Group by enhanced match category to get counts
    MatchCounts = Table.Group(
        UtilityDedup,
        {"ENHANCED_MATCH_CATEGORY"},
        {{"COUNT_ROTATIONS", each Table.RowCount(_), Int64.Type}}
    ),
    
    // 4) Pivot match categories into dashboard-friendly format
    MatchCountsPivot = Table.Pivot(
        MatchCounts,
        List.Distinct(MatchCounts[ENHANCED_MATCH_CATEGORY]),
        "ENHANCED_MATCH_CATEGORY",
        "COUNT_ROTATIONS",
        List.Sum
    ),
    
    // 5) Build summary metrics for dashboard (consolidate match types)
    MatchSummary = 
        let
            // Get individual counts (with null handling)
            Matched = Record.FieldOrDefault(MatchCountsPivot{0}?, "MATCHED", 0) +
                     Record.FieldOrDefault(MatchCountsPivot{0}?, "MATCHED_LOCATION_VARIANCE", 0) +
                     Record.FieldOrDefault(MatchCountsPivot{0}?, "MATCHED_DATE_VARIANCE", 0) +
                     Record.FieldOrDefault(MatchCountsPivot{0}?, "THREE_POINT_MATCH_APPROVED", 0),
            ElentraOnly = Record.FieldOrDefault(MatchCountsPivot{0}?, "ONLY_IN_ELENTRA", 0),
            PIQOnly = Record.FieldOrDefault(MatchCountsPivot{0}?, "ONLY_IN_PIQ", 0),
            Longitudinal = Record.FieldOrDefault(MatchCountsPivot{0}?, "LONGITUDINAL_COURSE_PATTERN", 0)
        in
            Table.FromRecords({
                [
                    MATCH_TYPE = "MATCHED_ROTATION_BOOKINGS",
                    COUNT_NON_AIM_ROTATIONS = Matched,
                    DESCRIPTION = "PIQ and Elentra rotations with successful match (includes location/date variance)",
                    LAST_UPDATED = fnDATE_ActiveAsOf()
                ],
                [
                    MATCH_TYPE = "ELENTRA_NO_MATCH",
                    COUNT_NON_AIM_ROTATIONS = ElentraOnly,
                    DESCRIPTION = "Elentra rotations with no corresponding PIQ booking",
                    LAST_UPDATED = fnDATE_ActiveAsOf()
                ],
                [
                    MATCH_TYPE = "PIQ_NO_MATCH", 
                    COUNT_NON_AIM_ROTATIONS = PIQOnly,
                    DESCRIPTION = "PIQ rotations with no corresponding Elentra booking",
                    LAST_UPDATED = fnDATE_ActiveAsOf()
                ],
                [
                    MATCH_TYPE = "LONGITUDINAL_PATTERN",
                    COUNT_NON_AIM_ROTATIONS = Longitudinal,
                    DESCRIPTION = "Courses with high enrollment indicating longitudinal vs rotation pattern",
                    LAST_UPDATED = fnDATE_ActiveAsOf()
                ]
            }),
    
    // 6) Set proper column types
    #"Set column types" = Table.TransformColumnTypes(
        MatchSummary,
        {
            {"MATCH_TYPE", type text},
            {"COUNT_NON_AIM_ROTATIONS", Int64.Type},
            {"DESCRIPTION", type text},
            {"LAST_UPDATED", type date}
        }
    )

in
    #"Set column types"