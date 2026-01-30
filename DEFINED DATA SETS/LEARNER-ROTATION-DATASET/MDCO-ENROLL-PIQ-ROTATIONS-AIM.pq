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

    // 8) Add metadata for tracking
    #"Added DATE_OF_RECORD" =
        Table.AddColumn(
            #"AIM students only",
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

    // 9) Final selection for AIM counting and tracking
    #"Selected columns" =
        Table.SelectColumns(
            #"Added SYS",
            {
                "MDCO_USR_UID",
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
        )
in
    #"Selected columns"