// MDCO-ENROLL-BANNER-COURSE-ROSTER-ACTIVE
//
// PURPOSE: Banner course enrollment processing for non-AIM students
// SOURCE: Banner course enrollment extract
// BUSINESS MODEL: Static campus assignments, authoritative enrollment source
// KEY: MDCO_ENROLL_COURSE_UID (student + course)
//
// EVALUATION SUPPORT: Provides lookup columns for evaluation processor
// - Student UID mapping for target matching
// - Course code standardization for evaluation routing
// - Campus resolution for consistent geography
//
let
    // === DATA SOURCE ===
    // Connect to SharePoint and retrieve Banner course enrollment CSV
    // NOTE: Update file name and path as needed for Banner extract
    Source = SharePoint.Files("https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev", [ApiVersion = 15]),
    GetCSVFile = Source{[Name = "BANNER-25AY26-COURSE-ENROLLMENTS.csv", #"Folder Path" = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/"]}[Content],
    ImportCSV = Csv.Document(GetCSVFile, [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromoteHeaders = Table.PromoteHeaders(ImportCSV, [PromoteAllScalars = true]),
    
    // === BANNER FIELD STANDARDIZATION ===
    // Rename Banner fields to VCOM OAT naming conventions
    // NOTE: Update column names based on actual Banner extract format
    StandardizeBannerFields = Table.RenameColumns(PromoteHeaders, {
        {"STUDENT_ID", "BANNER_STUDENT_ID"},
        {"FIRST_NAME", "FIRST_NAME"},            // Keep for name hash
        {"LAST_NAME", "LAST_NAME"},              // Keep for name hash
        {"COURSE_CODE", "BANNER_COURSE_CODE"},
        {"COURSE_TITLE", "BANNER_COURSE_TITLE"},
        {"ENROLLMENT_STATUS", "BANNER_ENROLL_STATUS"},
        {"ACADEMIC_YEAR", "ACADEMIC_YEAR"},
        {"TERM", "ACADEMIC_TERM"},
        {"CREDITS", "COURSE_CREDITS"},
        {"CAMPUS_CODE", "BANNER_CAMPUS_CODE"}
        // Add other Banner-specific fields as needed
    }),
    
    // === DATA TYPE STANDARDIZATION ===
    SetDataTypes = Table.TransformColumnTypes(StandardizeBannerFields, {
        {"BANNER_STUDENT_ID", type text},
        {"FIRST_NAME", type text},
        {"LAST_NAME", type text},
        {"BANNER_COURSE_CODE", type text},
        {"BANNER_COURSE_TITLE", type text},
        {"BANNER_ENROLL_STATUS", type text},
        {"ACADEMIC_YEAR", type text},
        {"ACADEMIC_TERM", type text},
        {"COURSE_CREDITS", type number},
        {"BANNER_CAMPUS_CODE", type text}
    }),
    
    // === STUDENT PROFILE LOOKUP ===
    // Map Banner student ID to MDCO_USR_UID
    #"Join student_profile" =
        Table.NestedJoin(
            SetDataTypes,
            {"BANNER_STUDENT_ID"},
            #"src_VCOM-OAT-DATA-LPROFILE-v1",
            {"student_id"},  // Assuming Banner ID is in student_id field
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
    // Map Banner course code to MDCO-COURSE-UID
    #"Join course map" =
        Table.NestedJoin(
            #"Filtered non-AIM students",
            {"BANNER_COURSE_CODE"},
            #"src_VCOM-OAT-DATA-BANNER-CRSUID_map",
            {"BANNER-COURSE-CODE"},  // Update field name based on mapping table
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
    // Resolve campus using Banner campus code
    // NOTE: May need campus mapping table for Banner codes
    #"Resolved MDCO_CAMPUS" =
        Table.AddColumn(
            #"Expanded course map",
            "MDCO_CAMPUS_UID",
            each 
                // Campus logic for course enrollments:
                // M1: ABRY (non-ENMED) or AHEM (ENMED only)
                // M2: Home campus from student profile
                if [PROGRAMS] = "ENMED" then "AHEM"
                else if Text.Contains([ACADEMIC_YEAR], "M1") or Text.Contains([ACADEMIC_TERM], "M1") then "ABRY"
                else [BANNER_CAMPUS_CODE],  // Use Banner campus for M2+
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
                if [FIRST_NAME] <> null and [LAST_NAME] <> null then
                    Text.Upper(Text.Clean([FIRST_NAME]) & Text.Clean([LAST_NAME]))
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
            each "BANNER",
            type text
        ),
    
    // === FINAL COLUMN SELECTION ===
    #"Selected columns" =
        Table.SelectColumns(
            #"Added SYS",
            {
                "MDCO_ENROLL_COURSE_UID",     // Primary key
                "MDCO_USR_UID",               // Student UID (for evaluation lookup)
                "MDCO_COURSE_UID",            // Course UID (for evaluation lookup)
                "MDCO_CAMPUS_UID",            // Campus UID (for evaluation lookup)
                "NAME_HASH",                  // Name hash for evaluation target matching
                "BANNER_STUDENT_ID",          // Original Banner ID
                "BANNER_COURSE_CODE",         // Original Banner course
                "BANNER_COURSE_TITLE",        // Course title (for evaluation display)
                "BANNER_ENROLL_STATUS",       // Enrollment status
                "FIRST_NAME",                 // First name (for evaluation display)
                "LAST_NAME",                  // Last name (for evaluation display)
                "ACADEMIC_YEAR",              // Academic year (for evaluation context)
                "ACADEMIC_TERM",              // Academic term (for evaluation context)
                "COURSE_CREDITS",             // Course credits
                "PROGRAMS",                   // Student program (AIM filtering)
                "STUDENT_EMAIL_SSO",          // Email (for evaluation lookup)
                "DATE_OF_RECORD",             // Snapshot date
                "RECORD_ACTIVE",              // Active flag
                "SYS"                         // Source system
            }
        ),
    
    // Mark primary key
    #"Marked key columns" = Table.AddKey(#"Selected columns", {"MDCO_ENROLL_COURSE_UID"}, false)

in
    #"Marked key columns"