let
  Source = SharePoint.Files("https://tamucs.sharepoint.com/sites/MED-ESTUDENTMANAGER", [ApiVersion = 15]),
  Navigation = Source{[Name = "enrollments.csv", #"Folder Path" = "https://tamucs.sharepoint.com/sites/MED-ESTUDENTMANAGER/Processing Documents/banner_canvas/"]}[Content],
  #"Imported CSV" = Csv.Document(Navigation, [Delimiter = ",", Columns = 8, QuoteStyle = QuoteStyle.None]),
  #"Promoted headers" = Table.PromoteHeaders(#"Imported CSV", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"course_id", type text}, {"user_id", type text}, {"role", type text}, {"role_id", type text}, {"section_id", type text}, {"status", type text}, {"associated_user_id", type text}, {"limit_section_privileges", type logical}}),
  #"Filtered rows" = Table.SelectRows(#"Changed column type", each ([role] = "student")),
  #"Removed columns" = Table.RemoveColumns(#"Filtered rows", {"role_id", "associated_user_id", "limit_section_privileges"}),
  #"Merged queries" = Table.NestedJoin(#"Removed columns", {"section_id"}, Sections, {"section_id"}, "Sections", JoinKind.LeftOuter),
  #"Expanded Sections" = Table.ExpandTableColumn(#"Merged queries", "Sections", {"name", "DEPT", "CRSNUM", "SECTNUM", "CRN", "TERM", "course_code", "MDCO_CATUID","MDCO_COURSECODE", "MDCO_COURSENAME"}, {"name", "DEPT", "CRSNUM", "SECTNUM", "CRN", "TERM", "course_code", "mdcourse_catid", "new_course_code", "new_course_name"}),
  #"Renamed columns" = Table.RenameColumns(#"Expanded Sections", {{"name", "short_name"}, {"new_course_code", "MDCO_CRSCODE"}, {"new_course_name", "MDCO_CRSNAME"}}),
  #"Merged queries 1" = Table.NestedJoin(#"Renamed columns", {"course_id"}, Courses, {"course_id"}, "Courses", JoinKind.LeftOuter),
  #"Expanded Courses" = Table.ExpandTableColumn(#"Merged queries 1", "Courses", {"long_name", "startdate", "BANNER_MATCH"}, {"long_name", "startdate", "BANNER_MATCH"}),
  #"Merged queries 2" = Table.NestedJoin(#"Expanded Courses", {"user_id"}, new_stumaster_roster, {"new_stu_uid"}, "new_stumaster_roster", JoinKind.LeftOuter),
  #"Expanded new_stumaster_roster" = Table.ExpandTableColumn(#"Merged queries 2", "new_stumaster_roster", {"stu_classof", "home_campus", "lname", "fname", "email", "fullname_lf"}, {"stu_classof", "home_campus", "lname", "fname", "email", "fullname_lf"}),
  #"Renamed columns 1" = Table.RenameColumns(#"Expanded new_stumaster_roster", {{"status", "banner_enrollment_status"}}),
  #"Inserted conditional column" = Table.AddColumn(#"Renamed columns 1", "banner_enroll_active", each if [banner_enrollment_status] = "active" then true else false),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Inserted conditional column", {{"banner_enroll_active", type logical}}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Changed column type 1", "CRSROSTER_UID", each [user_id] & "-" & [mdcourse_catid]), {{"CRSROSTER_UID", type text}}),
  #"Reordered columns" = Table.ReorderColumns(#"Added custom", {"course_id", "user_id", "role", "section_id", "banner_enrollment_status", "short_name", "DEPT", "CRSNUM", "SECTNUM", "CRN", "TERM", "course_code", "mdcourse_catid", "long_name", "startdate", "BANNER_MATCH", "stu_classof", "home_campus", "lname", "fname", "email", "CRSROSTER_UID", "fullname_lf", "banner_enroll_active"}),
  #"Marked key columns" = Table.AddKey(#"Reordered columns", {"CRSROSTER_UID"}, false)
in
  #"Marked key columns"