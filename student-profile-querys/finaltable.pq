// VCOM-OAT-DATA-LPROFILE-v1.0-finaltable
let
  Source = Table.NestedJoin(model_Student_Wide, {"StudentID"}, #"src_PIQ-StudentTemplate_csv", {"*StudentID"}, "src_PIQ-StudentTemplate_csv", JoinKind.LeftOuter),
  
  // Keep original expansion until proper email source is added from identity management system
  #"Expanded src_PIQ-StudentTemplate_csv" = Table.ExpandTableColumn(Source, "src_PIQ-StudentTemplate_csv", {"*Program", "*LastName", "AdmittedLast", "*FirstName", "AdmittedFirst", "PreferredName", "Former Name(s) (Please separate each name using semicolon (;))", "*Class", "AdmittedClass", "MatriculateDate", "Account(Active/Inactive)", "piq_account_active", "piq_DegreeConferred_tf"}, {"*Program", "*LastName", "AdmittedLast", "*FirstName", "AdmittedFirst", "PreferredName", "Former Name(s) (Please separate each name using semicolon (;))", "*Class", "AdmittedClass", "MatriculateDate", "Account(Active/Inactive)", "piq_account_active", "piq_DegreeConferred_tf"}),

  // Join Banner users data for email and account status
  #"Join banner_users" =
    Table.NestedJoin(
      #"Expanded src_PIQ-StudentTemplate_csv",
      {"StudentID"},
      src_banner_users,
      {"user_id"},
      "BannerUsers",
      JoinKind.LeftOuter
    ),

  #"Expanded banner_users" =
    Table.ExpandTableColumn(
      #"Join banner_users",
      "BannerUsers",
      {"banner_accnt_active", "email"},
      {"banner_accnt_active", "student_email_sso"}
    ),
  
  // Standardize column names using underscore convention
  #"Standardized column names" = Table.RenameColumns(#"Expanded banner_users", {
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
  
  // Sanity check for duplicate StudentIDs
  #"Grouped for duplicate check" = Table.Group(#"Standardized column names", {"student_id"}, {
    {"Count", each Table.RowCount(_), Int64.Type},
    {"AllData", each _, type table}
  }),
  
  // Identify records with duplicate StudentIDs but different data
  #"Duplicate check" = Table.SelectRows(#"Grouped for duplicate check", each [Count] > 1),
  
  // If duplicates exist, we'll handle them separately
  #"Has duplicates" = Table.RowCount(#"Duplicate check") > 0,
  
  // Main table: Remove full duplicates first, then check for StudentID conflicts
  #"Remove full duplicates" = Table.Distinct(#"Standardized column names"),
  
  // Check if we still have StudentID duplicates after removing full row duplicates
  #"Final duplicate check" = Table.Group(#"Remove full duplicates", {"student_id"}, {
    {"Count", each Table.RowCount(_), Int64.Type},
    {"Data", each _, type table}
  }),
  
  #"Still has StudentID duplicates" = Table.RowCount(Table.SelectRows(#"Final duplicate check", each [Count] > 1)) > 0,
  
  // Final clean table (only unique StudentIDs)
  #"Clean table" = if #"Still has StudentID duplicates" then 
    Table.SelectRows(#"Final duplicate check", each [Count] = 1)[Data]{0}
  else 
    #"Remove full duplicates",
    
  // Reorder columns for logical flow
  #"Reordered columns" = Table.ReorderColumns(#"Clean table", {
    "student_id", 
    "student_email_sso",
    "banner_accnt_active",
    "current_class", 
    "program",
    "resolved_academic_status", 
    "resolved_status_date", 
    "academic_status_active_tf",
    "first_name_current", 
    "last_name_current",
    "first_name_admitted", 
    "last_name_admitted", 
    "preferred_name", 
    "former_names",
    "class_template", 
    "admitted_class", 
    "matriculate_date",
    "campus_clinical", 
    "campus_pre_clerkship", 
    "campus_s3", 
    "campus_m1",
    "programs", 
    "distinction", 
    "pipeline",
    "account_status", 
    "piq_account_active", 
    "piq_degree_conferred_tf"
  })
in
  #"Reordered columns"