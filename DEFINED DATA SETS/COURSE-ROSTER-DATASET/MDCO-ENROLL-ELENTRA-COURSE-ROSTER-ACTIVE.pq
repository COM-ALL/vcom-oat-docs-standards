// MDCO-ENROLL-ELENTRA-COURSE-ROSTER
//
// PURPOSE: Elentra course enrollment processing for non-AIM students  
// SOURCE: Elentra M1/M2 and M3/M4 enrollment extracts
// BUSINESS MODEL: Static campus assignments, course-level enrollment tracking
// KEY: MDCO_ENROLL_COURSE_UID (student + course)
//
// MOVED FROM: LEARNER-ROTATION-DATASET (proper home is course roster dataset)
// EVALUATION SUPPORT: Provides lookup columns for evaluation processor
//
let
    // === DATA SOURCE ===
    // Import Elentra enrollment data directly from SharePoint
    SharePointSource = SharePoint.Files("https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev", [ApiVersion = 15]),
    #"Filtered to inbound folder" = Table.SelectRows(SharePointSource, each ([Folder Path] = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/")),
    
    // Load M1/M2 enrollment data
    M1M2Source = #"Filtered to inbound folder"{[Name = "ELENTRA-25AY26-M1M2-ENROLL.csv", #"Folder Path" = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/"]}[Content],
    M1M2Data = 
        let
            ImportedCSV = Csv.Document(M1M2Source, [Delimiter = ",", Columns = 9, QuoteStyle = QuoteStyle.None]),
            RemovedTopRows = Table.Skip(ImportedCSV, 2),
            PromotedHeaders = Table.PromoteHeaders(RemovedTopRows, [PromoteAllScalars = true]),
            FilteredRows = Table.SelectRows(PromotedHeaders, each ([#"Curriculum Period"] = "202615")),
            TaggedData = Table.AddColumn(FilteredRows, "DATA_COHORT", each "M1M2", type text)
        in
            TaggedData,
    
    // Load M3/M4 enrollment data  
    M3M4Source = #"Filtered to inbound folder"{[Name = "ELENTRA-25AY26-M3M4-ENROLL.csv", #"Folder Path" = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/"]}[Content],
    M3M4Data = 
        let
            ImportedCSV = Csv.Document(M3M4Source, [Delimiter = ",", Columns = 9, QuoteStyle = QuoteStyle.None]),
            RemovedTopRows = Table.Skip(ImportedCSV, 2),
            PromotedHeaders = Table.PromoteHeaders(RemovedTopRows, [PromoteAllScalars = true]),
            FilteredRows = Table.SelectRows(PromotedHeaders, each ([#"Curriculum Period"] = "Curriculum Period" or [#"Curriculum Period"] = "MED-CLERKSHIP AY 2025/2026")),
            SortedRows = Table.Sort(FilteredRows, {{"Curriculum Period", Order.Ascending}}),
            RemovedHeaders = Table.Skip(SortedRows, 141),
            TaggedData = Table.AddColumn(RemovedHeaders, "DATA_COHORT", each "M3M4", type text)
        in
            TaggedData,
    
    // Combine M1/M2 and M3/M4 enrollment extracts
    Source = Table.Combine({M3M4Data, M1M2Data}),

    // === FIELD STANDARDIZATION ===
    // Tag academic year for downstream reconciliation
    #"Added AYEAR" =
        Table.AddColumn(
            Source,
            "ACADEMIC_YEAR",
            each "2025-2026",
            type text
        ),

    // Normalize learner identity columns to VCOM OAT standards
    #"Renamed learner columns" =
        Table.RenameColumns(
            #"Added AYEAR",
            {
                {"Number", "ELENTRA_STUDENT_ID"},
                {"Email",  "STUDENT_EMAIL"}
            }
        ),

    // Remove curriculum-period columns (replaced by ACADEMIC_YEAR)
    #"Removed CP columns" =
        Table.RemoveColumns(
            #"Renamed learner columns",
            {"Curriculum Period", "CP Start Date", "CP Finish Date"}
        ),

    // === COURSE CODE NORMALIZATION ===
    // Split and rebuild course code for consistent mapping
    #"Split Course Code" =
        Table.SplitColumn(
            #"Removed CP columns",
            "Course Code",
            Splitter.SplitTextByDelimiter(" "),
            {"Course Code.1", "Course Code.2"}
        ),

    #"Rebuilt Course Code" =
        Table.AddColumn(
            #"Split Course Code",
            "ELENTRA_COURSE_CODE",
            each [#"Course Code.1"] & " " & [#"Course Code.2"],
            type text
        ),

    // Clean up split columns
    #"Removed split columns" =
        Table.RemoveColumns(#"Rebuilt Course Code", {"Course Code.1", "Course Code.2"}),

    // === STUDENT PROFILE LOOKUP ===
    // Map Elentra student ID to MDCO_USR_UID using student profile
    #"Join student_profile" =
        Table.NestedJoin(
            #"Removed split columns",
            {"ELENTRA_STUDENT_ID"},
            #"src_VCOM-OAT-DATA-LPROFILE-v1",
            {"student_id"},
            "StudentProfile",
            JoinKind.LeftOuter
        ),

    #"Expanded student_profile" =
        Table.ExpandTableColumn(
            #"Join student_profile",
            "StudentProfile",
            {"student_id", "programs", "student_email_sso"},
            {"MDCO_USR_UID", "PROGRAMS", "STUDENT_EMAIL_SSO"}
        ),

    // Filter out AIM students (process separately)
    #"Filtered non-AIM students" =
        Table.SelectRows(#"Expanded student_profile", 
            each [MDCO_USR_UID] <> null and ([PROGRAMS] <> "AIM" or [PROGRAMS] = null)),

    // === COURSE UID MAPPING ===
    // Map Elentra Course Code to MDCO-COURSE-UID
    #"Join course map" =
        Table.NestedJoin(
            #"Filtered non-AIM students",
            {"ELENTRA_COURSE_CODE"},
            #"src_VCOM-OAT-DATA-ELENTRA-CRSUID_map",
            {"ELENTRA-MDCODE"},
            "CourseMap",
            JoinKind.LeftOuter
        ),

    #"Expanded course map" =
        Table.ExpandTableColumn(
            #"Join course map",
            "CourseMap",
            {"MDCO-COURSE-UID"},
            {"MDCO_COURSE_UID"}
        ),
  #"Duplicated column" = Table.DuplicateColumn(#"Expanded course map", "Learner Name", "Learner Name - Copy"),
  #"Split column by delimiter" = Table.SplitColumn(#"Duplicated column", "Learner Name - Copy", Splitter.SplitTextByEachDelimiter({" "}, QuoteStyle.Csv, true), {"Learner Name - Copy.1", "Learner Name - Copy.2"}),
  #"Renamed columns" = Table.RenameColumns(#"Split column by delimiter", {{"Learner Name - Copy.1", "First Name"}, {"Learner Name - Copy.2", "Last Name"}}),

    // === CAMPUS RESOLUTION ===
    // Apply course roster campus logic (static assignments)
    #"Resolved MDCO_CAMPUS" =
        Table.AddColumn(
            #"Renamed columns",
            "MDCO_CAMPUS_UID",
            each 
                // Campus logic for course enrollments:
                // M1: ABRY (non-ENMED) or AHEM (ENMED only)  
                // M2+: Home campus (would need additional logic/data)
                if [PROGRAMS] = "ENMED" then "AHEM"
                else "ABRY",  // Default M1 campus for non-ENMED
            type text
        ),

    // === PRIMARY KEY GENERATION ===
    // Build MDCO_ENROLL_COURSE_UID (primary key)
    #"Added MDCO_ENROLL_COURSE_UID" =
        Table.AddColumn(
            #"Resolved MDCO_CAMPUS",
            "MDCO_ENROLL_COURSE_UID",
            each fnBuildCRSRosterUID_v1([MDCO_USR_UID], [MDCO_COURSE_UID]),
            type text
        ),

    // === EVALUATION MATCHING SUPPORT ===
    // Create name hash for evaluation target matching (no UIN in evaluation CSV)
    #"Added NAME_HASH" =
        Table.AddColumn(
            #"Added MDCO_ENROLL_COURSE_UID",
            "NAME_HASH",
            each 
                if [#"First Name"] <> null and [#"Last Name"] <> null then
                    Text.Upper(Text.Clean([#"First Name"]) & Text.Clean([#"Last Name"]))
                else null,
            type nullable text
        ),

    // === METADATA ADDITION ===
    #"Added DATE_OF_RECORD" =
        Table.AddColumn(
            #"Added NAME_HASH",
            "DATE_OF_RECORD",
            each fnDATE_ActiveAsOf(),
            type date
        ),

    #"Added RECORD_ACTIVE" =
        Table.AddColumn(
            #"Added DATE_OF_RECORD",
            "RECORD_ACTIVE",
            each true,
            type logical
        ),

    #"Added SYS" =
        Table.AddColumn(
            #"Added RECORD_ACTIVE",
            "SYS",
            each "ELENTRA",
            type text
        ),

    // === FINAL COLUMN SELECTION ===
    // Include evaluation support columns
    #"Selected columns" =
        Table.SelectColumns(
            #"Added SYS",
            {
                "MDCO_ENROLL_COURSE_UID",     // Primary key
                "MDCO_USR_UID",               // Student UID (for evaluation lookup)
                "MDCO_COURSE_UID",            // Course UID (for evaluation lookup)
                "MDCO_CAMPUS_UID",            // Campus UID (for evaluation lookup)
                "NAME_HASH",                  // Name hash for evaluation target matching
                "ELENTRA_STUDENT_ID",         // Original Elentra ID
                "ELENTRA_COURSE_CODE",        // Original Elentra course
                "STUDENT_EMAIL",              // Student email (for evaluation lookup)
                "STUDENT_EMAIL_SSO",          // SSO email (for evaluation lookup)
                "First Name",                 // First name (for evaluation display)
                "Last Name",                  // Last name (for evaluation display)

                "ACADEMIC_YEAR",              // Academic year context
                "PROGRAMS",                   // Student program (AIM filtering)
                "DATE_OF_RECORD",             // Snapshot date
                "RECORD_ACTIVE",              // Active flag
                "SYS"                         // Source system
            }
        ),

    // Mark primary key for database creation
    #"Marked key columns" = Table.AddKey(#"Selected columns", {"MDCO_ENROLL_COURSE_UID"}, false),
  #"Removed columns" = Table.RemoveColumns(#"Marked key columns", {"MDCO_USR_UID", "MDCO_COURSE_UID"}),
  #"Reordered columns" = Table.ReorderColumns(#"Removed columns", {"MDCO_ENROLL_COURSE_UID", "DATE_OF_RECORD", "RECORD_ACTIVE", "SYS", "ACADEMIC_YEAR", "MDCO_CAMPUS_UID", "NAME_HASH", "ELENTRA_STUDENT_ID", "ELENTRA_COURSE_CODE", "STUDENT_EMAIL", "STUDENT_EMAIL_SSO", "First Name", "Last Name", "PROGRAMS"}),
  #"Removed other columns" = Table.SelectColumns(#"Reordered columns", {"MDCO_ENROLL_COURSE_UID", "DATE_OF_RECORD", "RECORD_ACTIVE", "SYS", "ACADEMIC_YEAR", "MDCO_CAMPUS_UID"})

in
    #"Removed other columns"