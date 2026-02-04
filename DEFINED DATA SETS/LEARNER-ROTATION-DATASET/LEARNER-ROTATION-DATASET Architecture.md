# LEARNER-ROTATION-DATASET Architecture

This dataset is compiled from source csv documents via the dataflow:

```

MDCO ENROLL ROTATION COMPOSITE

````
and populates the tables listed below.

This represents a comprehensive audit and migration infrastructure with the following components:

## Core Data Tables (4 tables)

* MDCO-ENROLL-PIQ-ROTATION-SCHEDULED.pq - PIQ rotations excluding AIM students
* MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE.pq - Elentra rotations excluding AIM students
* MDCO-ENROLL-PIQ-ROTATIONS-AIM.pq - PIQ AIM students (separate tracking)
* MDCO-ENROLL-ELENTRA-ROTATIONS-AIM.pq - Elentra AIM students (separate tracking)

## Analysis & Utility Tables

* MDCO-ENROLL-ROTATIONS-UTILITY.pq - Cross-system comparison with match analysis
* MDCO-ENROLL-ELENTRA-COURSE-ROSTER-ACTIVE.pq - Course-level enrollment tracking

## Key* Technical Features Delivered

* REQUIREMENT: MDCO_ENROLL_LRN_ROTATION_UID is the only key column allowed in this dataset and must be calculated using the same functions for all tables. 
* Consistent UID Generation: fnBuildRotationUID_v1 with 5-parameter validation across all systems
* AIM Student Segregation: Separate processing pipeline for special populations
* Cross-System Student Mapping: LPROFILE integration for MDCO_USR_UID standardization
* Robust Campus Resolution: fnResolveMdcoCampus with enhanced null handling
* Match Analysis: Three-point matching (student + course + startdate) with variance tracking
* Audit Trail: Complete metadata tracking (DATE_OF_RECORD, RECORD_ACTIVE, SYS)
* Once the pipeline and resulting tables are assigned a major version number the core code may not be altered without going through full testing in a development environment. Any future alterations or code work should only be completed in a clearly identifed branch in GitHub.

## Source CSV Files and Dependencies

* MDCO-ENROLL-PIQ-ROTATION-SCHEDULED.pq
  * Source CSV: `PIQ_ROTATION_SCHEDULED.csv`
  * Dependencies: `PIQ_ROTATION_SCHEDULED.csv`

* MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE.pq
  * Source CSV: `ELENTRA_ROTATIONS_ACTIVE.csv`
  * Dependencies: `ELENTRA_ROTATIONS_ACTIVE.csv`

* MDCO-ENROLL-PIQ-ROTATIONS-AIM.pq
  * Source CSV: `PIQ_ROTATIONS_AIM.csv`
  * Dependencies: `PIQ_ROTATIONS_AIM.csv`

* MDCO-ENROLL-ELENTRA-ROTATIONS-AIM.pq
  * Source CSV: `ELENTRA_ROTATIONS_AIM.csv`
  * Dependencies: `ELENTRA_ROTATIONS_AIM.csv`

* MDCO-ENROLL-ROTATIONS-UTILITY.pq
  * Source CSV: `ROTATIONS_UTILITY.csv`
  * Dependencies: `ROTATIONS_UTILITY.csv`

* MDCO-ENROLL-ELENTRA-COURSE-ROSTER-ACTIVE.pq
  * Source CSV: `ELENTRA_COURSE_ROSTER_ACTIVE.csv`
  * Dependencies: `ELENTRA_COURSE_ROSTER_ACTIVE.csv`
`````