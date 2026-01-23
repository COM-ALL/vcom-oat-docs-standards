(courseCode as nullable text) as nullable text =>
let
    // Step 1: Apply generic text normalization (trim + uppercase + null handling)
    NormalizedText =
        fnNormalizeText(courseCode),

    // Step 2: Remove all spaces (MDCO MDCODE semantics)
    NoSpaces =
        if NormalizedText = null then
            null
        else
            Text.Replace(NormalizedText, " ", ""),

    // Step 3: Final guard
    FinalCourseCode =
        if NoSpaces = null or NoSpaces = "" then
            null
        else
            NoSpaces
in
    FinalCourseCode