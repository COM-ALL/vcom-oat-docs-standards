let
    // 1) Source Elentra & PIQ rotation tables
    srcElentra =
        #"MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE",
    srcPIQ =
        #"MDCO-ENROLL-PIQ-ROTATION-SCHEDULED",

    // 2) Standardize column names to underscore style (defensive;
    //    MissingField.Ignore means we won't error if some already match)
    ElentraStd =
        Table.RenameColumns(
            srcElentra,
            {
                {"MDCO-ENROLL-LRN-ROTATION-UID", "MDCO_ENROLL_LRN_ROTATION_UID"},
                {"MDCO-ENROLL-COURSE-UID",       "MDCO_ENROLL_COURSE_UID"},
                {"MDCO-COURSE-UID",              "MDCO_COURSE_UID"},
                {"MDCO-CAMPUS-UID",              "MDCO_CAMPUS_UID"},
                {"MDCO-USR-UID",                 "MDCO_USR_UID"},
                {"ELE-STARTDATE",                "ELE_STARTDATE"},
                {"ELE-ENDDATE",                  "ELE_ENDDATE"},
                {"ELE-ENROLL-STATUS",            "ELE_ENROLL_STATUS"}
            },
            MissingField.Ignore
        ),

    PIQStd =
        Table.RenameColumns(
            srcPIQ,
            {
                {"MDCO-ENROLL-LRN-ROTATION-UID", "MDCO_ENROLL_LRN_ROTATION_UID"},
                {"MDCO-ENROLL-COURSE-UID",       "MDCO_ENROLL_COURSE_UID"},
                {"MDCO-COURSE-UID",              "MDCO_COURSE_UID"},
                {"MDCO-CAMPUS",                  "MDCO_CAMPUS"},
                {"DATE-OF-RECORD",               "DATE_OF_RECORD"}
            },
            MissingField.Ignore
        ),

    // 3) Ensure the rotation UID is text in both tables
    ElentraKeysFixed =
        Table.TransformColumnTypes(
            ElentraStd,
            {{"MDCO_ENROLL_LRN_ROTATION_UID", type text}},
            null
        ),

    PIQKeysFixed =
        Table.TransformColumnTypes(
            PIQStd,
            {{"MDCO_ENROLL_LRN_ROTATION_UID", type text}},
            null
        ),

    // 4) Left join: Elentra rotations as base, PIQ by rotation UID
    #"Joined PIQ on Elentra" =
        Table.NestedJoin(
            ElentraKeysFixed,
            {"MDCO_ENROLL_LRN_ROTATION_UID"},
            PIQKeysFixed,
            {"MDCO_ENROLL_LRN_ROTATION_UID"},
            "PIQ",
            JoinKind.LeftOuter
        ),

    #"Expanded PIQ" =
        Table.ExpandTableColumn(
            #"Joined PIQ on Elentra",
            "PIQ",
            {
                "MDCO_ENROLL_COURSE_UID",
                "MDCO_USR_UID",
                "MDCO_COURSE_UID",
                "MDCO_CAMPUS",
                "startdate",
                "enddate",
                "DATE_OF_RECORD",
                "RECORD_ACTIVE",
                "SYS"
            },
            {
                "PIQ_MDCO_ENROLL_COURSE_UID",
                "PIQ_MDCO_USR_UID",
                "PIQ_MDCO_COURSE_UID",
                "PIQ_MDCO_CAMPUS",
                "PIQ_STARTDATE",
                "PIQ_ENDDATE",
                "PIQ_DATE_OF_RECORD",
                "PIQ_RECORD_ACTIVE",
                "PIQ_SYS"
            }
        ),

    // 5) Enhanced match analysis with litmus tests for edge cases
    
    // 5a) Longitudinal course detection (enrollment > 20 indicates longitudinal vs rotation)
    #"Course enrollment counts" =
        Table.Group(
            #"Expanded PIQ",
            {"MDCO_COURSE_UID", "ELE_STARTDATE"},
            {{"EnrollmentCount", each Table.RowCount(_), Int64.Type}}
        ),
    
    #"Join enrollment counts" =
        Table.NestedJoin(
            #"Expanded PIQ",
            {"MDCO_COURSE_UID", "ELE_STARTDATE"},
            #"Course enrollment counts",
            {"MDCO_COURSE_UID", "ELE_STARTDATE"},
            "EnrollCounts",
            JoinKind.LeftOuter
        ),
    
    #"Expanded enrollment counts" =
        Table.ExpandTableColumn(
            #"Join enrollment counts",
            "EnrollCounts",
            {"EnrollmentCount"},
            {"COURSE_ENROLLMENT_COUNT"}
        ),

    // 5b) Add basic match category before enhanced analysis
    #"Added basic match category" =
        Table.AddColumn(
            #"Expanded enrollment counts",
            "MATCH_CATEGORY",
            each if [PIQ_SYS] <> null
                 then "MATCHED"
                 else "ONLY_IN_ELENTRA",
            type text
        ),

    // 5c) Three-point matching analysis (student + course + start date, allowing location variance)
    #"Enhanced match category" =
        Table.AddColumn(
            #"Added basic match category",
            "ENHANCED_MATCH_CATEGORY",
            each 
                let
                    IsLongitudinal = [COURSE_ENROLLMENT_COUNT] > 20,
                    HasPIQMatch = [PIQ_SYS] <> null,
                    StartDateMatch = [ELE_STARTDATE] = [PIQ_STARTDATE],
                    EndDateVariance = if [ELE_ENDDATE] <> null and [PIQ_ENDDATE] <> null 
                                    then Duration.Days([PIQ_ENDDATE] - [ELE_ENDDATE])
                                    else null,
                    IsWeekendVariance = (EndDateVariance = 2 or EndDateVariance = -2),
                    LocationVariance = [MDCO_CAMPUS_UID] <> [PIQ_MDCO_CAMPUS]
                in
                    if IsLongitudinal then "LONGITUDINAL_COURSE_PATTERN"
                    else if HasPIQMatch and StartDateMatch and not LocationVariance then "MATCHED"
                    else if HasPIQMatch and StartDateMatch and LocationVariance then "MATCHED_LOCATION_VARIANCE"
                    else if HasPIQMatch and StartDateMatch and IsWeekendVariance then "MATCHED_DATE_VARIANCE"
                    else if HasPIQMatch and StartDateMatch then "THREE_POINT_MATCH_APPROVED"
                    else [MATCH_CATEGORY],
            type text
        ),

    // 5d) Add detailed variance analysis for reporting
    #"Added variance details" =
        Table.AddColumn(
            #"Enhanced match category",
            "VARIANCE_DETAILS",
            each 
                let
                    StartMatch = [ELE_STARTDATE] = [PIQ_STARTDATE],
                    EndVariance = if [ELE_ENDDATE] <> null and [PIQ_ENDDATE] <> null 
                                then Duration.Days([PIQ_ENDDATE] - [ELE_ENDDATE])
                                else null,
                    LocationMatch = [MDCO_CAMPUS_UID] = [PIQ_MDCO_CAMPUS]
                in
                    if not StartMatch then "START_DATE_MISMATCH"
                    else if EndVariance <> null and EndVariance <> 0 then "END_DATE_VARIANCE_" & Text.From(EndVariance) & "_DAYS"
                    else if not LocationMatch then "LOCATION_VARIANCE"
                    else if [COURSE_ENROLLMENT_COUNT] > 20 then "HIGH_ENROLLMENT_LONGITUDINAL"
                    else "NO_VARIANCE",
            type text
        ),

    // 6) Build match flags for Elentra-based rows (updated to use enhanced categories)
    ElentraRotationUIDs =
        List.Distinct(
            Table.Column(ElentraKeysFixed, "MDCO_ENROLL_LRN_ROTATION_UID")
        ),

    #"Filtered PIQ-only" =
        Table.SelectRows(
            PIQKeysFixed,
            each not List.Contains(
                ElentraRotationUIDs,
                [MDCO_ENROLL_LRN_ROTATION_UID]
            )
        ),

    // 7) Shape PIQ-only rows into aligned schema, flag as ONLY_IN_PIQ
    #"PIQ-only shaped" =
        let
            WithFlag =
                Table.AddColumn(
                    #"Filtered PIQ-only",
                    "ENHANCED_MATCH_CATEGORY",
                    each "ONLY_IN_PIQ",
                    type text
                ),
            WithVariance =
                Table.AddColumn(
                    WithFlag,
                    "VARIANCE_DETAILS",
                    each "PIQ_EXCLUSIVE",
                    type text
                )
        in
            WithVariance,

    // 8) Select common output columns for Elentra-based rows
    #"Elentra subset" =
        Table.SelectColumns(
            #"Added variance details",
            {
                "MDCO_ENROLL_LRN_ROTATION_UID",
                "MDCO_ENROLL_COURSE_UID",
                "MDCO_COURSE_UID",
                "MDCO_CAMPUS_UID",
                "MDCO_USR_UID",
                "ELENTRA_MDCODE",
                "SITE_CODE",
                "SCHEDULE_BLOCK",
                "ELE_STARTDATE",
                "ELE_ENDDATE",
                "ELE_ENROLL_STATUS",
                "DATE_OF_RECORD",
                "RECORD_ACTIVE",
                "SYS",
                // PIQ side (may be null if ONLY_IN_ELENTRA)
                "PIQ_MDCO_ENROLL_COURSE_UID",
                "PIQ_MDCO_USR_UID",
                "PIQ_MDCO_COURSE_UID",
                "PIQ_MDCO_CAMPUS",
                "PIQ_STARTDATE",
                "PIQ_ENDDATE",
                "PIQ_DATE_OF_RECORD",
                "PIQ_RECORD_ACTIVE",
                "PIQ_SYS",
                "ENHANCED_MATCH_CATEGORY",
                "VARIANCE_DETAILS",
                "COURSE_ENROLLMENT_COUNT"
            },
            MissingField.Ignore
        ),

 // 9) Select and align columns for PIQ-only rows
    #"PIQ subset" =
        let
            // Align PIQ column names to same pattern used in Elentra subset
            Renamed =
                Table.RenameColumns(
                    #"PIQ-only shaped",
                    {
                        {"MDCO_ENROLL_COURSE_UID", "PIQ_MDCO_ENROLL_COURSE_UID"},
                        {"MDCO_USR_UID",           "PIQ_MDCO_USR_UID"},
                        {"MDCO_COURSE_UID",        "PIQ_MDCO_COURSE_UID"},
                        {"MDCO_CAMPUS",            "PIQ_MDCO_CAMPUS"},
                        {"startdate",              "PIQ_STARTDATE"},
                        {"enddate",                "PIQ_ENDDATE"}
                    },
                    MissingField.Ignore
                ),

            // Add null Elentra-side columns so schema matches (but DO NOT re-add DATE_OF_RECORD etc.)
            WithNulls =
                Table.AddColumn(
                    Table.AddColumn(
                        Table.AddColumn(
                            Table.AddColumn(
                                Table.AddColumn(
                                    Table.AddColumn(
                                        Table.AddColumn(
                                            Table.AddColumn(
                                                Table.AddColumn(
                                                    Renamed,
                                                    "MDCO_COURSE_UID",
                                                    each null,
                                                    type text
                                                ),
                                                "MDCO_CAMPUS_UID",
                                                each null,
                                                type text
                                            ),
                                            "MDCO_USR_UID",
                                            each null,
                                            type text
                                        ),
                                        "ELENTRA_MDCODE",
                                        each null,
                                        type text
                                    ),
                                    "SITE_CODE",
                                    each null,
                                    type text
                                ),
                                "SCHEDULE_BLOCK",
                                each null,
                                type any
                            ),
                            "ELE_STARTDATE",
                            each null,
                            type date
                        ),
                        "ELE_ENDDATE",
                        each null,
                        type date
                    ),
                    "ELE_ENROLL_STATUS",
                    each null,
                    type text
                )
        in
            Table.SelectColumns(
                WithNulls,
                {
                    "MDCO_ENROLL_LRN_ROTATION_UID",
                    // Elentra side (null for PIQ-only)
                    "MDCO_ENROLL_COURSE_UID",
                    "MDCO_COURSE_UID",
                    "MDCO_CAMPUS_UID",
                    "MDCO_USR_UID",
                    "ELENTRA_MDCODE",
                    "SITE_CODE",
                    "SCHEDULE_BLOCK",
                    "ELE_STARTDATE",
                    "ELE_ENDDATE",
                    "ELE_ENROLL_STATUS",
                    // Elentra DATE_OF_RECORD/RECORD_ACTIVE would be null here;
                    // we keep the PIQ ones instead as separate fields.
                    "DATE_OF_RECORD",      // from PIQ
                    "RECORD_ACTIVE",       // from PIQ
                    "SYS",                 // from PIQ
                    // PIQ side
                    "PIQ_MDCO_ENROLL_COURSE_UID",
                    "PIQ_MDCO_USR_UID",
                    "PIQ_MDCO_COURSE_UID",
                    "PIQ_MDCO_CAMPUS",
                    "PIQ_STARTDATE",
                    "PIQ_ENDDATE",
                    "ENHANCED_MATCH_CATEGORY",
                    "VARIANCE_DETAILS"
                },
                MissingField.Ignore
            ),

    // 10) Combine Elentra-based and PIQ-only into one utility table
    MDCO_ENROLL_ROTATIONS_UTILITY =
        Table.Combine(
            {
                #"Elentra subset",
                #"PIQ subset"
            }
        ),

    // 11) Add analysis priority for dashboard filtering
    #"Added analysis priority" =
        Table.AddColumn(
            MDCO_ENROLL_ROTATIONS_UTILITY,
            "ANALYSIS_PRIORITY",
            each 
                if [ENHANCED_MATCH_CATEGORY] = "MATCHED" then "LOW"
                else if [ENHANCED_MATCH_CATEGORY] = "MATCHED_LOCATION_VARIANCE" then "LOW" 
                else if [ENHANCED_MATCH_CATEGORY] = "MATCHED_DATE_VARIANCE" then "LOW"
                else if [ENHANCED_MATCH_CATEGORY] = "THREE_POINT_MATCH_APPROVED" then "LOW"
                else if [ENHANCED_MATCH_CATEGORY] = "LONGITUDINAL_COURSE_PATTERN" then "MEDIUM"
                else "HIGH",
            type text
        ),

    #"Changed column type" = Table.TransformColumnTypes(#"Added analysis priority", {{"SCHEDULE_BLOCK", type text}})

in
    #"Changed column type"