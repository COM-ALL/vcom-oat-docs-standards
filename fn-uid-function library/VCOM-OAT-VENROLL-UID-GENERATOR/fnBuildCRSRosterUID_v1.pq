// fnBuildCRSRosterUID_v1.pq
(
    stu_uniqueid as nullable text,
    mdco_courseuid as nullable text
) as nullable text =>
let
    // Step 1: Normalize required inputs
    NormalizedStudentId =
        fnNormalizeStudentId(stu_uniqueid),

    NormalizedCourseUid =
        fnNormalizeText(mdco_courseuid),

    // Step 2: Validate required inputs
    IsValid =
        NormalizedStudentId <> null
        and NormalizedCourseUid <> null,

    // Step 3: Build UID only if valid
    CRSROSTER_UID =
        if IsValid then
            NormalizedStudentId & "-" & NormalizedCourseUid
        else
            null
in
    CRSROSTER_UID