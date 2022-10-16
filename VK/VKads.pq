
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

agency_client as (type nullable text meta [
        Documentation.FieldCaption = "Client agency ID:",
        Documentation.SampleValues = {"123456789"}
    ]),

get_archive as (type nullable text meta [
        Documentation.FieldCaption = "Get archived:",
        Documentation.AllowedValues = { "get archived", "dont get archived" }
    ]),

campaigns_num as (type nullable text meta [
        Documentation.FieldCaption = "Campaing number in ads query:",
        Documentation.SampleValues = {"10"}
    ])


    )
    as table meta [
        Documentation.Name = "Get data from VK Ads API",
       Documentation.LongDescription = "",
        Documentation.Examples = {
        [
            Description = "Get data by days and campaigns:",
            Code = "VKads.Stat(""12345678"", ""campaigns"",""2020-02-20"",""yesterday"", null, null, null )",
            Result = "Your campaign stat!"
        ],
        [
            Description = "Get data by days and ads:",
            Code = "VKads.Stat(""12345678"", ""ads"",""365daysAgo"",""today"", null, null, null )",
            Result = "Your ad stat!"
        ],
        [
            Description = "Get token by this link:",
            Code = "https://oauth.vk.com/authorize?client_id=7337090&display=page&redirect_uri=https://oauth.vk.com/blank.html&scope=ads,offline&response_type=token&v=5.120&state=123456",
            Result = "Your token!"
        ]
        }
    ];




VKads.Data=(account as text, reportType as text, start as text, end as text, agency_client as nullable text, get_archive as nullable text, campaigns_num as nullable text )=>
let 
method = if reportType = "campaigns" then "Campaigns" else if reportType = "ads" then "Ads" else "",
camp_num = if campaigns_num=null then "10" else campaigns_num,
get_arch = if get_archive="get archived" then "1" else "0",


 

campNms = campaignNames(agency_client,account,get_arch),

    #"Добавлен индекс" = Table.AddIndexColumn(campaignNames(agency_client,account,get_arch), "Индекс", 0, 1, Int64.Type),
    #"Вставлено: целочисленное деление" = Table.AddColumn(#"Добавлен индекс", "Номер", each Number.IntegerDivide([Индекс], Number.From(camp_num)), Int64.Type),
    #"Сгруппированные строки" = Table.Group(#"Вставлено: целочисленное деление", {"Номер"}, {{"Количество", each Text.Combine(_[id_rk],",")}}),
    #"Измененный тип" = Table.TransformColumnTypes(#"Сгруппированные строки",{{"Количество", type text}}),
    #"Добавлен пользовательский объект" = Table.AddColumn(#"Измененный тип", "ads", each adNames([Количество],agency_client , account, get_arch, campNms)),
    #"Добавлен пользовательский объект1" = Table.AddColumn(#"Добавлен пользовательский объект", "Строк", each Table.RowCount([ads])),
    #"Измененный тип1" = Table.TransformColumnTypes(#"Добавлен пользовательский объект1",{{"Строк", Int64.Type}}),
    Пользовательский1 = if List.Contains(#"Измененный тип1"[Строк], 2000) then error "Превышен лимит объявлений, уменьшите кол-во кампаний в 1 запросе" else Table.SelectColumns(#"Измененный тип1",{"ads"}),
    #"Развернутый элемент Пользовательский" = Table.ExpandTableColumn(Пользовательский1, "ads", {"ad_id", "campaign_id", "ad_name", "campaign_name"}, {"ad_id", "campaign_id", "ad_name", "campaign_name"}),
    adNms = Table.TransformColumnTypes(#"Развернутый элемент Пользовательский",{{"ad_id", type text}, {"campaign_id", type text}, {"ad_name", type text}, {"campaign_name", type text}}),
   



tbla= if method="Ads" then Table.SelectColumns(adNms,"ad_id") else Table.SelectColumns(campNms,"id_rk"),
    adsTry= try Table.RenameColumns(tbla,{{"ad_id", "id"}}) otherwise tbla,
    campTry= try Table.RenameColumns(adsTry,{{"id_rk", "id"}}) otherwise adsTry,
    #"dublikat" = Table.Distinct(campTry),
index = Table.AddIndexColumn(dublikat, "Индекс", 0, 1, Int64.Type),
delenie = Table.TransformColumns(index , {{"Индекс", each Number.IntegerDivide(_, 200), Int64.Type}}),
groupBy = Table.Group(delenie, {"Индекс"}, {{"Количество", each [id]}}),
userObject = Table.AddColumn(groupBy, "objects", each Text.Combine(List.Distinct([Количество]),",")),
removeColumns = Table.RemoveColumns(userObject,{"Количество", "Индекс"}),
changeTip= Table.TransformColumnTypes(removeColumns,{{"objects", type text}}),
addData = Table.AddColumn(changeTip, "data", each Function.InvokeAfter(()=> getData([objects], account, method, start,end, reportType, campNms, adNms),#duration(0,0,0,0.5))),
delCol = Table.RemoveColumns(addData,{"objects"}),

expList = 
if reportType = "campaigns" then 
{"id_rk", "name", "day", "spent", "impressions", "reach", "clicks", "join_rate"}  
else if reportType = "ads" then 
{"ad_id", "campaign_id", "ad_name", "campaign_name", "day", "spent", "impressions", "reach", "clicks", "join_rate"} 
else {},

colTypes = 
if reportType = "campaigns" then 
{{"id_rk", type text}, {"name", type text}, {"day", type date}, {"spent", Int64.Type}, {"impressions", Int64.Type}, {"reach", Int64.Type}, {"clicks", Int64.Type}, {"join_rate", Int64.Type}}
else if reportType = "ads" then 
{{"ad_id", type text}, {"campaign_id", type text}, {"ad_name", type text}, {"campaign_name", type text}, {"day", type date}, {"spent", Int64.Type}, {"impressions", Int64.Type}, {"reach", Int64.Type}, {"clicks", Int64.Type}, {"join_rate", Int64.Type}}
else {},

expAnd = try Table.TransformColumnTypes( Table.ExpandTableColumn(delCol, "data", expList,expList),colTypes) otherwise "Произошла ошибка",

    ren1 = try Table.RenameColumns(expAnd ,{{"day", "Дата"}}) otherwise expAnd ,
    ren2 = try Table.RenameColumns(ren1 ,{{"spent", "Расход"}}) otherwise ren1 ,
    ren3 = try Table.RenameColumns(ren2 ,{{"clicks", "Клики"}}) otherwise ren2 ,
    ren4 = try Table.RenameColumns(ren3 ,{{"impressions", "Показы"}}) otherwise ren3 ,
    ren5 = try Table.RenameColumns(ren4 ,{{"id_rk", "ID кампании"}}) otherwise ren4 ,
    ren6 = try Table.RenameColumns(ren5 ,{{"campaign_name", "Кампания"}}) otherwise ren5, 
    ren7 = try Table.RenameColumns(ren6 ,{{"campaign_id", "ID кампании"}}) otherwise ren6 ,
    ren8 = try Table.RenameColumns(ren7 ,{{"join_rate", "Подписки"}}) otherwise ren7 ,
    ren9 = try Table.RenameColumns(ren8 ,{{"ad_name", "Объявление"}}) otherwise ren8 ,
    ren10 = try Table.RenameColumns(ren9 ,{{"ad_id", "ID объявления"}}) otherwise ren9 ,
    ren11 = try Table.RenameColumns(ren10 ,{{"reach", "Охват"}}) otherwise ren10 ,
    ren12 = try Table.RenameColumns(ren11 ,{{"name", "Кампания"}}) otherwise ren11
in
    ren12;


    dateFunc= (dat)=>
if dat = "yesterday" then Date.ToText(Date.AddDays(Date.From(DateTime.LocalNow()) , -1),"yyyy-MM-dd") 
else if dat = "today" then Date.ToText(Date.From(DateTime.LocalNow()),"yyyy-MM-dd")
else if (try Number.From(Text.BeforeDelimiter(dat,"daysAgo")) otherwise 0) >0 then Date.ToText(Date.AddDays(Date.From(DateTime.LocalNow()),-1*Number.From(Text.BeforeDelimiter(dat,"daysAgo"))),"yyyy-MM-dd") 
else dat;


campaignNames = (agency_client,account,get_arch)=>
let
got = if agency_client =null then [] else [#"client_id"=agency_client], 
get = [#"account_id"=account,  #"access_token"=Extension.CurrentCredential()[Key], #"v"="5.130", #"include_deleted"=get_arch]&got,
web = Function.InvokeAfter(()=>Web.Contents("https://api.vk.com/method/ads.getCampaigns", [Query = get,  ManualStatusHandling = {404, 400}]),#duration(0,0,0,0.5)),
result = Json.Document(web),
response = result[response],
toTable = Table.FromList(response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
expanded = Table.ExpandRecordColumn(toTable, "Column1", 
{"id", "type", "name", "status", "day_limit", "all_limit", "start_time", "stop_time","create_time", "update_time", "views_limit"}, 
{"id", "type", "name", "status", "day_limit", "all_limit", "start_time", "stop_time", "create_time", "update_time", "views_limit"}),
chType = Table.TransformColumnTypes(expanded ,{{"id", type text}, {"name", type text}}),
deleted = Table.SelectColumns(chType,{"id", "name"}),
rename = Table.RenameColumns(deleted,{{"id", "id_rk"}})
in rename;



adNames = (ids, agency_client , account, get_arch, campNms )=>
let
got = if agency_client =null then [] else [#"client_id"=agency_client], 
get = [#"account_id"=account,  #"access_token"=Extension.CurrentCredential()[Key], #"v"="5.130", #"include_deleted"=get_arch , #"campaign_ids"= "["&ids&"]"]&got,
web = Function.InvokeAfter(()=>Web.Contents("https://api.vk.com/method/ads.getAds", [Query = get,  ManualStatusHandling = {404, 400}]),#duration(0,0,0,0.5)),
result = Json.Document(web),
response = result[response],
toTable = Table.FromList(response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
expanded = Table.ExpandRecordColumn(toTable, "Column1", 
{"id", "campaign_id", "status", "create_time", "update_time", "day_limit", "all_limit", "start_time", "stop_time", "name", "type", "views_limit"}, 
{"id", "campaign_id", "status", "create_time", "update_time", "day_limit", "all_limit", "start_time", "stop_time", "name", "type", "views_limit"}),
chType = Table.TransformColumnTypes(expanded,{{"id", type text}, {"name", type text}, {"campaign_id", type text}}),
deleted = Table.SelectColumns(chType, {"id", "campaign_id", "name"}),
rename = Table.RenameColumns(deleted,{{"id", "ad_id"}, {"name", "ad_name"}}),
user = Table.Join(rename, "campaign_id", campNms,  "id_rk", JoinKind.LeftOuter),
delet = Table.RemoveColumns(user,{"id_rk"}),
renam = Table.RenameColumns(delet,{{"name", "campaign_name"}})
in renam;



getData = (objectList, account, method, start,end, reportType, campNms, adNms)=>
let
get = [#"account_id"=account, #"ids_type"=Text.BeforeDelimiter(Text.Lower(method),"s"), 
#"access_token"=Extension.CurrentCredential()[Key], #"v"="5.130", #"ids"=objectList, #"period"="day", #"date_from"=dateFunc(start), #"date_to"=dateFunc(end)],
web = Function.InvokeAfter(()=>Web.Contents("https://api.vk.com/method/ads.getStatistics", [Query = get,  ManualStatusHandling = {404, 400}]),#duration(0,0,0,0.5)),
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
if reportType = "campaigns" then Table.RemoveColumns(Table.Join( znach,"id",campNms, "id_rk",JoinKind.LeftOuter),{"id"}) else
if reportType = "ads" then Table.RemoveColumns(Table.Join( znach,"id",adNms, "ad_id",JoinKind.LeftOuter),{"id"}) else "Неизвестный тип отчёта"
in join;


VKads = [
    TestConnection = (dataSourcePath) => 
        { 
        "VKads.Stat",
        Json.Document(dataSourcePath)[account],
        Json.Document(dataSourcePath)[reportType],
        Json.Document(dataSourcePath)[start],
        Json.Document(dataSourcePath)[end],
        Json.Document(dataSourcePath)[agency_client]?,
        Json.Document(dataSourcePath)[get_archive]?,
        Json.Document(dataSourcePath)[campaigns_num]?
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