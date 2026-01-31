// MDCO-ENROLL-PIQ-ROTATIONS-AIM
let
    // 1) Source from SharePoint folder - PIQ AIM students only
    Source =
        SharePoint.Files(
            "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev",
            [ApiVersion = 15]
        ),

    #"Filtered rows" =
        Table.SelectRows(
            Source,
            each not Text.StartsWith([Name], "Roster_")
              and not Text.StartsWith([Name], "global")
              and not Text.StartsWith([Name], "Roster-")
        ),

    Navigation =
        #"Filtered rows"{
            [ Name = "PIQ-25AY27-ROTATION-LEARNERS.csv",
              #"Folder Path"
                = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/" ]
        }[Content],

    #"Imported CSV" =
        Csv.Document(
            Navigation,
            [Delimiter = ",", Columns = 14, Encoding = 65001, QuoteStyle = QuoteStyle.None]
        ),

    #"Promoted headers" =
        Table.PromoteHeaders(#"Imported CSV", [PromoteAllScalars = true]),

    // 2) Trim and standardize date processing
    #"Trimmed CourseID" =
        Table.TransformColumns(
            #"Promoted headers",
            {{"*CourseID", each Text.Trim(_), type nullable text}}
        ),

    // 3) Robust date column standardization
    #"Trim header names" =
        Table.TransformColumnNames(#"Trimmed CourseID", Text.Trim),

    #"Renamed date columns" =
        Table.RenameColumns(
            #"Trim header names",
            {
                {"*BeginDate", "startdate"},
                {"*EndDate",   "enddate"}
            },
            MissingField.Ignore
        ),

    // 4) Ensure date types
    #"Fixed date types" =
        Table.TransformColumnTypes(
            #"Renamed date columns",
            {{"startdate", type date}, {"enddate", type date}}
        ),

    // 5) Standardize column headers to match other queries
    #"Standardized headers" =
        Table.RenameColumns(
            #"Fixed date types",
            {
                {"*StudentID", "PIQ_STUDENTID"},
                {"*CourseID", "PIQ_COURSEID"},
                {"Location(Site)", "SITE_CODE"},
                {"*AcademicYear", "ACADEMIC_YEAR"},
                {"AcademicTerm", "ACADEMIC_TERM"},
                {"*Activity(CourseDisplayName)", "COURSE_DISPLAY_NAME"},
                {"CourseCredits(Weeks)", "COURSE_CREDITS_WEEKS"},
                {"CourseSection", "COURSE_SECTION"},
                {"CourseDescription", "COURSE_DESCRIPTION"}
            },
            MissingField.Ignore
        ),

    // 6) Add student profile lookup to identify AIM students
    #"Join student_profile" =
        Table.NestedJoin(
            #"Standardized headers",
            {"PIQ_STUDENTID"},
            #"src_VCOM-OAT-DATA-LPROFILE-v1",
            {"student_id"},
            "StudentProfile",
            JoinKind.LeftOuter
        ),

    #"Expanded student_profile" =
        Table.ExpandTableColumn(
            #"Join student_profile",
            "StudentProfile",
            {"student_id", "programs", "student_email_sso"},
            {"MDCO_USR_UID", "PROGRAMS", "STUDENT_EMAIL_SSO"}
        ),

    // 7) Filter FOR AIM students only (opposite of main PIQ query)
    #"AIM students only" =
        Table.SelectRows(#"Expanded student_profile", 
            each [MDCO_USR_UID] <> null and [PROGRAMS] = "AIM"),

    // 8) Add course UID mapping (PIQ course -> MDCO-COURSE-UID, MDCO_CAMPUSUID)
    #"Merged course map" =
        Table.NestedJoin(
            #"AIM students only",
            {"PIQ_COURSEID"},
            #"VCOM-OAT-DATA-PIQ-CRSUID_map",
            {"PIQ-CATUID"},
            "VCOM-OAT-DATA-PIQ-CRSUID_map",
            JoinKind.LeftOuter
        ),

    #"Expanded course map" =
        Table.ExpandTableColumn(
            #"Merged course map",
            "VCOM-OAT-DATA-PIQ-CRSUID_map",
            {"MDCO-COURSE-UID", "MDCO_CAMPUSUID"},
            {"MDCO-COURSE-UID", "piq_CAMPUSUID"}
        ),

    // 9) Build MDCO_ENROLL_COURSE_UID (course-level enrollment)
    #"Added MDCO_ENROLL_COURSE_UID" =
        Table.AddColumn(
            #"Expanded course map",
            "MDCO_ENROLL_COURSE_UID",
            each fnBuildCRSRosterUID_v1([MDCO_USR_UID], [#"MDCO-COURSE-UID"]),
            type text
        ),

    // 10) Campus resolution using Elentra campus catalog
    #"Merged campus catalog" =
        Table.NestedJoin(
            #"Added MDCO_ENROLL_COURSE_UID",
            {"SITE_CODE"},
            #"src_VSITE-VDATA-ElentraCampusCatalog",
            {"elentra-campus-uid"},
            "CampusMap",
            JoinKind.LeftOuter
        ),

    #"Expanded campus catalog" =
        Table.ExpandTableColumn(
            #"Merged campus catalog",
            "CampusMap",
            {"mdco-campus-uid"},
            {"elentra_mdco_campus"}
        ),

    // 11) Resolve final MDCO_CAMPUS using fnResolveMdcoCampus
    #"Resolved MDCO_CAMPUS" =
        Table.AddColumn(
            #"Expanded campus catalog",
            "MDCO_CAMPUS",
            each fnResolveMdcoCampus([elentra_mdco_campus], [piq_CAMPUSUID]),
            type text
        ),

    // 12) Build MDCO_ENROLL_LRN_ROTATION_UID (THE KEY FIELD)
    #"Added MDCO_ENROLL_LRN_ROTATION_UID" =
        Table.AddColumn(
            #"Resolved MDCO_CAMPUS",
            "MDCO_ENROLL_LRN_ROTATION_UID",
            each fnBuildRotationUID_v1(
                    [MDCO_USR_UID],       // Student UID
                    [#"MDCO-COURSE-UID"], // Course UID
                    [startdate],          // PIQ start date
                    [enddate],            // PIQ end date
                    [MDCO_CAMPUS]         // Resolved campus
                 ),
            type text
        ),

    // 13) Add metadata for tracking
    #"Added DATE_OF_RECORD" =
        Table.AddColumn(
            #"Added MDCO_ENROLL_LRN_ROTATION_UID",
            "DATE_OF_RECORD",
            each fnDATE_ActiveAsOf(),
            type date
        ),

    #"Added RECORD_ACTIVE" =
        Table.AddColumn(
            #"Added DATE_OF_RECORD",
            "RECORD_ACTIVE",
            each true,
            type logical
        ),

    #"Added SYS" =
        Table.AddColumn(
            #"Added RECORD_ACTIVE",
            "SYS",
            each "PIQ",
            type text
        ),

    // 14) Final selection with all MDCO fields included
    #"Selected columns" =
        Table.SelectColumns(
            #"Added SYS",
            {
                "MDCO_ENROLL_LRN_ROTATION_UID",  // THE KEY FIELD
                "MDCO_ENROLL_COURSE_UID",
                "MDCO_USR_UID",
                "MDCO-COURSE-UID",
                "MDCO_CAMPUS",
                "PIQ_STUDENTID", 
                "PIQ_COURSEID",
                "startdate",
                "enddate",
                "SITE_CODE",
                "ACADEMIC_YEAR",
                "ACADEMIC_TERM",
                "COURSE_DISPLAY_NAME",
                "COURSE_CREDITS_WEEKS",
                "COURSE_SECTION",
                "COURSE_DESCRIPTION",
                "PROGRAMS",
                "STUDENT_EMAIL_SSO",
                "DATE_OF_RECORD",
                "RECORD_ACTIVE",
                "SYS",
                "Preceptor(s)",
                "Block",
                "Collection"
            }
        ),
  #"Marked key columns" = Table.AddKey(#"Selected columns", {"MDCO_ENROLL_LRN_ROTATION_UID"}, false)
in
    #"Marked key columns"