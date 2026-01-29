# LEARNER-ROTATION-DATASET Architecture

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

* Consistent UID Generation: fnBuildRotationUID_v1 with 5-parameter validation across all systems
* AIM Student Segregation: Separate processing pipeline for special populations
* Cross-System Student Mapping: LPROFILE integration for MDCO_USR_UID standardization
* Robust Campus Resolution: fnResolveMdcoCampus with enhanced null handling
* Match Analysis: Three-point matching (student + course + startdate) with variance tracking
* Audit Trail: Complete metadata tracking (DATE_OF_RECORD, RECORD_ACTIVE, SYS)