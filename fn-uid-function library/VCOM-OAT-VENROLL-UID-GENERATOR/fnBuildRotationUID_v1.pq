// fnBuildRotationUID_v1
(
    stu_uniqueid as nullable text,
    mdco_coursecode as nullable text,
    startdate as nullable date,
    enddate as nullable date,
    mdco_campusid as nullable text
) as nullable text =>
let
    // 1) Normalize identity components
    StudentId  = fnNormalizeStudentId(stu_uniqueid),
    CourseCode = fnNormalizeRotationCourseCode(mdco_coursecode),
    CampusId   = fnNormalizeText(mdco_campusid),

    // 2) Validate required date inputs early
    ValidStartDate =
        if startdate = null then null else startdate,

    ValidEndDate =
        if enddate = null then null else enddate,

    // 3) Derive week key from start date
    WeekRec =
        fnWeekKeyFromDate(ValidStartDate),   // [Year, WeekOfYear] or null

    // 4) Compute Excel-style day offsets
    BaseDate = #date(1899, 12, 30),

    StartSerial =
        if ValidStartDate = null then
            null
        else
            Duration.Days(ValidStartDate - BaseDate),

    EndSerial =
        if ValidEndDate = null then
            null
        else
            Duration.Days(ValidEndDate - BaseDate),

    // 5) Compute authoritative numeric UIDA value
    UIDA =
        if StartSerial = null or EndSerial = null or WeekRec = null then
            null
        else
            StartSerial + EndSerial + WeekRec[WeekOfYear],

    // 6) Validate overall input set
    IsValid =
        StudentId <> null
        and CourseCode <> null
        and CampusId <> null
        and WeekRec <> null
        and UIDA <> null,

    // 7) Format temporal key exactly
    YearText =
        if IsValid then
            Number.ToText(WeekRec[Year], "0000", "en-US")
        else
            null,

    WeekText =
        if IsValid then
            Number.ToText(WeekRec[WeekOfYear], "00", "en-US")
        else
            null,

    UIDAText =
        if IsValid then
            Number.ToText(UIDA, "0", "en-US")
        else
            null,

    TemporalKey =
        if IsValid then
            YearText & "." & WeekText & ":" & UIDAText
        else
            null,

    // 8) Assemble final ROTATION_UID
    ROTATION_UID =
        if IsValid then
            StudentId & "-" & CourseCode & "-" & TemporalKey & "-" & CampusId
        else
            null
in
    ROTATION_UID