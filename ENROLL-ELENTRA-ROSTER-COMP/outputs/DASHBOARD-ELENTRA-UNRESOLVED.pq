// DASHBOARD-ELENTRA-UNRESOLVED - Elentra rotations with no PIQ match (drill-through detail)
let
    // 1) Load deduplicated utility table
    UtilityRaw = #"MDCO-ENROLL-ROTATIONS-UTILITY",
    
    // 2) Deduplicate on ROTATION_UID (business rule compliance)
    UtilityDedup = Table.Distinct(UtilityRaw, {"MDCO_ENROLL_LRN_ROTATION_UID"}),
    
    // 3) Filter for Elentra-only rotations (no PIQ match)
    ElentraUnresolved = Table.SelectRows(
        UtilityDedup, 
        each [ENHANCED_MATCH_CATEGORY] = "ONLY_IN_ELENTRA"
    ),
    
    // 4) Add dashboard metadata
    #"Added dashboard metadata" = Table.AddColumn(
        ElentraUnresolved,
        "DASHBOARD_CATEGORY",
        each "ELENTRA_UNRESOLVED",
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
            
            // Elentra-specific fields
            "ELENTRA_MDCODE",
            "SITE_CODE", 
            "SCHEDULE_BLOCK",
            "ELE_STARTDATE",
            "ELE_ENDDATE", 
            "ELE_ENROLL_STATUS",
            
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
            
            // PIQ fields (will be null for Elentra-only)
            "PIQ_MDCO_ENROLL_COURSE_UID",
            "PIQ_MDCO_USR_UID", 
            "PIQ_MDCO_COURSE_UID",
            "PIQ_MDCO_CAMPUS",
            "PIQ_STARTDATE",
            "PIQ_ENDDATE",
            "PIQ_DATE_OF_RECORD", 
            "PIQ_RECORD_ACTIVE",
            "PIQ_SYS"
        },
        MissingField.Ignore
    ),
    
    // 6) Sort by start date and student for logical drill-through order
    #"Sorted for drill-through" = Table.Sort(
        #"All columns for analysis",
        {
            {"ELE_STARTDATE", Order.Ascending},
            {"MDCO_USR_UID", Order.Ascending},
            {"MDCO_COURSE_UID", Order.Ascending}
        }
    )

in
    #"Sorted for drill-through"