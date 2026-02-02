// VCOM-OAT-ELENTRA-ROTATION-PLANNING-EXPORT
// Registration Team Planning Report - Power Query Version
// Date: 2026-02-01

let
    // === SOURCE DATA FROM LAKEHOUSE ===
    // Access established datalake tables per VCOM OAT standards
    Source = Lakehouse.Contents(null),
    Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
    #"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
    
    // Primary rotation data
    rotationsTable = #"Navigation 1"{[Id = "MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE", ItemKind = "Table"]}[Data],
    
    // Course mapping data
    courseMappingTable = #"Navigation 1"{[Id = "VCOM-OAT-DATA-MDCO-CRSUID_mapkey", ItemKind = "Table"]}[Data],
    
    // === DATA FILTERING & PREPARATION ===
    // Filter valid records
    filteredRotations = Table.SelectRows(rotationsTable, each 
        [MDCO_COURSE_UID] <> null and 
        [ELE_STARTDATE] <> null
    ),
    
    // === CAMPUS MAPPING LOGIC ===
    // Access campus mapping from lakehouse
    campusMappingTable = #"Navigation 1"{[Id = "VSITE-VDATA-GlobalCampusCatalog", ItemKind = "Table"]}[Data],
    
    // === COURSE UID PARSING ===
    // Extract DEPT and COURSEID from MDCO_COURSE_UID
    addParsedCourseInfo = Table.AddColumn(filteredRotations, "DEPT", each 
        let
            courseUID = [MDCO_COURSE_UID],
            afterMDCO = Text.AfterDelimiter(courseUID, "MDCO-"),
            firstDigitPos = List.PositionOf(Text.ToList(afterMDCO), each Text.Contains("0123456789", _), 0)
        in
            if firstDigitPos >= 0 then Text.Start(afterMDCO, firstDigitPos) else null
    ),
    
    addCourseID = Table.AddColumn(addParsedCourseInfo, "COURSEID", each 
        let
            courseUID = [MDCO_COURSE_UID],
            afterMDCO = Text.AfterDelimiter(courseUID, "MDCO-"),
            beforeDot = Text.BeforeDelimiter(afterMDCO, ".", {0, RelativePosition.FromEnd})
        in
            beforeDot
    ),
    
    // === CAMPUS & SITE RESOLUTION ===
    // Join with campus mapping
    joinedCampusData = Table.NestedJoin(
        addCourseID,
        {"MDCO_CAMPUS_UID"},
        campusMappingTable,
        {"mdco-campus-uid"},
        "CampusMapping",
        JoinKind.LeftOuter
    ),
    
    expandedCampusData = Table.ExpandTableColumn(
        joinedCampusData,
        "CampusMapping",
        {"mdco-campus-name"},
        {"StandardCampusName"}
    ),
    
    // Add campus and site columns with proper logic
    addCampusAndSite = Table.AddColumn(expandedCampusData, "Campus", each 
        if [StandardCampusName] <> null then 
            [StandardCampusName]
        else if Text.Contains([MDCO_CAMPUS_UID], "vcom.") then
            let
                parts = Text.Split([MDCO_CAMPUS_UID], "."),
                middlePart = if List.Count(parts) >= 2 then parts{1} else null
            in
                if middlePart <> null then Text.Proper(middlePart) else [MDCO_CAMPUS_UID]
        else [MDCO_CAMPUS_UID]
    ),
    
    addSiteColumn = Table.AddColumn(addCampusAndSite, "Site", each 
        if [StandardCampusName] = null and Text.Contains([MDCO_CAMPUS_UID], "vcom.") then
            let
                parts = Text.Split([MDCO_CAMPUS_UID], "."),
                lastPart = if List.Count(parts) >= 3 then parts{2} else null
            in
                lastPart
        else null
    ),
    
    // === WEEK COUNT CALCULATION ===
    addWeekCount = Table.AddColumn(addSiteColumn, "Week Count", each 
        if [ELE_ENDDATE] <> null and [ELE_STARTDATE] <> null then
            let
                daysDiff = Duration.Days([ELE_ENDDATE] - [ELE_STARTDATE]),
                weekCount = Number.RoundUp(daysDiff / 7)
            in
                weekCount
        else null
    ),
    
    // === JOIN WITH COURSE NAMES ===
    joinedCourseNames = Table.NestedJoin(
        addWeekCount,
        {"MDCO_COURSE_UID"},
        courseMappingTable,
        {"MDCO_COURSE_UID"},
        "CourseMapping",
        JoinKind.LeftOuter
    ),
    
    expandedCourseNames = Table.ExpandTableColumn(
        joinedCourseNames,
        "CourseMapping",
        {"MDCO_COURSENAME"},
        {"Course Name"}
    ),
    
    // Replace null course names with "Unknown Course"
    replacedNullCourseNames = Table.ReplaceValue(
        expandedCourseNames,
        null,
        "Unknown Course",
        Replacer.ReplaceValue,
        {"Course Name"}
    ),
    
    // === GROUPING AND AGGREGATION ===
    groupedData = Table.Group(
        replacedNullCourseNames,
        {"DEPT", "COURSEID", "Course Name", "Campus", "Site", "Week Count", "ELE_STARTDATE", "ELE_ENDDATE"},
        {{"Enrollment Count", each Table.RowCount(_), Int64.Type}}
    ),
    
    // === FINAL COLUMN SELECTION AND SORTING ===
    selectedColumns = Table.SelectColumns(groupedData, {
        "DEPT",
        "COURSEID",
        "Course Name",
        "Campus",
        "Site",
        "Week Count",
        "Enrollment Count",
        "ELE_STARTDATE",
        "ELE_ENDDATE"
    }),
    
    // Rename date columns for final output
    renamedDateColumns = Table.RenameColumns(selectedColumns, {
        {"ELE_STARTDATE", "Start Date"},
        {"ELE_ENDDATE", "End Date"}
    }),
    
    // Sort by Start Date, End Date, DEPT, COURSEID
    sortedResults = Table.Sort(renamedDateColumns, {
        {"Start Date", Order.Ascending},
        {"End Date", Order.Ascending},
        {"DEPT", Order.Ascending},
        {"COURSEID", Order.Ascending}
    })
    
in
    sortedResults