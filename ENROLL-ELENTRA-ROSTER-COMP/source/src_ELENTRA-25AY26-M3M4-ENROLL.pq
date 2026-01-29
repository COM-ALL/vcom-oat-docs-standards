let
  Source = SharePoint.Files("https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each ([Folder Path] = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/")),
  Navigation = #"Filtered rows"{[Name = "ELENTRA-25AY26-M3M4-ENROLL.csv", #"Folder Path" = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/"]}[Content],
  #"Imported CSV" = Csv.Document(Navigation, [Delimiter = ",", Columns = 9, QuoteStyle = QuoteStyle.None]),
  #"Removed top rows" = Table.Skip(#"Imported CSV", 2),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed top rows", [PromoteAllScalars = true]),
  #"Filtered rows 1" = Table.SelectRows(#"Promoted headers", each ([Curriculum Period] = "Curriculum Period" or [Curriculum Period] = "MED-CLERKSHIP AY 2025/2026")),
  #"Sorted rows" = Table.Sort(#"Filtered rows 1", {{"Curriculum Period", Order.Ascending}}),
  #"Removed top rows 1" = Table.Skip(#"Sorted rows", 141)
in
  #"Removed top rows 1"