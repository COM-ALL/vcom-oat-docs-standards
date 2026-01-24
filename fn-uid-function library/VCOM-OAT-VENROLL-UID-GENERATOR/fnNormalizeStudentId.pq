// fnNormalizeStudentId
(studentId as nullable text) as nullable text =>
let
    // Step 1: Apply generic text normalization
    NormalizedText =
        fnNormalizeText(studentId),

    // Step 2: Remove all internal spaces (common in human-entered IDs)
    NoInternalSpaces =
        if NormalizedText = null then
            null
        else
            Text.Replace(NormalizedText, " ", ""),

    // Step 3: Final guard against empty results
    FinalStudentId =
        if NoInternalSpaces = null or NoInternalSpaces = "" then
            null
        else
            NoInternalSpaces
in
    FinalStudentId