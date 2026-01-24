// fnWeekKeyFromDate
(inputDate as nullable date) as nullable record =>
let
    // Step 1: Short-circuit nulls
    DateIfNotNull =
        if inputDate = null then
            null
        else
            inputDate,

    // Step 2: Derive year component
    YearComponent =
        if DateIfNotNull = null then
            null
        else
            Date.Year(DateIfNotNull),

    // Step 3: Derive week-of-year using Monday as the first day of the week
    WeekComponent =
        if DateIfNotNull = null then
            null
        else
            Date.WeekOfYear(DateIfNotNull, Day.Monday),

    // Step 4: Assemble record if valid
    WeekKey =
        if YearComponent = null or WeekComponent = null then
            null
        else
            [
                Year = YearComponent,
                WeekOfYear = WeekComponent
            ]
in
    WeekKey