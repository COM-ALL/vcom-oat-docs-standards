# COURSE-ROSTER-DATASET Architecture

## Overview
Course-level enrollment tracking across Banner, Elentra, and PIQ systems. This dataset focuses on static course enrollments (vs. dynamic rotation assignments) with campus assignments based on student home campus rather than clinical site locations.

## Business Model
- **Static Campus Assignment**: M1 students at ABRY (non-ENMED) or AHEM (ENMED only), M2 students at home campus
- **Group-Level Blocks**: Consistent for entire cohorts, not individual date ranges
- **Course Enrollment Focus**: Uses `MDCO_ENROLL_COURSE_UID` (shorter than rotation UID)
- **Multi-System Integration**: Banner (authoritative), Elentra (clinical), PIQ (tracking)

## Core Data Tables

### Banner Sources (Authoritative)
* MDCO-ENROLL-BANNER-COURSE-ROSTER-ACTIVE.pq - Banner course enrollments
* MDCO-ENROLL-BANNER-COURSE-ROSTER-AIM.pq - Banner AIM student enrollments (if different processing needed)

### Elentra Sources
* MDCO-ENROLL-ELENTRA-COURSE-ROSTER-ACTIVE.pq - Elentra course enrollments (moved from rotation dataset)
* MDCO-ENROLL-ELENTRA-COURSE-ROSTER-AIM.pq - Elentra AIM course enrollments

### PIQ Sources
* MDCO-ENROLL-PIQ-COURSE-ROSTER-ACTIVE.pq - PIQ course enrollments
* MDCO-ENROLL-PIQ-COURSE-ROSTER-AIM.pq - PIQ AIM course enrollments

## Analysis & Utility Tables
* MDCO-ENROLL-COURSE-UTILITY.pq - Cross-system course enrollment reconciliation
* MDCO-ENROLL-COURSE-LOOKUP.pq - Evaluation processor lookup support

## Key Differences from Rotation Dataset
- **Shorter UIDs**: `MDCO_ENROLL_COURSE_UID` vs `MDCO_ENROLL_LRN_ROTATION_UID`
- **Static Campus Logic**: Home campus assignment vs clinical site assignment
- **Banner Integration**: Banner as source of truth for course enrollments
- **Evaluation Support**: Provides lookup columns for evaluation processing

## Primary Key Structure
All tables use `MDCO_ENROLL_COURSE_UID` as primary key, enforcing:
- One student + One course = One enrollment record
- No duplicate course enrollments per student

## Dependencies
- **Student Profile**: `src_VCOM-OAT-DATA-LPROFILE-v1` for student UIDs
- **Course Mapping**: Banner, Elentra, PIQ course UID maps  
- **Campus Resolution**: Campus catalog for consistent campus UIDs
- **Evaluation Lookup**: Required columns for evaluation processor queries

## Data Flow
1. **Banner** → Authoritative course enrollments
2. **Elentra/PIQ** → Supplemental clinical course data
3. **Cross-System Reconciliation** → Identify discrepancies
4. **Evaluation Support** → Provide lookup data for student/course matching

## Notes
- Moved ELENTRA-COURSE-ROSTER from rotation dataset to proper home here
- Banner integration adds authoritative enrollment source
- Campus logic simplified vs rotation-level complexity
- Supports evaluation processor requirements