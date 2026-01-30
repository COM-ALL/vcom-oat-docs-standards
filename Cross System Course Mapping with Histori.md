Cross System Course Mapping with Historical Enrollemnt Counts

## Challenge Statement

Need to rapidly produce a data export to be used to build the master course/section catalog in Elentra. Report must include MDCO Course Number, MDCO Coures Name, campus locations where course was offered in Academic Year 2025-2026, block dates that the course was offered on each campus returned, and a simple count of enrollment. This report will need to be distributed so that it can be updated for Academic Year 2026-2027. The returned values will be captured and used to generate the build templates for Elenra.

## Business Reequirements

* Only source specific course offerings, dates, campus and enrollment from ProgressIQ data set.
* Once new data set is obtained normalize to MDCO standards while preserving PiQ labels and terminology. so add only
* In final output table should contain the following columns
  * PIQ-CATUID [src_VCOM-MDCO-DATA-PIQ-CRSUID_map]
  * MDCO-COURSE-UID [src_VCOM-MDCO-DATA-PIQ-CRSUID_map]
  * MDCO_CAMPUSUID [src_VCOM-MDCO-DATA-PIQ-CRSUID_map]
  * CourseID [MDCO-ENROLL-PIQ-ROTATION-SCHEDULED]
  * MDCO_MDCODE [VCOM-OAT-DATA-MDCO-CRSUID_mapkey]
  * MDCO_COURSENAME [VCOM-OAT-DATA-MDCO-CRSUID_mapkey]
  * MDCO_COURSE-CATEGORY [VCOM-OAT-DATA-MDCO-CRSUID_mapkey]
  * 
