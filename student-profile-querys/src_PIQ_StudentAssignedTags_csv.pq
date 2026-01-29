// src_PIQ-StudentTemplate_csv

let
  Source = SharePoint.Files("https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev", [ApiVersion = 15]),
  Navigation = Source{[Name = "PIQ_StudentAssignedTagsTemplate.csv", #"Folder Path" = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/"]}[Content],
  #"Imported CSV" = Csv.Document(Navigation, [Delimiter = ",", Columns = 25, Encoding = 65001, QuoteStyle = QuoteStyle.None]),
  #"Promoted headers" = Table.PromoteHeaders(#"Imported CSV", [PromoteAllScalars = true]),
  #"Removed other columns" = Table.SelectColumns(#"Promoted headers", {"Action (Delete)", "Notes", "EndDate", "StartDate", "*Tag(path example: campus||southern or status||academic||active)", "AdmittedClass", "Class", "FirstName", "LastName", "*StudentID"})
in
  #"Removed other columns"