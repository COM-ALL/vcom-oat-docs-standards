// src_banner_users

let
  Source = SharePoint.Files("https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev", [ApiVersion = 15]),
  #"Filtered rows" = Table.SelectRows(Source, each [Date modified] < #datetime(2026, 1, 26, 11, 59, 59)),
  Navigation = #"Filtered rows"{[Name = "users.csv", #"Folder Path" = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/"]}[Content],
  #"Imported CSV" = Csv.Document(Navigation, [Delimiter = ",", Columns = 12, Encoding = 65001, QuoteStyle = QuoteStyle.None]),
  #"Removed columns" = Table.RemoveColumns(#"Imported CSV", {"Column2", "Column3", "Column4", "Column5", "Column6", "Column7", "Column8", "Column9", "Column10"}),
  #"Promoted headers" = Table.PromoteHeaders(#"Removed columns", [PromoteAllScalars = true]),
  #"Inserted conditional column" = Table.AddColumn(#"Promoted headers", "banner_accnt_active", each if [status] = "active" then true else false),
  #"Changed column type" = Table.TransformColumnTypes(#"Inserted conditional column", {{"banner_accnt_active", type logical}}),
  #"Removed columns 1" = Table.RemoveColumns(#"Changed column type", {"status"}),
  #"Reordered columns" = Table.ReorderColumns(#"Removed columns 1", {"user_id", "banner_accnt_active", "email"})
in
  #"Reordered columns"