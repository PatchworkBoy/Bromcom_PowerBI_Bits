// getCMLiveFeed
// Retrieves LiveFeed tables as XML from CloudMIS endpoint using Web.Contents connector, passing thru Basic Auth.
// DataSource should be set to [Anonymous]
//
// Usage: getCMLiveFeed([School ID], [APIKey], [LiveFeedKey])
//
// Requires params:
// School = "" meta [IsParameterQuery = true, IsParameterQueryRequired = true, Type = type text]
// CloudMISKey = "" meta [IsParameterQuery = true, IsParameterQueryRequired = true, Type = type text]
// LiveFeedKey = ""  meta [IsParameterQuery = true, IsParameterQueryRequired = true, Type = type text]

(School as text, CloudMISKey as text, LiveFeedKey as text) => let
    BasicAuth = School & ":" & CloudMISKey,
    DataKey = Text.Replace(Text.Replace(LiveFeedKey,"%2b","+"),"%3b","="),
    Base64_Auth = Binary.ToText(Text.ToBinary(BasicAuth), BinaryEncoding.Base64),
    BaseUrl = "https://cloudmis.bromcom.com",
    RelativePath = "Nucleus/WebServices/ThirdParty/TPReportingService.asmx/getReportDataByKey",
    Headers = [
        Accept="application/xml",
        Authorization = "Basic " & Base64_Auth
    ],
    Options = [
        Headers = Headers,
        RelativePath = RelativePath,
        Query=[reportDataKey=DataKey],
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
    from_xml = Xml.Tables(maybe_bytes),
    TableMeld = Table.AddColumn(from_xml, "VisionSchoolId", each School),
    #"Removed Columns" = Table.RemoveColumns(TableMeld,{"Name"}),
    #"Reordered Columns" = Table.ReorderColumns(#"Removed Columns",{"VisionSchoolId", "Table"})
in
    #"Reordered Columns"