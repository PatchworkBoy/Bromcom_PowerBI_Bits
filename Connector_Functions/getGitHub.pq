// getGitHub
// Retrieves csv tables from DfE Analytical Services GitHub using Web.Contents connector.
// DataSource should be set to [Anonymous]
//
// These days you should be migrating from using this to using getEESapi
//
// Usage: getGitHub([FileName])
//
// Filename (text): EES_ytd_data.csv

(FileName as text) => let
    BaseUrl = "https://raw.githubusercontent.com/",
    RelativePath = "dfe-analytical-services/attendance-data-dashboard/main/data/" & FileName,
    Options = [
        RelativePath = RelativePath,
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
    from_web = Csv.Document(maybe_bytes,[Delimiter=",", Columns=23, Encoding=65001, QuoteStyle=QuoteStyle.None])
in
    from_web
