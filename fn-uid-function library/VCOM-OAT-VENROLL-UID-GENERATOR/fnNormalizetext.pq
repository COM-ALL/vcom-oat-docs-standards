// fnNormalizeText
(textValue as nullable text) as nullable text =>
let
    // Step 1: Short-circuit nulls
    ValueIfNotNull =
        if textValue = null then
            null
        else
            textValue,

    // Step 2: Trim leading and trailing whitespace
    TrimmedValue =
        if ValueIfNotNull = null then
            null
        else
            Text.Trim(ValueIfNotNull),

    // Step 3: Convert empty strings to null
    NullIfEmpty =
        if TrimmedValue = null or TrimmedValue = "" then
            null
        else
            TrimmedValue,

    // Step 4: Normalize casing
    NormalizedValue =
        if NullIfEmpty = null then
            null
        else
            Text.Upper(NullIfEmpty)
in
    NormalizedValue