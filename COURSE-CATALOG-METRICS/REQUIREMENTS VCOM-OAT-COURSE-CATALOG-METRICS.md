# VCOM-OAT-COURSE-CATALOG-METRICS

GOAL:
1. Understand the structure of the table and have a clear understanding of the column groups.
2. Rapidly produce a Semantic model that will provide quality measures based on the data set provided. Measures should include num of rows by campus, course, and date blocks. 
3.  Determine the best method to produce an exported report that will show a 'catalog' of courses sorted by campus and date block. 
4.  Prepare data for a drillable dashboard that allows consumers to drill down from campus -> course -> block -> block details.
5. There is no student data in this model. However, each row represents a unique student course registration.
6. Minor rule: When proposiing colors for dashboards they should be accessible and color blind friendly. And should not include the color orange. I work for Texas A&M University System and orange is a trigger color. #50000 is a good resource for color selection.

Definitions:

ELENTRA (ELE) - system that contains course schedules based on a lottery, course requirements, and electives selected by the student in advance.
BANNER (BAN) - system that contains current and historical student schedule. University offcial SIS, heavily controlled, and limited fields for metadata or detailed performance data. Key here is that this system only acknowledges two half year terms. SPRING (YYYY15) and FALL (YYYY35). 
ProgresIQ (PIQ) - system that contains meta data including performance evaluations, student academic status, and track. (In this model we will be analying the course registration patters for the past and current academic year to identify trends and project capacity nees for the next academic year.)

COURSE - Defined by an MDCODE (DEPT ###) MD codes are not used consistently across systems. The MDCO_COURSE code - normalizes the discrepencies across systems and provides an opportunity to identify discrepencies in course names. This model includes the course code and the course name in a column for each system. When dealing with the course level number and name we should always use the MDCO_ values has headers and identifiers. We may need to create an index of the courses for users who only work in one of the three systems.

BLOCK - a block is defined as the period of time between a start date and an end date. We have a standard rule that a block always starts on a MON and ends on a SUN for Electives. However compliance with this rule is not always enforced. Elentra recognizes a block and a start/end date; however, the other systems only report a start date (banner) or a start/end date (PIQ). The MDCO_BLOCK_UID is a normalized value that identifies all unique blocks across systems. However, we will not have access to that in this data set. We will need a data transformation to create a normalized block value based on start/end date combinations with enrollment counts (count of rows) for each course, and campus/site. We should consider the start date as the primary key for block identification. And, if a block has the same start date but different end date we can create a sub-block identifier. The WEEKNUM (always calcuated with a MONDAY start date) based on the start date is available in the data set to help with analysis and may be used as part of the block normalization process and block labeling. In addition the duration in weeks is also provided to help with analysis. Of particular interest is the ability to identify standard block lengths for electives (2 and 4 weeks) and clerkships (2, 6, and 8 weeks) and identify non-standard block lengths that may need further review. Block lengths tha vary by less than a 5 days should be considered for normalization to the standard block lengths. Block lenths that vary by more than 5 days should be flagged for review with a rating scale (minor, moderate, major) based on the number of days outside the standard block length.

Sites/Campuses - the location where a student is assigned for the duration of a block. BAN - recognizes a limited number of campuses, ELE - has a site -> building hieracy structure, PIQ does not has a string label and a code that is combined with the MDCODE to indicate campus. The MDCO_CAMPUS_UID is a normalized value that identifies all unique campus/sites. 

The definition for a rotation/enrollment is a unique combination of student, course, block, and site/campus. Each row in the data set represents a unique enrollment. However, the student identifier is not provided in this data set. So for this model we will be focusing on the course, block, and campus/site dimensions.

TABLE STRUCTURE:

I am providing the query that was used to create the data set for this model. The data set is a denormalized flat table that includes all columns from the three systems (BAN, ELE, PIQ) along with the normalized columns (MDCO_*) that were created as part of the ETL process. It is stored in the Datalake in the VCOM-OAT schema as VCOM_OAT_COURSE_CATALOG_METRICS.

-----------
Note code is only provided as reference for table structure and column definitions. (If you wanto to clean it great just drop it into a new file....however, do not change any column names and feel free to clean up this document as well)
-----------

````
let
  Source = #"MDCO-ENROLL-PIQ-ROTATION-SCHEDULED",
  #"Merged queries" = Table.NestedJoin(Source, {"MDCO_COURSE_UID"}, #"VCOM-OAT-DATA-MDCO-CRSUID_mapkey", {"MDCO_COURSE_UID"}, "VCOM-OAT-DATA-MDCO-CRSUID_mapkey", JoinKind.LeftOuter),
  #"Expanded VCOM-OAT-DATA-MDCO-CRSUID_mapkey" = Table.ExpandTableColumn(#"Merged queries", "VCOM-OAT-DATA-MDCO-CRSUID_mapkey", {"MDCO_MDCODE", "MDCO_COURSECAT_UID", "MDCO_COURSENAME", "MDCO_COURSE-CATEGORY"}, {"MDCO_MDCODE", "MDCO_COURSECAT_UID", "MDCO_COURSENAME", "MDCO_COURSE-CATEGORY"}),
  #"Invoked custom function" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded VCOM-OAT-DATA-MDCO-CRSUID_mapkey", "Invoked custom function", each fnCourseDurationWeeks_v1([STARTDATE], [ENDDATE])), {{"Invoked custom function", type number}}),
  #"Renamed columns" = Table.RenameColumns(#"Invoked custom function", {{"Invoked custom function", "DURATION"}}),
  #"Changed column type" = Table.TransformColumnTypes(#"Renamed columns", {{"DURATION", type text}}),
  #"Invoked custom function 1" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type", "Invoked custom function", each fnWeekKeyFromDate([STARTDATE])), {{"Invoked custom function", Int64.Type}}),
  #"Removed columns" = Table.RemoveColumns(#"Invoked custom function 1", {"Invoked custom function", "MDCO_COURSECAT_UID"}),
  #"Inserted conditional column" = Table.AddColumn(#"Removed columns", "TERM", each if [STARTDATE] < #date(2025, 7, 1) then 202515 else if [STARTDATE] < #date(2026, 1, 1) then 202535 else if [STARTDATE] < #date(2026, 7, 1) then 202615 else if [STARTDATE] < #date(2027, 1, 1) then 202635 else 202715),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Inserted conditional column", {{"TERM", type text}}),
  #"Added custom" = Table.AddColumn(#"Changed column type 1", "YEAR", each Date.Year([STARTDATE])),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "WEEKNUM", each Date.WeekOfYear([STARTDATE], Day.Monday)), {{"WEEKNUM", Int64.Type}}),
  #"Merged queries 1" = Table.NestedJoin(#"Added custom 1", {"MDCO_COURSE_UID"}, #"VCOM-OAT-DATA-BANNER-CRSUID_map", {"MDCO_COURSE_UID"}, "VCOM-OAT-DATA-BANNER-CRSUID_map", JoinKind.LeftOuter),
  #"Expanded VCOM-OAT-DATA-BANNER-CRSUID_map" = Table.ExpandTableColumn(#"Merged queries 1", "VCOM-OAT-DATA-BANNER-CRSUID_map", {"BANNER_CATUID"}, {"BANNER_CATUID"}),
  #"Merged queries 2" = Table.NestedJoin(#"Expanded VCOM-OAT-DATA-BANNER-CRSUID_map", {"MDCO_COURSE_UID"}, #"VCOM-OAT-DATA-ELENTRA-CRSUID_map", {"MDCO_COURSE_UID"}, "VCOM-OAT-DATA-ELENTRA-CRSUID_map", JoinKind.LeftOuter),
  #"Expanded VCOM-OAT-DATA-ELENTRA-CRSUID_map" = Table.ExpandTableColumn(#"Merged queries 2", "VCOM-OAT-DATA-ELENTRA-CRSUID_map", {"ELENTRA_CATUID"}, {"ELENTRA_CATUID"}),
  #"Reordered columns" = Table.ReorderColumns(#"Expanded VCOM-OAT-DATA-ELENTRA-CRSUID_map", {"MDCO_COURSE_UID", "MDCO_MDCODE", "PIQ_CATUID", "MDCO_COURSENAME", "YEAR", "TERM", "WEEKNUM", "DURATION", "STARTDATE", "ENDDATE", "MDCO_CAMPUS_UID", "PIQ_CAMPUS_LABEL", "MDCO_COURSE-CATEGORY", "BANNER_CATUID", "ELENTRA_CATUID"}),
  #"Merged queries 3" = Table.NestedJoin(#"Reordered columns", {"MDCO_CAMPUS_UID"}, #"VSITE-VDATA-ElentraCampusCatalog", {"MDCO_CAMP_CODE"}, "VSITE-VDATA-ElentraCampusCatalog", JoinKind.LeftOuter),
  #"Expanded VSITE-VDATA-ElentraCampusCatalog" = Table.ExpandTableColumn(#"Merged queries 3", "VSITE-VDATA-ElentraCampusCatalog", {"ELENTRA_SITEID", "ELENTRA_CAMPUS", "ELENTRA_BUILDING"}, {"ELENTRA_SITEID", "ELENTRA_CAMPUS", "ELENTRA_BUILDING"}),
  #"Changed column type 2" = Table.TransformColumnTypes(#"Expanded VSITE-VDATA-ElentraCampusCatalog", {{"DURATION", Int64.Type}}),
  #"Removed columns 1" = Table.RemoveColumns(#"Changed column type 2", {"ELENTRA_SITEID"}),
  #"Reordered columns 1" = Table.ReorderColumns(#"Removed columns 1", {"MDCO_COURSE_UID", "MDCO_MDCODE", "PIQ_CATUID", "MDCO_COURSENAME", "YEAR", "TERM", "WEEKNUM", "DURATION", "STARTDATE", "ENDDATE", "MDCO_CAMPUS_UID", "PIQ_CAMPUS_LABEL", "ELENTRA_CAMPUS", "ELENTRA_BUILDING", "MDCO_COURSE-CATEGORY", "BANNER_CATUID", "ELENTRA_CATUID"}),
  #"Renamed columns 1" = Table.RenameColumns(#"Reordered columns 1", {{"BANNER_CATUID", "CANVAS_CRS_NAME"}, {"ELENTRA_CATUID", "ELENTRA_CRS_NAME"}}),
  #"Changed column type 3" = Table.TransformColumnTypes(#"Renamed columns 1", {{"YEAR", Int64.Type}}),
  #"Duplicated column" = Table.DuplicateColumn(#"Changed column type 3", "CANVAS_CRS_NAME", "CANVAS_CRS_NAME - Copy"),
  #"Split column by delimiter" = Table.SplitColumn(#"Duplicated column", "CANVAS_CRS_NAME - Copy", Splitter.SplitTextByEachDelimiter({":"}, QuoteStyle.Csv), {"CANVAS_CRS_NAME - Copy.1", "CANVAS_CRS_NAME - Copy.2"}),
  #"Renamed columns 2" = Table.RenameColumns(#"Split column by delimiter", {{"CANVAS_CRS_NAME - Copy.1", "BANNER_MDCODE"}, {"CANVAS_CRS_NAME - Copy.2", "BANNER_COURSENAME"}}),
  #"Removed columns 2" = Table.RemoveColumns(#"Renamed columns 2", {"CANVAS_CRS_NAME"}),
  #"Split column by delimiter 1" = Table.SplitColumn(#"Removed columns 2", "ELENTRA_CRS_NAME", Splitter.SplitTextByEachDelimiter({":"}, QuoteStyle.Csv), {"ELENTRA_CRS_NAME.1", "ELENTRA_CRS_NAME.2"}),
  #"Renamed columns 3" = Table.RenameColumns(#"Split column by delimiter 1", {{"ELENTRA_CRS_NAME.1", "ELENTRA_MDCODE"}, {"ELENTRA_CRS_NAME.2", "ELENTRA_COURSENAME"}}),
  #"Trimmed text" = Table.TransformColumns(#"Renamed columns 3", {{"ELENTRA_MDCODE", each Text.Trim(_), type nullable text}, {"ELENTRA_COURSENAME", each Text.Trim(_), type nullable text}, {"BANNER_MDCODE", each Text.Trim(_), type nullable text}, {"BANNER_COURSENAME", each Text.Trim(_), type nullable text}})
in
  #"Trimmed text"
```

   

