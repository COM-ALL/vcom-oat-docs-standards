(
    startdate as nullable date,
    enddate as nullable date
) as nullable number =>
let
    // Step 1: Validate input dates
    ValidDates =
        startdate <> null
        and enddate <> null
        and enddate >= startdate,

    // Step 2: Compute day difference
    DayDifference =
        if ValidDates then
            Duration.Days(enddate - startdate)
        else
            null,

    // Step 3: Convert to weeks and round up
    DurationWeeks =
        if DayDifference = null then
            null
        else
            Number.RoundUp(DayDifference / 7, 0)
in
    DurationWeeks