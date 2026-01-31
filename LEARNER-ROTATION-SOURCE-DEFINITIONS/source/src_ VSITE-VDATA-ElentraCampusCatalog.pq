let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "VSITE-VDATA-ElentraCampusCatalog", ItemKind = "Table"]}[Data],
  #"Reordered columns" = Table.ReorderColumns(#"Navigation 2", {"elentra-campus-uid", "mdco-campus-uid", "elentra-campus-identifier", "elentra-building-identifier", "vsitevelentracampuscatalogid"})
in
  #"Reordered columns"