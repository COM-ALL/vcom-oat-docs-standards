// fnSectNumUIDfromDate
(
    ban_crn as nullable text,
    ban_startdate as nullable date,
    ban_term as nullable text,
    ban_sect as nullable text,
    ban_dept as nullable text,
    ban_crsnum as nullable text
) as nullable text =>
let
    // 1) Normalize identity components
    CRN = fnNormalizetext(ban_crn),
    Term = fnNormalizetext(ban_term),
    Section = fnNormalizetext(ban_sect),
    Department = fnNormalizetext(ban_dept),
    CourseNumber = fnNormalizetext(ban_crsnum),

    // 2) Validate required date input early
    ValidStartDate =
        if ban_startdate = null then null else ban_startdate,

    // 3) Derive week key from start date
    WeekRec =
        fnWeekKeyFromDate(ValidStartDate),   // [Year, WeekOfYear] or null

    // 4) Get day of week (1=Sunday, 2=Monday, ..., 7=Saturday)
    DayOfWeek =
        if ValidStartDate = null then
            null
        else
            Date.DayOfWeek(ValidStartDate, Day.Monday) + 1,

    // 5) Get month number from start date
    MonthNumber =
        if ValidStartDate = null then
            null
        else
            Date.Month(ValidStartDate),

    // 6) Validate overall input set
    IsValid =
        CRN <> null
        and Term <> null
        and Section <> null
        and Department <> null
        and CourseNumber <> null
        and WeekRec <> null
        and DayOfWeek <> null
        and MonthNumber <> null,

    // 7) Format STARTDATE-DATEUID components exactly
    // Note: STARTDATE-DATEUID format is YYYY:WW.DAYNUM (no month component)
    // DayOfWeek calculation updated to Monday = 1
    DayOfWeekMondayBase =
        if ValidStartDate = null then
            null
        else
            Date.DayOfWeek(ValidStartDate, Day.Monday) + 1,
    YearText =
        if IsValid then
            Number.ToText(WeekRec[Year], "0000", "en-US")
        else
            null,

    MonthText =
        if IsValid then
            Number.ToText(MonthNumber, "00", "en-US")
        else
            null,

    WeekText =
        if IsValid then
            Number.ToText(WeekRec[WeekOfYear], "00", "en-US")
        else
            null,

    DayText =
        if IsValid then
            Number.ToText(DayOfWeek, "0", "en-US")
        else
            null,

    // 8) Assemble STARTDATE-DATEUID: YYYY:WW.DAYNUM
    StartDateUID =
        if IsValid then
            YearText & ":" & WeekText & ".d" & DayText
        else
            null,

    // 9) Assemble final BANNER-SECTUID
    BANNER_SECTUID =
        if IsValid then
            CRN & "-" & Term & "-" & Department & CourseNumber & "." & Section & "-" & StartDateUID
        else
            null
in
    BANNER_SECTUID