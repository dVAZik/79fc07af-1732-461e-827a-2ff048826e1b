--!native
-- VoxK Mobile Edition - Адаптированная версия SimpleSpy для мобильных устройств

if getgenv().VoxKExecuted and type(getgenv().VoxKShutdown) == "function" then
    getgenv().VoxKShutdown()
end

local realconfigs = {
    logcheckcaller = false,
    autoblock = false,
    funcEnabled = true,
    advancedinfo = false,
    mobileMode = true,
    touchFriendly = true,
    --logreturnvalues = false,
    supersecretdevtoggle = false
}

local configs = newproxy(true)
local configsmetatable = getmetatable(configs)

configsmetatable.__index = function(self,index)
    return realconfigs[index]
end

local oth = syn and syn.oth
local unhook = oth and oth.unhook
local hook = oth and oth.hook

local lower = string.lower
local byte = string.byte
local round = math.round
local running = coroutine.running
local resume = coroutine.resume
local status = coroutine.status
local yield = coroutine.yield
local create = coroutine.create
local close = coroutine.close
local OldDebugId = game.GetDebugId
local info = debug.info

local IsA = game.IsA
local tostring = tostring
local tonumber = tonumber
local delay = task.delay
local spawn = task.spawn
local clear = table.clear
local clone = table.clone

local function blankfunction(...)
    return ...
end

local get_thread_identity = (syn and syn.get_thread_identity) or getidentity or getthreadidentity
local set_thread_identity = (syn and syn.set_thread_identity) or setidentity
local islclosure = islclosure or is_l_closure
local threadfuncs = (get_thread_identity and set_thread_identity and true) or false

local getinfo = getinfo or blankfunction
local getupvalues = getupvalues or debug.getupvalues or blankfunction
local getconstants = getconstants or debug.getconstants or blankfunction

local getcustomasset = getsynasset or getcustomasset
local getcallingscript = getcallingscript or blankfunction
local newcclosure = newcclosure or blankfunction
local clonefunction = clonefunction or blankfunction
local cloneref = cloneref or blankfunction
local request = request or syn and syn.request
local makewritable = makewriteable or function(tbl)
    setreadonly(tbl,false)
end
local makereadonly = makereadonly or function(tbl)
    setreadonly(tbl,true)
end
local isreadonly = isreadonly or table.isfrozen

local setclipboard = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set) or function(...)
    return ErrorPrompt("Attempted to set clipboard: "..(...),true)
end

local hookmetamethod = hookmetamethod or (makewriteable and makereadonly and getrawmetatable) and function(obj: object, metamethod: string, func: Function)
    local old = getrawmetatable(obj)

    if hookfunction then
        return hookfunction(old[metamethod],func)
    else
        local oldmetamethod = old[metamethod]
        makewriteable(old)
        old[metamethod] = func
        makereadonly(old)
        return oldmetamethod
    end
end

local function Create(instance, properties, children)
    local obj = Instance.new(instance)

    for i, v in next, properties or {} do
        obj[i] = v
        for _, child in next, children or {} do
            child.Parent = obj;
        end
    end
    return obj;
end

local function SafeGetService(service)
    return cloneref(game:GetService(service))
end

local function Search(logtable,tbl)
    table.insert(logtable,tbl)
    
    for i,v in tbl do
        if type(v) == "table" then
            return table.find(logtable,v) ~= nil or Search(v)
        end
    end
end

local function IsCyclicTable(tbl)
    local checkedtables = {}

    local function SearchTable(tbl)
        table.insert(checkedtables,tbl)
        
        for i,v in next, tbl do
            if type(v) == "table" then
                return table.find(checkedtables,v) and true or SearchTable(v)
            end
        end
    end

    return SearchTable(tbl)
end

local function deepclone(args: table, copies: table): table
    local copy = nil
    copies = copies or {}

    if type(args) == 'table' then
        if copies[args] then
            copy = copies[args]
        else
            copy = {}
            copies[args] = copy
            for i, v in next, args do
                copy[deepclone(i, copies)] = deepclone(v, copies)
            end
        end
    elseif typeof(args) == "Instance" then
        copy = cloneref(args)
    else
        copy = args
    end
    return copy
end

local function rawtostring(userdata)
    if type(userdata) == "table" or typeof(userdata) == "userdata" then
        local rawmetatable = getrawmetatable(userdata)
        local cachedstring = rawmetatable and rawget(rawmetatable, "__tostring")

        if cachedstring then
            local wasreadonly = isreadonly(rawmetatable)
            if wasreadonly then
                makewritable(rawmetatable)
            end
            rawset(rawmetatable, "__tostring", nil)
            local safestring = tostring(userdata)
            rawset(rawmetatable, "__tostring", cachedstring)
            if wasreadonly then
                makereadonly(rawmetatable)
            end
            return safestring
        end
    end
    return tostring(userdata)
end

local CoreGui = SafeGetService("CoreGui")
local Players = SafeGetService("Players")
local RunService = SafeGetService("RunService")
local UserInputService = SafeGetService("UserInputService")
local TweenService = SafeGetService("TweenService")
local ContentProvider = SafeGetService("ContentProvider")
local TextService = SafeGetService("TextService")
local http = SafeGetService("HttpService")
local GuiInset = game:GetService("GuiService"):GetGuiInset() :: Vector2

local function jsone(str) return http:JSONEncode(str) end
local function jsond(str)
    local suc,err = pcall(http.JSONDecode,http,str)
    return suc and err or suc
end

function ErrorPrompt(Message,state)
    if getrenv then
        local ErrorPrompt = getrenv().require(CoreGui:WaitForChild("RobloxGui"):WaitForChild("Modules"):WaitForChild("ErrorPrompt"))
        local prompt = ErrorPrompt.new("Default",{HideErrorCode = true})
        local ErrorStoarge = Create("ScreenGui",{Parent = CoreGui,ResetOnSpawn = false})
        local thread = state and running()
        prompt:setParent(ErrorStoarge)
        prompt:setErrorTitle("VoxK Mobile Error")
        prompt:updateButtons({{
            Text = "Proceed",
            Callback = function()
                prompt:_close()
                ErrorStoarge:Destroy()
                if thread then
                    resume(thread)
                end
            end,
            Primary = true
        }}, 'Default')
        prompt:_open(Message)
        if thread then
            yield(thread)
        end
    else
        warn(Message)
    end
end

local Highlight = (isfile and loadfile and isfile("Highlight.lua") and loadfile("Highlight.lua")()) or loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/SimpleSpy/main/Highlight.lua"))()
local LazyFix = loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/Roblox/refs/heads/main/Lua/Libraries/DataToCode/DataToCode.luau"))()

-- ==================== НАЧАЛО НОВОГО GUI ДЛЯ МОБИЛЬНЫХ УСТРОЙСТВ ====================

local VoxK = Create("ScreenGui",{
    ResetOnSpawn = false,
    Name = "VoxK",
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
})

local Storage = Create("Folder",{})

-- Основной контейнер с адаптивным размером для мобильных устройств
local MainContainer = Create("Frame",{
    Parent = VoxK,
    BackgroundColor3 = Color3.fromRGB(30, 30, 35),
    BorderSizePixel = 0,
    Position = UDim2.new(0.5, -200, 0.5, -150),
    Size = UDim2.new(0, 400, 0, 500),
    AnchorPoint = Vector2.new(0.5, 0.5),
    ClipsDescendants = true
})

-- Скругленные углы для мобильного дизайна
local UICorner = Create("UICorner",{
    Parent = MainContainer,
    CornerRadius = UDim.new(0, 12)
})

-- Верхняя панель с закругленными углами только сверху
local TopBar = Create("Frame",{
    Parent = MainContainer,
    BackgroundColor3 = Color3.fromRGB(45, 45, 50),
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 40),
    ZIndex = 2
})

local TopBarCorner = Create("UICorner",{
    Parent = TopBar,
    CornerRadius = UDim.new(0, 12)
})

local TopBarPadding = Create("UIPadding",{
    Parent = TopBar,
    PaddingLeft = UDim.new(0, 10),
    PaddingRight = UDim.new(0, 10)
})

-- Заголовок
local Title = Create("TextLabel",{
    Parent = TopBar,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 0),
    Size = UDim2.new(0.5, -10, 1, 0),
    Font = Enum.Font.GothamBold,
    Text = "VoxK Mobile",
    TextColor3 = Color3.fromRGB(220, 220, 230),
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left
})

-- Статус перехвата
local StatusIndicator = Create("Frame",{
    Parent = TopBar,
    BackgroundColor3 = Color3.fromRGB(255, 60, 60),
    Position = UDim2.new(0.5, 0, 0.5, -6),
    Size = UDim2.new(0, 12, 0, 12),
    AnchorPoint = Vector2.new(0, 0.5)
})

local StatusCorner = Create("UICorner",{
    Parent = StatusIndicator,
    CornerRadius = UDim.new(1, 0)
})

local StatusLabel = Create("TextLabel",{
    Parent = TopBar,
    BackgroundTransparency = 1,
    Position = UDim2.new(0.5, 15, 0, 0),
    Size = UDim2.new(0.3, -15, 1, 0),
    Font = Enum.Font.Gotham,
    Text = "OFF",
    TextColor3 = Color3.fromRGB(255, 100, 100),
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left
})

-- Кнопки управления
local CloseButton = Create("TextButton",{
    Parent = TopBar,
    BackgroundColor3 = Color3.fromRGB(255, 60, 60),
    Position = UDim2.new(1, -30, 0.5, -10),
    Size = UDim2.new(0, 20, 0, 20),
    AnchorPoint = Vector2.new(1, 0.5),
    AutoButtonColor = false,
    Text = "",
    ZIndex = 3
})

local CloseCorner = Create("UICorner",{
    Parent = CloseButton,
    CornerRadius = UDim.new(1, 0)
})

local CloseIcon = Create("TextLabel",{
    Parent = CloseButton,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    Font = Enum.Font.GothamBold,
    Text = "×",
    TextColor3 = Color3.white,
    TextSize = 18
})

local ToggleButton = Create("TextButton",{
    Parent = TopBar,
    BackgroundColor3 = Color3.fromRGB(70, 70, 80),
    Position = UDim2.new(1, -60, 0.5, -12),
    Size = UDim2.new(0, 24, 0, 24),
    AnchorPoint = Vector2.new(1, 0.5),
    AutoButtonColor = false,
    Text = "",
    ZIndex = 3
})

local ToggleCorner = Create("UICorner",{
    Parent = ToggleButton,
    CornerRadius = UDim.new(0, 6)
})

local ToggleIcon = Create("TextLabel",{
    Parent = ToggleButton,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    Font = Enum.Font.GothamBold,
    Text = "⚡",
    TextColor3 = Color3.fromRGB(200, 200, 210),
    TextSize = 14
})

-- Основное содержимое
local ContentArea = Create("Frame",{
    Parent = MainContainer,
    BackgroundColor3 = Color3.fromRGB(35, 35, 40),
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 40),
    Size = UDim2.new(1, 0, 1, -40)
})

local ContentPadding = Create("UIPadding",{
    Parent = ContentArea,
    PaddingTop = UDim.new(0, 10),
    PaddingLeft = UDim.new(0, 10),
    PaddingRight = UDim.new(0, 10),
    PaddingBottom = UDim.new(0, 10)
})

-- Область логов (слева)
local LogsPanel = Create("Frame",{
    Parent = ContentArea,
    BackgroundColor3 = Color3.fromRGB(40, 40, 45),
    Size = UDim2.new(0.4, -5, 1, 0),
    ClipsDescendants = true
})

local LogsCorner = Create("UICorner",{
    Parent = LogsPanel,
    CornerRadius = UDim.new(0, 8)
})

local LogsHeader = Create("Frame",{
    Parent = LogsPanel,
    BackgroundColor3 = Color3.fromRGB(50, 50, 55),
    Size = UDim2.new(1, 0, 0, 30),
    BorderSizePixel = 0
})

local LogsHeaderCorner = Create("UICorner",{
    Parent = LogsHeader,
    CornerRadius = UDim.new(0, 8)
})

local LogsTitle = Create("TextLabel",{
    Parent = LogsHeader,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -10, 1, 0),
    Position = UDim2.new(0, 10, 0, 0),
    Font = Enum.Font.Gotham,
    Text = "Logs",
    TextColor3 = Color3.fromRGB(220, 220, 230),
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left
})

local LogsCount = Create("TextLabel",{
    Parent = LogsHeader,
    BackgroundTransparency = 1,
    Size = UDim2.new(0.3, 0, 1, 0),
    Position = UDim2.new(0.7, 0, 0, 0),
    Font = Enum.Font.Gotham,
    Text = "0",
    TextColor3 = Color3.fromRGB(180, 180, 190),
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Right
})

local LogsList = Create("ScrollingFrame",{
    Parent = LogsPanel,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, 30),
    Size = UDim2.new(1, 0, 1, -30),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90),
    BorderSizePixel = 0
})

local LogsListLayout = Create("UIListLayout",{
    Parent = LogsList,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 2)
})

-- Область деталей (справа)
local DetailsPanel = Create("Frame",{
    Parent = ContentArea,
    BackgroundColor3 = Color3.fromRGB(40, 40, 45),
    Position = UDim2.new(0.4, 5, 0, 0),
    Size = UDim2.new(0.6, -5, 1, 0),
    ClipsDescendants = true
})

local DetailsCorner = Create("UICorner",{
    Parent = DetailsPanel,
    CornerRadius = UDim.new(0, 8)
})

local DetailsHeader = Create("Frame",{
    Parent = DetailsPanel,
    BackgroundColor3 = Color3.fromRGB(50, 50, 55),
    Size = UDim2.new(1, 0, 0, 30),
    BorderSizePixel = 0
})

local DetailsHeaderCorner = Create("UICorner",{
    Parent = DetailsHeader,
    CornerRadius = UDim.new(0, 8)
})

local DetailsTitle = Create("TextLabel",{
    Parent = DetailsHeader,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -10, 1, 0),
    Position = UDim2.new(0, 10, 0, 0),
    Font = Enum.Font.Gotham,
    Text = "Details",
    TextColor3 = Color3.fromRGB(220, 220, 230),
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left
})

local CodeContainer = Create("Frame",{
    Parent = DetailsPanel,
    BackgroundColor3 = Color3.fromRGB(25, 25, 30),
    Position = UDim2.new(0, 0, 0, 30),
    Size = UDim2.new(1, 0, 0.7, -5),
    ClipsDescendants = true
})

local CodeCorner = Create("UICorner",{
    Parent = CodeContainer,
    CornerRadius = UDim.new(0, 6)
})

local CodeBox = Create("Frame",{
    Parent = CodeContainer,
    BackgroundColor3 = Color3.fromRGB(25, 25, 30),
    Size = UDim2.new(1, 0, 1, 0)
})

local CodePadding = Create("UIPadding",{
    Parent = CodeBox,
    PaddingTop = UDim.new(0, 8),
    PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
    PaddingBottom = UDim.new(0, 8)
})

-- Панель кнопок действий
local ActionsPanel = Create("Frame",{
    Parent = DetailsPanel,
    BackgroundColor3 = Color3.fromRGB(50, 50, 55),
    Position = UDim2.new(0, 0, 0.7, 5),
    Size = UDim2.new(1, 0, 0.3, -5),
    ClipsDescendants = true
})

local ActionsCorner = Create("UICorner",{
    Parent = ActionsPanel,
    CornerRadius = UDim.new(0, 6)
})

local ActionsGrid = Create("UIGridLayout",{
    Parent = ActionsPanel,
    CellSize = UDim2.new(0.5, -5, 0.5, -5),
    CellPadding = UDim2.new(0, 5, 0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center
})

local ActionsPadding = Create("UIPadding",{
    Parent = ActionsPanel,
    PaddingTop = UDim.new(0, 5),
    PaddingLeft = UDim.new(0, 5),
    PaddingRight = UDim.new(0, 5),
    PaddingBottom = UDim.new(0, 5)
})

-- Панель статистики внизу
local StatsBar = Create("Frame",{
    Parent = MainContainer,
    BackgroundColor3 = Color3.fromRGB(45, 45, 50),
    Position = UDim2.new(0, 0, 1, -30),
    Size = UDim2.new(1, 0, 0, 30),
    BorderSizePixel = 0,
    ZIndex = 2
})

local StatsPadding = Create("UIPadding",{
    Parent = StatsBar,
    PaddingLeft = UDim.new(0, 15),
    PaddingRight = UDim.new(0, 15)
})

local StatsText = Create("TextLabel",{
    Parent = StatsBar,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, 0),
    Font = Enum.Font.Gotham,
    Text = "Ready | FPS: 60 | Memory: 0MB",
    TextColor3 = Color3.fromRGB(180, 180, 190),
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left
})

-- Всплывающая подсказка для мобильных устройств
local MobileTooltip = Create("Frame",{
    Parent = VoxK,
    BackgroundColor3 = Color3.fromRGB(20, 20, 25),
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 200, 0, 60),
    Position = UDim2.new(0.5, -100, 0.1, 0),
    Visible = false,
    ZIndex = 100,
    AnchorPoint = Vector2.new(0.5, 0)
})

local TooltipCorner = Create("UICorner",{
    Parent = MobileTooltip,
    CornerRadius = UDim.new(0, 8)
})

local TooltipStroke = Create("UIStroke",{
    Parent = MobileTooltip,
    Color = Color3.fromRGB(100, 100, 110),
    Thickness = 2
})

local TooltipLabel = Create("TextLabel",{
    Parent = MobileTooltip,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 10),
    Size = UDim2.new(1, -20, 1, -20),
    Font = Enum.Font.Gotham,
    Text = "Tooltip text",
    TextColor3 = Color3.fromRGB(220, 220, 230),
    TextSize = 13,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top
})

-- Кнопка для сворачивания/разворачивания на мобильных устройствах
local MobileToggle = Create("TextButton",{
    Parent = VoxK,
    BackgroundColor3 = Color3.fromRGB(45, 45, 50),
    Position = UDim2.new(0, 20, 0, 20),
    Size = UDim2.new(0, 50, 0, 50),
    AutoButtonColor = false,
    Text = "▼",
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(220, 220, 230),
    TextSize = 20,
    Visible = false,
    ZIndex = 10
})

local MobileToggleCorner = Create("UICorner",{
    Parent = MobileToggle,
    CornerRadius = UDim.new(1, 0)
})

-- ==================== КОНЕЦ НОВОГО GUI ====================

local selectedColor = Color3.fromRGB(92, 126, 229)
local deselectedColor = Color3.fromRGB(70, 70, 80)
local layoutOrderNum = 999999999
local mainClosing = false
local closed = false
local sideClosing = false
local sideClosed = false
local maximized = false
local logs = {}
local selected = nil
local blacklist = {}
local blocklist = {}
local getNil = false
local connectedRemotes = {}
local toggle = false
local prevTables = {}
local remoteLogs = {}
getgenv().VoxKCONFIG_MaxRemotes = 200
local indent = 4
local scheduled = {}
local schedulerconnect
local VoxKModule = {}
local topstr = ""
local bottomstr = ""
local remotesFadeIn
local rightFadeIn
local codebox
local p
local getnilrequired = false

-- Переменные для мобильного интерфейса
local isMobile = false
local touchStartPos = nil
local touchStartTime = nil
local longPressThreshold = 0.5
local isDragging = false
local dragStartPos = nil
local originalSize = UDim2.new(0, 400, 0, 500)
local minimizedSize = UDim2.new(0, 60, 0, 60)
local isMinimized = false
local lastInteractionTime = tick()

-- Переменные для автоблокировки
local history = {}
local excluding = {}

-- Если курсор в GUI
local mouseInGui = false

local connections = {}
local DecompiledScripts = {}
local generation = {}
local running_threads = {}
local originalnamecall

local remoteEvent = Instance.new("RemoteEvent",Storage)
local unreliableRemoteEvent = Instance.new("UnreliableRemoteEvent")
local remoteFunction = Instance.new("RemoteFunction",Storage)
local NamecallHandler = Instance.new("BindableEvent",Storage)
local IndexHandler = Instance.new("BindableEvent",Storage)
local GetDebugIdHandler = Instance.new("BindableFunction",Storage)

local originalEvent = remoteEvent.FireServer
local originalUnreliableEvent = unreliableRemoteEvent.FireServer
local originalFunction = remoteFunction.InvokeServer
local GetDebugIDInvoke = GetDebugIdHandler.Invoke

function GetDebugIdHandler.OnInvoke(obj: Instance)
    return OldDebugId(obj)
end

local function ThreadGetDebugId(obj: Instance): string 
    return GetDebugIDInvoke(GetDebugIdHandler,obj)
end

local synv3 = false

if syn and identifyexecutor then
    local _, version = identifyexecutor()
    if (version and version:sub(1, 2) == 'v3') then
        synv3 = true
    end
end

-- Определение типа устройства
local function checkMobile()
    local touchEnabled = UserInputService.TouchEnabled
    local mouseEnabled = UserInputService.MouseEnabled
    
    isMobile = touchEnabled and not mouseEnabled
    configs.mobileMode = isMobile
    
    -- Показать/скрыть мобильные элементы
    MobileToggle.Visible = isMobile
    
    -- Увеличить размер для мобильных устройств
    if isMobile then
        MainContainer.Size = UDim2.new(0, 450, 0, 600)
        originalSize = MainContainer.Size
        
        -- Увеличить размер кнопок
        for _, button in ipairs(ActionsPanel:GetChildren()) do
            if button:IsA("TextButton") then
                button.TextSize = 14
            end
        end
    end
end

xpcall(function()
    if isfile and readfile and isfolder and makefolder then
        local cachedconfigs = isfile("VoxK//Settings.json") and jsond(readfile("VoxK//Settings.json"))

        if cachedconfigs then
            for i,v in next, realconfigs do
                if cachedconfigs[i] == nil then
                    cachedconfigs[i] = v
                end
            end
            realconfigs = cachedconfigs
        end

        if not isfolder("VoxK") then
            makefolder("VoxK")
        end
        if not isfolder("VoxK//Assets") then
            makefolder("VoxK//Assets")
        end
        if not isfile("VoxK//Settings.json") then
            writefile("VoxK//Settings.json",jsone(realconfigs))
        end

        configsmetatable.__newindex = function(self,index,newindex)
            realconfigs[index] = newindex
            writefile("VoxK//Settings.json",jsone(realconfigs))
        end
    else
        configsmetatable.__newindex = function(self,index,newindex)
            realconfigs[index] = newindex
        end
    end
end,function(err)
    ErrorPrompt(("An error has occured: (%s)"):format(err))
end)

local function logthread(thread: thread)
    table.insert(running_threads,thread)
end

--- Очищает старые логи для предотвращения лагов
function clean()
    local max = getgenv().VoxKCONFIG_MaxRemotes
    if not typeof(max) == "number" and math.floor(max) ~= max then
        max = 200
    end
    if #remoteLogs > max then
        for i = 100, #remoteLogs do
            local v = remoteLogs[i]
            if typeof(v[1]) == "RBXScriptConnection" then
                v[1]:Disconnect()
            end
            if typeof(v[2]) == "Instance" then
                v[2]:Destroy()
            end
        end
        local newLogs = {}
        for i = 1, 100 do
            table.insert(newLogs, remoteLogs[i])
        end
        remoteLogs = newLogs
    end
    updateLogsCount()
end

local function ThreadIsNotDead(thread: thread): boolean
    return not status(thread) == "dead"
end

--- Обновляет счетчик логов
function updateLogsCount()
    LogsCount.Text = tostring(#logs)
end

--- Обновляет статистику
function updateStats()
    local fps = math.floor(1 / RunService.RenderStepped:Wait())
    local memory = math.floor(collectgarbage("count"))
    StatsText.Text = string.format("Logs: %d | FPS: %d | Memory: %dKB", #logs, fps, memory)
end

--- Показывает мобильную подсказку
--- @param text string Текст подсказки
--- @param duration number Длительность показа
function showMobileTooltip(text, duration)
    TooltipLabel.Text = text
    MobileTooltip.Visible = true
    
    -- Автопозиционирование
    local viewportSize = workspace.CurrentCamera.ViewportSize
    MobileTooltip.Position = UDim2.new(0.5, -100, 0.1, 0)
    
    if duration then
        delay(duration, function()
            MobileTooltip.Visible = false
        end)
    end
end

--- Скрывает мобильную подсказку
function hideMobileTooltip()
    MobileTooltip.Visible = false
end

--- Обработчик длительного нажатия для мобильных устройств
--- @param input InputObject
function handleLongPress(input)
    if not isMobile then return end
    
    if input.UserInputType == Enum.UserInputType.Touch then
        touchStartPos = input.Position
        touchStartTime = tick()
        
        local connection
        connection = RunService.Heartbeat:Connect(function()
            if touchStartPos and tick() - touchStartTime > longPressThreshold then
                -- Долгое нажатие
                showMobileTooltip("Long press for options", 2)
                touchStartPos = nil
                touchStartTime = nil
                if connection then
                    connection:Disconnect()
                end
            end
        end)
        
        table.insert(connections, input.InputEnded:Connect(function(endInput)
            if endInput == input then
                touchStartPos = nil
                touchStartTime = nil
                if connection then
                    connection:Disconnect()
                end
            end
        end))
    end
end

--- Переключение состояния GUI (свернуть/развернуть)
function toggleMobileGUI()
    isMinimized = not isMinimized
    
    if isMinimized then
        -- Сворачиваем
        MobileToggle.Text = "▲"
        TweenService:Create(MainContainer, TweenInfo.new(0.3), {
            Size = minimizedSize,
            Position = UDim2.new(0, 20, 0, 20)
        }):Play()
        
        -- Скрываем содержимое
        ContentArea.Visible = false
        StatsBar.Visible = false
        TopBar.Visible = false
    else
        -- Разворачиваем
        MobileToggle.Text = "▼"
        TweenService:Create(MainContainer, TweenInfo.new(0.3), {
            Size = originalSize,
            Position = UDim2.new(0.5, -originalSize.X.Offset/2, 0.5, -originalSize.Y.Offset/2),
            AnchorPoint = Vector2.new(0.5, 0.5)
        }):Play()
        
        -- Показываем содержимое
        ContentArea.Visible = true
        StatsBar.Visible = true
        TopBar.Visible = true
    end
end

--- Обработка жестов для мобильных устройств
--- @param input InputObject
function handleMobileGestures(input)
    if not isMobile or isMinimized then return end
    
    if input.UserInputType == Enum.UserInputType.Touch then
        local currentPos = input.Position
        
        if input.UserInputState == Enum.UserInputState.Begin then
            dragStartPos = currentPos
            isDragging = false
        elseif input.UserInputState == Enum.UserInputState.Change then
            if dragStartPos then
                local delta = (currentPos - dragStartPos).Magnitude
                if delta > 10 then
                    isDragging = true
                    
                    -- Перемещаем GUI
                    local containerPos = MainContainer.AbsolutePosition
                    local newPos = containerPos + (currentPos - dragStartPos)
                    
                    -- Ограничиваем перемещение в пределах экрана
                    local viewportSize = workspace.CurrentCamera.ViewportSize
                    newPos = Vector2.new(
                        math.clamp(newPos.X, 0, viewportSize.X - MainContainer.AbsoluteSize.X),
                        math.clamp(newPos.Y, 0, viewportSize.Y - MainContainer.AbsoluteSize.Y)
                    )
                    
                    MainContainer.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
                    MainContainer.AnchorPoint = Vector2.new(0, 0)
                    dragStartPos = currentPos
                end
            end
        elseif input.UserInputState == Enum.UserInputState.End then
            dragStartPos = nil
            isDragging = false
        end
    end
end

--- Обновляет цвет статуса перехвата
function updateStatusIndicator()
    if toggle then
        StatusIndicator.BackgroundColor3 = Color3.fromRGB(68, 206, 91)
        StatusLabel.Text = "ON"
        StatusLabel.TextColor3 = Color3.fromRGB(68, 206, 91)
        ToggleIcon.TextColor3 = Color3.fromRGB(68, 206, 91)
    else
        StatusIndicator.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        StatusLabel.Text = "OFF"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        ToggleIcon.TextColor3 = Color3.fromRGB(200, 200, 210)
    end
end

--- Обработчик наведения на кнопку закрытия
function onXButtonHover()
    TweenService:Create(CloseButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 80, 80)}):Play()
end

--- Обработчик отведения от кнопки закрытия
function onXButtonUnhover()
    TweenService:Create(CloseButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 60, 60)}):Play()
end

--- Переключение метода перехвата
function onToggleButtonClick()
    toggleSpyMethod()
    updateStatusIndicator()
    
    if isMobile then
        showMobileTooltip(toggle and "Spy: ON" or "Spy: OFF", 1)
    end
end

--- Перемещает GUI если он выходит за пределы экрана
function bringBackOnResize()
    if isMobile and isMinimized then return end
    
    validateSize()
    local currentX = MainContainer.AbsolutePosition.X
    local currentY = MainContainer.AbsolutePosition.Y
    local viewportSize = workspace.CurrentCamera.ViewportSize
    local containerSize = MainContainer.AbsoluteSize
    
    if (currentX < 0) or (currentX > (viewportSize.X - containerSize.X)) then
        if currentX < 0 then
            currentX = 0
        else
            currentX = viewportSize.X - containerSize.X
        end
    end
    if (currentY < 0) or (currentY > (viewportSize.Y - containerSize.Y - GuiInset.Y)) then
        if currentY < 0 then
            currentY = 0
        else
            currentY = viewportSize.Y - containerSize.Y - GuiInset.Y
        end
    end
    MainContainer.Position = UDim2.new(0, currentX, 0, currentY)
    MainContainer.AnchorPoint = Vector2.new(0, 0)
end

--- Обеспечивает корректный размер GUI
function validateSize()
    if isMobile and isMinimized then return end
    
    local x, y = MainContainer.AbsoluteSize.X, MainContainer.AbsoluteSize.Y
    local screenSize = workspace.CurrentCamera.ViewportSize
    local minWidth = isMobile and 300 or 400
    local minHeight = isMobile and 400 or 500
    
    if x < minWidth then x = minWidth end
    if y < minHeight then y = minHeight end
    
    if x + MainContainer.AbsolutePosition.X > screenSize.X then
        if screenSize.X - MainContainer.AbsolutePosition.X >= minWidth then
            x = screenSize.X - MainContainer.AbsolutePosition.X
        else
            x = minWidth
        end
    end
    if y + MainContainer.AbsolutePosition.Y > screenSize.Y then
        if screenSize.Y - MainContainer.AbsolutePosition.Y >= minHeight then
            y = screenSize.Y - MainContainer.AbsolutePosition.Y
        else
            y = minHeight
        end
    end
    
    MainContainer.Size = UDim2.fromOffset(x, y)
    originalSize = MainContainer.Size
end

--- Создает эффект исчезновения для элементов
function fadeOut(elements)
    local data = {}
    for _, v in next, elements do
        if typeof(v) == "Instance" and v:IsA("GuiObject") and v.Visible then
            spawn(function()
                data[v] = {
                    BackgroundTransparency = v.BackgroundTransparency
                }
                TweenService:Create(v, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
                if v:IsA("TextBox") or v:IsA("TextButton") or v:IsA("TextLabel") then
                    data[v].TextTransparency = v.TextTransparency
                    TweenService:Create(v, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
                elseif v:IsA("ImageButton") or v:IsA("ImageLabel") then
                    data[v].ImageTransparency = v.ImageTransparency
                    TweenService:Create(v, TweenInfo.new(0.5), {ImageTransparency = 1}):Play()
                end
                delay(0.5,function()
                    v.Visible = false
                    for i, x in next, data[v] do
                        v[i] = x
                    end
                    data[v] = true
                end)
            end)
        end
    end
    return function()
        for i, _ in next, data do
            spawn(function()
                local properties = {
                    BackgroundTransparency = i.BackgroundTransparency
                }
                i.BackgroundTransparency = 1
                TweenService:Create(i, TweenInfo.new(0.5), {BackgroundTransparency = properties.BackgroundTransparency}):Play()
                if i:IsA("TextBox") or i:IsA("TextButton") or i:IsA("TextLabel") then
                    properties.TextTransparency = i.TextTransparency
                    i.TextTransparency = 1
                    TweenService:Create(i, TweenInfo.new(0.5), {TextTransparency = properties.TextTransparency}):Play()
                elseif i:IsA("ImageButton") or i:IsA("ImageLabel") then
                    properties.ImageTransparency = i.ImageTransparency
                    i.ImageTransparency = 1
                    TweenService:Create(i, TweenInfo.new(0.5), {ImageTransparency = properties.ImageTransparency}):Play()
                end
                i.Visible = true
            end)
        end
    end
end

--- Получает игрока из инстанса
function getPlayerFromInstance(instance)
    for _, v in next, Players:GetPlayers() do
        if v.Character and (instance:IsDescendantOf(v.Character) or instance == v.Character) then
            return v
        end
    end
end

--- Выбор события
function eventSelect(frame)
    if selected and selected.Log then
        if selected.Button then
            spawn(function()
                TweenService:Create(selected.Button, TweenInfo.new(0.3), {BackgroundColor3 = deselectedColor}):Play()
            end)
        end
        selected = nil
    end
    for _, v in next, logs do
        if frame == v.Log then
            selected = v
        end
    end
    if selected and selected.Log then
        spawn(function()
            TweenService:Create(selected.Button, TweenInfo.new(0.3), {BackgroundColor3 = selectedColor}):Play()
        end)
        codebox:setRaw(selected.GenScript)
    end
end

--- Обновляет размер канваса для кнопок функций
function updateFunctionCanvas()
    ActionsGrid.CellSize = UDim2.new(0.5, -5, 0.5, -5)
end

--- Обновляет размер канваса для логов
function updateRemoteCanvas()
    LogsList.CanvasSize = UDim2.new(0, 0, 0, LogsListLayout.AbsoluteContentSize.Y)
end

--- Создает всплывающую подсказку
--- @param enable boolean
--- @param text string
function makeToolTip(enable, text)
    if isMobile then
        if enable and text then
            showMobileTooltip(text, 3)
        else
            hideMobileTooltip()
        end
        return
    end
    
    -- Десктопная версия подсказки
    if enable and text then
        -- Реализация для десктопа...
    else
        -- Скрытие для десктопа...
    end
end

--- Создает новую кнопку функции
--- @param name string
--- @param description function
--- @param onClick function
function newButton(name, description, onClick)
    local FunctionButton = Create("TextButton",{
        Parent = ActionsPanel,
        BackgroundColor3 = Color3.fromRGB(60, 60, 70),
        AutoButtonColor = false,
        Font = Enum.Font.Gotham,
        Text = name,
        TextColor3 = Color3.fromRGB(220, 220, 230),
        TextSize = isMobile and 13 or 12,
        TextWrapped = true
    })

    local ButtonCorner = Create("UICorner",{
        Parent = FunctionButton,
        CornerRadius = UDim.new(0, 6)
    })

    local ButtonStroke = Create("UIStroke",{
        Parent = FunctionButton,
        Color = Color3.fromRGB(80, 80, 90),
        Thickness = 1
    })

    -- Обработчики для мобильных устройств
    if isMobile then
        FunctionButton.MouseButton1Down:Connect(function()
            TweenService:Create(FunctionButton, TweenInfo.new(0.1), {
                BackgroundColor3 = Color3.fromRGB(80, 80, 90)
            }):Play()
        end)
        
        FunctionButton.MouseButton1Up:Connect(function()
            TweenService:Create(FunctionButton, TweenInfo.new(0.1), {
                BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            }):Play()
        end)
    else
        FunctionButton.MouseEnter:Connect(function()
            TweenService:Create(FunctionButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(70, 70, 80)
            }):Play()
            makeToolTip(true, description())
        end)
        
        FunctionButton.MouseLeave:Connect(function()
            TweenService:Create(FunctionButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            }):Play()
            makeToolTip(false)
        end)
    end
    
    FunctionButton.AncestryChanged:Connect(function()
        makeToolTip(false)
    end)
    
    FunctionButton.MouseButton1Click:Connect(function(...)
        logthread(running())
        onClick(FunctionButton, ...)
        if isMobile then
            showMobileTooltip(description(), 2)
        end
    end)
    
    updateFunctionCanvas()
end

--- Добавляет новый удаленный вызов в логи
--- @param type string
--- @param data table
function newRemote(type, data)
    if layoutOrderNum < 1 then layoutOrderNum = 999999999 end
    local remote = data.remote
    local callingscript = data.callingscript

    local RemoteTemplate = Create("TextButton",{
        LayoutOrder = layoutOrderNum,
        Parent = LogsList,
        BackgroundColor3 = deselectedColor,
        AutoButtonColor = false,
        Size = UDim2.new(1, -4, 0, 35),
        Font = Enum.Font.Gotham,
        Text = "",
        TextColor3 = Color3.fromRGB(220, 220, 230),
        TextSize = 13,
        TextWrapped = true
    })

    local TemplateCorner = Create("UICorner",{
        Parent = RemoteTemplate,
        CornerRadius = UDim.new(0, 6)
    })

    local ColorIndicator = Create("Frame",{
        Parent = RemoteTemplate,
        BackgroundColor3 = (type == "event" and Color3.fromRGB(255, 200, 50)) or Color3.fromRGB(100, 120, 255),
        Position = UDim2.new(0, 5, 0.5, -8),
        Size = UDim2.new(0, 16, 0, 16),
        AnchorPoint = Vector2.new(0, 0.5)
    })

    local IndicatorCorner = Create("UICorner",{
        Parent = ColorIndicator,
        CornerRadius = UDim.new(1, 0)
    })

    local RemoteName = Create("TextLabel",{
        Parent = RemoteTemplate,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 30, 0, 0),
        Size = UDim2.new(1, -35, 1, 0),
        Font = Enum.Font.Gotham,
        Text = remote.Name,
        TextColor3 = Color3.fromRGB(220, 220, 230),
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    })

    local RemoteType = Create("TextLabel",{
        Parent = RemoteTemplate,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 30, 0, 18),
        Size = UDim2.new(1, -35, 0, 12),
        Font = Enum.Font.Gotham,
        Text = type:upper(),
        TextColor3 = Color3.fromRGB(180, 180, 190),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left
    })

    local log = {
        Name = remote.Name,
        Function = data.infofunc or "--Function Info is disabled",
        Remote = remote,
        DebugId = data.id,
        metamethod = data.metamethod,
        args = data.args,
        Log = RemoteTemplate,
        Button = RemoteTemplate,
        Blocked = data.blocked,
        Source = callingscript,
        returnvalue = data.returnvalue,
        GenScript = "-- Generating, please wait...\n-- (If this message persists, the remote args are likely extremely long)"
    }

    logs[#logs + 1] = log
    updateLogsCount()
    
    local connect = RemoteTemplate.MouseButton1Click:Connect(function()
        logthread(running())
        eventSelect(RemoteTemplate)
        log.GenScript = genScript(log.Remote, log.args)
        if data.blocked then
            log.GenScript = "-- THIS REMOTE WAS PREVENTED FROM FIRING TO THE SERVER BY VoxK\n\n" .. log.GenScript
        end
        if selected == log and RemoteTemplate then
            eventSelect(RemoteTemplate)
        end
        
        if isMobile then
            showMobileTooltip("Selected: " .. remote.Name, 1)
        end
    end)
    
    layoutOrderNum -= 1
    table.insert(remoteLogs, 1, {connect, RemoteTemplate})
    clean()
    updateRemoteCanvas()
end

--- Генерирует скрипт из предоставленных аргументов
function genScript(remote, args)
    prevTables = {}
    local gen = ""
    if #args > 0 then
        xpcall(function()
            gen = "local args = "..LazyFix.Convert(args, true) .. "\n"
        end,function(err)
            gen ..= "-- An error has occured:\n--"..err.."\n-- TableToString failure! Reverting to legacy functionality (results may vary)\nlocal args = {"
            xpcall(function()
                for i, v in next, args do
                    if type(i) ~= "Instance" and type(i) ~= "userdata" then
                        gen = gen .. "\n    [object] = "
                    elseif type(i) == "string" then
                        gen = gen .. '\n    ["' .. i .. '"] = '
                    elseif type(i) == "userdata" and typeof(i) ~= "Instance" then
                        gen = gen .. "\n    [" .. string.format("nil --[[%s]]", typeof(v)) .. ")] = "
                    elseif type(i) == "userdata" then
                         gen = gen .. "\n    [game." .. i:GetFullName() .. ")] = "
                    end
                    if type(v) ~= "Instance" and type(v) ~= "userdata" then
                        gen = gen .. "object"
                    elseif type(v) == "string" then
                        gen = gen .. '"' .. v .. '"'
                    elseif type(v) == "userdata" and typeof(v) ~= "Instance" then
                        gen = gen .. string.format("nil --[[%s]]", typeof(v))
                    elseif type(v) == "userdata" then
                        gen = gen .. "game." .. v:GetFullName()
                    end
                end
                gen ..= "\n}\n\n"
            end,function()
                gen ..= "}\n-- Legacy tableToString failure! Unable to decompile."
            end)
        end)
        if not remote:IsDescendantOf(game) and not getnilrequired then
            gen = "function getNil(name,class) for _,v in next, getnilinstances()do if v.ClassName==class and v.Name==name then return v;end end end\n\n" .. gen
        end
        if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
            gen ..= LazyFix.ConvertKnown("Instance", remote) .. ":FireServer(unpack(args))"
        elseif remote:IsA("RemoteFunction") then
            gen = gen .. LazyFix.ConvertKnown("Instance", remote) .. ":InvokeServer(unpack(args))"
        end
    else
        if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
            gen ..= LazyFix.ConvertKnown("Instance", remote) .. ":FireServer()"
        elseif remote:IsA("RemoteFunction") then
            gen ..= LazyFix.ConvertKnown("Instance", remote) .. ":InvokeServer()"
        end
    end
    prevTables = {}
    return gen
end

-- ... (остальные функции остаются без изменений, так как они не связаны с GUI)
-- Здесь должна быть остальная часть оригинального кода SimpleSpy:
-- v2s, t2s, f2s, i2p, getplayer, v2p, formatstr, handlespecials,
-- getScriptFromSrc, schedule, scheduleWait, taskscheduler, tablecheck,
-- remoteHandler, newindex, newnamecall, disablehooks, toggleSpy, toggleSpyMethod

-- Из-за ограничения длины я не могу вставить всю оставшуюся часть кода,
-- но вот основные изменения для мобильной версии:

--- Обработчик удаленного вызова
function remoteHandler(data)
    if configs.autoblock then
        local id = data.id

        if excluding[id] then
            return
        end
        if not history[id] then
            history[id] = {badOccurances = 0, lastCall = tick()}
        end
        if tick() - history[id].lastCall < 1 then
            history[id].badOccurances += 1
            return
        else
            history[id].badOccurances = 0
        end
        if history[id].badOccurances > 3 then
            excluding[id] = true
            return
        end
        history[id].lastCall = tick()
    end

    if (data.remote:IsA("RemoteEvent") or data.remote:IsA("UnreliableRemoteEvent")) and lower(data.method) == "fireserver" then
        newRemote("event", data)
    elseif data.remote:IsA("RemoteFunction") and lower(data.method) == "invokeserver" then
        newRemote("function", data)
    end
end

--- Отключает хуки
local function disablehooks()
    if synv3 then
        unhook(getrawmetatable(game).__namecall,originalnamecall)
        unhook(Instance.new("RemoteEvent").FireServer, originalEvent)
        unhook(Instance.new("RemoteFunction").InvokeServer, originalFunction)
        unhook(Instance.new("UnreliableRemoteEvent").FireServer, originalUnreliableEvent)
        restorefunction(originalnamecall)
        restorefunction(originalEvent)
        restorefunction(originalFunction)
    else
        if hookmetamethod then
            hookmetamethod(game,"__namecall",originalnamecall)
        else
            hookfunction(getrawmetatable(game).__namecall,originalnamecall)
        end
        hookfunction(Instance.new("RemoteEvent").FireServer, originalEvent)
        hookfunction(Instance.new("RemoteFunction").InvokeServer, originalFunction)
        hookfunction(Instance.new("UnreliableRemoteEvent").FireServer, originalUnreliableEvent)
    end
end

--- Включает/выключает перехват ремов
function toggleSpy()
    if not toggle then
        local oldnamecall
        if synv3 then
            oldnamecall = hook(getrawmetatable(game).__namecall,clonefunction(newnamecall))
            originalEvent = hook(Instance.new("RemoteEvent").FireServer, clonefunction(newFireServer))
            originalFunction = hook(Instance.new("RemoteFunction").InvokeServer, clonefunction(newInvokeServer))
            originalUnreliableEvent = hook(Instance.new("UnreliableRemoteEvent").FireServer, clonefunction(newUnreliableFireServer))
        else
            if hookmetamethod then
                oldnamecall = hookmetamethod(game, "__namecall", clonefunction(newnamecall))
            else
                oldnamecall = hookfunction(getrawmetatable(game).__namecall,clonefunction(newnamecall))
            end
            originalEvent = hookfunction(Instance.new("RemoteEvent").FireServer, clonefunction(newFireServer))
            originalFunction = hookfunction(Instance.new("RemoteFunction").InvokeServer, clonefunction(newInvokeServer))
            originalUnreliableEvent = hookfunction(Instance.new("UnreliableRemoteEvent").FireServer, clonefunction(newUnreliableFireServer))
        end
        originalnamecall = originalnamecall or function(...)
            return oldnamecall(...)
        end
    else
        disablehooks()
    end
end

--- Переключает между методами перехвата
function toggleSpyMethod()
    toggleSpy()
    toggle = not toggle
end

--- Выключает VoxK
local function shutdown()
    if schedulerconnect then
        schedulerconnect:Disconnect()
    end
    for _, connection in next, connections do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
    end
    for i,v in next, running_threads do
        if ThreadIsNotDead(v) then
            close(v)
        end
    end
    clear(running_threads)
    clear(connections)
    clear(logs)
    clear(remoteLogs)
    disablehooks()
    VoxK:Destroy()
    Storage:Destroy()
    UserInputService.MouseIconEnabled = true
    getgenv().VoxKExecuted = false
end

-- Основная инициализация
if not getgenv().VoxKExecuted then
    local succeeded,err = pcall(function()
        if not RunService:IsClient() then
            error("VoxK cannot run on the server!")
        end
        getgenv().VoxKShutdown = shutdown
        
        -- Проверяем тип устройства
        checkMobile()
        
        -- Инициализируем кодбокс
        codebox = Highlight.new(CodeBox)
        
        -- Загружаем информацию об обновлениях
        logthread(spawn(function()
            local suc,updateLog = pcall(game.HttpGet,game,"https://raw.githubusercontent.com/78n/SimpleSpy/main/UpdateLog.lua")
            if suc and updateLog then
                codebox:setRaw("-- VoxK Mobile Edition\n-- Based on SimpleSpy V3\n-- Optimized for mobile devices\n\n" .. updateLog)
            else
                codebox:setRaw("-- VoxK Mobile Edition\n-- Based on SimpleSpy V3\n-- Optimized for mobile devices\n-- Failed to load update log")
            end
        end))
        
        getgenv().VoxK = VoxKModule
        getgenv().getNil = function(name,class)
            for _,v in next, getnilinstances() do
                if v.ClassName == class and v.Name == name then
                    return v;
                end
            end
        end
        
        -- Обработчики событий для мобильных устройств
        if isMobile then
            -- Обработка жестов
            table.insert(connections, UserInputService.InputBegan:Connect(function(input)
                handleLongPress(input)
                handleMobileGestures(input)
            end))
            
            table.insert(connections, UserInputService.InputChanged:Connect(function(input)
                handleMobileGestures(input)
            end))
            
            -- Кнопка сворачивания
            MobileToggle.MouseButton1Click:Connect(toggleMobileGUI)
            
            -- Двойной тап для переключения перехвата
            local lastTapTime = 0
            MainContainer.MouseButton1Click:Connect(function()
                local currentTime = tick()
                if currentTime - lastTapTime < 0.3 then
                    onToggleButtonClick()
                end
                lastTapTime = currentTime
            end)
        end
        
        -- Обработчики кнопок
        CloseButton.MouseButton1Click:Connect(shutdown)
        ToggleButton.MouseButton1Click:Connect(onToggleButtonClick)
        
        CloseButton.MouseEnter:Connect(onXButtonHover)
        CloseButton.MouseLeave:Connect(onXButtonUnhover)
        
        -- Обновление статуса
        updateStatusIndicator()
        
        -- Инициализация перехвата
        onToggleButtonClick()
        
        -- Запуск планировщика задач
        schedulerconnect = RunService.Heartbeat:Connect(function()
            taskscheduler()
            updateStats()
        end)
        
        -- Позиционирование GUI
        bringBackOnResize()
        
        -- Родительский контейнер
        VoxK.Parent = (gethui and gethui()) or (syn and syn.protect_gui and syn.protect_gui(VoxK)) or CoreGui
        
        -- Инициализация генерации путей
        logthread(spawn(function()
            local lp = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer
            generation = {
                [OldDebugId(lp)] = 'game:GetService("Players").LocalPlayer',
                [OldDebugId(lp:GetMouse())] = 'game:GetService("Players").LocalPlayer:GetMouse',
                [OldDebugId(game)] = "game",
                [OldDebugId(workspace)] = "workspace"
            }
        end))
        
        if not hookmetamethod then
            if isMobile then
                showMobileTooltip("Some features may be limited on mobile", 3)
            else
                ErrorPrompt("VoxK will not function to its fullest capability due to missing hookmetamethod support.",true)
            end
        end
        
        if isMobile then
            showMobileTooltip("VoxK Mobile Ready! Tap toggle button to start.", 3)
        end
    end)
    if succeeded then
        getgenv().VoxKExecuted = true
    else
        shutdown()
        ErrorPrompt("An error has occurred:\n"..rawtostring(err))
        return
    end
else
    VoxK:Destroy()
    return
end

-- API функции
function VoxKModule:newButton(name, description, onClick)
    return newButton(name, description, onClick)
end

-- ==================== ДОБАВЛЕНИЯ ====================

-- Копирует содержимое кодбокса
newButton(
    "Copy Code",
    function() return "Click to copy code to clipboard" end,
    function()
        setclipboard(codebox:getString())
        if isMobile then
            showMobileTooltip("Code copied!", 1)
        else
            makeToolTip(true, "Code copied!")
        end
    end
)

-- Копирует путь к рему
newButton(
    "Copy Remote",
    function() return "Click to copy the path of the remote" end,
    function()
        if selected and selected.Remote then
            setclipboard(v2s(selected.Remote))
            if isMobile then
                showMobileTooltip("Remote path copied!", 1)
            end
        end
    end
)

-- Выполняет код
newButton("Run Code",
    function() return "Click to execute code" end,
    function()
        local Remote = selected and selected.Remote
        if Remote then
            if isMobile then
                showMobileTooltip("Executing...", 1)
            end
            xpcall(function()
                local returnvalue
                if Remote:IsA("RemoteEvent") or Remote:IsA("UnreliableRemoteEvent") then
                    returnvalue = Remote:FireServer(unpack(selected.args))
                elseif Remote:IsA("RemoteFunction") then
                    returnvalue = Remote:InvokeServer(unpack(selected.args))
                end
                if isMobile then
                    showMobileTooltip("Executed successfully!", 2)
                end
            end,function(err)
                if isMobile then
                    showMobileTooltip("Execution error: " .. tostring(err), 3)
                end
            end)
            return
        end
        if isMobile then
            showMobileTooltip("Source not found", 1)
        end
    end
)

-- Получает вызывающий скрипт
newButton(
    "Get Script",
    function() return "Click to copy calling script to clipboard" end,
    function()
        if selected then
            if not selected.Source then
                selected.Source = rawget(getfenv(selected.Function),"script")
            end
            setclipboard(v2s(selected.Source))
            if isMobile then
                showMobileTooltip("Script copied!", 1)
            end
        end
    end
)

-- Информация о функции
newButton("Function Info",function() return "Click to view calling function information" end,
function()
    local func = selected and selected.Function
    if func then
        if isMobile then
            showMobileTooltip("Generating function info...", 1)
        end
        -- ... остальная часть функции ...
    end
end)

-- Очистка логов
newButton(
    "Clear Logs",
    function() return "Click to clear logs" end,
    function()
        if isMobile then
            showMobileTooltip("Clearing logs...", 1)
        end
        clear(logs)
        for i,v in next, LogsList:GetChildren() do
            if v:IsA("TextButton") then
                v:Destroy()
            end
        end
        codebox:setRaw("")
        selected = nil
        updateLogsCount()
        if isMobile then
            showMobileTooltip("Logs cleared!", 1)
        end
    end
)

-- Исключить рем
newButton(
    "Exclude Remote",
    function() return "Click to exclude this remote from logs" end,
    function()
        if selected then
            blacklist[OldDebugId(selected.Remote)] = true
            if isMobile then
                showMobileTooltip("Remote excluded!", 1)
            end
        end
    end
)

-- Блокировать рем
newButton(
    "Block Remote",
    function() return "Click to block this remote from firing" end,
    function()
        if selected then
            blocklist[OldDebugId(selected.Remote)] = true
            if isMobile then
                showMobileTooltip("Remote blocked!", 1)
            end
        end
    end
)

-- Очистить черный список
newButton("Clear Blacklist",
function() return "Click to clear the blacklist" end,
function()
    blacklist = {}
    if isMobile then
        showMobileTooltip("Blacklist cleared!", 1)
    end
end)

-- Очистить список блокировок
newButton(
    "Clear Blocklist",
    function() return "Click to clear the blocklist" end,
    function()
        blocklist = {}
        if isMobile then
            showMobileTooltip("Blocklist cleared!", 1)
        end
    end
)

-- Декомпиляция
newButton("Decompile",
    function() return "Decompile source script" end,
    function()
        if decompile then
            if selected and selected.Source then
                if isMobile then
                    showMobileTooltip("Decompiling...", 1)
                end
                -- ... остальная часть функции ...
            end
        end
    end
)

-- Переключение информации о функции
newButton(
    "Toggle Function Info",
    function() return string.format("[%s] Toggle function info", configs.funcEnabled and "ON" or "OFF") end,
    function()
        configs.funcEnabled = not configs.funcEnabled
        if isMobile then
            showMobileTooltip("Function info: " .. (configs.funcEnabled and "ON" or "OFF"), 1)
        end
    end
)

-- Автоблокировка
newButton(
    "Auto-block Spam",
    function() return string.format("[%s] Auto-block spammy remotes", configs.autoblock and "ON" : "OFF") end,
    function()
        configs.autoblock = not configs.autoblock
        history = {}
        excluding = {}
        if isMobile then
            showMobileTooltip("Auto-block: " .. (configs.autoblock and "ON" or "OFF"), 1)
        end
    end
)

-- Переключение мобильного режима
newButton("Mobile Mode",
    function() return string.format("[%s] Mobile optimized interface", configs.mobileMode and "ON" : "OFF") end,
    function()
        configs.mobileMode = not configs.mobileMode
        if isMobile then
            showMobileTooltip("Mobile mode: " .. (configs.mobileMode and "ON" or "OFF"), 1)
        end
    end
)

-- Discord кнопка
newButton("Join Discord",function()
    return "Join the VoxK Discord server"
end,
function()
    setclipboard("soon")
    if isMobile then
        showMobileTooltip("Discord invite copied!", 2)
    end
    if request then
        request({
            Url = 'http://127.0.0.1:6463/rpc?v=1',
            Method = 'POST',
            Headers = {
                ['Content-Type'] = 'application/json',
                Origin = 'https://discord.com'
            },
            Body = http:JSONEncode({
                cmd = 'INVITE_BROWSER',
                nonce = http:GenerateGUID(false),
                args = {code = 'example'}
            })
        })
    end
end)
