# VCOM-OAT-ELENTRA-ROTATION-PLANNING-EXPORT

**Date Created**: February 1, 2026  
**Requested By**: Registration Team  
**Purpose**: Planning assistance for active Elentra rotations  

## Business Requirements

The registration team requested a CSV export from `[dbo].[MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE]` with the following specifications:

### Required Output Columns:
- **DEPT** - Department code (extracted from MDCO_COURSE_UID)
- **COURSEID** - Course ID (extracted from MDCO_COURSE_UID) 
- **Course Name** - Standardized course name from MDCO master table
- **Campus** - Human-readable campus name
- **Site** - Specific site identifier for non-standard campuses (last segment of UID)
- **Week Count** - Duration of rotation in weeks (calculated from start/end dates)
- **Enrollment Count** - Student count grouped by start date
- **Start Date** - Block rotation start date
- **End Date** - Block rotation end date (critical for medical school scheduling)

### Source Data:
- Primary table: `[dbo].[MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE]`
- Course mapping: `[dbo].[VCOM-MDCO-CRSUID_mapkey]`
- Source columns: `MDCO_COURSE_UID`, `MDCO_CAMPUS_UID`, `ELE_STARTDATE`, `ELE_ENDDATE`

## Implementation

### SQL Query

```sql
-- VCOM-OAT-ELENTRA-ROTATION-PLANNING-EXPORT
-- Registration Team Planning Report
-- Date: 2026-02-01

WITH campus_mapping AS (
    -- Map campus UIDs to readable campus names
    SELECT 
        'vcom.abry.campus' as campus_uid, 'Bryan' as campus_name, 'ABRY' as campus_code
    UNION ALL SELECT 'vcom.ardr.campus', 'Round Rock', 'ARDR'
    UNION ALL SELECT 'vcom.ahem.campus', 'Houston', 'AHEM' 
    UNION ALL SELECT 'vcom.ahwh.campus', 'Houston-Willowbrook', 'AHWH'
    UNION ALL SELECT 'vcom.adll.campus', 'Dallas', 'ADLL'
),

parsed_courses AS (
    -- Extract DEPT and COURSEID from MDCO_COURSE_UID
    -- Format: MDCO-DEPT###.### -> DEPT=DEPT, COURSEID=DEPT###
    SELECT 
        r.MDCO_COURSE_UID,
        r.MDCO_CAMPUS_UID,
        r.ELE_STARTDATE,
        r.ELE_ENDDATE,
        -- Extract department (e.g., MDCO-IMED905.210 -> IMED)
        LEFT(SUBSTRING(r.MDCO_COURSE_UID, 6, LEN(r.MDCO_COURSE_UID)), 
             PATINDEX('%[0-9]%', SUBSTRING(r.MDCO_COURSE_UID, 6, LEN(r.MDCO_COURSE_UID))) - 1) AS DEPT,
        -- Extract course ID (e.g., MDCO-IMED905.210 -> IMED905)  
        SUBSTRING(r.MDCO_COURSE_UID, 6, 
                  CHARINDEX('.', r.MDCO_COURSE_UID + '.') - 6) AS COURSEID
    FROM [dbo].[MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE] r
    WHERE r.MDCO_COURSE_UID IS NOT NULL 
      AND r.ELE_STARTDATE IS NOT NULL
)

SELECT 
    pc.DEPT,
    pc.COURSEID,
    COALESCE(ck.MDCO_COURSENAME, 'Unknown Course') AS [Course Name],
    COALESCE(cm.campus_name, 
             -- Handle non-standard campus codes (extract middle segment, proper case)
             CASE WHEN pc.MDCO_CAMPUS_UID LIKE 'vcom.%.%'
                  THEN UPPER(LEFT(SUBSTRING(pc.MDCO_CAMPUS_UID, 
                              CHARINDEX('.', pc.MDCO_CAMPUS_UID) + 1,
                              CHARINDEX('.', pc.MDCO_CAMPUS_UID, CHARINDEX('.', pc.MDCO_CAMPUS_UID) + 1) - CHARINDEX('.', pc.MDCO_CAMPUS_UID) - 1), 1)) +
                       LOWER(SUBSTRING(SUBSTRING(pc.MDCO_CAMPUS_UID, 
                              CHARINDEX('.', pc.MDCO_CAMPUS_UID) + 1,
                              CHARINDEX('.', pc.MDCO_CAMPUS_UID, CHARINDEX('.', pc.MDCO_CAMPUS_UID) + 1) - CHARINDEX('.', pc.MDCO_CAMPUS_UID) - 1), 2, 999))
                  ELSE pc.MDCO_CAMPUS_UID
             END) AS Campus,
    -- Extract site identifier (last segment after final dot) for non-standard campuses
    CASE WHEN cm.campus_name IS NULL AND pc.MDCO_CAMPUS_UID LIKE 'vcom.%.%'
         THEN SUBSTRING(pc.MDCO_CAMPUS_UID, 
                       LEN(pc.MDCO_CAMPUS_UID) - CHARINDEX('.', REVERSE(pc.MDCO_CAMPUS_UID)) + 2,
                       LEN(pc.MDCO_CAMPUS_UID))
         ELSE NULL
    END AS Site,
    -- Calculate rotation duration in weeks (rounded up for partial weeks)
    CASE WHEN pc.ELE_ENDDATE IS NOT NULL AND pc.ELE_STARTDATE IS NOT NULL
         THEN CEILING(CAST(DATEDIFF(day, pc.ELE_STARTDATE, pc.ELE_ENDDATE) AS FLOAT) / 7.0)
         ELSE NULL
    END AS [Week Count],
    COUNT(*) AS [Enrollment Count],
    pc.ELE_STARTDATE AS [Start Date],
    pc.ELE_ENDDATE AS [End Date]
FROM parsed_courses pc
LEFT JOIN [dbo].[VCOM-MDCO-CRSUID_mapkey] ck 
    ON pc.MDCO_COURSE_UID = ck.MDCO_COURSE_UID
LEFT JOIN campus_mapping cm 
    ON pc.MDCO_CAMPUS_UID = cm.campus_uid
GROUP BY 
    pc.DEPT,
    pc.COURSEID, 
    ck.MDCO_COURSENAME,
    cm.campus_name,
    pc.MDCO_CAMPUS_UID,
    pc.ELE_STARTDATE,
    pc.ELE_ENDDATE
ORDER BY 
    pc.ELE_STARTDATE,
    pc.ELE_ENDDATE,
    pc.DEPT,
    pc.COURSEID;
```

## Power BI/Fabric Implementation

### Power Query M Script

Following VCOM OAT datalake patterns:

```powerquery
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
        {"MDCO-CAMPUS-UID"},
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
        else if Text.Contains([#"MDCO-CAMPUS-UID"], "vcom.") then
            let
                parts = Text.Split([#"MDCO-CAMPUS-UID"], "."),
                middlePart = if List.Count(parts) >= 2 then parts{1} else null
            in
                if middlePart <> null then Text.Proper(middlePart) else [#"MDCO-CAMPUS-UID"]
        else [#"MDCO-CAMPUS-UID"]
    ),
    
    addSiteColumn = Table.AddColumn(addCampusAndSite, "Site", each 
        if [StandardCampusName] = null and Text.Contains([#"MDCO-CAMPUS-UID"], "vcom.") then
            let
                parts = Text.Split([#"MDCO-CAMPUS-UID"], "."),
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
        {"MDCO-COURSE-UID"},
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
```

### Deployment in Power BI/Fabric

#### Option 1: Dataflow (Recommended)
1. **Create new Dataflow** in your Fabric workspace
2. **Paste the Power Query M script** above
3. **Name the dataflow**: `VCOM-OAT-ELENTRA-ROTATION-PLANNING-EXPORT`
4. **Publish and refresh** to generate the dataset
5. **Connect Power BI report** to the published dataflow

#### Option 2: Direct Power BI Query
1. **Open Power BI Desktop**
2. **Get Data** → **Blank Query**
3. **Open Advanced Editor** and paste the M script
4. **Apply changes** and load data
5. **Create visualizations** as needed

#### Option 3: CSV Export from Power BI
1. **Load data using Option 1 or 2**
2. **Create a simple table visualization** with all columns
3. **Export data** → **CSV format**
4. **Save as**: `VCOM-OAT-ELENTRA-ROTATION-PLANNING-EXPORT-20260201.csv`

### Performance Benefits
- **Fabric Lakehouse Integration**: Leverages your existing data infrastructure
- **Incremental Refresh**: Can be configured for automatic updates
- **Power BI Native**: No SQL Server dependency for this specific report
- **Established Patterns**: Follows your VCOM OAT datalake access standards

### Expected Output Format

| DEPT | COURSEID | Course Name | Campus | Site | Week Count | Enrollment Count | Start Date | End Date |
|------|----------|-------------|---------|------|------------|------------------|------------|----------|
| IMED | IMED905 | INPATIENT MEDICINE NOCTURNIST | Houston | NULL | 2 | 12 | 2026-02-15 | 2026-02-28 |
| MEID | MEID105 | ADVISING WEEK | Bryan | NULL | 1 | 8 | 2026-02-15 | 2026-02-21 |
| MFCM | MFCM989 | FAMILY MEDICINE ROTATION | Rural | canton | 8 | 4 | 2026-02-22 | 2026-04-18 |

### Export File Naming Convention

Following VCOM OAT standards:
```
VCOM-OAT-ELENTRA-ROTATION-PLANNING-EXPORT-20260201.csv
```

## Data Quality Considerations

1. **Missing Course Mappings**: Any courses in the rotations table not found in the MDCO keymap will show "Unknown Course"
2. **Non-Standard Campus UIDs**: Campus UIDs not in the 5 primary campuses will show:
   - Campus: Proper-cased middle segment (e.g., `vcom.rural.canton` → `Rural`)
   - Site: Last segment identifier (e.g., `vcom.rural.canton` → `canton`)
3. **Week Count Calculation**: Duration calculated as CEILING(days ÷ 7) to ensure partial weeks count as full weeks for medical school scheduling
4. **Null Handling**: Records missing MDCO_COURSE_UID or ELE_STARTDATE are excluded from results

## Usage Notes

- **Grouping**: Results are grouped by start date as requested by the registration team
- **Sorting**: Ordered by start date, then end date for block rotation planning, then by department and course
- **Campus Display**: Uses full campus names (not codes) for readability, with separate site identifiers for non-standard locations
- **Date Format**: Both start and end dates shown in YYYY-MM-DD format for medical school block scheduling
- **Block Rotations**: End dates are critical for medical school scheduling since block rotations have varying durations
- **Week Count**: Automatically calculated duration helps with resource planning and rotation standardization

## Implementation History

- **2026-02-01**: Initial implementation based on registration team requirements
- **Query Focus**: Limited to source columns as specified: MDCO_COURSE_UID, MDCO_CAMPUS_UID, ELE_STARTDATE, ELE_ENDDATE