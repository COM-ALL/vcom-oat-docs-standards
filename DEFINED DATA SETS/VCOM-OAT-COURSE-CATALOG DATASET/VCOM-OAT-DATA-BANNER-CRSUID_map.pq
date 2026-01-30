//VCOM-OAT-DATA-BANNER-CRSUID_map

let
  Source = CommonDataService.Database("org4c96263d.crm.dynamics.com", [CreateNavigationProperties = null]),
  #"Navigation 1" = Source{[Schema = "dbo", Item = "cr026_vcomoatdatabannercrsuid_map"]}[Data],
  #"Removed other columns" = Table.SelectColumns(#"Navigation 1", {"cr026_bancrscatkey", "cr026_mdco_course_uid"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed other columns", {{"cr026_bancrscatkey", "BANNER_CATUID"}, {"cr026_mdco_course_uid", "MDCO_COURSE_UID"}}),
  #"Marked key columns" = Table.AddKey(#"Renamed columns", {"BANNER_CATUID"}, false)
in
  #"Marked key columns"