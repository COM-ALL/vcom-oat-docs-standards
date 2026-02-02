# VCOM-OAT-ROTATION-PLANNING-EXPORT - Table & Column Reference

**Purpose**: Complete documentation of all tables and column mappings used in the rotation planning export query

## 📊 SOURCE TABLES

### 1. Primary Data Table
**Table**: `MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE`  
**Source**: Lakehouse table  
**Columns Used**:
- `MDCO_COURSE_UID` (filter condition, course parsing, course name join)
- `MDCO_CAMPUS_UID` (campus mapping join, campus/site logic)
- `ELE_STARTDATE` (filter condition, week count calculation, grouping)
- `ELE_ENDDATE` (week count calculation, grouping)

### 2. Course Mapping Table
**Table**: `VCOM-OAT-DATA-MDCO-CRSUID_mapkey`  
**Source**: Lakehouse table  
**Join Column**: `MDCO_COURSE_UID` (underscores)  
**Extracted Columns**:
- `MDCO_COURSENAME` → renamed to `Course Name`

### 3. Campus Mapping Table
**Table**: `VSITE-VDATA-GlobalCampusCatalog`  
**Source**: Lakehouse table  
**Join Column**: `mdco-campus-uid` (dashes)  
**Available Columns**: `[mdco-campus-uid]`, `[mdco-campus-name]`, `[mdco-campus-desc]`, `[campus-city]`, `[mdco-campus-active]`  
**Currently Extracted**: `mdco-campus-name` → renamed to `StandardCampusName`

## 🔗 JOIN OPERATIONS

### Campus Mapping Join (Lines 46-54)
```powerquery
Table.NestedJoin(
    addCourseID,                    // Left table: transformed rotation data
    {"MDCO_CAMPUS_UID"},           // Left join key: campus UID from source (underscores)
    campusMappingTable,            // Right table: GlobalCampusCatalog
    {"mdco-campus-uid"},           // Right join key: campus UID from catalog (dashes)
    "CampusMapping",               // Join result name
    JoinKind.LeftOuter
)
```

### Course Name Join (Lines 88-96)
```powerquery
Table.NestedJoin(
    addWeekCount,                  // Left table: data with week counts
    {"MDCO_COURSE_UID"},          // Left join key: course UID from source (underscores)
    courseMappingTable,           // Right table: MDCO course mapping
    {"MDCO_COURSE_UID"},          // Right join key: course UID from mapping (underscores)
    "CourseMapping",              // Join result name
    JoinKind.LeftOuter
)
```

## ⚠️ COLUMN NAME ISSUES

### Issue 1: Campus Mapping Column Mismatch (Line 60)
**Current Code**:
```powerquery
expandedCampusData = Table.ExpandTableColumn(
    joinedCampusData,
    "CampusMapping",
    {"campus_name"},               // ❌ This column name is wrong
    {"StandardCampusName"}
),
```

**Should Be**:
```powerquery
expandedCampusData = Table.ExpandTableColumn(
    joinedCampusData,
    "CampusMapping", 
    {"mdco-campus-name"},          // ✅ Correct column name
    {"StandardCampusName"}
),
```

### Issue 2: Source Table Column References
**Current Status**:
- `MDCO_COURSE_UID` - ✅ Correct (underscores)
- `MDCO_CAMPUS_UID` - ✅ Correct (underscores)  
- `ELE_STARTDATE` - ✅ Correct (underscores)
- `ELE_ENDDATE` - ✅ Correct (underscores)

## 🎯 GENERATED COLUMNS

### Calculated Fields
1. **DEPT** - Extracted from `MDCO_COURSE_UID` (department portion)
2. **COURSEID** - Extracted from `MDCO_COURSE_UID` (full course code)
3. **Campus** - Logic using `StandardCampusName` or parsed campus UID
4. **Site** - Last segment of campus UID for non-standard campuses
5. **Week Count** - Calculated from start/end date difference

### Final Output Columns
- `DEPT` (generated)
- `COURSEID` (generated)
- `Course Name` (from MDCO mapping table)
- `Campus` (generated logic)
- `Site` (generated logic)
- `Week Count` (calculated)
- `Enrollment Count` (aggregated count)
- `Start Date` (renamed from `ELE_STARTDATE`)
- `End Date` (renamed from `ELE_ENDDATE`)

## 🔧 IMMEDIATE FIX NEEDED

**Line 60**: Change `{"campus_name"}` to `{"mdco-campus-name"}` to match the actual column name in the `VSITE-VDATA-GlobalCampusCatalog` table.

```powerquery
// WRONG:
{"campus_name"}

// CORRECT:
{"mdco-campus-name"}
```

## 🏗️ TABLE ARCHITECTURE SUMMARY

```
MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE
├── MDCO_COURSE_UID (underscores) ──┐
├── MDCO_CAMPUS_UID (underscores) ──┼──► Campus Join
├── ELE_STARTDATE (underscores)     │
└── ELE_ENDDATE (underscores)       │
                                    │
VSITE-VDATA-GlobalCampusCatalog     │
├── mdco-campus-uid (dashes) ←──────┘
├── mdco-campus-name (dashes) ──► Extract as StandardCampusName
├── mdco-campus-desc (dashes)
├── campus-city (dashes)
└── mdco-campus-active (dashes)

VCOM-OAT-DATA-MDCO-CRSUID_mapkey
├── MDCO_COURSE_UID (underscores) ←──┐
├── MDCO_MDCODE (underscores)         │
├── MDCO_COURSECAT_UID (underscores)  │
├── MDCO_COURSENAME (underscores) ────┼──► Extract as Course Name
└── MDCO_COURSE-CATEGORY (mixed)      │
                                      │
MDCO_COURSE_UID (underscores) ────────┘
```