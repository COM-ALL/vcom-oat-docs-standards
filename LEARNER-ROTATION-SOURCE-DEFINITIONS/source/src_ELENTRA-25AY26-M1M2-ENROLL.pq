let
  Source = SharePoint.Files("https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/")),
  Navigation = #"Filtered rows"{[Name = "ELENTRA-25AY26-M1M2-ENROLL.csv", #"Folder Path" = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/"]}[Content],
  #"Imported CSV" = Csv.Document(Navigation, [Delimiter = ",", Columns = 9, QuoteStyle = QuoteStyle.None]),
  #"Removed top rows" = Table.Skip(#"Imported CSV", 2),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed top rows", [PromoteAllScalars = true]),
  #"Sorted rows" = Table.Sort(#"Promoted headers", {{"Curriculum Period", Order.Ascending}}),
  #"Filtered rows 1" = Table.SelectRows(#"Sorted rows", each ([Curriculum Period] = "202615"))
in
  #"Filtered rows 1"