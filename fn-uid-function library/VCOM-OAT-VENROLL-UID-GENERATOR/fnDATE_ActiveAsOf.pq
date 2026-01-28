// fnDATE_ActiveAsOf

// fnYesterdayCT() -> date
() as date =>
let
    utcNow = DateTimeZone.FixedUtcNow(),

    // Use base -6 to figure out the year & local date
    baseCentral = DateTimeZone.SwitchZone(utcNow, -6),
    baseCentralDate = Date.From(DateTimeZone.RemoveZone(baseCentral)),
    y = Date.Year(baseCentralDate),

    // US DST: second Sunday in March to first Sunday in November
    march1 = #date(y, 3, 1),
    firstSundayInMarch = Date.AddDays(march1, Number.Mod(7 - Date.DayOfWeek(march1, Day.Sunday), 7)),
    secondSundayInMarch = Date.AddDays(firstSundayInMarch, 7),

    nov1 = #date(y, 11, 1),
    firstSundayInNov = Date.AddDays(nov1, Number.Mod(7 - Date.DayOfWeek(nov1, Day.Sunday), 7)),

    isDST = (baseCentralDate >= secondSundayInMarch) and (baseCentralDate < firstSundayInNov),
    offset = if isDST then -5 else -6,

    centralNow = DateTimeZone.SwitchZone(utcNow, offset),
    yesterdayCT = Date.AddDays(Date.From(DateTimeZone.RemoveZone(centralNow)), -3)
in
    yesterdayCT