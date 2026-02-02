# VCOM OAT | LEARNER ROTATION DATASET | DEV

## Overview

This repository contains the development codebase for the **LEARNER-ROTATION-DATASET**, focused specifically on **rotation schedules** rather than course enrollment. A rotation schedule is defined as an event that includes:

- Student assignment
- Course number
- Start date and end date  
- Campus assignment
- Block duration (typically 1, 2, or 4 weeks)

## Core Business Definition

**Rotation Schedule**: An event-based assignment of a student to a specific course for a defined time period at a designated campus location.

**Key Distinction**: This dataset focuses on **scheduling events** (when/where/who) rather than enrollment status (active/inactive/waitlist).

## Data Architecture Goals

### Primary Objectives
1. **Unified UID Generation**: Create consistent `MDCO_ENROLL_LRN_ROTATION_UID` across all source systems
2. **Cross-System Integration**: Harmonize rotation data from Progress IQ and Elentra systems
3. **AIM Population Tracking**: Separate processing pipeline for special student populations
4. **Campus Resolution**: Standardized campus assignment using `MDCO_CAMPUS` values

### Core MDCO Identifiers (LOCKED FORMAT)
These identifier formats are **immutable** and cannot be altered:

| Identifier | Purpose | Format Rules |
|------------|---------|-------------|
| `MDCO_ENROLL_LRN_ROTATION_UID` | Unique rotation event identifier | Generated via `fnBuildRotationUID_v1()` |
| `MDCO_ENROLL_COURSE_UID` | Course-level enrollment link | Generated via `fnBuildCRSRosterUID_v1()` |
| `MDCO_USR_UID` | Standardized student identifier | From LPROFILE source system |
| `MDCO_COURSE_UID` | Normalized course identifier | Via course mapping tables |
| `MDCO_CAMPUS` | Standardized campus location | Via `fnResolveMdcoCampus()` |

## Coding Standards

### Column Naming Convention
- **Use underscores (`_`) in ALL column headings**
- **Prohibited in columns**: `-`, `.`, `:`
- Examples: `ELE_STARTDATE`, `PIQ_COURSEID`, `SCHEDULE_BLOCK`

### Value Formatting Convention  
- **Use hyphens (`-`), periods (`.`), colons (`:`) as hash separators in VALUES**
- **Prohibited in values**: `_` (reserved for column names)
- Examples: `VCOM-MD-001`, `2025.FALL`, `14:30:00`

### Power Query Standards
```powerquery
// Query title as first line comment for easy identification
// stg_StudentRotations_PIQ

// Function naming conventions
fnBuildRotationUID_v1()     // UID generators with version suffix
fnNormalizeText()           // Data normalization functions
fnResolveMdcoCampus()      // Business logic functions

// Column transformation pattern
Table.RenameColumns(
    source,
    {
        {"old-name", "NEW_UNDERSCORE_NAME"}
    },
    MissingField.Ignore
)
```

## Repository Structure

```
src/
├── preprocessing/           # Stage 1: CSV to Datalake
│   ├── ELENTRA_ROTATIONS_PREPROCESSED.pq
│   └── PIQ_ROTATIONS_PREPROCESSED.pq
├── business_logic/         # Stage 2: Business Rules & UID Generation  
│   ├── MDCO_ENROLL_PIQ_ROTATION_SCHEDULED.pq
│   ├── MDCO_ENROLL_ELENTRA_ROTATIONS_ACTIVE.pq
│   ├── MDCO_ENROLL_PIQ_ROTATIONS_AIM.pq
│   └── MDCO_ENROLL_ELENTRA_ROTATIONS_AIM.pq
└── analytics/              # Stage 3: Cross-System Analysis
    └── MDCO_ENROLL_ROTATIONS_UTILITY.pq
```

## Data Processing Pipeline

### Stage 1: Preprocessing (Recommended Architecture)
- **Input**: Raw CSV files from SharePoint
- **Output**: Clean, typed, standardized datalake tables
- **Benefits**: Single-point data normalization, improved performance, consistent transformations

### Stage 2: Business Logic Application
- **Input**: Preprocessed datalake tables via `Lakehouse.Contents()`
- **Processing**: UID generation, AIM filtering, campus resolution
- **Output**: Business-ready rotation datasets

### Stage 3: Analytics & Reporting
- **Input**: Stage 2 business tables
- **Processing**: Cross-system matching, variance analysis
- **Output**: Management reporting and audit tables

## Source Files & Dependencies

### Primary Source Files
| CSV File | Academic Year | Used By |
|----------|---------------|---------|
| `PIQ-25AY27-ROTATION-LEARNERS.csv` | 2025-2027 | PIQ-based rotation queries |
| `ELENTRA-25AY26-ROTATIONS.csv` | 2025-2026 | Elentra-based rotation queries |

### Critical Dependencies
| Dependency | Purpose | Used By |
|------------|---------|---------|
| `src_VCOM_OAT_DATA_LPROFILE_v1` | Student profile master with MDCO_USR_UID | All core tables |
| `VCOM_OAT_DATA_PIQ_CRSUID_map` | PIQ course → MDCO course UID mapping | PIQ queries |
| `src_VCOM_OAT_DATA_ELENTRA_CRSUID_map` | Elentra course → MDCO course UID mapping | Elentra queries |
| `src_VSITE_VDATA_ElentraCampusCatalog` | Campus code → MDCO campus UID mapping | All core tables |

## Development Guidelines

### Version Control Strategy
- **Main Branch**: Documentation and established standards only
- **Development Branch**: All active development and testing
- **Feature Branches**: Specific enhancements or fixes

### Testing Requirements
- **Development Environment**: All changes must be tested in isolated dev environment
- **Data Validation**: Cross-system UID consistency verification required
- **Performance Testing**: Query execution time benchmarks for large datasets

### Deployment Protocol
1. Complete development in feature/dev branches
2. Comprehensive testing with production-scale data
3. Code review and documentation updates
4. Staged deployment to TEST → UAT → PROD environments

## Function Library Dependencies

### Core UID Generation Functions
```powerquery
// Student + Course enrollment UID
fnBuildCRSRosterUID_v1(student_uid, course_uid)

// Complete rotation event UID (THE primary key)
fnBuildRotationUID_v1(student_uid, course_uid, start_date, end_date, campus_uid)

// Campus resolution with fallback logic
fnResolveMdcoCampus(elentra_campus, piq_campus, default_value)

// Current processing date stamp
fnDATE_ActiveAsOf()
```

### Data Normalization Functions
```powerquery
// Text standardization
fnNormalizeText(input_text)

// Student ID standardization  
fnNormalizeStudentId(student_identifier)
```

## Data Quality Standards

### Required Validations
- **Non-null UID Generation**: All MDCO identifiers must be successfully generated
- **Date Consistency**: Start dates must be <= end dates
- **Campus Assignment**: All rotations must have valid MDCO_CAMPUS values
- **Cross-System Matching**: Three-point matching validation (student + course + start date)

### AIM Population Handling
- **Separate Processing**: AIM students processed in dedicated queries due to unique scheduling patterns
- **Audit Trail**: Complete tracking to prevent data loss during population segregation
- **Cross-Reference**: AIM assignments cross-validated with main population for completeness

## Performance Optimization

### Data Layer Architecture
- **Established Dataset Precedence**: Use published datalake tables via `Lakehouse.Contents()`
- **Avoid Reprocessing**: Never duplicate SharePoint CSV access in downstream queries
- **Two-Tier Pattern**: Heavy ETL separated from lightweight analytics

### Query Optimization
- **Selective Column Loading**: Only load required columns in each transformation step
- **Early Filtering**: Apply business rules as early as possible in query pipeline
- **Index Utilization**: Leverage UID columns for efficient joins

## Troubleshooting Guide

### Common Issues
1. **UID Generation Failures**: Check null values in required input parameters
2. **Campus Resolution Errors**: Verify campus mapping table completeness
3. **Date Type Mismatches**: Ensure consistent date type handling across all queries
4. **AIM Population Loss**: Verify filtering logic doesn't exclude intended students

### Debugging Steps
1. Validate source CSV file structure and encoding
2. Check dependency table availability and freshness
3. Test UID generation functions with sample data
4. Verify campus and course mapping completeness

## Contact & Support

For questions about this dataset or development standards:
- **Repository**: VCOM OAT Data Standards Documentation
- **Standards Reference**: Domain-driven naming conventions and Power Query patterns
- **Function Library**: Core UID generation and normalization functions
