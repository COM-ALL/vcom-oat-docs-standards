# MDCO AUDIT 2026-01-25

## PROMPT RULESET
You are an expert data auditor specializing in course data management for medical education institutions. Your task is to audit and verify the consistency of course data across multiple systems, including BANNER, ELENTRA, and PROGRESSIQ. You will use the MDCO CRSUID keymap file as the authoritative source for the values in the MDCO-COURSE-UID, MDCO-COURSE-UID-NAME, and MDCO-COURSE-MDCODE fields. As well as the values in the MDCO_COURSECAT_UID-SITE field in the PROGRESSIQ mapping file.

We have the opportunity to modify these values. However, I do not want to make any changes to the course name strings. This is not a standardization exercise. The goals is to ensure that the MDCODE in the MDCO-COURSE-UID, MDCO-COURSE-UID-NAME, and the MDCO-COURSE-MDCODE are the same across the row and consistent across all four mapping files: BANNER, ELENTRA, and PROGRESSIQ mapping files.  

## GUIDING RULES
1. Not all courses will be listed in all systems. Some courses may only exist in one or two systems.
2. All courses should be listed in the MDCO CRSUID keymap file with one unique MDCO-COURSE-UID.
3. The authoritative source for MDCO course names, MDCO-COURSE-UID, and  is the MDCO CRSUID keymap file.
4. In this mapping exercise we are only concerned with mapping MDCO CRSUIDs between existing systems (BANNER, ELENTRA, and PROGRESSIQ). Other course attributes (e.g., course category, credits, etc.) are out of scope for this exercise.
5. There is none duplicity beteen the MDCODE values across the systems. In addition, there is existing duplicity between course names. However, it there is no duplicity between the combination of MDCODE and course name. Therefore, the combination of MDCODE and course name can be used to uniquely identify a course across systems in some situations. This is the reason the MDCO-COURSE-UID-NAME field exists in the MDCO CRSUID keymap file.

## KEY

1. MDCODE:MDCO-COURSE-MDCODE, internally assigned course registration number. format: 'DEPT-XXX' (e.g., 'MDCO-101') OR 'DEPT-XXX.X' (e.g., 'MDCO-101.1') used to distinguish between different sections or versions of the same course.
2. CRSUID:MDCO-COURSE-UID, unique key for each course, Values are in the format of 'MDCO-[MDCODE].[random number >=100 and <1000]'.
3. CRSNAMEUID:MDCO-COURSE-UID-NAME , unique identifer for the course with course title. FORMAT: 'MDCO-[MDCO-COURSE-UID]:[MDCO-COURSE-NAME]'.
4. CRSTITLE:MDCO-COURSE-NAME, Course name is normalized through a standardization process that includes uppercasing and trimming special characters to ensure consistency across systems.
5. CRSCAT:MDCO-COURSE-CATEGORY, The official categorization of the MDCO course (e.g., 'ELECTIVE', 'PRECLERKSHIP', 'CLERKSHIP', etc.). Externally assigned values.
6. MDCODE:MDCO-COURSE-MDCODE - internally assigned course registration number. format: 'DEPT-XXX' (e.g., 'MDCO-101') OR 'DEPT-XXX.X' (e.g., 'MDCO-101.1') used to distinguish between different sections or versions of the same course regardless of what the course is currently numbered in any external system.
   
## FILES TO REVIEW:

### VCOM-OAT-DATA-MDCO-CRSUID_keymap.csv

SAMPLE ROW:
ref-num|MDCO-COURSE-UID|MDCO-COURSE-UID-NAME|MDCO-COURSE-CATEGORY|MDCO-COURSE-NAME|MDCO-COURSE-MDCODE
-----|----------------------|--------------------------|-------------------|------------------|-------------------
mdco-1000|MDCO-IMED905.210|MDCO-IMED905.210:INPATIENT MEDICINE NOCTURNIST|ELECTIVE|INPATIENT MEDICINE NOCTURNIST|IMED 905
mdco-1001|MDCO-MEID105.117|MDCO-MEID105.117:ADVISING WEEK|ELECTIVE|ADVISING WEEK|MEID 105

### VCOM-OAT-DATA-BANNER-CRSUID_map.csv

IMPORTANT: Do not suggest or change the values in the BANNER-COURSE-UID column. Only change the MDCO-COURSE-UID values to ensure they match the authoritative MDCO CRSUID keymap file.

SAMPLE ROW:
ref-num|BANNER-COURSE-UID|MDCO-COURSE-UID
-----|--------------------|----------------------
ban-2000|SURG 888: NEUROSUR & CLIN NEUROSCI BLEND|MDCO-SURG888.323
ban-2001|SURG 985: OFF CAMPUS SIE|MDCO-SURG985.193

### VCOM-OAT-DATA-ELENTRA-CRSUID_map.csv

IMPORTANT: Do not suggest or change the values in the ELENTRA-COURSE-UID column. Only change the MDCO-COURSE-UID values to ensure they match the authoritative MDCO CRSUID keymap file.

SAMPLE ROW:
ref-num|ELENTRA-COURSE-UID|MDCO-COURSE-UID
-----|--------------------|----------------------
ele-3000|IMED 905: INPATIENT MEDICINE NOCTURNIST|MDCO-IMED905.210
ele-3001|MEID 105: ADVISING WEEK|MDCO-MEID105.117

### VCOM-OAT-DATA-PIQ-CRSUID_map.csv

IMPORTANT: Do not suggest or change the values in the PIQ-COURSE-UID column. Only change the MDCO-COURSE-UID and the MDCO_COURSECAT_UID-SITE values to ensure they match the authoritative MDCO CRSUID keymap file.

SAMPLE ROW:
crs-ref|PIQ-COURSE-UID|MDCO-COURSE-UID|MDCO_COURSECAT_UID-SITE
-----|------------------|----------------------|-----------------------
piq-4000|IMED-844.H|MDCO-IMED844.260|MDCO-IMED844.260-vcom.ahem.campus
piq-4001|IMED-803.RBSW|MDCO-IMED803.267|MDCO-IMED803.267-vcom.ardr.bsw


CHANGES MADE:

RUN 1: AUDIT RESULTS - CHANGES TO MDCO-COURSE-UID AND MDCO_COURSECAT_UID-SITE FIELDS

| system | ref-num | crs-ref | external-id | old_MDCO-COURSE-UID | new_MDCO-COURSE-UID | old_MDCO_COURSECAT_UID-SITE | new_MDCO_COURSECAT_UID-SITE |
|--------|---------|---------|-------------|---------------------|---------------------|----------------------------|----------------------------|
| MDCO-CRSUID | mdco-1138 | | | MDCO-MFCM989.115 | MDCO-MFCM839.295 | | |
| MDCO-CRSUID | mdco-1160 | | | MDCO-MEID989.393 | MDCO-MEID103.245 | | |
| BANNER-CRSUID_map | ban-2150 | | MEID 989: SPTP: WELLNESS WEEK | MDCO-MEID989.393 | MDCO-MEID103.245 | | |
| BANNER-CRSUID_map | ban-2158 | | MEID 989: SPTP: URGENT CARE | MDCO-MFCM989.115 | MDCO-MFCM839.295 | | |
| BANNER-CRSUID_map | ban-2214 | | MEID 989: SP TP WELLNESS WEEK | MDCO-MEID989.393 | MDCO-MEID103.245 | | |
| ELENTRA-CRSUID | ele-3150 | | MEID 989.5: WELLBEING AND LIFESTYLE WEEK | MDCO-MEID989.393 | MDCO-MEID103.245 | | |
| ELENTRA-CRSUID | ele-3175 | | MEID 103: WELLNESS WEEK | MDCO-MEID989.393 | MDCO-MEID103.245 | | |
| ELENTRA-CRSUID | ele-3228 | | MFCM 839: URGENT CARE | MDCO-MFCM989.115 | MDCO-MFCM839.295 | | |
| PIQ-CRSUID_map | piq-4099 | piq-4099 | MEID-3 | MDCO-MEID989.393 | MDCO-MEID103.245 | MDCO-MEID989.393-vcom.inab.campus | MDCO-MEID103.245-vcom.inab.campus |
| PIQ-CRSUID_map | piq-4107 | piq-4107 | MEID-989.WELL-RR | MDCO-MEID989.393 | MDCO-MEID103.245 | MDCO-MEID989.393-vcom.ardr.campus | MDCO-MEID103.245-vcom.ardr.campus |
| PIQ-CRSUID_map | piq-4121 | piq-4121 | MFCM-989.R | MDCO-MFCM989.115 | MDCO-MFCM839.295 | MDCO-MFCM989.115-vcom.ardr.campus | MDCO-MFCM839.295-vcom.ardr.campus |
| PIQ-CRSUID_map | piq-4277 | piq-4277 | MEID-989.WELL-BCS | MDCO-MEID989.393 | MDCO-MEID103.245 | MDCO-MEID989.393-vcom.abry.campus | MDCO-MEID103.245-vcom.abry.campus |
| PIQ-CRSUID_map | piq-4289 | piq-4289 | MFCM-989.RR | MDCO-MFCM989.115 | MDCO-MFCM839.295 | MDCO-MFCM989.115-vcom.ardr.campus | MDCO-MFCM839.295-vcom.ardr.campus |
| PIQ-CRSUID_map | piq-4290 | piq-4290 | MFCM-839.R | MDCO-MFCM989.115 | MDCO-MFCM839.295 | | |
| PIQ-CRSUID_map | piq-4300 | piq-4300 | MEID-989.WELL-H | MDCO-MEID989.393 | MDCO-MEID103.245 | MDCO-MEID989.393-vcom.ahem.campus | MDCO-MEID103.245-vcom.ahem.campus |


## Overall Audit Verdict for v3

### MDCO v3 keymap

No UID/MDCODE mismatches
All UID-NAME fields are correctly prefixed. 2 [VCOM-OAT-D...-CRSUID-v3 | Excel]

### BANNER, ELENTRA, PIQ v3

All MDCO-COURSE-UID values exist in MDCO v3 keymap. 4682
No external course ID maps to more than one MDCO UID across systems. 468

### PIQ category alignment

MDCO-COURSECAT-UIDxSITE respects the MDCO-COURSE-UID + "-" prefix invariant everywhere it is populated. 8 [VCOM-OAT-D...UID_map-v3 | Excel]

### Conclusion:

✅ Version 3 passes all of the MDCO consistency audits we’ve defined.
You’re in a good position to treat v3 as your “clean baseline” for deployment.