// src_VCOM-OAT-DATA-LPROFILE-v1
let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "VCOM-OAT-DATA-LPROFILE-v1", ItemKind = "Table"]}[Data],
  
  // Filter out rows where student_email_sso is null (students not enrolled but still active in PIQ)
  #"Filtered non-null email" = Table.SelectRows(#"Navigation 2", each [student_email_sso] <> null and [student_email_sso] <> ""),
  
  #"Reordered columns" = Table.ReorderColumns(#"Filtered non-null email", {"student_id", "student_email_sso", "banner_accnt_active", "current_class", "program", "resolved_academic_status", "resolved_status_date", "academic_status_active_tf", "first_name_current", "last_name_current", "first_name_admitted", "last_name_admitted", "preferred_name", "former_names", "class_template", "admitted_class", "matriculate_date", "campus_clinical", "campus_pre_clerkship", "campus_s3", "campus_m1", "programs", "distinction", "pipeline", "account_status", "piq_account_active", "piq_degree_conferred_tf"})
in
  #"Reordered columns"