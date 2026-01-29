// DASHBOARD-DEDUPLICATION-LOG - Track deduplication impact across all rotation tables
let
    // 1) ELENTRA DEDUPLICATION ANALYSIS
    ElentraActive_Raw = #"MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE",
    ElentraAIM_Raw = #"MDCO-ENROLL-ELENTRA-ROTATIONS-AIM",
    
    ElentraActive_Dedup = Table.Distinct(ElentraActive_Raw, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    ElentraAIM_Dedup = Table.Distinct(ElentraAIM_Raw, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    
    // 2) PIQ DEDUPLICATION ANALYSIS
    PIQ_Raw = #"MDCO-ENROLL-PIQ-ROTATION-SCHEDULED",
    PIQAIM_Raw = #"MDCO-ENROLL-PIQ-ROTATIONS-AIM",
    
    PIQ_Dedup = Table.Distinct(PIQ_Raw, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    PIQAIM_Dedup = Table.Distinct(PIQAIM_Raw, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    
    // 3) UTILITY TABLE DEDUPLICATION
    Utility_Raw = #"MDCO-ENROLL-ROTATIONS-UTILITY",
    Utility_Dedup = Table.Distinct(Utility_Raw, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    
    // 4) BUILD DEDUPLICATION SUMMARY
    DeduplicationLog = Table.FromRecords({
        [
            TABLE_NAME = "ELENTRA-ROTATIONS-ACTIVE",
            ORIGINAL_COUNT = Table.RowCount(ElentraActive_Raw),
            DEDUPLICATED_COUNT = Table.RowCount(ElentraActive_Dedup),
            DUPLICATES_REMOVED = Table.RowCount(ElentraActive_Raw) - Table.RowCount(ElentraActive_Dedup),
            DEDUP_PERCENTAGE = if Table.RowCount(ElentraActive_Raw) = 0 then 0 else 
                              (Table.RowCount(ElentraActive_Raw) - Table.RowCount(ElentraActive_Dedup)) / Table.RowCount(ElentraActive_Raw),
            DEDUP_KEY = "MDCO_ENROLL_LRN_ROTATION_UID",
            BUSINESS_RULE = "No learner in same rotation/block/location",
            LAST_UPDATED = fnDATE_ActiveAsOf()
        ],
        [
            TABLE_NAME = "ELENTRA-ROTATIONS-AIM", 
            ORIGINAL_COUNT = Table.RowCount(ElentraAIM_Raw),
            DEDUPLICATED_COUNT = Table.RowCount(ElentraAIM_Dedup),
            DUPLICATES_REMOVED = Table.RowCount(ElentraAIM_Raw) - Table.RowCount(ElentraAIM_Dedup),
            DEDUP_PERCENTAGE = if Table.RowCount(ElentraAIM_Raw) = 0 then 0 else
                              (Table.RowCount(ElentraAIM_Raw) - Table.RowCount(ElentraAIM_Dedup)) / Table.RowCount(ElentraAIM_Raw),
            DEDUP_KEY = "MDCO_ENROLL_LRN_ROTATION_UID",
            BUSINESS_RULE = "No learner in same rotation/block/location",
            LAST_UPDATED = fnDATE_ActiveAsOf()
        ],
        [
            TABLE_NAME = "PIQ-ROTATION-SCHEDULED",
            ORIGINAL_COUNT = Table.RowCount(PIQ_Raw),
            DEDUPLICATED_COUNT = Table.RowCount(PIQ_Dedup),
            DUPLICATES_REMOVED = Table.RowCount(PIQ_Raw) - Table.RowCount(PIQ_Dedup),
            DEDUP_PERCENTAGE = if Table.RowCount(PIQ_Raw) = 0 then 0 else
                              (Table.RowCount(PIQ_Raw) - Table.RowCount(PIQ_Dedup)) / Table.RowCount(PIQ_Raw),
            DEDUP_KEY = "MDCO_ENROLL_LRN_ROTATION_UID", 
            BUSINESS_RULE = "No learner in same rotation/block/location",
            LAST_UPDATED = fnDATE_ActiveAsOf()
        ],
        [
            TABLE_NAME = "PIQ-ROTATIONS-AIM",
            ORIGINAL_COUNT = Table.RowCount(PIQAIM_Raw),
            DEDUPLICATED_COUNT = Table.RowCount(PIQAIM_Dedup), 
            DUPLICATES_REMOVED = Table.RowCount(PIQAIM_Raw) - Table.RowCount(PIQAIM_Dedup),
            DEDUP_PERCENTAGE = if Table.RowCount(PIQAIM_Raw) = 0 then 0 else
                              (Table.RowCount(PIQAIM_Raw) - Table.RowCount(PIQAIM_Dedup)) / Table.RowCount(PIQAIM_Raw),
            DEDUP_KEY = "MDCO_ENROLL_LRN_ROTATION_UID",
            BUSINESS_RULE = "No learner in same rotation/block/location", 
            LAST_UPDATED = fnDATE_ActiveAsOf()
        ],
        [
            TABLE_NAME = "ROTATIONS-UTILITY",
            ORIGINAL_COUNT = Table.RowCount(Utility_Raw),
            DEDUPLICATED_COUNT = Table.RowCount(Utility_Dedup),
            DUPLICATES_REMOVED = Table.RowCount(Utility_Raw) - Table.RowCount(Utility_Dedup),
            DEDUP_PERCENTAGE = if Table.RowCount(Utility_Raw) = 0 then 0 else
                              (Table.RowCount(Utility_Raw) - Table.RowCount(Utility_Dedup)) / Table.RowCount(Utility_Raw),
            DEDUP_KEY = "MDCO_ENROLL_LRN_ROTATION_UID",
            BUSINESS_RULE = "No learner in same rotation/block/location",
            LAST_UPDATED = fnDATE_ActiveAsOf()
        ]
    }),
    
    // 5) Set proper column types
    #"Set column types" = Table.TransformColumnTypes(
        DeduplicationLog,
        {
            {"TABLE_NAME", type text},
            {"ORIGINAL_COUNT", Int64.Type},
            {"DEDUPLICATED_COUNT", Int64.Type}, 
            {"DUPLICATES_REMOVED", Int64.Type},
            {"DEDUP_PERCENTAGE", Percentage.Type},
            {"DEDUP_KEY", type text},
            {"BUSINESS_RULE", type text},
            {"LAST_UPDATED", type date}
        }
    )

in
    #"Set column types"