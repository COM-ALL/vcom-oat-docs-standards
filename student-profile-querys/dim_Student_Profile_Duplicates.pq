// dim_Student_Profile_Duplicates
let
  Source = Table.NestedJoin(model_Student_Wide, {"StudentID"}, #"src_PIQ-StudentTemplate_csv", {"*StudentID"}, "src_PIQ-StudentTemplate_csv", JoinKind.LeftOuter),
  #"Expanded src_PIQ-StudentTemplate_csv" = Table.ExpandTableColumn(Source, "src_PIQ-StudentTemplate_csv", {"*Program", "*LastName", "AdmittedLast", "*FirstName", "AdmittedFirst", "PreferredName", "Former Name(s) (Please separate each name using semicolon (;))", "*Class", "AdmittedClass", "MatriculateDate", "Account(Active/Inactive)", "piq_account_active", "piq_DegreeConferred_tf"}, {"*Program", "*LastName", "AdmittedLast", "*FirstName", "AdmittedFirst", "PreferredName", "Former Name(s) (Please separate each name using semicolon (;))", "*Class", "AdmittedClass", "MatriculateDate", "Account(Active/Inactive)", "piq_account_active", "piq_DegreeConferred_tf"}),
  
  // Standardize column names using underscore convention
  #"Standardized column names" = Table.RenameColumns(#"Expanded src_PIQ-StudentTemplate_csv", {
    {"StudentID", "student_id"},
    {"Class", "current_class"},
    {"CAMPUS CLINICAL", "campus_clinical"},
    {"CAMPUS PRE-CLERKSHIP", "campus_pre_clerkship"},
    {"CAMPUS S3", "campus_s3"},
    {"PROGRAMS", "programs"},
    {"CAMPUS M1", "campus_m1"},
    {"DISTINCTION", "distinction"},
    {"PIPELINE", "pipeline"},
    {"*Program", "program"},
    {"*LastName", "last_name_current"},
    {"AdmittedLast", "last_name_admitted"},
    {"*FirstName", "first_name_current"},
    {"AdmittedFirst", "first_name_admitted"},
    {"PreferredName", "preferred_name"},
    {"Former Name(s) (Please separate each name using semicolon (;))", "former_names"},
    {"*Class", "class_template"},
    {"AdmittedClass", "admitted_class"},
    {"MatriculateDate", "matriculate_date"},
    {"Account(Active/Inactive)", "account_status"},
    {"piq_account_active", "piq_account_active"},
    {"piq_DegreeConferred_tf", "piq_degree_conferred_tf"},
    {"RESOLVED ACADEMIC STATUS", "resolved_academic_status"},
    {"RESOLVED STATUS DATE", "resolved_status_date"},
    {"ACASTATUS_TF", "academic_status_active_tf"}
  }),
  
  // Remove full row duplicates first
  #"Remove full duplicates" = Table.Distinct(#"Standardized column names"),
  
  // Group by StudentID to find duplicates
  #"Grouped by StudentID" = Table.Group(#"Remove full duplicates", {"student_id"}, {
    {"Count", each Table.RowCount(_), Int64.Type},
    {"Data", each _, type table}
  }),
  
  // Filter to only duplicated StudentIDs (Count > 1)
  #"Only duplicates" = Table.SelectRows(#"Grouped by StudentID", each [Count] > 1),
  
  // Expand the duplicate records - use Table.ExpandTableColumn with all available column names
  #"Expanded duplicates" = if Table.RowCount(#"Only duplicates") = 0 then 
    #table({"student_id", "current_class", "duplicate_row_number"}, {}) 
  else
    Table.ExpandTableColumn(#"Only duplicates", "Data", Table.ColumnNames(#"Remove full duplicates")),
  
  // Add row number for each duplicate group (only if we have duplicates)
  #"Added index within group" = if Table.RowCount(#"Expanded duplicates") = 0 then 
    #"Expanded duplicates"
  else
    Table.AddIndexColumn(#"Expanded duplicates", "duplicate_row_number", 1, 1, Int64.Type),
  
  // Remove the temporary Count column (only if it exists)
  #"Final result" = if Table.HasColumns(#"Added index within group", {"Count"}) then
    Table.RemoveColumns(#"Added index within group", {"Count"})
  else
    #"Added index within group"
in
  #"Final result"