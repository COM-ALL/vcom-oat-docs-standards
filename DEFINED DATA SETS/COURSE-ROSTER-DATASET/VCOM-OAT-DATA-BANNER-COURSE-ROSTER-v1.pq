// VCOM-OAT-DATA-BANNER-COURSE-ROSTER-v1
// Course Roster Dataset - Banner Integration
// Processes Banner three-file structure (enrollments, sections, courses)
// Based on prototype flow pattern with campus extraction before section merge

let
    // ================================
    // SOURCE DATA LOADING
    // ================================
    Source = SharePoint.Contents("https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev", [ApiVersion = 15]),
    #"data-files" = Source{[Name="data-files"]}[Content],
    #"inbound-folder" = #"data-files"{[Name="inbound"]}[Content],
    #"banner-folder" = #"inbound-folder"{[Name="banner"]}[Content],
    
    // Load Banner enrollments.csv
    enrollments_csv = #"banner-folder"{[Name="enrollments.csv"]}[Content],
    enrollments_source = Csv.Document(enrollments_csv, [Delimiter=",", Columns=8, Encoding=65001, QuoteStyle=QuoteStyle.None]),
    enrollments_headers = Table.PromoteHeaders(enrollments_source, [PromoteAllScalars=true]),
    enrollments_typed = Table.TransformColumnTypes(enrollments_headers, {
        {"Student UIN", type text},
        {"CRN", type text},
        {"Term", type text},
        {"Section ID", type text},
        {"Enrollment Status", type text},
        {"Course Title", type text},
        {"Course Code", type text},
        {"Start Date", type date}
    }),
    
    // Load Banner sections.csv
    sections_csv = #"banner-folder"{[Name="sections.csv"]}[Content],
    sections_source = Csv.Document(sections_csv, [Delimiter=",", Columns=6, Encoding=65001, QuoteStyle=QuoteStyle.None]),
    sections_headers = Table.PromoteHeaders(sections_source, [PromoteAllScalars=true]),
    sections_typed = Table.TransformColumnTypes(sections_headers, {
        {"Section ID", type text},
        {"CRN", type text},
        {"Term", type text},
        {"Course Code", type text},
        {"Section Number", type text},
        {"Campus", type text}
    }),
    
    // Load Banner courses.csv
    courses_csv = #"banner-folder"{[Name="courses.csv"]}[Content],
    courses_source = Csv.Document(courses_csv, [Delimiter=",", Columns=4, Encoding=65001, QuoteStyle=QuoteStyle.None]),
    courses_headers = Table.PromoteHeaders(courses_source, [PromoteAllScalars=true]),
    courses_typed = Table.TransformColumnTypes(courses_headers, {
        {"Course Code", type text},
        {"Course Title", type text},
        {"Course Description", type text},
        {"Credits", type number}
    }),

    // ================================
    // BANNER UID MAPPING TABLE
    // ================================
    mapping_csv = #"banner-folder"{[Name="VCOM-OAT-DATA-BANNER-CRSUID_map-master.csv"]}[Content],
    mapping_source = Csv.Document(mapping_csv, [Delimiter=",", Columns=null, Encoding=65001, QuoteStyle=QuoteStyle.None]),
    mapping_headers = Table.PromoteHeaders(mapping_source, [PromoteAllScalars=true]),
    mapping_clean = Table.TransformColumnTypes(mapping_headers, {
        {"BANNER_COURSECODE", type text},
        {"MDCO_CATUID", type text},
        {"BANNER_COURSETITLE", type text}
    }),

    // ================================
    // CAMPUS EXTRACTION BEFORE MERGES
    // ================================
    // CRITICAL: Extract campus from sections BEFORE any merges that might lose this info
    sections_with_campus = Table.AddColumn(sections_typed, "EXTRACTED_CAMPUS", each 
        if [Course Code] <> null and Text.Length([Course Code]) >= 3 then
            let
                courseNum = Text.End([Course Code], 3),
                numValue = try Number.FromText(courseNum) otherwise 999
            in
                if numValue <= 800 and [Section Number] <> null and Text.Length([Section Number]) >= 3 then
                    let
                        sectionSuffix = Text.End([Section Number], 2)
                    in
                        if sectionSuffix = "B" then "ABRY"
                        else if sectionSuffix = "D" then "ADLL" 
                        else if sectionSuffix = "L" then "LYNC"
                        else if sectionSuffix = "R" then "ROAN"
                        else [Campus]  // Fall back to Banner campus field
                else [Campus]  // Use Banner campus for 800+ level courses
        else [Campus]  // Default to Banner campus
    ),

    // ================================
    // DATA INTEGRATION PIPELINE
    // ================================
    
    // Step 1: Join enrollments with sections (preserving campus)
    enroll_sections = Table.NestedJoin(
        enrollments_typed, {"CRN", "Term"}, 
        sections_with_campus, {"CRN", "Term"}, 
        "SectionInfo", JoinKind.LeftOuter
    ),
    expand_sections = Table.ExpandTableColumn(enroll_sections, "SectionInfo", 
        {"Section ID", "Section Number", "EXTRACTED_CAMPUS"}, 
        {"BANNER_SECTIONID", "BANNER_SECTION", "BANNER_CAMPUS"}
    ),
    
    // Step 2: Join with course catalog
    enroll_with_courses = Table.NestedJoin(
        expand_sections, {"Course Code"}, 
        courses_typed, {"Course Code"}, 
        "CourseInfo", JoinKind.LeftOuter
    ),
    expand_courses = Table.ExpandTableColumn(enroll_with_courses, "CourseInfo", 
        {"Course Description", "Credits"}, 
        {"BANNER_DESCRIPTION", "BANNER_CREDITS"}
    ),
    
    // Step 3: Map to MDCO Course UIDs
    with_mdco_mapping = Table.NestedJoin(
        expand_courses, {"Course Code"}, 
        mapping_clean, {"BANNER_COURSECODE"}, 
        "MDCOMapping", JoinKind.LeftOuter
    ),
    expand_mdco = Table.ExpandTableColumn(with_mdco_mapping, "MDCOMapping", 
        {"MDCO_CATUID"}, 
        {"MDCO_CATUID"}
    ),

    // ================================
    // UID GENERATION & STANDARDIZATION
    // ================================
    
    // Generate Course Roster UID using established pattern
    with_croster_uid = Table.AddColumn(expand_mdco, "CROSTER_UID", each 
        if [MDCO_CATUID] <> null and [Student UIN] <> null and [Term] <> null then
            Text.Upper([Student UIN]) & "-" & [MDCO_CATUID] & "-" & [Term]
        else null
    ),
    
    // Generate NAME_HASH for evaluation matching (per architecture)
    with_name_hash = Table.AddColumn(with_croster_uid, "NAME_HASH", each
        if [Student UIN] <> null then
            let
                // Use UIN as primary name hash since Banner includes UINs
                cleanUIN = Text.Upper(Text.Trim([Student UIN]))
            in
                cleanUIN
        else null
    ),

    // ================================
    // FIELD STANDARDIZATION
    // ================================
    
    // Standardize column names to match prototype pattern
    standardized_columns = Table.RenameColumns(with_name_hash, {
        {"Student UIN", "STU_UIN"},
        {"CRN", "BANNER_CRN"}, 
        {"Term", "BANNER_TERM"},
        {"Enrollment Status", "BANNER_ENROLLMENT_STATUS"},
        {"Course Title", "BANNER_COURSETITLE"},
        {"Course Code", "BANNER_COURSECODE"},
        {"Start Date", "BANNER_STARTDATE"}
    }),
    
    // Add enrollment status boolean (following prototype pattern)
    with_enrolled_flag = Table.AddColumn(standardized_columns, "BANNER_ENROLLED", each 
        if [BANNER_ENROLLMENT_STATUS] = "Enrolled" then true
        else if [BANNER_ENROLLMENT_STATUS] = "Active" then true
        else false
    ),
    
    // Add data source identifier
    with_source = Table.AddColumn(with_enrolled_flag, "DATA_SOURCE", each "BANNER"),
    
    // Add load timestamp
    with_timestamp = Table.AddColumn(with_source, "LOAD_TIMESTAMP", each DateTime.LocalNow()),

    // ================================
    // FINAL OUTPUT STRUCTURE
    // ================================
    
    // Select and order final columns to match Course Roster Dataset schema
    final_columns = Table.SelectColumns(with_timestamp, {
        "CROSTER_UID",           // Primary key
        "MDCO_CATUID",           // Links to course catalog 
        "STU_UIN",               // Student identifier
        "NAME_HASH",             // For evaluation matching
        "BANNER_TERM",           // Academic term
        "BANNER_STARTDATE",      // Course start date
        "BANNER_ENROLLED",       // Enrollment status (boolean)
        "BANNER_CRN",            // Course Reference Number
        "BANNER_SECTIONID",      // Section ID
        "BANNER_SECTION",        // Section number
        "BANNER_CAMPUS",         // Extracted/resolved campus
        "BANNER_COURSECODE",     // Banner course code
        "BANNER_COURSETITLE",    // Course title
        "BANNER_DESCRIPTION",    // Course description
        "BANNER_CREDITS",        // Credit hours
        "BANNER_ENROLLMENT_STATUS", // Text enrollment status
        "DATA_SOURCE",           // Source system
        "LOAD_TIMESTAMP"         // ETL timestamp
    }),
    
    // Apply data quality filters
    quality_filtered = Table.SelectRows(final_columns, each 
        [CROSTER_UID] <> null and 
        [STU_UIN] <> null and 
        [BANNER_CRN] <> null
    ),
    
    // Sort by student, term, and course for consistency
    final_sorted = Table.Sort(quality_filtered, {
        {"STU_UIN", Order.Ascending}, 
        {"BANNER_TERM", Order.Descending},
        {"BANNER_COURSECODE", Order.Ascending}
    })

in
    final_sorted