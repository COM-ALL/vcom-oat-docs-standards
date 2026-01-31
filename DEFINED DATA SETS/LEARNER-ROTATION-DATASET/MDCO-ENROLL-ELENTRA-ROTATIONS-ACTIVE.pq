let
    // 1) Load Elentra rotations CSV from SharePoint
    Source =
        SharePoint.Files(
            "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev",
            [ApiVersion = 15]
        ),

    #"Filtered rows" =
        Table.SelectRows(
            Source,
            each [Folder Path]
                = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/"
        ),

    Navigation =
        #"Filtered rows"{
            [ Name = "ELENTRA-25AY26-ROTATIONS.csv",
              #"Folder Path"
                = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/" ]
        }[Content],

    #"Imported CSV" =
        Csv.Document(
            Navigation,
            [Delimiter = ",", Columns = 14, QuoteStyle = QuoteStyle.None]
        ),

    #"Promoted headers" =
        Table.PromoteHeaders(#"Imported CSV", [PromoteAllScalars = true]),

    // 2) Filter out non-course rows
    #"Filtered course code" =
        Table.SelectRows(
            #"Promoted headers",
            each [Course Code] <> "N/A"
        ),

    // 3) Ensure date types for rotation dates only
    #"Changed type dates" =
        Table.TransformColumnTypes(
            #"Filtered course code",
            {
                {"(Custom) Start Date", type date},
                {"(Custom) End Date", type date}
            }
        ),

    // 5) Normalize and classify enrollment Status -> ELE_ENROLL_STATUS
    #"Trimmed Status" =
        Table.TransformColumns(
            #"Changed type dates",
            {{"Status", each Text.Trim(_), type nullable text}}
        ),

    #"Added ELE_ENROLL_STATUS" =
        Table.AddColumn(
            #"Trimmed Status",
            "ELE_ENROLL_STATUS",
            each
                if [Status] = "Confirmed" or [Status] = "" then
                    "ACTIVE"
                else if [Status] = "Requested" then
                    "WAITLIST"
                else
                    "INACTIVE",
            type text
        ),

    #"Removed raw Status" =
        Table.RemoveColumns(#"Added ELE_ENROLL_STATUS", {"Status"}),

    // 6) Add snapshot metadata: DATE_OF_RECORD, RECORD_ACTIVE, SYS
    #"Added DATE_OF_RECORD" =
        Table.AddColumn(
            #"Removed raw Status",
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
            each "ELENTRA",
            type text
        ),

    // 7) Rename business columns to MDCO-friendly names (using actual CSV column names)
    #"Renamed business columns" =
        Table.RenameColumns(
            #"Added SYS",
            {
                {"(Custom) Start Date",   "ELE_STARTDATE"},     // Rotation start date
                {"(Custom) End Date",     "ELE_ENDDATE"},       // Rotation end date
                {"Course Code",           "ELENTRA_MDCODE"},
                {"Number/Email",          "STU_EMAIL"},          // Fixed: actual column name
                {"First Name",            "FIRST_NAME"},
                {"Last Name",             "LAST_NAME"},
                {"Rotation Code",         "ROTATION_CODE"},
                {"Schedule Blocks (No.)", "SCHEDULE_BLOCK"},
                {"Block Length (Weeks)",  "BLOCK_LENGTH_WEEKS"},
                {"Site(s)",               "SITE_CODE"},
                {"Has Custom Date",       "HAS_CUSTOM_DATE"},
                {"Status",                "STATUS"}
            },
            MissingField.Ignore
        ),

    // 8) Retrieve MDCO_USR_UID from LPROFILE v1 (Progress IQ student profile with SSO email)
    // Exclude AIM students - they will be processed separately due to unique scheduling patterns
    #"Join student_profile" =
        Table.NestedJoin(
            #"Renamed business columns",
            {"STU_EMAIL"},
            #"src_VCOM-OAT-DATA-LPROFILE-v1",
            {"student_email_sso"},
            "StudentProfile",
            JoinKind.LeftOuter
        ),

    #"Expanded student_profile" =
        Table.ExpandTableColumn(
            #"Join student_profile",
            "StudentProfile",
            {"student_id", "programs", "student_email_sso"},     // Added programs + email
            {"MDCO_USR_UID", "PROGRAMS", "STUDENT_EMAIL_SSO"}    // Consistent naming
        ),

    // Filter out AIM students from main enrollment matching process
    #"Filtered non-AIM students" =
        Table.SelectRows(#"Expanded student_profile", 
            each [MDCO_USR_UID] <> null and ([PROGRAMS] <> "AIM" or [PROGRAMS] = null)),

    // 9) Map ELENTRA_MDCODE -> MDCO_COURSE_UID using Elentra course UID map
    #"Join course map" =
        Table.NestedJoin(
            #"Filtered non-AIM students",
            {"ELENTRA_MDCODE"},
            #"src_VCOM-OAT-DATA-ELENTRA-CRSUID_map",
            {"ELENTRA-MDCODE"},
            "CourseMap",
            JoinKind.LeftOuter
        ),

    #"Expanded course map" =
        Table.ExpandTableColumn(
            #"Join course map",
            "CourseMap",
            {"MDCO-COURSE-UID"},
            {"MDCO_COURSE_UID"}
        ),

    // 10) Map SITE_CODE -> ELE_MDCO_CAMPUS_UID using Elentra campus catalog
    #"Join campus map" =
        Table.NestedJoin(
            #"Expanded course map",
            {"SITE_CODE"},
            #"src_VSITE-VDATA-ElentraCampusCatalog",
            {"elentra-campus-uid"},
            "CampusMap",
            JoinKind.LeftOuter
        ),

    #"Expanded campus map" =
        Table.ExpandTableColumn(
            #"Join campus map",
            "CampusMap",
            {"mdco-campus-uid"},
            {"ELE_MDCO_CAMPUS_UID"}
        ),

    // 11) Resolve final MDCO_CAMPUS_UID using fnResolveMdcoCampus
    #"Resolved MDCO_CAMPUS_UID" =
        Table.AddColumn(
            #"Expanded campus map",
            "MDCO_CAMPUS_UID",
            each fnResolveMdcoCampus([ELE_MDCO_CAMPUS_UID], null),
            type text
        ),

    // 12) Build MDCO_ENROLL_COURSE_UID (course enrollment)
    #"Added MDCO_ENROLL_COURSE_UID" =
        Table.AddColumn(
            #"Resolved MDCO_CAMPUS_UID",
            "MDCO_ENROLL_COURSE_UID",
            each fnBuildCRSRosterUID_v1([MDCO_USR_UID], [MDCO_COURSE_UID]),
            type text
        ),

   // 13) Build extended learner rotation UID for Elentra
#"Added MDCO_ENROLL_LRN_ROTATION_UID" =
    Table.AddColumn(
        #"Added MDCO_ENROLL_COURSE_UID",   // <-- fixed
        "MDCO_ENROLL_LRN_ROTATION_UID",
        each fnBuildRotationUID_v1(
                [MDCO_USR_UID],
                [MDCO_COURSE_UID],
                [ELE_STARTDATE],
                [ELE_ENDDATE],
                [MDCO_CAMPUS_UID]
             ),
        type text
    ),

    // 14) Final utility-level selection (using actual available columns)
    #"Selected columns" =
        Table.SelectColumns(
            #"Added MDCO_ENROLL_LRN_ROTATION_UID",
            {
                "MDCO_ENROLL_LRN_ROTATION_UID",
                "MDCO_ENROLL_COURSE_UID",
                "MDCO_USR_UID",
                "MDCO_COURSE_UID",
                "MDCO_CAMPUS_UID",
                "ELENTRA_MDCODE",
                "ELE_STARTDATE",
                "ELE_ENDDATE",
                "ELE_ENROLL_STATUS",
                "DATE_OF_RECORD",
                "RECORD_ACTIVE",
                "SYS",
                "STU_EMAIL",
                "FIRST_NAME",
                "LAST_NAME",
                "ROTATION_CODE",
                "SCHEDULE_BLOCK",
                "BLOCK_LENGTH_WEEKS",
                "SITE_CODE",
                "HAS_CUSTOM_DATE"
            }
        ),
  #"Marked key columns" = Table.AddKey(#"Selected columns", {"MDCO_ENROLL_LRN_ROTATION_UID"}, false)
in
    #"Marked key columns"