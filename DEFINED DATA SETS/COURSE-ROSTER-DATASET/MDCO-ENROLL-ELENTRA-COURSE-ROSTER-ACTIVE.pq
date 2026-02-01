// MDCO-ENROLL-ELENTRA-COURSE-ROSTER-ACTIVE
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
    // Combine M1/M2 and M3/M4 Elentra enrollment extracts
    Source =
        Table.Combine({
            #"src_ELENTRA-25AY26-M3M4-ENROLL",
            #"src_ELENTRA-25AY26-M1M2-ENROLL"
        }),

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
        Table.RemoveColumns(#"Rebuilt Course Code", {"Course Code.1", "Course Code.2", "Course Code"}),

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

    // === CAMPUS RESOLUTION ===
    // Apply course roster campus logic (static assignments)
    #"Resolved MDCO_CAMPUS" =
        Table.AddColumn(
            #"Expanded course map",
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
                "Course Title",               // Course title (for evaluation display)
                "ACADEMIC_YEAR",              // Academic year context
                "PROGRAMS",                   // Student program (AIM filtering)
                "DATE_OF_RECORD",             // Snapshot date
                "RECORD_ACTIVE",              // Active flag
                "SYS"                         // Source system
            }
        ),

    // Mark primary key for database creation
    #"Marked key columns" = Table.AddKey(#"Selected columns", {"MDCO_ENROLL_COURSE_UID"}, false)

in
    #"Marked key columns"