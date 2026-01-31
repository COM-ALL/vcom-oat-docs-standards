// FUTURE_AIE_IMPORTER
// Purpose: Universal AIE evaluation processor with HTML cleaning and standardized field mapping
// Source: Multiple CSV files from SharePoint with varying column counts but consistent patterns
// Output: Clean evaluation records ready for UID generation and roster mapping

let
    // === HELPER FUNCTIONS ===
    // Function to remove HTML tags and decode HTML entities
    fnCleanHTML = (text as nullable text) as nullable text =>
        if text = null then null
        else 
            let
                // Remove HTML tags
                RemoveTags = Text.Replace(Text.Replace(Text.Replace(Text.Replace(
                    Text.Replace(Text.Replace(Text.Replace(Text.Replace(
                        text,
                        "<p>", ""), "</p>", " "),
                        "<span", ""), "</span>", ""),
                        "<strong>", ""), "</strong>", ""),
                        "<b>", ""), "</b>", ""),
                // Remove style attributes (everything between style="" including quotes)
                RemoveStyles = Text.Replace(Text.Replace(Text.Replace(
                    RemoveTags,
                    "style=""font-size:12px;""", ""),
                    "style=""font-family:Arial, Helvetica, sans-serif;""", ""),
                    "style=""line-height:107%;""", ""),
                // Remove remaining style patterns
                RemoveStylePatterns = Text.Replace(Text.Replace(Text.Replace(
                    RemoveStyles,
                    " style=""", ""), """", ""), ">", ""),
                // Decode HTML entities
                DecodeEntities = Text.Replace(Text.Replace(Text.Replace(Text.Replace(
                    Text.Replace(RemoveStylePatterns,
                        "&#8217;", "'"),
                        "&amp;", "&"),
                        "&lt;", "<"),
                        "&gt;", ">"),
                        "&nbsp;", " "),
                // Clean extra whitespace
                CleanWhitespace = Text.Trim(Text.Clean(DecodeEntities))
            in
                if CleanWhitespace = "" then null else CleanWhitespace,

    // Function to normalize question headers to Q1, Q2, Q3 etc.
    fnNormalizeQuestionHeader = (headerText as text, questionNumber as number) as text =>
        "Q" & Text.From(questionNumber),

    // === DATA SOURCE ===
    // Connect to SharePoint and retrieve AIE evaluation responses CSV
    // NOTE: Update file name and column count as needed for different CSV files
    Source = SharePoint.Files("https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev", [ApiVersion = 15]),
    GetCSVFile = Source{[Name = "FormResponsesReportActingInternshipElectiveEvaluation.csv", #"Folder Path" = "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev/datafiles/inbound/"]}[Content],
    ImportCSV = Csv.Document(GetCSVFile, [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    PromoteHeaders = Table.PromoteHeaders(ImportCSV, [PromoteAllScalars = true]),
    
    // === HEADER STANDARDIZATION ===
    // Map complex HTML headers to standardized field names
    StandardizeHeaders = Table.RenameColumns(PromoteHeaders, {
        // Core evaluation fields (from current_aie_dv.pq mapping)
        {"Assessment ID", "EVAL_E_ASSESSMENT_ID"},
        {"Form", "EVAL_E_FORM"},
        {"Assessment Type", "EVAL_E_ASSESSMENT_TYPE"},
        {"Assessment Method", "EVAL_E_ASSESSMENT_METHOD"},
        {"Assessor Type", "EVAL_E_ASSESSOR_TYPE"},
        {"Assessor", "EVAL_E_ASSESSOR"},
        {"Target", "Target"},  // Keep original for student lookup
        {"Task Type", "Task Type"},  // Keep original 
        {"Course Code", "MDCODE"},  // Keep original for processing
        {"Course", "EVAL_E_COURSE"},
        {"Distribution", "EVAL_E_DISTRIBUTION"},
        {"Rotation", "EVAL_E_ROTATION"},
        {"Rotation Start Date", "EVAL_E_ROTATIONSTARTDATE"},
        {"Rotation End Date", "EVAL_E_ROTATIONENDDATE"},
        {"Preceptor(s)", "EVAL_E_PRECEPTORS"},
        {"Clinical Location", "EVAL_E_CLINICALLOCATION"},
        {"Status", "Status"},  // Keep original
        {"Event", "EVAL_E_EVENT"},
        {"Event Date", "EVAL_E_EVENTDATE"},
        {"Delivery Date", "EVAL_E_DELIVERYDATE"},
        {"Completion Date", "EVAL_E_COMPLETIONDATE"},
        {"Flagged", "EVAL_E_FLAGGED"}
        // Note: Q columns and Grade column will be handled dynamically below
    }),

    // === DYNAMIC QUESTION COLUMN HANDLING ===
    // Get all column names to identify Q columns and Grade column
    ColumnNames = Table.ColumnNames(StandardizeHeaders),
    
    // Find question columns (after standard fields, before Grade)
    QuestionColumns = List.Select(ColumnNames, each not List.Contains({
        "EVAL_E_ASSESSMENT_ID", "EVAL_E_FORM", "EVAL_E_ASSESSMENT_TYPE", "EVAL_E_ASSESSMENT_METHOD",
        "EVAL_E_ASSESSOR_TYPE", "EVAL_E_ASSESSOR", "Target", "Task Type", "MDCODE", "EVAL_E_COURSE",
        "EVAL_E_DISTRIBUTION", "EVAL_E_ROTATION", "EVAL_E_ROTATIONSTARTDATE", "EVAL_E_ROTATIONENDDATE",
        "EVAL_E_PRECEPTORS", "EVAL_E_CLINICALLOCATION", "Status", "EVAL_E_EVENT", "EVAL_E_EVENTDATE",
        "EVAL_E_DELIVERYDATE", "EVAL_E_COMPLETIONDATE", "EVAL_E_FLAGGED", "Elective Grade"
    }, _)),

    // Create question column rename list
    QuestionRenames = List.Transform(
        List.Positions(QuestionColumns),
        each {QuestionColumns{_}, "Q" & Text.From(_ + 1)}
    ),

    // Apply question column renames
    RenameQuestionColumns = Table.RenameColumns(StandardizeHeaders, QuestionRenames),

    // Rename Grade column to match current structure
    RenameGradeColumn = if List.Contains(Table.ColumnNames(RenameQuestionColumns), "Elective Grade") 
        then Table.RenameColumns(RenameQuestionColumns, {{"Elective Grade", "EVAL_E_GRADE"}})
        else if List.Contains(Table.ColumnNames(RenameQuestionColumns), "Grade")
        then Table.RenameColumns(RenameQuestionColumns, {{"Grade", "EVAL_E_GRADE"}})
        else RenameQuestionColumns,

    // === DATA TYPE STANDARDIZATION ===
    // Apply proper data types to all columns
    SetDataTypes = Table.TransformColumnTypes(RenameGradeColumn, {
        {"EVAL_E_ASSESSMENT_ID", Int64.Type},
        {"EVAL_E_FORM", type text},
        {"EVAL_E_ASSESSMENT_TYPE", type text},
        {"EVAL_E_ASSESSMENT_METHOD", type text},
        {"EVAL_E_ASSESSOR_TYPE", type text},
        {"EVAL_E_ASSESSOR", type text},
        {"Target", type text},
        {"Task Type", type text},
        {"MDCODE", type text},
        {"EVAL_E_COURSE", type text},
        {"EVAL_E_DISTRIBUTION", type text},
        {"EVAL_E_ROTATION", type text},
        {"EVAL_E_ROTATIONSTARTDATE", type date},
        {"EVAL_E_ROTATIONENDDATE", type date},
        {"EVAL_E_PRECEPTORS", type text},
        {"EVAL_E_CLINICALLOCATION", type text},
        {"Status", type text},
        {"EVAL_E_EVENT", type text},
        {"EVAL_E_EVENTDATE", type text},
        {"EVAL_E_DELIVERYDATE", type datetime},
        {"EVAL_E_COMPLETIONDATE", type datetime},
        {"EVAL_E_FLAGGED", type text},
        {"EVAL_E_GRADE", type text}
        // Question columns will remain as text for cleaning
    }),

    // === HTML CLEANING FOR QUESTION FIELDS ===
    // Get the actual question column names after renaming
    FinalColumnNames = Table.ColumnNames(SetDataTypes),
    ActualQuestionColumns = List.Select(FinalColumnNames, each Text.StartsWith(_, "Q")),

    // Clean all question columns using the HTML cleaning function
    CleanQuestionFields = Table.TransformColumns(
        SetDataTypes,
        List.Transform(ActualQuestionColumns, each {_, fnCleanHTML, type nullable text})
    ),

    // === ADDITIONAL TEXT CLEANING ===
    // Clean Grade field if it contains HTML
    CleanGradeField = Table.TransformColumns(CleanQuestionFields, {
        {"EVAL_E_GRADE", fnCleanHTML, type nullable text}
    }),

    // === STANDARDIZED FIELD CREATION ===
    // Create completion date field for analytics (matching current structure)
    AddCompletionDate = Table.AddColumn(CleanGradeField, "EVAL_COMP_DATE", 
        each if [EVAL_E_COMPLETIONDATE] = null then null else Date.From([EVAL_E_COMPLETIONDATE]), type nullable date),
    
    // Create lowercase assessor match field for lookups (matching current structure)
    AddAssessorMatch = Table.AddColumn(AddCompletionDate, "assessor_match", 
        each if [EVAL_E_ASSESSOR] = null then null else Text.Lower([EVAL_E_ASSESSOR]), type nullable text)

in
    AddAssessorMatch