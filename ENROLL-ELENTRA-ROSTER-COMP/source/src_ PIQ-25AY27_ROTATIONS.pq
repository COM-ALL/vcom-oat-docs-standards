let
  Source = SharePoint.Files("https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each not Text.StartsWith([Name], "Roster_") and not Text.StartsWith([Name], "global") and not Text.StartsWith([Name], "Roster-")),
  Navigation = #"Filtered rows"{[Name = "PIQ-25AY27-ROTATION-LEARNERS.csv", #"Folder Path" = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/"]}[Content],
  #"Imported CSV" = Csv.Document(Navigation, [Delimiter = ",", Columns = 14, Encoding = 65001, QuoteStyle = QuoteStyle.None]),
  #"Promoted headers" = Table.PromoteHeaders(#"Imported CSV", [PromoteAllScalars = true]),
  #"Trimmed text" = Table.TransformColumns(#"Promoted headers", {{"*CourseID", each Text.Trim(_), type nullable text}}),
  #"Merged queries" = Table.NestedJoin(#"Trimmed text", {"*CourseID"}, #"VCOM-OAT-DATA-PIQ-CRSUID_map", {"PIQ-CATUID"}, "VCOM-OAT-DATA-PIQ-CRSUID_map", JoinKind.LeftOuter),
  #"Expanded VCOM-OAT-DATA-PIQ-CRSUID_map" = Table.ExpandTableColumn(#"Merged queries", "VCOM-OAT-DATA-PIQ-CRSUID_map", {"MDCO-COURSE-UID", "MDCO_CAMPUSUID"}, {"MDCO-COURSE-UID", "MDCO_CAMPUSUID"}),
  #"Invoked custom function" = Table.TransformColumnTypes(Table.AddColumn(#"Expanded VCOM-OAT-DATA-PIQ-CRSUID_map", "Invoked custom function", each fnBuildCRSRosterUID_v1([#"*StudentID"], [#"MDCO-COURSE-UID"])), {{"Invoked custom function", type text}}),
  #"Renamed columns" = Table.RenameColumns(#"Invoked custom function", {{"Invoked custom function", "MDCO-ENROLL-COURSE-UID"}}),
  #"Reordered columns" = Table.ReorderColumns(#"Renamed columns", {"MDCO-ENROLL-COURSE-UID", "*StudentID", "Preceptor(s)", "*CourseID", "CourseSection", "CourseDescription", "*AcademicYear", "AcademicTerm", "*Activity(CourseDisplayName)", "Location(Site)", "*BeginDate", "*EndDate", "CourseCredits(Weeks)", "Block", "Collection", "MDCO-COURSE-UID", "MDCO_CAMPUSUID"}),
  #"Renamed columns 1" = Table.RenameColumns(#"Reordered columns", {{"*BeginDate", "startdate"}, {"*EndDate", "enddate"}}),
  #"Reordered columns 1" = Table.ReorderColumns(#"Renamed columns 1", {"MDCO-ENROLL-COURSE-UID", "startdate", "MDCO_CAMPUSUID", "*StudentID", "Preceptor(s)", "*CourseID", "CourseSection", "CourseDescription", "*AcademicYear", "AcademicTerm", "*Activity(CourseDisplayName)", "enddate", "CourseCredits(Weeks)", "Block", "Collection", "MDCO-COURSE-UID", "Location(Site)"}),
  #"Changed column type" = Table.TransformColumnTypes(#"Reordered columns 1", {{"startdate", type date}, {"enddate", type date}})
in
  #"Changed column type"