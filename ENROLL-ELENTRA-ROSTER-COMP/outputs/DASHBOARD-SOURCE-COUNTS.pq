// DASHBOARD-SOURCE-COUNTS - System management source counts with deduplication
let
    // 1) ELENTRA COUNTS - Load from published datalake tables (already processed)
    ElentraAll_Raw = 
        let
            Source = Lakehouse.Contents(null),
            Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
            #"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
            #"Navigation 2" = #"Navigation 1"{[Id = "MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE", ItemKind = "Table"]}[Data]
        in
            #"Navigation 2",
    
    ElentraAIM_Raw = 
        let
            Source = Lakehouse.Contents(null),
            Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
            #"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
            #"Navigation 2" = #"Navigation 1"{[Id = "MDCO-ENROLL-ELENTRA-ROTATIONS-AIM", ItemKind = "Table"]}[Data]
        in
            #"Navigation 2",
    
    // Deduplicate Elentra ALL (ACTIVE + AIM combined for total count)
    ElentraCombined = Table.Combine({ElentraAll_Raw, ElentraAIM_Raw}),
    ElentraAll_Dedup = Table.Distinct(ElentraCombined, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    
    // Deduplicate Elentra AIM only
    ElentraAIM_Dedup = Table.Distinct(ElentraAIM_Raw, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    
    // Deduplicate Elentra Non-AIM (ACTIVE table already excludes AIM)
    ElentraNonAIM_Dedup = Table.Distinct(ElentraAll_Raw, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    
    // 2) PIQ COUNTS - Load from published datalake tables (already processed)
    PIQAll_Raw = 
        let
            Source = Lakehouse.Contents(null),
            Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
            #"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
            #"Navigation 2" = #"Navigation 1"{[Id = "MDCO-ENROLL-PIQ-ROTATION-SCHEDULED", ItemKind = "Table"]}[Data]
        in
            #"Navigation 2",
    
    PIQAIM_Raw = 
        let
            Source = Lakehouse.Contents(null),
            Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
            #"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
            #"Navigation 2" = #"Navigation 1"{[Id = "MDCO-ENROLL-PIQ-ROTATIONS-AIM", ItemKind = "Table"]}[Data]
        in
            #"Navigation 2",
    
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