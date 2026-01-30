// VCOM-OAT-DATA-MDCO-CRSUID_mapkey

let
  Source = CommonDataService.Database("org4c96263d.crm.dynamics.com", [CreateNavigationProperties = null]),
  #"Navigation 1" = Source{[Schema = "dbo", Item = "cr026_vcomoatdatamdcocrsuid_mapkey"]}[Data],
  #"Reordered columns" = Table.ReorderColumns(#"Navigation 1", {"cr026_mdco_course_uid", "cr026_mdco_coursecat_uid", "cr026_mdco_mdcode", "cr026_mdco_coursename", "cr026_mdco_coursecategory"}),
  #"Removed other columns" = Table.SelectColumns(#"Reordered columns", {"cr026_mdco_course_uid", "cr026_mdco_coursecat_uid", "cr026_mdco_mdcode", "cr026_mdco_coursename", "cr026_mdco_coursecategory"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed other columns", {{"cr026_mdco_course_uid", "MDCO_COURSE_UID"}}),
  #"Reordered columns 1" = Table.ReorderColumns(#"Renamed columns", {"MDCO_COURSE_UID", "cr026_mdco_mdcode", "cr026_mdco_coursecat_uid", "cr026_mdco_coursename", "cr026_mdco_coursecategory"}),
  #"Renamed columns 1" = Table.RenameColumns(#"Reordered columns 1", {{"cr026_mdco_mdcode", "MDCO_MDCODE"}, {"cr026_mdco_coursecat_uid", "MDCO_COURSECAT_UID"}, {"cr026_mdco_coursename", "MDCO_COURSENAME"}, {"cr026_mdco_coursecategory", "MDCO_COURSE-CATEGORY"}}),
  #"Marked key columns" = Table.AddKey(#"Renamed columns 1", {"MDCO_COURSE_UID"}, false)
in
  #"Marked key columns"