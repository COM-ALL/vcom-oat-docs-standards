// fnExcelSerialFromDate
(inputDate as nullable date) as nullable number =>
let
    // Step 1: Short-circuit nulls
    DateIfNotNull =
        if inputDate = null then
            null
        else
            inputDate,

    // Step 2: Define Excel's canonical base date
    // Excel date serial 0 corresponds to 1899-12-30
    ExcelBaseDate =
        #date(1899, 12, 30),

    // Step 3: Validate date range
    ValidDate =
        if DateIfNotNull = null or DateIfNotNull < ExcelBaseDate then
            null
        else
            DateIfNotNull,

    // Step 4: Compute serial as day difference
    SerialNumber =
        if ValidDate = null then
            null
        else
            Duration.Days(ValidDate - ExcelBaseDate)
in
    SerialNumber