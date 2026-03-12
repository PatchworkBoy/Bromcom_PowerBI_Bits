// --- getVisionDatePaged ---
// NO URL-ENCODING of $ or , : we DO NOT use the Query option, we construct a raw query string on RelativePath.
// OData v3 DateTime literal is used: datetime'YYYY-MM-DDTHH:MM:SS'  (matches Vision's Edm.DateTime columns).
// Vision endpoint & Basic auth per docs: https://vision.bromcom.com/odata; username = Customer Code; password = API Key.  (See docs)  [6](https://docs.bromcom.com/article-tags/power-bi-powerbi/)

(MAT as text, MATKey as text, TableName as text,
 RangeStart as any, RangeEnd as any, WindowDays as number,
 optional QueryOpts as nullable record, optional DateField as nullable text,
 optional Options as nullable record) as table =>
let
    // TableName = Date/DateTime column to use for paging
    VisionPagingPreset = [
        Students                              = "Instant",
        AssessmentResults                     = "ResultDate",
        BehaviourEvents                       = "EventDateTime",
        Exclusions                            = "DateOfIncident",
        PreAdmissionStudents                  = "DateOfBirth",
        Staff                                 = "StartDate",
        StaffAbsences                         = "StartDate",
        StaffAdditionalPayments               = "StartDate",
        StaffBasePayments                     = "StartDate",
        StaffContracts                        = "StartDate",
        StaffDisabilities                     = "DateAdvised",
        StaffQualifications                   = "QTSAchievedDate",
        StaffRoles                            = "StartDate",
        StudentExtendedTable01s               = "ResultDate",
        Locations                             = "StartDate",
        Collections                           = "StartDate",
        CollectionAssociates                  = "StartDate",
        CollectionExecutives                  = "StartDate",
        CollectionHierarchies                 = "StartDate",
        CollectionLocations                   = "StartDate",
        VisionSchools                         = "DateJoinedMat",
        AttendanceSummaryByWeek               = "WeekStartDate",
        CTFAssesments                         = "ResultDate",
        StaffSCRPreviousNames                 = "DateOfChange",
        StaffSCRPhotoIDChecks                 = "EvidenceDate",
        StaffSCRBackgroundChecks              = "CheckedDate",
        StaffSCRDBSEvidences                  = "Instant",
        StaffQualificationChecks              = "Instant",
        StaffSCRRightToWorkEvidences          = "EvidenceTakenDate",
        SchoolPerformanceLogs                 = "Instant",
        PersonAddresses                       = "StartDate",
        FineAssessmentResults                 = "ResultDate",
        StudentEnrolments                     = "StartDate",
        StudentSchoolHistory                  = "DateOfEntry",
        CurriculumAssessmentResults           = "ResultDate",
        LessonAttendanceCodesByWeek           = "StartDate",
        AllAttendancesByDate                  = "AttendanceDate",
        SessionAttendanceYTD                  = "Date",
        SessionAttendance                     = "AttendanceDate",
        StaffDataAudit                        = "AuditDate",
        StudentDataAudit                      = "AuditDate",
        StudentDinnerRegisters                = "ModifiedDate",
        StudentAlternativeProvisionDetails    = "AlternativeProvisionEntryDate",
        OnlinePayments                        = "OrderDateTime",
        FinanceJournals                       = "JournalFinancialYearStartDate",
        FinanceChartOfAccountsEnquiries       = "FinancialYearStartDate",
        StudentNurtureUnitHistories           = "StartDate",
        StaffEmploymentHistory                = "EmploymentStartDate",
        StudentSureStart                      = "StartDate",
        StudentPersonalLearningPlans          = "StartDate",
        StaffMedicalNotes                     = "Date",
        StudentMedicalNotes                   = "Date",
        StudentPreSchoolExperiences           = "Instant",
        StudentProvisions                     = "ProvisionTypeStartDate"
    ],
    // ---------- Options ----------
    Opts            = if Options = null then [IgnoreBucketErrors=false] else Options,
    IgnoreBucketErr = if Record.HasFields(Opts,"IgnoreBucketErrors") then Opts[IgnoreBucketErrors] else false,

    // ---------- Vision endpoint & headers ----------
    BaseUrl   = "https://vision.bromcom.com/odata/",
    Auth      = "Basic " & Binary.ToText(Text.ToBinary(MAT & ":" & MATKey), BinaryEncoding.Base64),
    Headers   = [Accept="application/json", Authorization=Auth],

    // ---------- Choose date field ----------
    EffectiveDateField =
        if DateField <> null then DateField
        else if Record.HasFields(VisionPagingPreset, TableName) then Record.Field(VisionPagingPreset, TableName)
        else error "No paging date field found for " & TableName & ". Supply DateField or extend VisionPagingPreset.",

    // ---------- OData v2/v3 DateTime literal ----------
    // Emit datetime'YYYY-MM-DDTHH:MM:SS' to match Edm.DateTime columns.  [4](https://community.sap.com/t5/technology-blog-posts-by-sap/date-and-time-in-sap-gateway-foundation/ba-p/13327657)
    FormatDateTimeLiteral = (v as any) as text =>
        let
            dt  = if Value.Is(v, type datetime) then v else DateTime.From(Date.From(v)),
            iso = DateTime.ToText(dt, "yyyy-MM-ddTHH:mm:ss")
        in  "datetime'" & iso & "'",

    // ---------- Build RAW query string (no encoding of $ or ,) ----------
    // We will only replace spaces with %20 at the very end; everything else ($, commas in $select) stays literal.
    BuildRawQuery = (base as nullable record, windowPredicate as text) as text =>
        let
            // map friendly keys -> OData keys (we're building plain text, so no identifier issues)
            get = (k as text) => if base <> null and Record.HasFields(base, k) and Record.Field(base, k) <> null then Text.From(Record.Field(base, k)) else null,

            sel   = get("select"),
            expd  = get("expand"),
            ob    = get("orderby"),
            top   = get("top"),
            userF = get("filter"),

            mergedFilter = if userF <> null and Text.Trim(userF) <> "" then "(" & userF & ") and (" & windowPredicate & ")" else windowPredicate,

            parts0 = {},
            parts1 = if sel  <> null then parts0 & {"$select="  & sel} else parts0,
            parts2 = if expd <> null then parts1 & {"$expand="  & expd} else parts1,
            parts3 = if ob   <> null then parts2 & {"$orderby=" & ob } else parts2,
            parts4 = if top  <> null then parts3 & {"$top="    & top} else parts3,
            parts5 =            parts4 & {"$filter=" & mergedFilter},

            raw    = Text.Combine(parts5, "&"),
            // Only encode spaces -> %20; keep $ and , exactly as-is (per your requirement).
            rawOut = Text.Replace(raw, " ", "%20")
        in
            rawOut,

    // ---------- Request helper ----------
    Request = (relativeWithQuery as text) as list =>
        let
            doReq = () =>
                let
                    bin  = Web.Contents(BaseUrl, [
                        RelativePath = relativeWithQuery,
                        Headers      = Headers,
                        ManualStatusHandling = {400,401,403,404}
                    ]),
                    json = Json.Document(bin),
                    val  = if Record.HasFields(json, "value") then json[value] else {}
                in  val
        in
            if IgnoreBucketErr then (try doReq() otherwise {}) else doReq(),

    // ---------- Buckets [start, end) ----------
    BucketStarts =
        List.Generate(
            () => RangeStart,
            (d) => d < RangeEnd,
            (d) => Date.AddDays(Date.From(d), WindowDays)
        ),

    FetchBucket = (dStart as any) as list =>
        let
            dEnd       = Date.AddDays(Date.From(dStart), WindowDays),
            endBound   = if Date.From(dEnd) < Date.From(RangeEnd) then dEnd else RangeEnd,

            litStart   = FormatDateTimeLiteral(dStart),
            litEnd     = FormatDateTimeLiteral(endBound),

            // Window predicate using OData v3 DateTime literal  (no URL encoding here)
            window     = EffectiveDateField & " ge " & litStart & " and " & EffectiveDateField & " lt " & litEnd,

            // Build raw query string (keeps $ and , literal)
            rawQuery   = BuildRawQuery(QueryOpts, window),
            // Place the ENTIRE query string on RelativePath (we do NOT use Query=[...] which encodes).  [3](https://community.fabric.microsoft.com/t5/Power-Query/Web-Contents-Query-Parameters-prevent-from-encoding/td-p/3455082)[7](https://community.fabric.microsoft.com/t5/Power-Query/Avoid-URL-encoding-in-the-Query-of-Web-Contents/td-p/3197114)
            relative   = TableName & "?" & rawQuery,

            vals       = Request(relative)
        in
            vals,

    Items = List.Combine(List.Transform(BucketStarts, each FetchBucket(_))),
    Out   = if List.Count(Items)=0 then #table({}, {}) else Table.FromRecords(Items)
in
    Out
