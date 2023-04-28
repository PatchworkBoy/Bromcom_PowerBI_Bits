// getCMTable
// Retrieves oData tables as JSON from CloudMIS endpoint using Web.Contents connector, passing thru Basic Auth.
// DataSource should be set to [Anonymous]
//
// Usage: getCMTable([SchoolId], [APIKey], [TableName])
//
// Requires params:
// School = "" meta [IsParameterQuery = true, IsParameterQueryRequired = true, Type = type text]
// CloudMISKey = "" meta [IsParameterQuery = true, IsParameterQueryRequired = true, Type = type text]
// TableName = ""  meta [IsParameterQuery = true, IsParameterQueryRequired = true, Type = type text]

(School as text, CloudMISKey as text, TableName as text) => let
    BasicAuth = School & ":" & CloudMISKey,
    Base64_Auth = Binary.ToText(Text.ToBinary(BasicAuth), BinaryEncoding.Base64),
    BaseUrl = "https://cloudmis.bromcom.com",
    RelativePath = "Nucleus/oData",
    oDataSrc = TableName,
    Headers = [
        Accept="application/json",
        Authorization = "Basic " & Base64_Auth
    ],
    Options = [
        RelativePath = RelativePath & "/" & oDataSrc,
        Headers = Headers,
        ManualStatusHandling = {400, 404}
    ],
    binary_response = Web.Contents(BaseUrl, Options),
    buffered = Binary.Buffer(binary_response),
    response_metadata = Value.Metadata(binary_response),
    status_code = response_metadata[Response.Status],
    // for 400 and 404, return extra error info
    maybe_bytes =
        if List.Contains({400, 404}, status_code)
        then response_metadata else buffered,
    // returns either document else web request error
    from_json = Json.Document(maybe_bytes),
    value = from_json[value],
    TableConvert = Table.FromList(value, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    TableMeld = Table.AddColumn(TableConvert, "VisionSchoolId", each School),
    TableTidy = Table.ReorderColumns(TableMeld,{"VisionSchoolId", "Column1"})
in
    TableTidy