let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "VCOM-OAT-DATA-ELENTRA-CRSUID_map", ItemKind = "Table"]}[Data],
  #"Reordered columns" = Table.ReorderColumns(#"Navigation 2", {"MDCO-COURSE-UID", "ELENTRA-CATUID", "vcomoatdataelentracrsuid_mapid"}),
  #"Duplicated column" = Table.DuplicateColumn(#"Reordered columns", "ELENTRA-CATUID", "ELENTRA-CATUID - Copy"),
  #"Split column by delimiter" = Table.SplitColumn(#"Duplicated column", "ELENTRA-CATUID - Copy", Splitter.SplitTextByEachDelimiter({":"}, QuoteStyle.Csv), {"ELENTRA-CATUID - Copy.1", "ELENTRA-CATUID - Copy.2"}),
  #"Renamed columns" = Table.RenameColumns(#"Split column by delimiter", {{"ELENTRA-CATUID - Copy.1", "ELENTRA-MDCODE"}, {"ELENTRA-CATUID - Copy.2", "ELENTRA-COURSE-NAME"}})
in
  #"Renamed columns"