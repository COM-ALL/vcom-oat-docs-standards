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
  #"Merged queries" = Table.NestedJoin(#"Changed type dates", {"Site(s)"}, #"src_VSITE-VDATA-ElentraCampusCatalog", {"elentra-campus-uid"}, "src_VSITE-VDATA-ElentraCampusCatalog", JoinKind.LeftOuter),
  #"Expanded src_VSITE-VDATA-ElentraCampusCatalog" = Table.ExpandTableColumn(#"Merged queries", "src_VSITE-VDATA-ElentraCampusCatalog", {"mdco-campus-uid"}, {"mdco-campus-uid"}),

    // 4) Tag academic year and system
    #"Added AYEAR" =
        Table.AddColumn(
            #"Expanded src_VSITE-VDATA-ElentraCampusCatalog",
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

    // 5) Rename business columns to MDCO-friendly names using actual column names
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

    // 6) Retrieve MDCO_USR_UID for AIM students ONLY
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

    // Filter to AIM students ONLY
    #"AIM students only" =
        Table.SelectRows(#"Expanded student_profile", each [MDCO_USR_UID] <> null and [PROGRAMS] = "AIM"),

    // 7) Map ELENTRA_MDCODE -> MDCO_COURSE_UID using Elentra course UID map
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
            {"MDCO-COURSE-UID", "MDCO-CAMPUS"},
            {"MDCO_COURSE_UID", "MDCO_CAMPUS_UID"}
        ),

    #"Filtered mapped courses" =
        Table.SelectRows(#"Expanded course map", each [MDCO_COURSE_UID] <> null),
  #"Invoked custom function" = Table.TransformColumnTypes(Table.AddColumn(#"Filtered mapped courses", "Invoked custom function", each fnResolveMdcoCampus([#"mdco-campus-uid"], [SITE_CODE], "no.campus.assigned")), {{"Invoked custom function", type text}}),
  #"Renamed columns 1" = Table.RenameColumns(#"Invoked custom function", {{"Invoked custom function", "MDCO_CAMPUS_UIDv2"}}),

    // 8) Handle special AIM course patterns (courses ending in 800, exclude NEXT 800 and EMED 800)
    #"Added AIM course flag" =
        Table.AddColumn(
            #"Renamed columns 1",
            "AIM_COURSE_PATTERN",
            each 
                if Text.EndsWith([ELENTRA_MDCODE], "800") and 
                   not Text.Contains([ELENTRA_MDCODE], "NEXT 800") and 
                   not Text.Contains([ELENTRA_MDCODE], "EMED 800")
                then "AIM_800_SERIES"
                else if Text.Contains([ELENTRA_MDCODE], "NEXT 800") then "AIM_EXCLUDED_NEXT"
                else if Text.Contains([ELENTRA_MDCODE], "EMED 800") then "AIM_EXCLUDED_EMED"  
                else "AIM_OTHER",
            type text
        ),
  #"Invoked custom function 2" = Table.TransformColumnTypes(Table.AddColumn(#"Added AIM course flag", "Invoked custom function", each fnBuildRotationUID_v1([MDCO_USR_UID], [MDCO_COURSE_UID], [ELE_STARTDATE], [ELE_ENDDATE], [MDCO_CAMPUS_UIDv2])), {{"Invoked custom function", type text}}),

    // 9) Build MDCO_ENROLL_LRN_ROTATION_UID using normalized data
    #"Built rotation UID" =
        Table.AddColumn(
            #"Invoked custom function 2",
            "MDCO_ENROLL_LRN_ROTATION_UID",
            each fnBuildRotationUID_v1(
                [MDCO_USR_UID],
                [MDCO_COURSE_UID],
                [ELE_STARTDATE],
                [Custom]
            ),
            type text
        ),
  #"Removed columns" = Table.RemoveColumns(#"Built rotation UID", {"MDCO_ENROLL_LRN_ROTATION_UID"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed columns", {{"Invoked custom function", "MDCO_ENROLL_LRN_ROTATION_UID"}}),
  #"Reordered columns" = Table.ReorderColumns(#"Renamed columns", {"MDCO_ENROLL_LRN_ROTATION_UID", "STU_EMAIL", "FIRST_NAME", "LAST_NAME", "ELENTRA_MDCODE", "ROTATION_CODE", "SCHEDULE_BLOCK", "BLOCK_LENGTH_WEEKS", "SITE_CODE", "Preceptor(s)", "ELE_STARTDATE", "ELE_ENDDATE", "HAS_CUSTOM_DATE", "STATUS", "Clinical Tags", "mdco-campus-uid", "AYEAR", "SYS", "MDCO_USR_UID", "PROGRAMS", "MDCO_COURSE_UID", "MDCO_CAMPUS_UID", "AIM_COURSE_PATTERN"})
in
    #"Reordered columns"