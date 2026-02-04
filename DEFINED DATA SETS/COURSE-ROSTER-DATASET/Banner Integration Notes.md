# COURSE-ROSTER-DATASET Banner Integration

## Overview
The **VCOM-OAT-DATA-BANNER-COURSE-ROSTER-v1.pq** query implements Banner enrollment data integration for the Course Roster Dataset, based on the proven prototype flow pattern from the existing Power Automate implementation.

## Architecture Alignment

### 1. **Prototype Flow Compatibility**
- **Follows established pattern** from `prototypeflow_banner_enrollments.pq`
- **Maintains core schema** with `CROSTER_UID`, `MDCO_CATUID`, and Banner identifiers
- **Preserves join logic** for course and student profile lookups
- **Adapts for three-file structure** instead of single Dataverse table

### 2. **Campus Extraction Solution**
- **Extracts campus BEFORE merges** to prevent data loss identified in prototype analysis
- **Implements section parsing logic**: `##B→ABRY`, `##D→ADLL`, `##L→LYNC`, `##R→ROAN`
- **Course-level logic**: Campus extraction only for courses ≤800 level
- **Fallback handling**: Uses Banner campus field when parsing fails

### 3. **Course Roster Dataset Integration**
```powerquery
// Primary Key Generation (matches architecture)
CROSTER_UID = STU_UIN + "-" + MDCO_CATUID + "-" + TERM

// NAME_HASH for Evaluation Matching
NAME_HASH = STU_UIN  // Banner provides UINs directly

// MDCO Course Mapping
Uses: VCOM-OAT-DATA-BANNER-CRSUID_map-master.csv
```

## Data Pipeline Flow

### 1. **Source Data Processing**
```
enrollments.csv → Student enrollment records
sections.csv    → Section details with campus info  
courses.csv     → Course catalog information
mapping.csv     → MDCO course UID mappings
```

### 2. **Critical Campus Extraction**
```powerquery
// BEFORE any joins that might lose section context
sections_with_campus = Table.AddColumn(sections_typed, "EXTRACTED_CAMPUS", each 
    if courseNum <= 800 and section_suffix in ["B","D","L","R"] then
        campus_mapping[suffix]  // ABRY, ADLL, LYNC, ROAN
    else 
        [Campus]  // Use Banner campus field
)
```

### 3. **Integration Pipeline**
```
1. enrollments ⟵⟶ sections (with extracted campus)
2. + courses (catalog information)  
3. + MDCO mapping (course UID resolution)
4. + UID generation (CROSTER_UID, NAME_HASH)
5. + standardization (field names, data types)
```

## Output Schema Comparison

| **Field** | **Prototype Pattern** | **New Implementation** | **Notes** |
|-----------|----------------------|----------------------|-----------|
| `CROSTER_UID` | ✓ Primary key | ✓ Primary key | Consistent pattern |
| `MDCO_CATUID` | ✓ From UID split | ✓ From mapping join | More robust source |
| `STU_UIN` | ✓ Student ID | ✓ Student ID | Consistent |
| `NAME_HASH` | ✗ Not present | ✓ Added | Evaluation matching |
| `BANNER_CAMPUS` | ✓ Basic field | ✓ Enhanced logic | Campus extraction |
| Banner Fields | ✓ Standard set | ✓ Expanded set | More comprehensive |

## Data Quality Features

### 1. **Validation Rules**
- **Non-null constraints**: `CROSTER_UID`, `STU_UIN`, `BANNER_CRN`
- **UID format validation**: Student-Course-Term pattern
- **Campus resolution**: Multi-level fallback logic

### 2. **Error Handling**
- **Missing mapping graceful**: Continues processing with null `MDCO_CATUID`
- **Campus extraction safe**: Falls back to Banner campus on parsing errors  
- **Type conversion protected**: Uses `try/otherwise` patterns

### 3. **Performance Optimizations**
- **Single-pass processing**: Minimizes data scanning
- **Selective column loading**: Reduces memory footprint
- **Pre-filtering**: Removes invalid records early

## Integration Points

### 1. **Course Roster Dataset**
- **Primary Banner source** for enrollment data
- **Joins with Elentra** via `MDCO_CATUID` mapping
- **Student profile lookup** via `STU_UIN` key

### 2. **Evaluation Matching**
- **NAME_HASH field** enables evaluation-to-student matching
- **UIN-based hashing** (Banner advantage over Elentra)
- **Consistent with evaluation processing architecture**

### 3. **Lakehouse Integration**
- **Publishable format** ready for datalake deployment
- **Reusable reference** for downstream analytics
- **Audit trail preserved** with load timestamps

## Next Steps

1. **Testing Phase**
   - Validate against sample Banner files
   - Confirm campus extraction logic with real section data
   - Test MDCO mapping completeness

2. **Student Profile Integration** 
   - Connect to student master roster
   - Add demographic and class-of information
   - Match prototype's student join pattern

3. **Dataset Consolidation**
   - Union with Elentra course roster data
   - Implement unified schema
   - Deploy to lakehouse for consumption

## Dependencies

- **Banner Files**: `enrollments.csv`, `sections.csv`, `courses.csv`
- **Mapping File**: `VCOM-OAT-DATA-BANNER-CRSUID_map-master.csv`
- **SharePoint Access**: `tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev`
- **Student Master**: Future join with student profile dataset