// DASHBOARD-SOURCE-COUNTS - System management source counts with deduplication
let
    // 1) ELENTRA COUNTS - Load and deduplicate source tables
    ElentraAll_Raw = #"MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE",
    ElentraAIM_Raw = #"MDCO-ENROLL-ELENTRA-ROTATIONS-AIM",
    
    // Deduplicate Elentra ALL (ACTIVE + AIM combined for total count)
    ElentraCombined = Table.Combine({ElentraAll_Raw, ElentraAIM_Raw}),
    ElentraAll_Dedup = Table.Distinct(ElentraCombined, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    
    // Deduplicate Elentra AIM only
    ElentraAIM_Dedup = Table.Distinct(ElentraAIM_Raw, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    
    // Deduplicate Elentra Non-AIM (ACTIVE table already excludes AIM)
    ElentraNonAIM_Dedup = Table.Distinct(ElentraAll_Raw, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    
    // 2) PIQ COUNTS - Load and deduplicate source tables
    PIQAll_Raw = #"MDCO-ENROLL-PIQ-ROTATION-SCHEDULED",
    PIQAIM_Raw = #"MDCO-ENROLL-PIQ-ROTATIONS-AIM",
    
    // Deduplicate PIQ ALL (SCHEDULED + AIM combined for total count)
    // Note: PIQ-AIM table uses MDCO_USR_UID as key, SCHEDULED uses ROTATION_UID
    PIQAll_Dedup = Table.Distinct(PIQAll_Raw, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    
    // Deduplicate PIQ AIM only (using MDCO_USR_UID since no rotation UID calculated)
    PIQAIM_Dedup = Table.Distinct(PIQAIM_Raw, {"MDCO_USR_UID"}),
    
    // Deduplicate PIQ Non-AIM (SCHEDULED table already excludes AIM)
    PIQNonAIM_Dedup = Table.Distinct(PIQAll_Raw, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    
    // 3) Build source count summary table
    SourceCounts = 
        Table.FromRecords({
            [
                SOURCE_SYSTEM = "ELENTRA", 
                POPULATION = "ALL", 
                COUNT_ROTATION_BOOKINGS = Table.RowCount(ElentraAll_Dedup),
                LAST_UPDATED = fnDATE_ActiveAsOf()
            ],
            [
                SOURCE_SYSTEM = "ELENTRA", 
                POPULATION = "AIM", 
                COUNT_ROTATION_BOOKINGS = Table.RowCount(ElentraAIM_Dedup),
                LAST_UPDATED = fnDATE_ActiveAsOf()
            ],
            [
                SOURCE_SYSTEM = "ELENTRA", 
                POPULATION = "NON-AIM", 
                COUNT_ROTATION_BOOKINGS = Table.RowCount(ElentraNonAIM_Dedup),
                LAST_UPDATED = fnDATE_ActiveAsOf()
            ],
            [
                SOURCE_SYSTEM = "PIQ", 
                POPULATION = "ALL", 
                COUNT_ROTATION_BOOKINGS = Table.RowCount(PIQAll_Dedup) + Table.RowCount(PIQAIM_Dedup),
                LAST_UPDATED = fnDATE_ActiveAsOf()
            ],
            [
                SOURCE_SYSTEM = "PIQ", 
                POPULATION = "AIM", 
                COUNT_ROTATION_BOOKINGS = Table.RowCount(PIQAIM_Dedup),
                LAST_UPDATED = fnDATE_ActiveAsOf()
            ],
            [
                SOURCE_SYSTEM = "PIQ", 
                POPULATION = "NON-AIM", 
                COUNT_ROTATION_BOOKINGS = Table.RowCount(PIQNonAIM_Dedup),
                LAST_UPDATED = fnDATE_ActiveAsOf()
            ]
        }),
    
    // 4) Set proper column types
    #"Set column types" = Table.TransformColumnTypes(
        SourceCounts,
        {
            {"SOURCE_SYSTEM", type text},
            {"POPULATION", type text},
            {"COUNT_ROTATION_BOOKINGS", Int64.Type},
            {"LAST_UPDATED", type date}
        }
    )

in
    #"Set column types"