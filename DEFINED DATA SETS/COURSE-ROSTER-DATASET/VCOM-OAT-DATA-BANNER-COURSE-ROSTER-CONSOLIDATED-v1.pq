// VCOM-OAT-DATA-BANNER-COURSE-ROSTER-CONSOLIDATED-v1
// Consolidates all Banner terms and applies graduation filtering
// Handles overlap from graduated students across term datasets
// Creates clean Banner enrollment dataset for integration

let
    // ================================
    // TERM CONFIGURATION
    // ================================
    
    // Current academic year terms to process
    // Adjust these based on current academic calendar
    // MED SCHOOL ACADEMIC YEAR 2025-2026 contains enrollment from the following Banner terms, we will deal with the split in the spring term later in the scipt
    CurrentTerms = {
        "202515",  // Banner Term Spring 2025 (Jan-June 2025)
        "202535",  // Banner Term Fall 2025 (July-Dec 2025)
        "202615"   // Banner Term Spring 2026 (Jan-June 2026)
    },

    // ================================
    // TERM DATA LOADING
    // ================================
    
    // Create list of term processors
    ProcessTermData = (termCode as text) =>
        let
            // Load term-specific processor (would be parameterized in real implementation)
            // For now, this represents the pattern - actual implementation would reference
            // separate queries or use dataflow parameters
            Source = SharePoint.Contents("https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev", [ApiVersion = 15]),
            #"data-files" = Source{[Name="data-files"]}[Content],
            #"inbound-folder" = #"data-files"{[Name="inbound"]}[Content],
            TermProcessor = #"inbound-folder"{[Name="banner-" & termCode & "-processed"]}[Content],
            TermData = Table.AddColumn(TermProcessor, "PROCESS_TERM", each termCode)
        in
            TermData,
    
    // Process all terms
    AllTermsData = List.Transform(CurrentTerms, each ProcessTermData(_)),
    
    // Union all term data
    CombinedTerms = Table.Combine(AllTermsData),

    // ================================
    // GRADUATION FILTERING LOGIC
    // ================================
    
    // Identify students who appear in multiple terms
    StudentTermCounts = Table.Group(CombinedTerms, {"STU_UIN"}, {
        {"TermList", each List.Distinct([BANNER_TERM_CODE]), type list},
        {"TermCount", each List.Count(List.Distinct([BANNER_TERM_CODE])), Int64.Type},
        {"LatestTerm", each List.Max([BANNER_TERM_CODE]), type text},
        {"EarliestTerm", each List.Min([BANNER_TERM_CODE]), type text}
    }),
    
    // Identify potentially graduated students
    // Logic: Students who appear in early terms but NOT in latest term
    GraduatedStudents = Table.SelectRows(StudentTermCounts, each 
        [TermCount] < List.Count(CurrentTerms) and 
        [LatestTerm] <> List.Max(CurrentTerms)
    ),
    
    // Create graduation flag lookup
    GraduationLookup = Table.SelectColumns(GraduatedStudents, {"STU_UIN"}),
    GraduationFlagged = Table.AddColumn(GraduationLookup, "LIKELY_GRADUATED", each true),
    
    // Join graduation flags back to main dataset
    WithGradFlags = Table.NestedJoin(
        CombinedTerms, {"STU_UIN"},
        GraduationFlagged, {"STU_UIN"},
        "GradInfo", JoinKind.LeftOuter
    ),
    ExpandGradFlags = Table.ExpandTableColumn(WithGradFlags, "GradInfo", 
        {"LIKELY_GRADUATED"}, {"LIKELY_GRADUATED"}
    ),
    
    // Fill null graduation flags as false
    CleanGradFlags = Table.ReplaceValue(ExpandGradFlags, null, false, Replacer.ReplaceValue, {"LIKELY_GRADUATED"}),

    // ================================
    // CURRENT ENROLLMENT FILTERING
    // ================================
    
    // Define current academic year logic
    // This is simplified - real logic would be more complex based on MED calendar rules
    CurrentAcademicYear = "2025-2026",
    
    // Filter for currently enrolled students (not graduated)
    CurrentlyEnrolled = Table.SelectRows(CleanGradFlags, each 
        [LIKELY_GRADUATED] = false and
        [BANNER_ENROLLED] = true
    ),

    // ================================
    // DEDUPLICATION LOGIC
    // ================================
    
    // Remove duplicate enrollments (same student, same course, multiple terms)
    // Keep most recent enrollment
    Deduplicated = Table.Group(CurrentlyEnrolled, 
        {"STU_UIN", "MDCO_CATUID"}, 
        {{"LatestEnrollment", each 
            let
                SortedRows = Table.Sort(_, {{"BANNER_TERM_CODE", Order.Descending}, {"LOAD_TIMESTAMP", Order.Descending}}),
                LatestRow = Table.FirstN(SortedRows, 1)
            in
                LatestRow
        }}
    ),
    
    // Expand deduplicated records
    ExpandDeduplicated = Table.ExpandTableColumn(Deduplicated, "LatestEnrollment", 
        Table.ColumnNames(CurrentlyEnrolled)
    ),

    // ================================
    // DATA QUALITY ENHANCEMENTS
    // ================================
    
    // Add consolidation metadata
    WithConsolidationInfo = Table.AddColumn(ExpandDeduplicated, "CONSOLIDATION_INFO", each [
        ProcessedTerms = List.Count(CurrentTerms),
        TotalRecordsBeforeFilter = Table.RowCount(CombinedTerms),
        GraduatedStudentsFiltered = Table.RowCount(GraduatedStudents),
        DuplicatesRemoved = Table.RowCount(CurrentlyEnrolled) - Table.RowCount(ExpandDeduplicated),
        ConsolidationDate = DateTime.LocalNow()
    ]),
    
    // Expand consolidation metadata
    ExpandConsolidationInfo = Table.ExpandRecordColumn(WithConsolidationInfo, "CONSOLIDATION_INFO",
        {"ProcessedTerms", "TotalRecordsBeforeFilter", "GraduatedStudentsFiltered", "DuplicatesRemoved", "ConsolidationDate"},
        {"PROCESSED_TERMS", "TOTAL_RECORDS_BEFORE", "GRADUATED_FILTERED", "DUPLICATES_REMOVED", "CONSOLIDATION_DATE"}
    ),

    // ================================
    // ACADEMIC YEAR CLASSIFICATION
    // ================================
    
    // Add academic year classification based on enrollment patterns
    // This is a simplified version - real implementation would use more sophisticated logic
    WithAcademicYear = Table.AddColumn(ExpandConsolidationInfo, "MED_ACADEMIC_YEAR", each
        if [BANNER_TERM_CODE] >= "202515" and [BANNER_TERM_CODE] <= "202615" then "2025-2026"
        else if [BANNER_TERM_CODE] >= "202615" and [BANNER_TERM_CODE] <= "202715" then "2026-2027"  
        else "UNKNOWN"
    ),

    // ================================
    // FINAL BANNER DATASET
    // ================================
    
    // Select columns for final consolidated Banner dataset
    FinalBannerDataset = Table.SelectColumns(WithAcademicYear, {
        "CROSTER_UID",                  // Primary key
        "MDCO_CATUID",                  // Course mapping
        "STU_UIN",                      // Student ID
        "NAME_HASH",                    // Evaluation matching
        "MED_ACADEMIC_YEAR",            // MED academic year
        "BANNER_TERM_CODE",             // Term
        "BANNER_YEAR",                  // Calendar year
        "BANNER_SEMESTER",              // SPRING/FALL
        "BANNER_STARTDATE",             // Course start
        "BANNER_TERM_ENDDATE",          // Term end
        "BANNER_ENROLLED",              // Enrollment status
        "BANNER_CRN",                   // Course Reference Number
        "BANNER_SECTIONID",             // Section ID
        "BANNER_SECTION",               // Section number
        "BANNER_CAMPUS",                // Campus
        "BANNER_COURSECODE",            // Course code
        "BANNER_COURSETITLE",           // Course title
        "BANNER_DESCRIPTION",           // Course description
        "BANNER_CREDITS",               // Credit hours
        "BANNER_ENROLLMENT_STATUS",     // Text status
        "LIKELY_GRADUATED",             // Graduation flag
        "DATA_SOURCE",                  // Source system
        "PROCESSOR_VERSION",            // Processing version
        "CONSOLIDATION_DATE"            // Consolidation timestamp
    }),
    
    // Apply final quality filters
    QualityFiltered = Table.SelectRows(FinalBannerDataset, each 
        [CROSTER_UID] <> null and
        [STU_UIN] <> null and
        [MDCO_CATUID] <> null and
        [BANNER_ENROLLED] = true and
        [LIKELY_GRADUATED] = false
    ),
    
    // Sort final dataset
    FinalSorted = Table.Sort(QualityFiltered, {
        {"MED_ACADEMIC_YEAR", Order.Descending},
        {"BANNER_TERM_CODE", Order.Descending}, 
        {"STU_UIN", Order.Ascending},
        {"BANNER_COURSECODE", Order.Ascending}
    }),

    // ================================
    // SUMMARY STATISTICS
    // ================================
    
    // Add summary statistics for monitoring
    SummaryStats = [
        TotalEnrollments = Table.RowCount(FinalSorted),
        UniqueStudents = List.Count(List.Distinct(FinalSorted[STU_UIN])),
        UniqueCourses = List.Count(List.Distinct(FinalSorted[MDCO_CATUID])),
        TermsProcessed = List.Count(CurrentTerms),
        GraduatedFiltered = List.Count(List.Distinct(GraduatedStudents[STU_UIN])),
        ProcessingDate = DateTime.LocalNow()
    ]

in
    FinalSorted