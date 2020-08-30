
section VKads;

[DataSource.Kind="VKads", Publish="VKads.Publish"]
shared VKads.Stat =  Value.ReplaceType(VKads.Data, FuncType);


FuncType = type function (

    account as (type text meta [        
        Documentation.FieldCaption = "Account ID:",
         Documentation.SampleValues = {"12345678"}
    ]),

reportType  as (type text meta [        
        Documentation.FieldCaption = "Report type:",
         Documentation.SampleValues = {"campaigns"},
        Documentation.AllowedValues = { "ads", "campaigns" }
    ]),


    start as (type text meta [
        Documentation.FieldCaption = "Start date:",
        Documentation.SampleValues = {"2020-02-28"}
    ]),
     end as (type text meta [
        Documentation.FieldCaption = "End date:",
        Documentation.SampleValues = {"yesterday"}
    ]),
optional  client as (type text meta [
        Documentation.FieldCaption = "Agency client ID:",
        Documentation.SampleValues = {"123456789"}
    ])


    )
    as table meta [
        Documentation.Name = "Get data from VK Ads API",
       Documentation.LongDescription = "",
        Documentation.Examples = {
        [
            Description = "Get data by days and campaigns:",
            Code = "VKads.Stat(""12345678"", ""campaigns"",""2020-02-20"",""yesterday"")",
            Result = "Your campaign stat!"
        ],
        [
            Description = "Get data by days and ads:",
            Code = "VKads.Stat(""12345678"", ""ads"",""365daysAgo"",""today"")",
            Result = "Your ad stat!"
        ],
        [
            Description = "Get token by this link:",
            Code = "https://oauth.vk.com/authorize?client_id=7337090&display=page&redirect_uri=https://oauth.vk.com/blank.html&scope=ads,offline&response_type=token&v=5.120&state=123456",
            Result = "Your token!"
        ]
        }
    ];




VKads.Data=(account as text, reportType as text, start as text, end as text, optional client as text )=>
let 
method = if reportType = "campaigns" then "Campaigns" else if reportType = "ads" then "Ads" else "",
gott = if client = null then [] else [#"client_id"=client], 
gett = [#"account_id"=account,  #"access_token"=Extension.CurrentCredential()[Key], #"v"="5.107"]&gott,
webo = Function.InvokeAfter(()=>Web.Contents("https://api.vk.com/method/ads.get" & method, [Query = gett,  ManualStatusHandling = {404, 400}]),#duration(0,0,0,0.2)),
results = Json.Document(webo),
responses = results[response],
toTables= Table.FromList(responses, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
expandeds = Table.ExpandRecordColumn(toTables, "Column1", {"id"},{"id"}),
chTypes = Table.TransformColumnTypes(expandeds,{{"id", type text}}),
onlyId = Table.SelectColumns(chTypes,{"id"}),
dubli = Table.Distinct(onlyId),
index = Table.AddIndexColumn(dubli , "Индекс", 0),
delenie = Table.TransformColumns(index , {{"Индекс", each Number.IntegerDivide(_, 200), Int64.Type}}),
groupBy = Table.Group(delenie, {"Индекс"}, {{"Количество", each [id]}}),
userObject = Table.AddColumn(groupBy, "objects", each Text.Combine(List.Distinct([Количество]),",")),
removeColumns = Table.RemoveColumns(userObject,{"Количество", "Индекс"}),
changeTip= Table.TransformColumnTypes(removeColumns,{{"objects", type text}}),
addData = Table.AddColumn(changeTip, "data", each Function.InvokeAfter(()=> getData([objects],account,reportType,start, end, client),#duration(0,0,0,0.5))),
deletErr = Table.RemoveRowsWithErrors(addData,{"data"}),
delCol = Table.RemoveColumns(deletErr,{"objects"}),
expList = 
if reportType = "campaigns" then {"id_rk", "name", "day", "spent", "impressions", "reach", "clicks", "join_rate"}  
else if reportType = "ads" then {"ad_id", "campaign_id", "ad_name", "campaign_name", "day", "spent", "impressions", "reach", "clicks", "join_rate"} 
else {},
colTypes = 
if reportType = "campaigns" then {{"id_rk", type text}, {"name", type text}, {"day", type date}, {"spent", type number}, {"impressions", Int64.Type}, {"reach", Int64.Type}, {"clicks", Int64.Type}, {"join_rate", Int64.Type}}
else if reportType = "ads" then {{"ad_id", type text}, {"campaign_id", type text}, {"ad_name", type text}, {"campaign_name", type text}, {"day", type date}, {"spent", type number}, {"impressions", Int64.Type}, {"reach", Int64.Type}, {"clicks", Int64.Type}, {"join_rate", Int64.Type}}
else {},
expAnd = try Table.TransformColumnTypes( Table.ExpandTableColumn(delCol, "data", expList,expList),colTypes) otherwise "Произошла ошибка"
in  try results[error] otherwise expAnd;


campaignNames = (account as text, client as nullable text )=>
let
got = if client =null then [] else [#"client_id"=client], 
get = [#"account_id"=account,  #"access_token"=Extension.CurrentCredential()[Key], #"v"="5.107"]&got,
web = Function.InvokeAfter(()=> Web.Contents("https://api.vk.com/method/ads.getCampaigns", [Query = get,  ManualStatusHandling = {404, 400}]),#duration(0,0,0,0.2)),
result = Json.Document(web),
response = result[response],
toTable = Table.FromList(response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
expanded = Table.ExpandRecordColumn(toTable, "Column1",{"id",  "name"}, {"id", "name"}),
chType = Table.TransformColumnTypes(expanded ,{{"id", type text}, {"name", type text}}),
deleted = Table.SelectColumns(chType,{"id", "name"}),
rename = Table.RenameColumns(deleted,{{"id", "id_rk"}})
in rename;

adNames = (account as text, client as nullable text)=>
let
got = if client =null then [] else [#"client_id"=client], 
get = [#"account_id"=account,  #"access_token"=Extension.CurrentCredential()[Key], #"v"="5.107"]&got,
web = Function.InvokeAfter(()=> Web.Contents("https://api.vk.com/method/ads.getAds", [Query = get,  ManualStatusHandling = {404, 400}]),#duration(0,0,0,0.3)),
result = Json.Document(web),
response = result[response],
toTable = Table.FromList(response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
expanded = Table.ExpandRecordColumn(toTable, "Column1", {"id", "campaign_id", "name"}, {"id", "campaign_id", "name"}),
chType = Table.TransformColumnTypes(expanded,{{"id", type text}, {"name", type text}, {"campaign_id", type text}}),
deleted = Table.SelectColumns(chType, {"id", "campaign_id", "name"}),
rename = Table.RenameColumns(deleted,{{"id", "ad_id"}, {"name", "ad_name"}}),
user = Table.Join(rename, "campaign_id", campaignNames(account, client), "id_rk", JoinKind.LeftOuter),
delet = Table.RemoveColumns(user,{"id_rk"}),
renam = Table.RenameColumns(delet,{{"name", "campaign_name"}})
in renam;


getData = (objectList as text, account as text, reportType as text, start as text, end as text, client as nullable text )=>
let
method = if reportType = "campaigns" then "Campaigns" else if reportType = "ads" then "Ads" else "",
get = [#"account_id"=account, #"ids_type"=Text.BeforeDelimiter(Text.Lower(method),"s"), 
#"access_token"=Extension.CurrentCredential()[Key], #"v"="5.107", #"ids"=objectList, #"period"="day", #"date_from"=dateFunc(start), #"date_to"=dateFunc(end)],
web = Function.InvokeAfter(()=>Web.Contents("https://api.vk.com/method/ads.getStatistics", [Query = get,  ManualStatusHandling = {404, 400}]),#duration(0,0,0,0.3)),
result = Json.Document(web),
response = result[response],
toTables = Table.FromList(response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
exp = Table.ExpandRecordColumn(toTables, "Column1", {"id", "stats"}, {"id", "stats"}),
exp2 = Table.ExpandListColumn(exp, "stats"),
exp3 = Table.ExpandRecordColumn(exp2, "stats", 
{"day", "spent", "impressions", "reach", "clicks", "join_rate"},
{"day", "spent", "impressions", "reach", "clicks", "join_rate"}),
filter = Table.SelectRows(exp3, each ([day] <> null)),
type1 = Table.TransformColumnTypes(filter,{{"day", type date}, {"id", type text}}),
type2 = Table.TransformColumnTypes(type1, {{"spent", type number}}, "en-AU"),
type3 = Table.TransformColumnTypes(type2,{{"impressions", type number}, {"reach", type number}, {"clicks", type number}, {"join_rate", type number}}),
znach = Table.ReplaceValue(type3, null,0,Replacer.ReplaceValue,{"spent", "impressions", "reach", "clicks", "join_rate"}),
join = 
if reportType = "campaigns" then Table.RemoveColumns(Table.Join( znach,"id",campaignNames(account,client), "id_rk",JoinKind.LeftOuter),{"id"}) else
if reportType = "ads" then Table.RemoveColumns(Table.Join( znach,"id",adNames(account,client), "ad_id",JoinKind.LeftOuter),{"id"}) else "Неизвестный тип отчёта"
in join;


dateFunc= (dat)=>
       if dat = "yesterday" then Date.ToText(Date.AddDays(Date.From(DateTime.LocalNow()) , -1),"yyyy-MM-dd") 
       else if dat = "today" then Date.ToText(Date.From(DateTime.LocalNow()),"yyyy-MM-dd")
       else if (try Number.From(Text.BeforeDelimiter(dat,"daysAgo")) otherwise 0) >0 then Date.ToText(Date.AddDays(Date.From(DateTime.LocalNow()),-1*Number.From(Text.BeforeDelimiter(dat,"daysAgo"))),"yyyy-MM-dd") 
       else dat;



VKads = [
    TestConnection = (dataSourcePath) => 
        { 
        "VKads.Stat",
        Json.Document(dataSourcePath)[account],
        Json.Document(dataSourcePath)[reportType],
        Json.Document(dataSourcePath)[start],
        Json.Document(dataSourcePath)[end],
        Json.Document(dataSourcePath)[client]?
        },
    Authentication = [
        
       Key =[ ]
    ],
    Label = "VKads Connection"
];


VKads.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { "VKads  Connector", "Help" },
    LearnMoreUrl = "https://www.youtube.com/channel/UCqSLNYLN_3mf6nA1Xf7fu1g",
    SourceImage = VKads.Icons,
    SourceTypeImage = VKads.Icons
];

VKads.Icons = [
    Icon16 = { Extension.Contents("VKads16.png"), Extension.Contents("VKads20.png"), Extension.Contents("VKads24.png"), Extension.Contents("VKads32.png") },
    Icon32 = { Extension.Contents("VKads32.png"), Extension.Contents("VKads40.png"), Extension.Contents("VKads48.png"), Extension.Contents("VKads64.png") }
];
