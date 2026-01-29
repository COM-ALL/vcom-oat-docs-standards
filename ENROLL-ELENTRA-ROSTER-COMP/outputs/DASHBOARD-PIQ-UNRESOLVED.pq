// DASHBOARD-PIQ-UNRESOLVED - PIQ rotations with no Elentra match (drill-through detail)
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
    
    // 2) Deduplicate on ROTATION_UID (business rule compliance)
    UtilityDedup = Table.Distinct(UtilityRaw, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    
    // 3) Filter for PIQ-only rotations (no Elentra match)
    PIQUnresolved = Table.SelectRows(
        UtilityDedup,
        each [ENHANCED_MATCH_CATEGORY] = "ONLY_IN_PIQ"
    ),
    
    // 4) Add dashboard metadata
    #"Added dashboard metadata" = Table.AddColumn(
        PIQUnresolved,
        "DASHBOARD_CATEGORY",
        each "PIQ_UNRESOLVED",
        type text
    ),
    
    #"Added last updated" = Table.AddColumn(
        #"Added dashboard metadata",
        "DASHBOARD_LAST_UPDATED",
        each fnDATE_ActiveAsOf(),
        type date
    ),
    
    // 5) Select all available columns for drill-through analysis
    #"All columns for analysis" = Table.SelectColumns(
        #"Added last updated",
        {
            // Primary keys and identifiers
            "MDCO_ENROLL_LRN_ROTATION_UID",
            "MDCO_ENROLL_COURSE_UID",
            "MDCO_USR_UID", 
            "MDCO_COURSE_UID",
            "MDCO_CAMPUS_UID",
            
            // PIQ-specific fields (populated for PIQ-only records)
            "PIQ_MDCO_ENROLL_COURSE_UID",
            "PIQ_MDCO_USR_UID",
            "PIQ_MDCO_COURSE_UID", 
            "PIQ_MDCO_CAMPUS",
            "PIQ_STARTDATE",
            "PIQ_ENDDATE",
            "PIQ_DATE_OF_RECORD",
            "PIQ_RECORD_ACTIVE",
            "PIQ_SYS",
            
            // Analysis fields
            "ENHANCED_MATCH_CATEGORY",
            "VARIANCE_DETAILS", 
            "COURSE_ENROLLMENT_COUNT",
            "ANALYSIS_PRIORITY",
            
            // System metadata  
            "DATE_OF_RECORD",
            "RECORD_ACTIVE",
            "SYS",
            
            // Dashboard metadata
            "DASHBOARD_CATEGORY", 
            "DASHBOARD_LAST_UPDATED",
            
            // Elentra fields (will be null for PIQ-only)
            "ELENTRA_MDCODE",
            "SITE_CODE",
            "SCHEDULE_BLOCK", 
            "ELE_STARTDATE",
            "ELE_ENDDATE",
            "ELE_ENROLL_STATUS"
        },
        MissingField.Ignore
    ),
    
    // 6) Sort by PIQ start date and student for logical drill-through order
    #"Sorted for drill-through" = Table.Sort(
        #"All columns for analysis",
        {
            {"PIQ_STARTDATE", Order.Ascending},
            {"PIQ_MDCO_USR_UID", Order.Ascending}, 
            {"PIQ_MDCO_COURSE_UID", Order.Ascending}
        }
    )

in
    #"Sorted for drill-through"