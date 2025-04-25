// getPerfData
// Retrieves xlsx/csv tables from find-school-performance-data.service.gov.uk using Web.Contents connector.
// DataSource should be set to [Anonymous]
//
// NB: NO LONGER WORKS - DfE BLOCK MICROSOFT BI SERVICE SERVERS (??)
//
// Usage: getPerfData([YearRef], [YearRef2], [Filter], [Format])
//
// YearRef (text): 2021-2022
// YearRef2 (text): 2020-2021
// Filter (text): any of... GIAS, KS4, KS5 etc
// Format (text): xls or csv

(YearRef as text, YearRef2 as text, Filter as text, Format as text) => let
    BaseUrl = "https://www.find-school-performance-data.service.gov.uk/",
    Download = "true",
    Regions = "0",
    Meta = "false",
    Year = if (Filter = "WORKFORCE" or Filter = "SPENDPERPUPIL" or Filter ="SPENDPERPUPILFULL") then YearRef2 else YearRef,
    RelativePath = "download-data",
    Options = [
        RelativePath = RelativePath,
        Query=[
            download=Download,
            regions=Regions,
            filters=Filter,
            fileformat=Format,
            year=Year,
            meta=Meta
        ],
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
    from_web = if Filter = "KS4UNDERLYING" then 
        unZip(maybe_bytes) else 
        if Format = "csv" then 
            Csv.Document(maybe_bytes,[Delimiter=",", Columns=23, Encoding=65001, QuoteStyle=QuoteStyle.None]) else
            Excel.Workbook(maybe_bytes)
in
    from_web
