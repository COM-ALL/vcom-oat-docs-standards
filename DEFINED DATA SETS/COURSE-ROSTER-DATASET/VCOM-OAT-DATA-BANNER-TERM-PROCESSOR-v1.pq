// VCOM-OAT-DATA-BANNER-TERM-PROCESSOR-v1
// Processes single Banner term (Spring or Fall)
// Parameters: TermCode (e.g., "202615" for Spring 2026)
// Handles 3-file Banner structure for specified term

let
    // ================================
    // PARAMETERS & CONFIGURATION
    // ================================
    
    // Term parameter - will be set by calling query or dataflow
    TermCode = "202615",  // Example: Spring 2026
    
    // Derive term info
    TermInfo = [
        Code = TermCode,
        Year = Text.Start(TermCode, 4),
        Semester = if Text.End(TermCode, 2) = "15" then "SPRING" else "FALL",
        AcademicYear = if Text.End(TermCode, 2) = "15" 
                      then Text.Start(TermCode, 4) 
                      else Text.From(Number.FromText(Text.Start(TermCode, 4)) - 1) & "-" & Text.Start(TermCode, 4)
    ],

    // ================================
    // SOURCE DATA LOADING
    // ================================
    Source = SharePoint.Contents("https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev", [ApiVersion = 15]),
    #"data-files" = Source{[Name="data-files"]}[Content],
    #"inbound-folder" = #"data-files"{[Name="inbound"]}[Content],
    #"banner-folder" = #"inbound-folder"{[Name="banner"]}[Content],
    
    // Term-specific subfolder structure
    term_folder = #"banner-folder"{[Name=TermCode]}[Content],
    
    // Load Banner enrollments.csv for this term
    enrollments_csv = term_folder{[Name="enrollments.csv"]}[Content],
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
    
    // Validate term consistency
    enrollments_filtered = Table.SelectRows(enrollments_typed, each [Term] = TermCode),
    
    // Load Banner sections.csv for this term
    sections_csv = term_folder{[Name="sections.csv"]}[Content],
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
    sections_filtered = Table.SelectRows(sections_typed, each [Term] = TermCode),
    
    // Load Banner courses.csv (term-agnostic catalog)
    courses_csv = term_folder{[Name="courses.csv"]}[Content],
    courses_source = Csv.Document(courses_csv, [Delimiter=",", Columns=4, Encoding=65001, QuoteStyle=QuoteStyle.None]),
    courses_headers = Table.PromoteHeaders(courses_source, [PromoteAllScalars=true]),
    courses_typed = Table.TransformColumnTypes(courses_headers, {
        {"Course Code", type text},
        {"Course Title", type text},
        {"Course Description", type text},
        {"Credits", type number}
    }),

    // ================================
    // BANNER UID MAPPING (SHARED)
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
    // CAMPUS EXTRACTION LOGIC
    // ================================
    
    // Extract campus BEFORE any merges to prevent data loss
    sections_with_campus = Table.AddColumn(sections_filtered, "EXTRACTED_CAMPUS", each 
        if [Course Code] <> null and Text.Length([Course Code]) >= 3 then
            let
                courseNum = Text.End([Course Code], 3),
                numValue = try Number.FromText(courseNum) otherwise 999
            in
                if numValue <= 800 and [Section Number] <> null and Text.Length([Section Number]) >= 2 then
                    let
                        sectionSuffix = Text.End([Section Number], 1)
                    in
                        if sectionSuffix = "B" then "ABRY"
                        else if sectionSuffix = "D" then "ADLL" 
                        else if sectionSuffix = "L" then "LYNC"
                        else if sectionSuffix = "R" then "ROAN"
                        else [Campus]  // Fall back to Banner campus
                else [Campus]  // Use Banner campus for 800+ level courses
        else [Campus]  // Default to Banner campus
    ),

    // ================================
    // DATA INTEGRATION PIPELINE
    // ================================
    
    // Step 1: Join enrollments with sections (preserving campus)
    enroll_sections = Table.NestedJoin(
        enrollments_filtered, {"CRN", "Term"}, 
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
    
    // Generate Course Roster UID
    with_croster_uid = Table.AddColumn(expand_mdco, "CROSTER_UID", each 
        if [MDCO_CATUID] <> null and [Student UIN] <> null and [Term] <> null then
            Text.Upper([Student UIN]) & "-" & [MDCO_CATUID] & "-" & [Term]
        else null
    ),
    
    // Generate NAME_HASH for evaluation matching
    with_name_hash = Table.AddColumn(with_croster_uid, "NAME_HASH", each
        if [Student UIN] <> null then Text.Upper(Text.Trim([Student UIN]))
        else null
    ),

    // Add term metadata
    with_term_info = Table.AddColumn(with_name_hash, "TERM_INFO", each TermInfo),
    expand_term_info = Table.ExpandRecordColumn(with_term_info, "TERM_INFO", 
        {"Code", "Year", "Semester", "AcademicYear"}, 
        {"BANNER_TERM_CODE", "BANNER_YEAR", "BANNER_SEMESTER", "BANNER_ACADEMIC_YEAR"}
    ),

    // ================================
    // FIELD STANDARDIZATION
    // ================================
    
    // Standardize column names 
    standardized_columns = Table.RenameColumns(expand_term_info, {
        {"Student UIN", "STU_UIN"},
        {"CRN", "BANNER_CRN"}, 
        {"Term", "BANNER_TERM"},
        {"Enrollment Status", "BANNER_ENROLLMENT_STATUS"},
        {"Course Title", "BANNER_COURSETITLE"},
        {"Course Code", "BANNER_COURSECODE"},
        {"Start Date", "BANNER_STARTDATE"}
    }),
    
    // Add enrollment status boolean
    with_enrolled_flag = Table.AddColumn(standardized_columns, "BANNER_ENROLLED", each 
        if [BANNER_ENROLLMENT_STATUS] = "Enrolled" then true
        else if [BANNER_ENROLLMENT_STATUS] = "Active" then true  
        else false
    ),
    
    // Calculate term end date based on semester
    with_term_end = Table.AddColumn(with_enrolled_flag, "BANNER_TERM_ENDDATE", each
        if [BANNER_SEMESTER] = "SPRING" then 
            #date(Number.FromText([BANNER_YEAR]), 6, 30)  // June 30
        else 
            #date(Number.FromText([BANNER_YEAR]), 12, 31) // December 31
    ),
    
    // Add processing metadata
    with_source = Table.AddColumn(with_term_end, "DATA_SOURCE", each "BANNER"),
    with_processor = Table.AddColumn(with_source, "PROCESSOR_VERSION", each "BANNER-TERM-v1"),
    with_timestamp = Table.AddColumn(with_processor, "LOAD_TIMESTAMP", each DateTime.LocalNow()),

    // ================================
    // FINAL OUTPUT STRUCTURE
    // ================================
    
    // Select final columns for term-level output
    final_columns = Table.SelectColumns(with_timestamp, {
        "CROSTER_UID",                  // Primary key
        "MDCO_CATUID",                  // Course mapping
        "STU_UIN",                      // Student ID
        "NAME_HASH",                    // Evaluation matching
        "BANNER_TERM_CODE",             // Term identifier  
        "BANNER_YEAR",                  // Calendar year
        "BANNER_SEMESTER",              // SPRING/FALL
        "BANNER_ACADEMIC_YEAR",         // Academic year span
        "BANNER_STARTDATE",             // Course start
        "BANNER_TERM_ENDDATE",          // Term end (calculated)
        "BANNER_ENROLLED",              // Enrollment flag
        "BANNER_CRN",                   // Course Reference Number
        "BANNER_SECTIONID",             // Section ID
        "BANNER_SECTION",               // Section number
        "BANNER_CAMPUS",                // Resolved campus
        "BANNER_COURSECODE",            // Course code
        "BANNER_COURSETITLE",           // Course title
        "BANNER_DESCRIPTION",           // Course description  
        "BANNER_CREDITS",               // Credit hours
        "BANNER_ENROLLMENT_STATUS",     // Text status
        "DATA_SOURCE",                  // Source system
        "PROCESSOR_VERSION",            // Processing version
        "LOAD_TIMESTAMP"                // ETL timestamp
    }),
    
    // Apply data quality filters
    quality_filtered = Table.SelectRows(final_columns, each 
        [CROSTER_UID] <> null and 
        [STU_UIN] <> null and 
        [BANNER_CRN] <> null and
        [BANNER_TERM_CODE] = TermCode  // Ensure term consistency
    ),
    
    // Sort for consistency
    final_sorted = Table.Sort(quality_filtered, {
        {"STU_UIN", Order.Ascending}, 
        {"BANNER_COURSECODE", Order.Ascending}
    })

in
    final_sorted