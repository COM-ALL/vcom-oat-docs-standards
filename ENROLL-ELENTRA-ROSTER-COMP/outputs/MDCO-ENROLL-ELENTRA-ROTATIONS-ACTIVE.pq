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

    // 3) Ensure date types for custom start/end
    #"Changed type dates" =
        Table.TransformColumnTypes(
            #"Filtered course code",
            {
                {"(Custom) Start Date", type date},
                {"(Custom) End Date",   type date}
            }
        ),

    // 4) Drop unused descriptive columns
    #"Removed extra columns" =
        Table.RemoveColumns(
            #"Changed type dates",
            {
                "First Name",
                "Last Name",
                "Block Length (Weeks)",
                "Preceptor(s)",
                "Clinical Tags"
            }
        ),

    // 5) Normalize and classify enrollment Status -> ELE_ENROLL_STATUS
    #"Trimmed Status" =
        Table.TransformColumns(
            #"Removed extra columns",
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

    // 7) Rename business columns to MDCO-friendly names
    #"Renamed business columns" =
        Table.RenameColumns(
            #"Added SYS",
            {
                {"(Custom) Start Date",   "ELE_STARTDATE"},
                {"(Custom) End Date",     "ELE_ENDDATE"},
                {"Has Custom Date",       "HAS_CUSTOM_DATES"},
                {"STATUS_2",              "ELE_ENROLL_STATUS"},   // already set above, harmless rename if present
                {"Site(s)",               "SITE_CODE"},
                {"Schedule Blocks (No.)", "SCHEDULE_BLOCK"},
                {"Course Code",           "ELENTRA_MDCODE"},
                {"Number/Email",          "STU_EMAIL"}
            },
            MissingField.Ignore
        ),

    // 8) Retrieve MDCO_USR_UID from mdmaster_sturoster
    #"Join mdmaster_sturoster" =
        Table.NestedJoin(
            #"Renamed business columns",
            {"STU_EMAIL"},
            src_mdmaster_sturoster,
            {"new_elentra_email"},
            "Sturoster",
            JoinKind.LeftOuter
        ),

    #"Expanded mdmaster" =
        Table.ExpandTableColumn(
            #"Join mdmaster_sturoster",
            "Sturoster",
            {"new_student_uid"},
            {"MDCO_USR_UID"}
        ),

    #"Filtered non-null student" =
        Table.SelectRows(#"Expanded mdmaster", each [MDCO_USR_UID] <> null),

    // 9) Map ELENTRA_MDCODE -> MDCO_COURSE_UID using Elentra course UID map
    #"Join course map" =
        Table.NestedJoin(
            #"Filtered non-null student",
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

    // 12) Build MDCO_ENROLL_COURSE_UID (course enrollment key)
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

    // 14) Final utility-level selection
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
                "SITE_CODE",
                "SCHEDULE_BLOCK",
                "ELE_STARTDATE",
                "ELE_ENDDATE",
                "ELE_ENROLL_STATUS",
                "DATE_OF_RECORD",
                "RECORD_ACTIVE",
                "SYS"
            }
        )
in
    #"Selected columns"