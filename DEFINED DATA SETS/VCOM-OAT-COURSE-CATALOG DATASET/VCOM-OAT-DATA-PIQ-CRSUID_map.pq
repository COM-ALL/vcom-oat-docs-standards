// VCOM-OAT-DATA-PIQ-CRSUID_map

let
  Source = CommonDataService.Database("org4c96263d.crm.dynamics.com", [CreateNavigationProperties = null]),
  #"Navigation 1" = Source{[Schema = "dbo", Item = "cr026_vcomoatdatapiqcrsuid_map"]}[Data],
  #"Reordered columns" = Table.ReorderColumns(#"Navigation 1", {"cr026_piq_courseid", "cr026_mdco_catuid", "cr026_mdco_piqxele_catuidsiteuid", "cr026_mdco_campusuid"}),
  #"Removed columns" = Table.RemoveColumns(#"Reordered columns", {"createdon", "createdby", "modifiedon", "modifiedby", "createdonbehalfby", "modifiedonbehalfby", "createdbyname", "createdbyyominame", "createdonbehalfbyname", "createdonbehalfbyyominame", "modifiedbyname", "modifiedbyyominame", "modifiedonbehalfbyname", "modifiedonbehalfbyyominame", "ownerid", "owneridname", "owneridyominame", "owningbusinessunit", "owninguser", "owningteam", "owningbusinessunitname", "statecode", "statecodename", "statuscode", "statuscodename", "importsequencenumber", "overriddencreatedon", "timezoneruleversionnumber", "utcconversiontimezonecode", "cr026_name", "asyncoperation", "businessunit", "processsession", "systemuser(createdby)", "systemuser(createdonbehalfby)", "systemuser(modifiedby)", "systemuser(modifiedonbehalfby)", "systemuser(owninguser)", "team"}),
  #"Renamed columns" = Table.RenameColumns(#"Removed columns", {{"cr026_piq_courseid", "PIQ-CATUID"}, {"cr026_mdco_catuid", "MDCO-COURSE-UID"}, {"cr026_mdco_piqxele_catuidsiteuid", "mdco_PIQxELE-CATUIDSITEUID"}, {"cr026_mdco_campusuid", "MDCO_CAMPUSUID"}}),
  #"Marked key columns" = Table.AddKey(#"Renamed columns", {"PIQ-CATUID"}, false),
  #"Marked key columns 1" = Table.AddKey(#"Marked key columns", {"PIQ-CATUID"}, false)
in
  #"Marked key columns 1"