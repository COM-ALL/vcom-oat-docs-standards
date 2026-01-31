let
    // 1) Combine M1/M2 and M3/M4 Elentra enrollment extracts
    Source =
        Table.Combine({
            #"src_ELENTRA-25AY26-M3M4-ENROLL",
            #"src_ELENTRA-25AY26-M1M2-ENROLL"
        }),

    // 2) Tag academic year (utility column for downstream reconciliation)
    #"Added AYEAR" =
        Table.AddColumn(
            Source,
            "AYEAR",
            each "2025-2026",
            type text
        ),

    // 3) Normalize learner identity columns (still with hyphens here)
    #"Renamed learner columns" =
        Table.RenameColumns(
            #"Added AYEAR",
            {
                {"Number", "USER-UID"},
                {"Email",  "USER-EMAIL"}
            }
        ),

    // 4) Remove curriculum-period columns (we rely on AYEAR + IDs instead)
    #"Removed CP columns" =
        Table.RemoveColumns(
            #"Renamed learner columns",
            {"Curriculum Period", "CP Start Date", "CP Finish Date"}
        ),

    // 5) Normalize Elentra Course Code for mapping
    #"Split Course Code" =
        Table.SplitColumn(
            #"Removed CP columns",
            "Course Code",
            Splitter.SplitTextByDelimiter(" "),
            {"Course Code.1", "Course Code.2"}
        ),

    #"Rebuilt Course Code" =
        Table.AddColumn(
            #"Split Course Code",
            "Course Code",
            each [#"Course Code.1"] & " " & [#"Course Code.2"],
            type text
        ),

    // 6) Map Elentra Course Code -> MDCO-COURSE-UID
    #"Merged course map" =
        Table.NestedJoin(
            #"Rebuilt Course Code",
            {"Course Code"},
            #"src_VCOM-OAT-DATA-ELENTRA-CRSUID_map",
            {"ELENTRA-MDCODE"},
            "CourseMap",
            JoinKind.LeftOuter
        ),

    #"Expanded course map" =
        Table.ExpandTableColumn(
            #"Merged course map",
            "CourseMap",
            {"MDCO-COURSE-UID"},
            {"MDCO-COURSE-UID"}
        ),

    // 7) Trim identifiers before building the enrollment UID
    #"Trimmed identifiers" =
        Table.TransformColumns(
            #"Expanded course map",
            {
                {"USER-UID",        each Text.Trim(_), type nullable text},
                {"MDCO-COURSE-UID", each Text.Trim(_), type nullable text}
            }
        ),

    // 8) Build the MDCO-ENROLL-COURSE-UID (course enrollment key)
    #"Added ENROLL UID" =
        Table.AddColumn(
            #"Trimmed identifiers",
            "MDCO-ENROLL-COURSE-UID",
            each fnBuildCRSRosterUID_v1([#"USER-UID"], [#"MDCO-COURSE-UID"]),
            type text
        ),

    // 9) Reduce to utility-level columns:
    //    - MDCO-ENROLL-COURSE-UID (key)
    //    - AYEAR (context)
    #"Selected enrollment columns" =
        Table.SelectColumns(
            #"Added ENROLL UID",
            {"MDCO-ENROLL-COURSE-UID", "AYEAR"}
        ),

    // 10) Add system-agnostic snapshot metadata
    #"Added DateOfRecord" =
        Table.AddColumn(
            #"Selected enrollment columns",
            "DateOfRecord",
            each fnDATE_ActiveAsOf(),
            type date
        ),

    #"Added RecordActive" =
        Table.AddColumn(
            #"Added DateOfRecord",
            "RecordActive",
            each true,
            type logical
        ),

    #"Added SYS" =
        Table.AddColumn(
            #"Added RecordActive",
            "SYS",
            each "ELENTRA",
            type text
        ),

    // 11) Final normalization of MDCO columns to underscore style
    #"Renamed MDCO columns" =
        Table.RenameColumns(
            #"Added SYS",
            {
                {"MDCO-ENROLL-COURSE-UID", "MDCO_ENROLL_COURSE_UID"},
                {"AYEAR",                  "AYEAR"},
                {"DateOfRecord",           "DATE_OF_RECORD"},
                {"RecordActive",           "RECORD_ACTIVE"},
                {"SYS",                    "SYS"}
            }
        ),
  #"Marked key columns" = Table.AddKey(#"Renamed MDCO columns", {"MDCO_ENROLL_COURSE_UID"}, false)

in
    #"Marked key columns"