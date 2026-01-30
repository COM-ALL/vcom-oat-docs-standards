let
  Source = CommonDataService.Database("org4c96263d.crm.dynamics.com", [CreateNavigationProperties = null]),
  #"Navigation 1" = Source{[Schema = "dbo", Item = "cr026_vcomoatdataelentracrsuid_map"]}[Data],
  #"Removed other columns" = Table.SelectColumns(#"Navigation 1", {"cr026_elecrscatkey", "cr026_mdco_course_uid"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed other columns", {{"cr026_elecrscatkey", "ELENTRA-CATUID"}, {"cr026_mdco_course_uid", "MDCO-COURSE-UID"}}),
  #"Marked key columns" = Table.AddKey(#"Renamed columns", {"ELENTRA-CATUID"}, false)
in
  #"Marked key columns"