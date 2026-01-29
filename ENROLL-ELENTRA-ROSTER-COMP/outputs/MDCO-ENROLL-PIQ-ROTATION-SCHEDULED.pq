let
    // 0) Source from SharePoint folder
    Source =
        SharePoint.Files(
            "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev",
            [ApiVersion = 15]
        ),

    // 1) Keep only the PIQ learners CSV
    #"Filtered rows" =
        Table.SelectRows(
            Source,
            each not Text.StartsWith([Name], "Roster_")
              and not Text.StartsWith([Name], "global")
              and not Text.StartsWith([Name], "Roster-")
        ),

    // 2) Navigate to the specific file (binary content)
    Navigation =
        #"Filtered rows"{
            [ Name = "PIQ-25AY27-ROTATION-LEARNERS.csv",
              #"Folder Path"
                = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/" ]
        }[Content],

    // 3) Read CSV
    #"Imported CSV" =
        Csv.Document(
            Navigation,
            [Delimiter = ",", Columns = 14, Encoding = 65001, QuoteStyle = QuoteStyle.None]
        ),

    // 4) Promote headers
    #"Promoted headers" =
        Table.PromoteHeaders(#"Imported CSV", [PromoteAllScalars = true]),

    // 5) Trim *CourseID
    #"Trimmed *CourseID" =
        Table.TransformColumns(
            #"Promoted headers",
            {{"*CourseID", each Text.Trim(_), type nullable text}}
        ),

    // 6) Merge to course UID map (PIQ course -> MDCO-COURSE-UID, MDCO_CAMPUSUID)
    #"Merged course map" =
        Table.NestedJoin(
            #"Trimmed *CourseID",
            {"*CourseID"},
            #"src_VCOM-MDCO-DATA-PIQ-CRSUID_map",
            {"PIQ-CATUID"},
            "VCOM-MDCO-DATA-PIQ-CRSUID_map",
            JoinKind.LeftOuter
        ),

    #"Expanded course map" =
        Table.ExpandTableColumn(
            #"Merged course map",
            "VCOM-MDCO-DATA-PIQ-CRSUID_map",
            {"MDCO-COURSE-UID", "MDCO_CAMPUSUID"},
            {"MDCO-COURSE-UID", "MDCO_CAMPUSUID"}
        ),

    // 7) Build MDCO_ENROLL_COURSE_UID (course-level enrollment)
    #"Added MDCO_ENROLL_COURSE_UID" =
        Table.TransformColumnTypes(
            Table.AddColumn(
                #"Expanded course map",
                "MDCO_ENROLL_COURSE_UID",
                each fnBuildCRSRosterUID_v1([#"*StudentID"], [#"MDCO-COURSE-UID"])
            ),
            {{"MDCO_ENROLL_COURSE_UID", type text}}
        ),

    // 8) Reorder to get date columns in view (still original names for now)
    #"Reordered columns" =
        Table.ReorderColumns(
            #"Added MDCO_ENROLL_COURSE_UID",
            {
                "MDCO_ENROLL_COURSE_UID",
                "*StudentID",
                "Preceptor(s)",
                "*CourseID",
                "CourseSection",
                "CourseDescription",
                "*AcademicYear",
                "AcademicTerm",
                "*Activity(CourseDisplayName)",
                "Location(Site)",
                "*BeginDate",
                "*EndDate",
                "CourseCredits(Weeks)",
                "Block",
                "Collection",
                "MDCO-COURSE-UID",
                "MDCO_CAMPUSUID"
            }
        ),

    // -----------------------------------------------------------------------
    // 9) ROBUST DATE RENAME / ENSURE startdate/enddate - PIQ DATES ONLY
    // -----------------------------------------------------------------------
    #"Trim header names" =
        Table.TransformColumnNames(#"Reordered columns", Text.Trim),

    #"Renamed date columns (best effort)" =
        Table.RenameColumns(
            #"Trim header names",
            {
                {"*BeginDate", "startdate"},
                {"*EndDate",   "enddate"}
            },
            MissingField.Ignore
        ),

    cols     = Table.ColumnNames(#"Renamed date columns (best effort)"),
    HasStart = List.Contains(cols, "startdate"),
    HasEnd   = List.Contains(cols, "enddate"),

    // Safely pull a field if present
    fnGet = (r as record, name as text) as any =>
        Record.FieldOrDefault(r, name, null),

    // If startdate not present yet, create it from likely header variants
    #"Ensure startdate" =
        if HasStart then
            #"Renamed date columns (best effort)"
        else
            Table.AddColumn(
                #"Renamed date columns (best effort)",
                "startdate",
                each
                    let
                        c1 = fnGet(_, "*BeginDate"),
                        c2 = if c1 <> null then c1 else fnGet(_, "*Begin Date"),
                        c3 = if c2 <> null then c2 else fnGet(_, "BeginDate"),
                        c4 = if c3 <> null then c3 else fnGet(_, "Begin Date"),
                        raw = c4
                    in
                        try Date.From(raw) otherwise (try Date.FromText(Text.From(raw)) otherwise null),
                type date
            ),

    // If enddate not present yet, create it similarly
    #"Ensure enddate" =
        if HasEnd then
            #"Ensure startdate"
        else
            Table.AddColumn(
                #"Ensure startdate",
                "enddate",
                each
                    let
                        c1 = fnGet(_, "*EndDate"),
                        c2 = if c1 <> null then c1 else fnGet(_, "*End Date"),
                        c3 = if c2 <> null then c2 else fnGet(_, "EndDate"),
                        c4 = if c3 <> null then c3 else fnGet(_, "End Date"),
                        raw = c4
                    in
                        try Date.From(raw) otherwise (try Date.FromText(Text.From(raw)) otherwise null),
                type date
            ),

    // Convert to date types explicitly (no-op if already date)
    #"PIQ date types fixed" =
        Table.TransformColumnTypes(
            #"Ensure enddate",
            {{"startdate", type date}, {"enddate", type date}}
        ),

    // 10) Rename PIQ campus column for clarity
    #"Renamed PIQ campus column" =
        Table.RenameColumns(
            #"PIQ date types fixed",
            {{"MDCO_CAMPUSUID", "piq_CAMPUSUID"}},
            MissingField.Ignore
        ),

    // 11) Merge with Elentra rotations to pull Elentra campus, but do NOT change dates
    #"Merged with Elentra rotations" =
        Table.NestedJoin(
            #"Renamed PIQ campus column",
            {"MDCO_ENROLL_COURSE_UID", "startdate"},
            #"MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE",
            {"MDCO_ENROLL_COURSE_UID", "ELE_STARTDATE"},
            "ElentraRot",
            JoinKind.LeftOuter
        ),

    #"Expanded Elentra rotations" =
        Table.ExpandTableColumn(
            #"Merged with Elentra rotations",
            "ElentraRot",
            {"MDCO_CAMPUS_UID"},
            {"ele_CAMPUS_UID"}
        ),

    // 12) Merge Elentra campus catalog to ensure consistent MDCO campus IDs
    #"Merged campus catalog" =
        Table.NestedJoin(
            #"Expanded Elentra rotations",
            {"Location(Site)"},
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

    // 13) Resolve final MDCO_CAMPUS using fnResolveMdcoCampus (Elentra first, then PIQ)
    #"Resolved MDCO_CAMPUS" =
        Table.TransformColumnTypes(
            Table.AddColumn(
                #"Expanded campus catalog",
                "MDCO_CAMPUS",
                each fnResolveMdcoCampus([elentra_mdco_campus], [piq_CAMPUSUID])
            ),
            {{"MDCO_CAMPUS", type text}}
        ),

    // 14) Build learner rotation UID from PIQ dates + resolved campus
    #"Added MDCO_ENROLL_LRN_ROTATION_UID" =
        Table.TransformColumnTypes(
            Table.AddColumn(
                #"Resolved MDCO_CAMPUS",
                "MDCO_ENROLL_LRN_ROTATION_UID",
                each fnBuildRotationUID_v1(
                        [#"*StudentID"],     // PIQ student ID
                        [#"MDCO-COURSE-UID"], // MDCO course code
                        [startdate],          // PIQ startdate (never overwritten)
                        [enddate],            // PIQ enddate (never overwritten)
                        [#"MDCO_CAMPUS"]      // resolved campus
                     )
            ),
            {{"MDCO_ENROLL_LRN_ROTATION_UID", type text}}
        ),
  #"Invoked custom function" = Table.TransformColumnTypes(Table.AddColumn(#"Added MDCO_ENROLL_LRN_ROTATION_UID", "Invoked custom function", each fnDATE_ActiveAsOf()), {{"Invoked custom function", type date}}),
  #"Renamed columns" = Table.RenameColumns(#"Invoked custom function", {{"Invoked custom function", "DATE-OF-RECORD"}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Renamed columns", "RECORD_ACTIVE", each true), {{"RECORD_ACTIVE", type logical}}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Added custom", "SYS", each "PIQ"), {{"SYS", type text}}),

    // 15) Final selection
    #"Selected columns" =
        Table.SelectColumns(
            #"Added custom 1",
            {
                "MDCO_ENROLL_LRN_ROTATION_UID",
                "MDCO_ENROLL_COURSE_UID",
                "MDCO-COURSE-UID",
                "MDCO_CAMPUS",
                "*StudentID",
                "startdate",
                "enddate",
                "*CourseID",
                "Location(Site)",
                "DATE-OF-RECORD",
                "RECORD_ACTIVE",
                "SYS"
            }
        )
in
    #"Selected columns"