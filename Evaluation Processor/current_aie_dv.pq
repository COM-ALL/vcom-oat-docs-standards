// CURRENT_AIE
// Purpose: Process AIE (Assessment in Education) evaluation responses from Elentra
// Source: SharePoint CSV export from Elentra evaluation system
// Output: Standardized evaluation records with UIDs and roster mappings
// Dependencies: cr026_piq_evaluator_list, new_stu_elentraroster, new_master_rotation_map

let
    // === DATA SOURCE ===
    // Connect to SharePoint and retrieve AIE evaluation responses CSV
    Source = SharePoint.Files("https://tamucs.sharepoint.com/sites/MED-PIQ-WAREHOUSE", [ApiVersion = 15]),
    GetCSVFile = Source{[Name = "FORM_RESPONSES_AIE.csv", #"Folder Path" = "https://tamucs.sharepoint.com/sites/MED-PIQ-WAREHOUSE/LOGB_PROCESSOR/ELENTRA_PROCESSOR/"]}[Content],
    ImportCSV = Csv.Document(GetCSVFile, [Delimiter = ",", Columns = 36, Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromoteHeaders = Table.PromoteHeaders(ImportCSV, [PromoteAllScalars = true]),
    
    // === DATA TYPE STANDARDIZATION ===
    // Apply proper data types to all columns from Elentra export
    SetDataTypes = Table.TransformColumnTypes(PromoteHeaders, {
        {"Assessment ID", Int64.Type}, 
        {"Form", type text}, 
        {"Assessment Type", type text}, 
        {"Assessment Method", type text}, 
        {"Assessor Type", type text}, 
        {"Assessor", type text}, 
        {"Target", type text}, 
        {"Task Type", type text}, 
        {"Course Code", type text}, 
        {"Course", type text}, 
        {"Distribution", type text}, 
        {"Rotation", type text}, 
        {"Rotation Start Date", type date}, 
        {"Rotation End Date", type date}, 
        {"Preceptor(s)", type text}, 
        {"Clinical Location", type text}, 
        {"Status", type text}, 
        {"Event", type text}, 
        {"Event Date", type text}, 
        {"Delivery Date", type datetime}, 
        {"Completion Date", type datetime}, 
        {"Flagged", type text}, 
        {"Q1", type text}, 
        {"Q2", type text}, 
        {"Q3", type text}, 
        {"Q4", type text}, 
        {"Q5", type text}, 
        {"Q6", type text}, 
        {"Q7", type text}, 
        {"Q8", type text}, 
        {"Q9", type text}, 
        {"Q10", type text}, 
        {"Q11", type text}, 
        {"Q12", type text}, 
        {"Q13", type text}, 
        {"Grade", type text}
    }),
    
    // === TEXT CLEANING ===
    // Clean and trim all question response fields and grade field
    CleanQuestionFields = Table.TransformColumns(SetDataTypes, {
        {"Q1", each if _ = null then null else Text.Trim(Text.Clean(_)), type nullable text}, 
        {"Q2", each if _ = null then null else Text.Trim(Text.Clean(_)), type nullable text}, 
        {"Q3", each if _ = null then null else Text.Trim(Text.Clean(_)), type nullable text}, 
        {"Q4", each if _ = null then null else Text.Trim(Text.Clean(_)), type nullable text}, 
        {"Q5", each if _ = null then null else Text.Trim(Text.Clean(_)), type nullable text}, 
        {"Q6", each if _ = null then null else Text.Trim(Text.Clean(_)), type nullable text}, 
        {"Q7", each if _ = null then null else Text.Trim(Text.Clean(_)), type nullable text}, 
        {"Q8", each if _ = null then null else Text.Trim(Text.Clean(_)), type nullable text}, 
        {"Q9", each if _ = null then null else Text.Trim(Text.Clean(_)), type nullable text}, 
        {"Q10", each if _ = null then null else Text.Trim(Text.Clean(_)), type nullable text}, 
        {"Q11", each if _ = null then null else Text.Trim(Text.Clean(_)), type nullable text}, 
        {"Q12", each if _ = null then null else Text.Trim(Text.Clean(_)), type nullable text}, 
        {"Q13", each if _ = null then null else Text.Trim(Text.Clean(_)), type nullable text}, 
        {"Grade", each if _ = null then null else Text.Trim(Text.Clean(_)), type nullable text}
    }),
    
    // === STANDARDIZED FIELD CREATION ===
    // Create completion date field for analytics
    AddCompletionDate = Table.AddColumn(CleanQuestionFields, "EVAL_COMP_DATE", 
        each if [Completion Date] = null then null else Date.From([Completion Date]), type nullable date),
    
    // Create lowercase assessor match field for lookups
    AddAssessorMatch = Table.AddColumn(AddCompletionDate, "assessor_match", 
        each if [Assessor] = null then null else Text.Lower([Assessor]), type nullable text),
    
    // === COURSE CODE PROCESSING ===
    // Rename and process course codes for UID generation
    RenameCourseCode = Table.RenameColumns(AddAssessorMatch, {{"Course Code", "MDCODE"}}),
    
    // Split course code into department and course number
    SplitCourseCode = Table.SplitColumn(
        Table.AddColumn(RenameCourseCode, "DEPT_TEMP", each [MDCODE]),
        "DEPT_TEMP", 
        Splitter.SplitTextByDelimiter(" "), 
        {"DEPT", "CRSNUM"}
    ),
    
    SetSplitTypes = Table.TransformColumnTypes(SplitCourseCode, {{"DEPT", type text}, {"CRSNUM", type text}}),
    
    // Create standardized course code for matching
    AddCourseCode = Table.AddColumn(SetSplitTypes, "EVAL_E_COURSECODE", 
        each if [DEPT] = null or [CRSNUM] = null then null else [DEPT] & [CRSNUM], type nullable text),
    
    // === ASSESSOR LOOKUP ===
    // Join with evaluator list to get PIQ unique IDs
    JoinEvaluators = Table.NestedJoin(AddCourseCode, {"assessor_match"}, cr026_piq_evaluator_list, {"cr026_piq_match_name"}, "cr026_piq_evaluator_list", JoinKind.LeftOuter),
    ExpandEvaluators = Table.ExpandTableColumn(JoinEvaluators, "cr026_piq_evaluator_list", {"cr026_piq_uniqueid"}, {"ASSESSOR_NUM"}),
    
    // Clean assessor number format (remove leading zero)
    CleanAssessorNum = Table.ReplaceValue(ExpandEvaluators, "02", "2", Replacer.ReplaceValue, {"ASSESSOR_NUM"}),
    
    // === STUDENT LOOKUP ===
    // Join with student roster to get UINs
    JoinStudents = Table.NestedJoin(CleanAssessorNum, {"Target"}, new_stu_elentraroster, {"new_stue_fullname"}, "new_stu_elentraroster", JoinKind.LeftOuter),
    ExpandStudents = Table.ExpandTableColumn(JoinStudents, "new_stu_elentraroster", {"new_stue_uin"}, {"TARGET_UIN"}),
    
    // === STANDARDIZE FIELD NAMES ===
    // Rename all fields to follow VCOM OAT naming conventions
    StandardizeFieldNames = Table.RenameColumns(ExpandStudents, {
        {"Assessment ID", "EVAL_E_ASSESSMENT_ID"},
        {"Q1", "EVAL_E_Q1"}, {"Q2", "EVAL_E_Q2"}, {"Q3", "EVAL_E_Q3"}, {"Q4", "EVAL_E_Q4"}, 
        {"Q5", "EVAL_E_Q5"}, {"Q6", "EVAL_E_Q6"}, {"Q7", "EVAL_E_Q7"}, {"Q8", "EVAL_E_Q8"}, 
        {"Q9", "EVAL_E_Q9"}, {"Q10", "EVAL_E_Q10"}, {"Q11", "EVAL_E_Q11"}, {"Q12", "EVAL_E_Q12"}, 
        {"Q13", "EVAL_E_Q13"}, {"Assessment Method", "EVAL_E_ASSESSMENT_METHOD"}, 
        {"Assessor Type", "EVAL_E_ASSESSOR_TYPE"}, {"Assessor", "EVAL_E_ASSESSOR"}, 
        {"Assessment Type", "EVAL_E_ASSESSMENT_TYPE"}, {"Clinical Location", "EVAL_E_CLINICALLOCATION"}, 
        {"Completion Date", "EVAL_E_COMPLETIONDATE"}, {"Course", "EVAL_E_COURSE"}, 
        {"Delivery Date", "EVAL_E_DELIVERYDATE"}, {"Distribution", "EVAL_E_DISTRIBUTION"}, 
        {"Event", "EVAL_E_EVENT"}, {"Event Date", "EVAL_E_EVENTDATE"}, 
        {"Flagged", "EVAL_E_FLAGGED"}, {"Form", "EVAL_E_FORM"}, {"Grade", "EVAL_E_GRADE"}, 
        {"Preceptor(s)", "EVAL_E_PRECEPTORS"}, {"Rotation Start Date", "EVAL_E_ROTATIONSTARTDATE"}, 
        {"Rotation End Date", "EVAL_E_ROTATIONENDDATE"}, {"Rotation", "EVAL_E_ROTATION"}
    }),
    
    // Convert assessment ID to text for UID concatenation
    ConvertAssessmentID = Table.TransformColumnTypes(StandardizeFieldNames, {{"EVAL_E_ASSESSMENT_ID", type text}}),
    
    // Convert event date to proper date type
    ConvertEventDate = Table.TransformColumnTypes(ConvertAssessmentID, {{"EVAL_E_EVENTDATE", type date}}),
    
    // === UID GENERATION ===
    // Generate unique identifier components for roster matching
    AddUIDComponents = Table.AddColumn(ConvertEventDate, "UIDA", 
        each if [EVAL_E_ROTATIONSTARTDATE] = null or [EVAL_E_ROTATIONENDDATE] = null then null 
        else Text.From(Duration.Days([EVAL_E_ROTATIONSTARTDATE] - #date(1899, 12, 30)) + 
                      Duration.Days([EVAL_E_ROTATIONENDDATE] - #date(1899, 12, 30)) + 
                      Date.WeekOfYear([EVAL_E_ROTATIONSTARTDATE], Day.Monday)), type nullable text),
    
    AddWeekNumber = Table.AddColumn(AddUIDComponents, "weeknum", 
        each if [EVAL_E_ROTATIONSTARTDATE] = null then null 
        else Text.From(Date.WeekOfYear([EVAL_E_ROTATIONSTARTDATE], Day.Monday)), type nullable text),
    
    // Generate roster UID for rotation matching
    AddRosterUID = Table.AddColumn(AddWeekNumber, "ROSTER_UID", 
        each if [TARGET_UIN] = null or [EVAL_E_COURSECODE] = null or [weeknum] = null or [UIDA] = null 
        then null else [TARGET_UIN] & "-" & [EVAL_E_COURSECODE] & "-" & [weeknum] & ":" & [UIDA], type nullable text),
    
    // === ROTATION MAPPING ===
    // Join with master rotation schedule for standardized course data
    JoinRotations = Table.NestedJoin(AddRosterUID, {"ROSTER_UID"}, new_master_rotation_map, {"new_roster_uid"}, "new_master_rotation_map", JoinKind.LeftOuter),
    ExpandRotations = Table.ExpandTableColumn(JoinRotations, "new_master_rotation_map", {
        "new_rotation_uid", "new_startdate", "new_enddate", "new_piq_crsnum", 
        "new_piq_coursedescription", "new_piq_campuslabel_25ay26", "new_course_group"
    }, {
        "SCHEDULE_UID", "OASIS_STARTDATE", "OASIS_ENDDATE", "NEW_OMDCODE", 
        "new_piq_coursedescription", "new_piq_campuslabel_25ay26", "new_course_group"
    }),
    
    // Set proper date types for rotation dates
    SetRotationDates = Table.TransformColumnTypes(ExpandRotations, {
        {"OASIS_STARTDATE", type date}, 
        {"OASIS_ENDDATE", type date}
    }),
    
    // === FINAL UID GENERATION ===
    // Create unique evaluation identifier
    AddEvaluationUID = Table.AddColumn(SetRotationDates, "EVAL_E_EVALUATION_UID", 
        each if [ROSTER_UID] = null or [EVAL_E_ASSESSMENT_ID] = null 
        then null else [ROSTER_UID] & "-" & [EVAL_E_ASSESSMENT_ID], type nullable text),
    
    // === FINAL PROCESSING ===
    // Sort and organize final dataset
    SortByUID = Table.Sort(AddEvaluationUID, {{"EVAL_E_EVALUATION_UID", Order.Ascending}}),
    
    // Remove duplicate evaluation records
    RemoveDuplicates = Table.Distinct(SortByUID, {"EVAL_E_EVALUATION_UID"}),
    
    // Organize columns in logical order
    ReorderColumns = Table.ReorderColumns(RemoveDuplicates, {
        // Primary identifiers
        "EVAL_E_EVALUATION_UID", "EVAL_E_ASSESSMENT_ID", "ROSTER_UID", "SCHEDULE_UID",
        // Assessment metadata
        "EVAL_E_FORM", "EVAL_E_ASSESSMENT_TYPE", "EVAL_E_ASSESSMENT_METHOD",
        // Assessor information
        "EVAL_E_ASSESSOR_TYPE", "EVAL_E_ASSESSOR", "ASSESSOR_NUM",
        // Student information
        "Target", "TARGET_UIN",
        // Course information
        "MDCODE", "EVAL_E_COURSECODE", "EVAL_E_COURSE", "NEW_OMDCODE", "new_piq_coursedescription",
        // Rotation information
        "EVAL_E_ROTATION", "EVAL_E_ROTATIONSTARTDATE", "EVAL_E_ROTATIONENDDATE",
        "OASIS_STARTDATE", "OASIS_ENDDATE", "new_course_group",
        // Clinical details
        "EVAL_E_PRECEPTORS", "EVAL_E_CLINICALLOCATION", "new_piq_campuslabel_25ay26",
        // Evaluation responses
        "EVAL_E_Q1", "EVAL_E_Q2", "EVAL_E_Q3", "EVAL_E_Q4", "EVAL_E_Q5", "EVAL_E_Q6",
        "EVAL_E_Q7", "EVAL_E_Q8", "EVAL_E_Q9", "EVAL_E_Q10", "EVAL_E_Q11", "EVAL_E_Q12", "EVAL_E_Q13",
        // Outcomes
        "EVAL_E_GRADE", "EVAL_E_FLAGGED",
        // Dates and status
        "EVAL_E_DELIVERYDATE", "EVAL_E_COMPLETIONDATE", "EVAL_COMP_DATE",
        "EVAL_E_EVENT", "EVAL_E_EVENTDATE", "Status",
        // Technical fields
        "EVAL_E_DISTRIBUTION", "Task Type"
    })

in
    ReorderColumns