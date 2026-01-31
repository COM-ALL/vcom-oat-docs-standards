// MDCO-ENROLL-ELENTRA-ROTATIONS-AIM
let
    // 1) Source Elentra enrollment data (same source as ACTIVE script)
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

    // 4) Map campus early using Elentra campus catalog
    #"Merged campus catalog" = 
        Table.NestedJoin(
            #"Changed type dates", 
            {"Site(s)"}, 
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
            {"ELE_MDCO_CAMPUS_UID"}
        ),

    // 5) Add metadata and rename columns
    #"Added AYEAR" =
        Table.AddColumn(
            #"Expanded campus catalog",
            "AYEAR",
            each "2025-2026",
            type text
        ),

    #"Added SYS" =
        Table.AddColumn(
            #"Added AYEAR",
            "SYS",
            each "ELENTRA",
            type text
        ),

    #"Renamed business columns" =
        Table.RenameColumns(
            #"Added SYS",
            {
                {"(Custom) Start Date",   "ELE_STARTDATE"},
                {"(Custom) End Date",     "ELE_ENDDATE"},
                {"Course Code",           "ELENTRA_MDCODE"},
                {"Number/Email",          "STU_EMAIL"},
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

    // 6) Join student profile and filter AIM students
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
            {"student_id", "programs"},
            {"MDCO_USR_UID", "PROGRAMS"}
        ),

    #"AIM students only" =
        Table.SelectRows(#"Expanded student_profile", each [MDCO_USR_UID] <> null and [PROGRAMS] = "AIM"),

    // 7) Map course UID
    #"Join course map" =
        Table.NestedJoin(
            #"AIM students only",
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

    #"Filtered mapped courses" =
        Table.SelectRows(#"Expanded course map", each [MDCO_COURSE_UID] <> null),

    // 8) Resolve final campus UID using hardened function
    #"Resolved MDCO_CAMPUS_UID" =
        Table.AddColumn(
            #"Filtered mapped courses",
            "MDCO_CAMPUS_UID",
            each fnResolveMdcoCampus([ELE_MDCO_CAMPUS_UID], null, "NO.CAMPUS.ASSIGNED"),
            type text
        ),

    // 9) Build final rotation UID
    #"Built MDCO_ENROLL_LRN_ROTATION_UID" =
        Table.AddColumn(
            #"Resolved MDCO_CAMPUS_UID",
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

    // 10) Final column selection
    #"Selected columns" =
        Table.SelectColumns(
            #"Built MDCO_ENROLL_LRN_ROTATION_UID",
            {
                "MDCO_ENROLL_LRN_ROTATION_UID",
                "STU_EMAIL",
                "FIRST_NAME",
                "LAST_NAME",
                "ELENTRA_MDCODE",
                "ROTATION_CODE",
                "SCHEDULE_BLOCK",
                "BLOCK_LENGTH_WEEKS",
                "SITE_CODE",
                "ELE_STARTDATE",
                "ELE_ENDDATE",
                "HAS_CUSTOM_DATE",
                "STATUS",
                "AYEAR",
                "SYS",
                "MDCO_USR_UID",
                "PROGRAMS",
                "MDCO_COURSE_UID",
                "MDCO_CAMPUS_UID"
            }
        ),
  #"Marked key columns" = Table.AddKey(#"Selected columns", {"MDCO_ENROLL_LRN_ROTATION_UID"}, false)
in
    #"Marked key columns"