--!native
--50/50 this breaks but it's a beta for a reason!

if getgenv().SimpleSpyExecuted and type(getgenv().SimpleSpyShutdown) == "function" then
    getgenv().SimpleSpyShutdown()
end

local realconfigs = {
    logcheckcaller = false,
    autoblock = false,
    funcEnabled = true,
    advancedinfo = false,
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
        
        for i,v in next, tbl do -- Stupid mistake on my part thanks 59it for pointing it out
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
        prompt:setErrorTitle("Simple Spy V3 Error")
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

-- ===========================================
-- МИНИМАЛИСТИЧНЫЙ НОВОГОДНИЙ GUI
-- ===========================================
local SimpleSpy3 = Create("ScreenGui",{
    ResetOnSpawn = false,
    DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Global
})

local Storage = Create("Folder",{})

-- Главный контейнер
local MainContainer = Create("Frame",{
    Parent = SimpleSpy3,
    BackgroundColor3 = Color3.fromRGB(10, 10, 10),
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,
    Position = UDim2.new(0.5, -200, 0.5, -150),
    Size = UDim2.new(0, 400, 0, 300),
    AnchorPoint = Vector2.new(0.5, 0.5),
    ClipsDescendants = true
})

-- Новогоднее свечение
local HolidayGlow = Create("Frame",{
    Parent = MainContainer,
    BackgroundColor3 = Color3.fromRGB(200, 30, 30),
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 0.95,
    ZIndex = 0
})

-- Минималистичный заголовок
local Header = Create("Frame",{
    Parent = MainContainer,
    BackgroundColor3 = Color3.fromRGB(15, 15, 15),
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 36),
    ZIndex = 2
})

-- Акцентная линия
local AccentLine = Create("Frame",{
    Parent = Header,
    BackgroundColor3 = Color3.fromRGB(255, 60, 60),
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 2),
    Position = UDim2.new(0, 0, 1, 0)
})

-- Логотип
local Logo = Create("TextLabel",{
    Parent = Header,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 0),
    Size = UDim2.new(0, 120, 1, 0),
    Font = Enum.Font.GothamBold,
    Text = "❄️ SIMPLE SPY",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left
})

-- Статус
local StatusIndicator = Create("Frame",{
    Parent = Header,
    BackgroundColor3 = Color3.fromRGB(255, 60, 60),
    BorderSizePixel = 0,
    Position = UDim2.new(1, -80, 0.5, -6),
    Size = UDim2.new(0, 12, 0, 12),
    ZIndex = 3
})

local StatusLabel = Create("TextLabel",{
    Parent = Header,
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -64, 0, 0),
    Size = UDim2.new(0, 50, 1, 0),
    Font = Enum.Font.GothamMedium,
    Text = "OFF",
    TextColor3 = Color3.fromRGB(255, 60, 60),
    TextSize = 14
})

-- Минималистичные кнопки управления
local CloseButton = Create("TextButton",{
    Parent = Header,
    BackgroundColor3 = Color3.fromRGB(20, 20, 20),
    BorderSizePixel = 0,
    Position = UDim2.new(1, -32, 0.5, -10),
    Size = UDim2.new(0, 20, 0, 20),
    Font = Enum.Font.GothamMedium,
    Text = "×",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 18,
    ZIndex = 3
})

local ToggleButton = Create("TextButton",{
    Parent = Header,
    BackgroundColor3 = Color3.fromRGB(20, 20, 20),
    BorderSizePixel = 0,
    Position = UDim2.new(1, -58, 0.5, -10),
    Size = UDim2.new(0, 20, 0, 20),
    Font = Enum.Font.GothamMedium,
    Text = "▶",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 14,
    ZIndex = 3
})

-- Основное содержимое
local ContentArea = Create("Frame",{
    Parent = MainContainer,
    BackgroundColor3 = Color3.fromRGB(18, 18, 18),
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 36),
    Size = UDim2.new(1, 0, 1, -36)
})

-- Панель логов
local LogsPanel = Create("ScrollingFrame",{
    Parent = ContentArea,
    Active = true,
    BackgroundColor3 = Color3.fromRGB(15, 15, 15),
    BorderSizePixel = 0,
    Size = UDim2.new(0.4, -1, 1, 0),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(255, 60, 60),
    ClipsDescendants = true
})

local LogsLayout = Create("UIListLayout",{
    Parent = LogsPanel,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim2.new(0, 0, 0, 1)
})

-- Правая панель
local RightPanel = Create("Frame",{
    Parent = ContentArea,
    BackgroundColor3 = Color3.fromRGB(20, 20, 20),
    BorderSizePixel = 0,
    Position = UDim2.new(0.4, 0, 0, 0),
    Size = UDim2.new(0.6, 0, 1, 0)
})

-- Кодовая панель
local CodePanel = Create("Frame",{
    Parent = RightPanel,
    BackgroundColor3 = Color3.fromRGB(12, 12, 12),
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0.7, 0)
})

local CodeBox = Create("Frame",{
    Parent = CodePanel,
    BackgroundColor3 = Color3.fromRGB(8, 8, 8),
    BorderSizePixel = 0,
    Position = UDim2.new(0, 8, 0, 8),
    Size = UDim2.new(1, -16, 1, -16)
})

-- Панель инструментов
local ToolsPanel = Create("ScrollingFrame",{
    Parent = RightPanel,
    Active = true,
    BackgroundColor3 = Color3.fromRGB(15, 15, 15),
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0.7, 0),
    Size = UDim2.new(1, 0, 0.3, 0),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(255, 60, 60)
})

local ToolsGrid = Create("UIGridLayout",{
    Parent = ToolsPanel,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    CellPadding = UDim2.new(0, 4, 0, 4),
    CellSize = UDim2.new(0.33, -8, 0, 30),
    StartCorner = Enum.StartCorner.TopLeft
})

-- Минималистичная подсказка
local ToolTip = Create("Frame",{
    Parent = SimpleSpy3,
    BackgroundColor3 = Color3.fromRGB(20, 20, 20),
    BorderSizePixel = 1,
    BorderColor3 = Color3.fromRGB(255, 60, 60),
    Size = UDim2.new(0, 200, 0, 40),
    ZIndex = 100,
    Visible = false,
    AnchorPoint = Vector2.new(0, 1)
})

local ToolTipLabel = Create("TextLabel",{
    Parent = ToolTip,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 6, 0, 6),
    Size = UDim2.new(1, -12, 1, -12),
    Font = Enum.Font.Gotham,
    Text = "",
    TextColor3 = Color3.fromRGB(240, 240, 240),
    TextSize = 12,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top
})

-- Разделитель
local Divider = Create("Frame",{
    Parent = ContentArea,
    BackgroundColor3 = Color3.fromRGB(40, 40, 40),
    BorderSizePixel = 0,
    Position = UDim2.new(0.4, 0, 0, 0),
    Size = UDim2.new(0, 1, 1, 0)
})

-------------------------------------------------------------------------------

local selectedColor = Color3.fromRGB(255, 60, 60)
local deselectedColor = Color3.fromRGB(40, 40, 40)
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
getgenv().SIMPLESPYCONFIG_MaxRemotes = 300
local indent = 4
local scheduled = {}
local schedulerconnect
local SimpleSpy = {}
local topstr = ""
local bottomstr = ""
local remotesFadeIn
local rightFadeIn
local codebox
local p
local getnilrequired = false

local history = {}
local excluding = {}
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

xpcall(function()
    if isfile and readfile and isfolder and makefolder then
        local cachedconfigs = isfile("SimpleSpy//Settings.json") and jsond(readfile("SimpleSpy//Settings.json"))

        if cachedconfigs then
            for i,v in next, realconfigs do
                if cachedconfigs[i] == nil then
                    cachedconfigs[i] = v
                end
            end
            realconfigs = cachedconfigs
        end

        if not isfolder("SimpleSpy") then
            makefolder("SimpleSpy")
        end
        if not isfolder("SimpleSpy//Assets") then
            makefolder("SimpleSpy//Assets")
        end
        if not isfile("SimpleSpy//Settings.json") then
            writefile("SimpleSpy//Settings.json",jsone(realconfigs))
        end

        configsmetatable.__newindex = function(self,index,newindex)
            realconfigs[index] = newindex
            writefile("SimpleSpy//Settings.json",jsone(realconfigs))
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

function clean()
    local max = getgenv().SIMPLESPYCONFIG_MaxRemotes
    if not typeof(max) == "number" and math.floor(max) ~= max then
        max = 500
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
end

local function ThreadIsNotDead(thread: thread): boolean
    return not status(thread) == "dead"
end

function scaleToolTip()
    local size = TextService:GetTextSize(ToolTipLabel.Text, ToolTipLabel.TextSize, ToolTipLabel.Font, Vector2.new(188, math.huge))
    ToolTipLabel.Size = UDim2.new(0, size.X, 0, size.Y)
    ToolTip.Size = UDim2.new(0, size.X + 12, 0, size.Y + 12)
end

function updateStatus()
    if toggle then
        TweenService:Create(StatusIndicator, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(60, 255, 100)}):Play()
        StatusLabel.Text = "ON"
        StatusLabel.TextColor3 = Color3.fromRGB(60, 255, 100)
        ToggleButton.Text = "❚❚"
    else
        TweenService:Create(StatusIndicator, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(255, 60, 60)}):Play()
        StatusLabel.Text = "OFF"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
        ToggleButton.Text = "▶"
    end
end

function onToggleButtonHover()
    TweenService:Create(ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 60, 60)}):Play()
end

function onToggleButtonUnhover()
    TweenService:Create(ToggleButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20, 20, 20)}):Play()
end

function onXButtonHover()
    TweenService:Create(CloseButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 60, 60)}):Play()
end

function onXButtonUnhover()
    TweenService:Create(CloseButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20, 20, 20)}):Play()
end

function onToggleButtonClick()
    toggleSpyMethod()
    updateStatus()
end

function connectResize()
    if not workspace.CurrentCamera then
        workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
    end
    local lastCam = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(bringBackOnResize)
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        lastCam:Disconnect()
        if typeof(lastCam) == 'Connection' then
            lastCam:Disconnect()
        end
        lastCam = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(bringBackOnResize)
    end)
end

function bringBackOnResize()
    validateSize()
    if sideClosed then
        minimizeSize()
    else
        maximizeSize()
    end
    local currentX = MainContainer.AbsolutePosition.X
    local currentY = MainContainer.AbsolutePosition.Y
    local viewportSize = workspace.CurrentCamera.ViewportSize
    if (currentX < 0) or (currentX > (viewportSize.X - MainContainer.AbsoluteSize.X)) then
        if currentX < 0 then
            currentX = 0
        else
            currentX = viewportSize.X - MainContainer.AbsoluteSize.X
        end
    end
    if (currentY < 0) or (currentY > (viewportSize.Y - MainContainer.AbsoluteSize.Y - GuiInset.Y)) then
        if currentY < 0 then
            currentY = 0
        else
            currentY = viewportSize.Y - MainContainer.AbsoluteSize.Y - GuiInset.Y
        end
    end
    TweenService:Create(MainContainer, TweenInfo.new(0.1), {Position = UDim2.new(0, currentX, 0, currentY)}):Play()
end

function onBarInput(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local lastPos = input.UserInputType == Enum.UserInputType.Touch and input.Position or UserInputService:GetMouseLocation()
        local mainPos = MainContainer.AbsolutePosition
        local offset = mainPos - lastPos
        local currentPos = offset + lastPos
        
        if not connections["drag"] then
            connections["drag"] = RunService.RenderStepped:Connect(function()
                local newPos = UserInputService:GetMouseLocation()
                if newPos ~= lastPos then
                    local currentX = (offset + newPos).X
                    local currentY = (offset + newPos).Y
                    local viewportSize = workspace.CurrentCamera.ViewportSize
                    
                    if (currentX < 0 and currentX < currentPos.X) or (currentX > (viewportSize.X - MainContainer.AbsoluteSize.X) and currentX > currentPos.X) then
                        if currentX < 0 then
                            currentX = 0
                        else
                            currentX = viewportSize.X - MainContainer.AbsoluteSize.X
                        end
                    end
                    if (currentY < 0 and currentY < currentPos.Y) or (currentY > (viewportSize.Y - MainContainer.AbsoluteSize.Y - GuiInset.Y) and currentY > currentPos.Y) then
                        if currentY < 0 then
                            currentY = 0
                        else
                            currentY = viewportSize.Y - MainContainer.AbsoluteSize.Y - GuiInset.Y
                        end
                    end
                    currentPos = Vector2.new(currentX, currentY)
                    lastPos = newPos
                    TweenService:Create(MainContainer, TweenInfo.new(0.1), {Position = UDim2.new(0, currentPos.X, 0, currentPos.Y)}):Play()
                end
            end)
        end
        
        table.insert(connections, UserInputService.InputEnded:Connect(function(inputE)
            if input == inputE then
                if connections["drag"] then
                    connections["drag"]:Disconnect()
                    connections["drag"] = nil
                end
            end
        end))
    end
end

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

function toggleMinimize(override)
    if mainClosing and not override or maximized then
        return
    end
    mainClosing = true
    closed = not closed
    if closed then
        if not sideClosed then
            toggleSideTray(true)
        end
        LogsPanel.Visible = true
        remotesFadeIn = fadeOut(LogsPanel:GetDescendants())
        TweenService:Create(LogsPanel, TweenInfo.new(0.5), {Size = UDim2.new(0, 0, 1, 0)}):Play()
        wait(0.5)
    else
        TweenService:Create(LogsPanel, TweenInfo.new(0.5), {Size = UDim2.new(0.4, -1, 1, 0)}):Play()
        wait(0.5)
        if remotesFadeIn then
            remotesFadeIn()
            remotesFadeIn = nil
        end
        bringBackOnResize()
    end
    mainClosing = false
end

function toggleSideTray(override)
    if sideClosing and not override or maximized then
        return
    end
    sideClosing = true
    sideClosed = not sideClosed
    if sideClosed then
        rightFadeIn = fadeOut(RightPanel:GetDescendants())
        wait(0.5)
        minimizeSize(0.5)
        wait(0.5)
        RightPanel.Visible = false
    else
        if closed then
            toggleMinimize(true)
        end
        RightPanel.Visible = true
        maximizeSize(0.5)
        wait(0.5)
        if rightFadeIn then
            rightFadeIn()
        end
        bringBackOnResize()
    end
    sideClosing = false
end

function maximizeSize(speed)
    if not speed then
        speed = 0.05
    end
    TweenService:Create(LogsPanel, TweenInfo.new(speed), {Size = UDim2.new(0.4, -1, 1, 0)}):Play()
    TweenService:Create(RightPanel, TweenInfo.new(speed), {Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.new(0.4, 0, 0, 0)}):Play()
    TweenService:Create(Divider, TweenInfo.new(speed), {Position = UDim2.new(0.4, 0, 0, 0)}):Play()
end

function minimizeSize(speed)
    if not speed then
        speed = 0.05
    end
    TweenService:Create(LogsPanel, TweenInfo.new(speed), {Size = UDim2.new(1, 0, 1, 0)}):Play()
    TweenService:Create(RightPanel, TweenInfo.new(speed), {Size = UDim2.new(0, 0, 1, 0), Position = UDim2.new(1, 0, 0, 0)}):Play()
    TweenService:Create(Divider, TweenInfo.new(speed), {Position = UDim2.new(1, 0, 0, 0)}):Play()
end

function validateSize()
    local x, y = MainContainer.AbsoluteSize.X, MainContainer.AbsoluteSize.Y
    local screenSize = workspace.CurrentCamera.ViewportSize
    
    if screenSize.X < 500 or screenSize.Y < 500 then
        x = math.min(screenSize.X * 0.95, 400)
        y = math.min(screenSize.Y * 0.85, 400)
    else
        if x + MainContainer.AbsolutePosition.X > screenSize.X then
            if screenSize.X - MainContainer.AbsolutePosition.X >= 400 then
                x = screenSize.X - MainContainer.AbsolutePosition.X
            else
                x = 400
            end
        elseif y + MainContainer.AbsolutePosition.Y > screenSize.Y then
            if screenSize.Y - MainContainer.AbsolutePosition.Y >= 300 then
                y = screenSize.Y - MainContainer.AbsolutePosition.Y
            else
                y = 300
            end
        end
    end
    
    MainContainer.Size = UDim2.fromOffset(x, y)
end

function mouseMoved()
    local mousePos = UserInputService:GetMouseLocation() - GuiInset
    if not closed
    and mousePos.X >= Header.AbsolutePosition.X and mousePos.X <= Header.AbsolutePosition.X + Header.AbsoluteSize.X
    and mousePos.Y >= MainContainer.AbsolutePosition.Y and mousePos.Y <= MainContainer.AbsolutePosition.Y + Header.AbsoluteSize.Y then
        if not mouseInGui then
            mouseInGui = true
        end
    else
        mouseInGui = false
    end
end

function backgroundUserInput(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        local mousePos = UserInputService:GetMouseLocation() - GuiInset
        if mousePos.X >= Header.AbsolutePosition.X and mousePos.X <= Header.AbsolutePosition.X + Header.AbsoluteSize.X
        and mousePos.Y >= MainContainer.AbsolutePosition.Y and mousePos.Y <= MainContainer.AbsolutePosition.Y + Header.AbsoluteSize.Y then
            onBarInput(input)
        end
    end
end

function getPlayerFromInstance(instance)
    for _, v in next, Players:GetPlayers() do
        if v.Character and (instance:IsDescendantOf(v.Character) or instance == v.Character) then
            return v
        end
    end
end

function eventSelect(frame)
    if selected and selected.Log then
        if selected.Button then
            spawn(function()
                TweenService:Create(selected.Button, TweenInfo.new(0.2), {BackgroundColor3 = deselectedColor}):Play()
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
            TweenService:Create(frame.Button, TweenInfo.new(0.2), {BackgroundColor3 = selectedColor}):Play()
        end)
        codebox:setRaw(selected.GenScript)
    end
    
    if sideClosed then
        toggleSideTray()
    end
end

function updateToolsCanvas()
    ToolsPanel.CanvasSize = UDim2.new(0, ToolsGrid.AbsoluteCellCount * (ToolsGrid.CellSize.X.Offset + ToolsGrid.CellPadding.X.Offset), 0, 0)
end

function updateLogsCanvas()
    LogsPanel.CanvasSize = UDim2.new(0, 0, 0, LogsLayout.AbsoluteContentSize.Y)
end

function makeToolTip(enable, text)
    if enable and text then
        if ToolTip.Visible then
            ToolTip.Visible = false
            local tooltip = connections["ToolTip"]
            if tooltip then
                tooltip:Disconnect()
            end
        end
        
        local first = true
        connections["ToolTip"] = RunService.RenderStepped:Connect(function()
            local MousePos = UserInputService:GetMouseLocation()
            local topLeft = MousePos + Vector2.new(20, 20)
            local bottomRight = topLeft + ToolTip.AbsoluteSize
            local ViewportSize = workspace.CurrentCamera.ViewportSize
            
            if topLeft.X < 0 then
                topLeft = Vector2.new(0, topLeft.Y)
            elseif bottomRight.X > ViewportSize.X then
                topLeft = Vector2.new(ViewportSize.X - ToolTip.AbsoluteSize.X, topLeft.Y)
            end
            if topLeft.Y < 0 then
                topLeft = Vector2.new(topLeft.X, 0)
            elseif bottomRight.Y > ViewportSize.Y - 35 then
                topLeft = Vector2.new(topLeft.X, ViewportSize.Y - ToolTip.AbsoluteSize.Y - 35)
            end
            
            if topLeft.X <= MousePos.X and topLeft.Y <= MousePos.Y then
                topLeft = Vector2.new(MousePos.X - ToolTip.AbsoluteSize.X - 2, MousePos.Y - ToolTip.AbsoluteSize.Y - 2)
            end
            
            if first then
                ToolTip.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
                first = false
            else
                ToolTip:TweenPosition(UDim2.fromOffset(topLeft.X, topLeft.Y), "Out", "Linear", 0.1)
            end
        end)
        
        ToolTipLabel.Text = text
        ToolTip.Visible = true
        scaleToolTip()
        return
    else
        if ToolTip.Visible then
            ToolTip.Visible = false
            local tooltip = connections["ToolTip"]
            if tooltip then
                tooltip:Disconnect()
            end
        end
    end
end

function newButton(name, description, onClick)
    local Button = Create("TextButton",{
        Name = name,
        Parent = ToolsPanel,
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = name,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextSize = 12,
        AutoButtonColor = false
    })
    
    Button.MouseEnter:Connect(function()
        TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 60, 60)}):Play()
        makeToolTip(true, description())
    end)
    
    Button.MouseLeave:Connect(function()
        TweenService:Create(Button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
        makeToolTip(false)
    end)
    
    Button.MouseButton1Click:Connect(function(...)
        logthread(running())
        onClick(Button, ...)
    end)
    
    Button.TouchTap:Connect(function()
        logthread(running())
        onClick(Button)
    end)
    
    updateToolsCanvas()
    return Button
end

function newRemote(type, data)
    if layoutOrderNum < 1 then layoutOrderNum = 999999999 end
    local remote = data.remote
    local callingscript = data.callingscript

    local RemoteItem = Create("Frame",{
        LayoutOrder = layoutOrderNum,
        Name = "RemoteItem",
        Parent = LogsPanel,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 0, 32)
    })
    
    local Button = Create("TextButton",{
        Name = "Button",
        Parent = RemoteItem,
        BackgroundColor3 = deselectedColor,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        AutoButtonColor = false,
        Font = Enum.Font.Gotham,
        Text = "",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 14
    })
    
    local Icon = Create("TextLabel",{
        Parent = Button,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, 0),
        Size = UDim2.new(0, 24, 1, 0),
        Font = Enum.Font.GothamMedium,
        Text = type == "event" and "⚡" or "⚙️",
        TextColor3 = Color3.fromRGB(255, 60, 60),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    
    local Text = Create("TextLabel",{
        TextTruncate = Enum.TextTruncate.AtEnd,
        Name = "Text",
        Parent = Button,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 32, 0, 0),
        Size = UDim2.new(1, -40, 1, 0),
        Font = Enum.Font.Gotham,
        Text = remote.Name,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left
    })

    local log = {
        Name = remote.name,
        Function = data.infofunc or "--Function Info is disabled",
        Remote = remote,
        DebugId = data.id,
        metamethod = data.metamethod,
        args = data.args,
        Log = RemoteItem,
        Button = Button,
        Blocked = data.blocked,
        Source = callingscript,
        returnvalue = data.returnvalue,
        GenScript = "-- Generating, please wait..."
    }

    logs[#logs + 1] = log
    local connect = Button.MouseButton1Click:Connect(function()
        logthread(running())
        eventSelect(RemoteItem)
        log.GenScript = genScript(log.Remote, log.args)
        if data.blockcheck then
            log.GenScript = "-- THIS REMOTE WAS PREVENTED FROM FIRING TO THE SERVER BY SIMPLESPY\n\n" .. log.GenScript
        end
        if selected == log and RemoteItem then
            eventSelect(RemoteItem)
        end
    end)
    
    Button.TouchTap:Connect(function()
        logthread(running())
        eventSelect(RemoteItem)
        log.GenScript = genScript(log.Remote, log.args)
        if data.blockcheck then
            log.GenScript = "-- THIS REMOTE WAS PREVENTED FROM FIRING TO THE SERVER BY SIMPLESPY\n\n" .. log.GenScript
        end
        if selected == log and RemoteItem then
            eventSelect(RemoteItem)
        end
    end)
    
    layoutOrderNum -= 1
    table.insert(remoteLogs, 1, {connect, RemoteItem})
    clean()
    updateLogsCanvas()
end

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

local CustomGeneration = {
    Vector3 = (function()
        local temp = {}
        for i,v in Vector3 do
            if type(v) == "vector" then
                temp[v] = `Vector3.{i}`
            end
        end
        return temp
    end)(),
    Vector2 = (function()
        local temp = {}
        for i,v in Vector2 do
            if type(v) == "userdata" then
                temp[v] = `Vector2.{i}`
            end
        end
        return temp
    end)(),
    CFrame = {
        [CFrame.identity] = "CFrame.identity"
    }
}

local number_table = {
    ["inf"] = "math.huge",
    ["-inf"] = "-math.huge",
    ["nan"] = "0/0"
}

local ufunctions
ufunctions = {
    TweenInfo = function(u)
        return `TweenInfo.new({u.Time}, {u.EasingStyle}, {u.EasingDirection}, {u.RepeatCount}, {u.Reverses}, {u.DelayTime})`
    end,
    Ray = function(u)
        local Vector3tostring = ufunctions["Vector3"]

        return `Ray.new({Vector3tostring(u.Origin)}, {Vector3tostring(u.Direction)})`
    end,
    BrickColor = function(u)
        return `BrickColor.new({u.Number})`
    end,
    NumberRange = function(u)
        return `NumberRange.new({u.Min}, {u.Max})`
    end,
    Region3 = function(u)
        local center = u.CFrame.Position
        local centersize = u.Size/2
        local Vector3tostring = ufunctions["Vector3"]

        return `Region3.new({Vector3tostring(center-centersize)}, {Vector3tostring(center+centersize)})`
    end,
    Faces = function(u)
        local faces = {}
        if u.Top then
            table.insert(faces, "Top")
        end
        if u.Bottom then
            table.insert(faces, "Enum.NormalId.Bottom")
        end
        if u.Left then
            table.insert(faces, "Enum.NormalId.Left")
        end
        if u.Right then
            table.insert(faces, "Enum.NormalId.Right")
        end
        if u.Back then
            table.insert(faces, "Enum.NormalId.Back")
        end
        if u.Front then
            table.insert(faces, "Enum.NormalId.Front")
        end
        return `Faces.new({table.concat(faces, ", ")})`
    end,
    EnumItem = function(u)
        return tostring(u)
    end,
    Enums = function(u)
        return "Enum"
    end,
    Enum = function(u)
        return `Enum.{u}`
    end,
    Vector3 = function(u)
        return CustomGeneration.Vector3[u] or `Vector3.new({u})`
    end,
    Vector2 = function(u)
        return CustomGeneration.Vector2[u] or `Vector2.new({u})`
    end,
    CFrame = function(u)
        return CustomGeneration.CFrame[u] or `CFrame.new({table.concat({u:GetComponents()},", ")})`
    end,
    PathWaypoint = function(u)
        return `PathWaypoint.new({ufunctions["Vector3"](u.Position)}, {u.Action}, "{u.Label}")`
    end,
    UDim = function(u)
        return `UDim.new({u})`
    end,
    UDim2 = function(u)
        return `UDim2.new({u})`
    end,
    Rect = function(u)
        local Vector2tostring = ufunctions["Vector2"]
        return `Rect.new({Vector2tostring(u.Min)}, {Vector2tostring(u.Max)})`
    end,
    Color3 = function(u)
        return `Color3.new({u.R}, {u.G}, {u.B})`
    end,
    RBXScriptSignal = function(u)
        return "RBXScriptSignal --[[RBXScriptSignal's are not supported]]"
    end,
    RBXScriptConnection = function(u)
        return "RBXScriptConnection --[[RBXScriptConnection's are not supported]]"
    end,
}

local typeofv2sfunctions = {
    number = function(v)
        local number = tostring(v)
        return number_table[number] or number
    end,
    boolean = function(v)
        return tostring(v)
    end,
    string = function(v,l)
        return formatstr(v, l)
    end,
    ["function"] = function(v)
        return f2s(v)
    end,
    table = function(v, l, p, n, vtv, i, pt, path, tables, tI)
        return t2s(v, l, p, n, vtv, i, pt, path, tables, tI)
    end,
    Instance = function(v)
        local DebugId = OldDebugId(v)
        return i2p(v,generation[DebugId])
    end,
    userdata = function(v)
        if configs.advancedinfo then
            if getrawmetatable(v) then
                return "newproxy(true)"
            end
            return "newproxy(false)"
        end
        return "newproxy(true)"
    end
}

local typev2sfunctions = {
    userdata = function(v,vtypeof)
        if ufunctions[vtypeof] then
            return ufunctions[vtypeof](v)
        end
        return `{vtypeof}({rawtostring(v)}) --[[Generation Failure]]`
    end,
    vector = ufunctions["Vector3"]
}


function v2s(v, l, p, n, vtv, i, pt, path, tables, tI)
    local vtypeof = typeof(v)
    local vtypeoffunc = typeofv2sfunctions[vtypeof]
    local vtypefunc = typev2sfunctions[type(v)]
    local vtype = type(v)
    if not tI then
        tI = {0}
    else
        tI[1] += 1
    end

    if vtypeoffunc then
        return vtypeoffunc(v, l, p, n, vtv, i, pt, path, tables, tI)
    elseif vtypefunc then
        return vtypefunc(v,vtypeof)
    end
    return `{vtypeof}({rawtostring(v)}) --[[Generation Failure]]`
end

function v2v(t)
    topstr = ""
    bottomstr = ""
    getnilrequired = false
    local ret = ""
    local count = 1
    for i, v in next, t do
        if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then
            ret = ret .. "local " .. i .. " = " .. v2s(v, nil, nil, i, true) .. "\n"
        elseif rawtostring(i):match("^[%a_]+[%w_]*$") then
            ret = ret .. "local " .. lower(rawtostring(i)) .. "_" .. rawtostring(count) .. " = " .. v2s(v, nil, nil, lower(rawtostring(i)) .. "_" .. rawtostring(count), true) .. "\n"
        else
            ret = ret .. "local " .. type(v) .. "_" .. rawtostring(count) .. " = " .. v2s(v, nil, nil, type(v) .. "_" .. rawtostring(count), true) .. "\n"
        end
        count = count + 1
    end
    if getnilrequired then
        topstr = "function getNil(name,class) for _,v in next, getnilinstances() do if v.ClassName==class and v.Name==name then return v;end end end\n" .. topstr
    end
    if #topstr > 0 then
        ret = topstr .. "\n" .. ret
    end
    if #bottomstr > 0 then
        ret = ret .. bottomstr
    end
    return ret
end

function t2s(t, l, p, n, vtv, i, pt, path, tables, tI)
    local globalIndex = table.find(getgenv(), t)
    if type(globalIndex) == "string" then
        return globalIndex
    end
    if not tI then
        tI = {0}
    end
    if not path then
        path = ""
    end
    if not l then
        l = 0
        tables = {}
    end
    if not p then
        p = t
    end
    for _, v in next, tables do
        if n and rawequal(v, t) then
            bottomstr = bottomstr .. "\n" .. rawtostring(n) .. rawtostring(path) .. " = " .. rawtostring(n) .. rawtostring(({v2p(v, p)})[2])
            return "{} --[[DUPLICATE]]"
        end
    end
    table.insert(tables, t)
    local s =  "{"
    local size = 0
    l += indent
    for k, v in next, t do
        size = size + 1
        if size > (getgenv().SimpleSpyMaxTableSize or 1000) then
            s = s .. "\n" .. string.rep(" ", l) .. "-- MAXIMUM TABLE SIZE REACHED, CHANGE 'getgenv().SimpleSpyMaxTableSize' TO ADJUST MAXIMUM SIZE "
            break
        end
        if rawequal(k, t) then
            bottomstr ..= `\n{n}{path}[{n}{path}] = {(rawequal(v,k) and `{n}{path}` or v2s(v, l, p, n, vtv, k, t, `{path}[{n}{path}]`, tables))}`
            size -= 1
            continue
        end
        local currentPath = ""
        if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then
            currentPath = "." .. k
        else
            currentPath = "[" .. v2s(k, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. "]"
        end
        if size % 100 == 0 then
            scheduleWait()
        end
        s = s .. "\n" .. string.rep(" ", l) .. "[" .. v2s(k, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. "] = " .. v2s(v, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. ","
    end
    if #s > 1 then
        s = s:sub(1, #s - 1)
    end
    if size > 0 then
        s = s .. "\n" .. string.rep(" ", l - indent)
    end
    return s .. "}"
end

function f2s(f)
    for k, x in next, getgenv() do
        local isgucci, gpath
        if rawequal(x, f) then
            isgucci, gpath = true, ""
        elseif type(x) == "table" then
            isgucci, gpath = v2p(f, x)
        end
        if isgucci and type(k) ~= "function" then
            if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then
                return k .. gpath
            else
                return "getgenv()[" .. v2s(k) .. "]" .. gpath
            end
        end
    end
    
    if configs.funcEnabled then
        local funcname = info(f,"n")
        
        if funcname and funcname:match("^[%a_]+[%w_]*$") then
            return `function {funcname}() end -- Function Called: {funcname}`
        end
    end
    return tostring(f)
end

function i2p(i,customgen)
    if customgen then
        return customgen
    end
    local player = getplayer(i)
    local parent = i
    local out = ""
    if parent == nil then
        return "nil"
    elseif player then
        while true do
            if parent and parent == player.Character then
                if player == Players.LocalPlayer then
                    return 'game:GetService("Players").LocalPlayer.Character' .. out
                else
                    return i2p(player) .. ".Character" .. out
                end
            else
                if parent.Name:match("[%a_]+[%w+]*") ~= parent.Name then
                    out = ':FindFirstChild(' .. formatstr(parent.Name) .. ')' .. out
                else
                    out = "." .. parent.Name .. out
                end
            end
            task.wait()
            parent = parent.Parent
        end
    elseif parent ~= game then
        while true do
            if parent and parent.Parent == game then
                if SafeGetService(parent.ClassName) then
                    if lower(parent.ClassName) == "workspace" then
                        return `workspace{out}`
                    else
                        return 'game:GetService("' .. parent.ClassName .. '")' .. out
                    end
                else
                    if parent.Name:match("[%a_]+[%w_]*") then
                        return "game." .. parent.Name .. out
                    else
                        return 'game:FindFirstChild(' .. formatstr(parent.Name) .. ')' .. out
                    end
                end
            elseif not parent.Parent then
                getnilrequired = true
                return 'getNil(' .. formatstr(parent.Name) .. ', "' .. parent.ClassName .. '")' .. out
            else
                if parent.Name:match("[%a_]+[%w_]*") ~= parent.Name then
                    out = ':WaitForChild(' .. formatstr(parent.Name) .. ')' .. out
                else
                    out = ':WaitForChild("' .. parent.Name .. '")'..out
                end
            end
            if i:IsDescendantOf(Players.LocalPlayer) then
                return 'game:GetService("Players").LocalPlayer'..out
            end
            parent = parent.Parent
            task.wait()
        end
    else
        return "game"
    end
end

function getplayer(instance)
    for _, v in next, Players:GetPlayers() do
        if v.Character and (instance:IsDescendantOf(v.Character) or instance == v.Character) then
            return v
        end
    end
end

function v2p(x, t, path, prev)
    if not path then
        path = ""
    end
    if not prev then
        prev = {}
    end
    if rawequal(x, t) then
        return true, ""
    end
    for i, v in next, t do
        if rawequal(v, x) then
            if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then
                return true, (path .. "." .. i)
            else
                return true, (path .. "[" .. v2s(i) .. "]")
            end
        end
        if type(v) == "table" then
            local duplicate = false
            for _, y in next, prev do
                if rawequal(y, v) then
                    duplicate = true
                end
            end
            if not duplicate then
                table.insert(prev, t)
                local found
                found, p = v2p(x, v, path, prev)
                if found then
                    if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then
                        return true, "." .. i .. p
                    else
                        return true, "[" .. v2s(i) .. "]" .. p
                    end
                end
            end
        end
    end
    return false, ""
end

function formatstr(s, indentation)
    if not indentation then
        indentation = 0
    end
    local handled, reachedMax = handlespecials(s, indentation)
    return '"' .. handled .. '"' .. (reachedMax and " --[[ MAXIMUM STRING SIZE REACHED, CHANGE 'getgenv().SimpleSpyMaxStringSize' TO ADJUST MAXIMUM SIZE ]]" or "")
end

local function isFinished(coroutines: table)
    for _, v in next, coroutines do
        if status(v) == "running" then
            return false
        end
    end
    return true
end

local specialstrings = {
    ["\n"] = function(thread,index)
        resume(thread,index,"\\n")
    end,
    ["\t"] = function(thread,index)
        resume(thread,index,"\\t")
    end,
    ["\\"] = function(thread,index)
        resume(thread,index,"\\\\")
    end,
    ['"'] = function(thread,index)
        resume(thread,index,"\\\"")
    end
}

function handlespecials(s, indentation)
    local i = 0
    local n = 1
    local coroutines = {}
    local coroutineFunc = function(i, r)
        s = s:sub(0, i - 1) .. r .. s:sub(i + 1, -1)
    end
    local timeout = 0
    repeat
        i += 1
        if timeout >= 10 then
            task.wait()
            timeout = 0
        end
        local char = s:sub(i, i)

        if byte(char) then
            timeout += 1
            local c = create(coroutineFunc)
            table.insert(coroutines, c)
            local specialfunc = specialstrings[char]

            if specialfunc then
                specialfunc(c,i)
                i += 1
            elseif byte(char) > 126 or byte(char) < 32 then
                resume(c, i, "\\" .. byte(char))
                i += #rawtostring(byte(char))
            end
            if i >= n * 100 then
                local extra = string.format('" ..\n%s"', string.rep(" ", indentation + indent))
                s = s:sub(0, i) .. extra .. s:sub(i + 1, -1)
                i += #extra
                n += 1
            end
        end
    until char == "" or i > (getgenv().SimpleSpyMaxStringSize or 10000)
    while not isFinished(coroutines) do
        RunService.Heartbeat:Wait()
    end
    clear(coroutines)
    if i > (getgenv().SimpleSpyMaxStringSize or 10000) then
        s = string.sub(s, 0, getgenv().SimpleSpyMaxStringSize or 10000)
        return s, true
    end
    return s, false
end

function getScriptFromSrc(src)
    local realPath
    local runningTest
    local s, e
    local match = false
    if src:sub(1, 1) == "=" then
        realPath = game
        s = 2
    else
        runningTest = src:sub(2, e and e - 1 or -1)
        for _, v in next, getnilinstances() do
            if v.Name == runningTest then
                realPath = v
                break
            end
        end
        s = #runningTest + 1
    end
    if realPath then
        e = src:sub(s, -1):find("%.")
        local i = 0
        repeat
            i += 1
            if not e then
                runningTest = src:sub(s, -1)
                local test = realPath.FindFirstChild(realPath, runningTest)
                if test then
                    realPath = test
                end
                match = true
            else
                runningTest = src:sub(s, e)
                local test = realPath.FindFirstChild(realPath, runningTest)
                local yeOld = e
                if test then
                    realPath = test
                    s = e + 2
                    e = src:sub(e + 2, -1):find("%.")
                    e = e and e + yeOld or e
                else
                    e = src:sub(e + 2, -1):find("%.")
                    e = e and e + yeOld or e
                end
            end
        until match or i >= 50
    end
    return realPath
end

function schedule(f, ...)
    table.insert(scheduled, {f, ...})
end

function scheduleWait()
    local thread = running()
    schedule(function()
        resume(thread)
    end)
    yield()
end

local function taskscheduler()
    if not toggle then
        scheduled = {}
        return
    end
    if #scheduled > SIMPLESPYCONFIG_MaxRemotes + 100 then
        table.remove(scheduled, #scheduled)
    end
    if #scheduled > 0 then
        local currentf = scheduled[1]
        table.remove(scheduled, 1)
        if type(currentf) == "table" and type(currentf[1]) == "function" then
            pcall(unpack(currentf))
        end
    end
end

local function tablecheck(tabletocheck,instance,id)
    return tabletocheck[id] or tabletocheck[instance.Name]
end

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

local newindex = function(method,originalfunction,...)
    if typeof(...) == 'Instance' then
        local remote = cloneref(...)

        if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") or remote:IsA("UnreliableRemoteEvent") then
            if not configs.logcheckcaller and checkcaller() then return originalfunction(...) end
            local id = ThreadGetDebugId(remote)
            local blockcheck = tablecheck(blocklist,remote,id)
            local args = {select(2,...)}

            if not tablecheck(blacklist,remote,id) and not IsCyclicTable(args) then
                local data = {
                    method = method,
                    remote = remote,
                    args = deepclone(args),
                    infofunc = infofunc,
                    callingscript = callingscript,
                    metamethod = "__index",
                    blockcheck = blockcheck,
                    id = id,
                    returnvalue = {}
                }
                args = nil

                if configs.funcEnabled then
                    data.infofunc = info(2,"f")
                    local calling = getcallingscript()
                    data.callingscript = calling and cloneref(calling) or nil
                end

                schedule(remoteHandler,data)
            end
            if blockcheck then return end
        end
    end
    return originalfunction(...)
end

local newnamecall = newcclosure(function(...)
    local method = getnamecallmethod()

    if method and (method == "FireServer" or method == "fireServer" or method == "InvokeServer" or method == "invokeServer") then
        if typeof(...) == 'Instance' then
            local remote = cloneref(...)

            if IsA(remote,"RemoteEvent") or IsA(remote,"RemoteFunction") or IsA(remote,"UnreliableRemoteEvent") then    
                if not configs.logcheckcaller and checkcaller() then return originalnamecall(...) end
                local id = ThreadGetDebugId(remote)
                local blockcheck = tablecheck(blocklist,remote,id)
                local args = {select(2,...)}

                if not tablecheck(blacklist,remote,id) and not IsCyclicTable(args) then
                    local data = {
                        method = method,
                        remote = remote,
                        args = deepclone(args),
                        infofunc = infofunc,
                        callingscript = callingscript,
                        metamethod = "__namecall",
                        blockcheck = blockcheck,
                        id = id,
                        returnvalue = {}
                    }
                    args = nil

                    if configs.funcEnabled then
                        data.infofunc = info(2,"f")
                        local calling = getcallingscript()
                        data.callingscript = calling and cloneref(calling) or nil
                    end

                    schedule(remoteHandler,data)
                end
                if blockcheck then return end
            end
        end
    end
    return originalnamecall(...)
end)

local newFireServer = newcclosure(function(...)
    return newindex("FireServer",originalEvent,...)
end)

local newUnreliableFireServer = newcclosure(function(...)
    return newindex("FireServer",originalUnreliableEvent,...)
end)

local newInvokeServer = newcclosure(function(...)
    return newindex("InvokeServer",originalFunction,...)
end)

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

function toggleSpyMethod()
    toggleSpy()
    toggle = not toggle
end

local function shutdown()
    if schedulerconnect then
        schedulerconnect:Disconnect()
    end
    for _, connection in next, connections do
        connection:Disconnect()
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
    SimpleSpy3:Destroy()
    Storage:Destroy()
    UserInputService.MouseIconEnabled = true
    getgenv().SimpleSpyExecuted = false
end

-- main
if not getgenv().SimpleSpyExecuted then
    local succeeded,err = pcall(function()
        if not RunService:IsClient() then
            error("SimpleSpy cannot run on the server!")
        end
        getgenv().SimpleSpyShutdown = shutdown
        
        -- Адаптация для мобильных устройств
        local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
        if isMobile then
            MainContainer.Size = UDim2.new(0.95, 0, 0.8, 0)
            MainContainer.AnchorPoint = Vector2.new(0.5, 0.5)
            MainContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
            validateSize()
        end
        
        toggleSpyMethod()
        updateStatus()
        
        if not hookmetamethod then
            ErrorPrompt("Simple Spy V3 will not function to it's fullest capablity due to your executor not supporting hookmetamethod.",true)
        end
        
        codebox = Highlight.new(CodeBox)
        
        logthread(spawn(function()
            local suc,err = pcall(game.HttpGet,game,"https://raw.githubusercontent.com/78n/SimpleSpy/main/UpdateLog.lua")
            codebox:setRaw((suc and err) or "")
        end))
        
        getgenv().SimpleSpy = SimpleSpy
        getgenv().getNil = function(name,class)
            for _,v in next, getnilinstances() do
                if v.ClassName == class and v.Name == name then
                    return v;
                end
            end
        end
        
        -- Подключение событий
        ToolTipLabel:GetPropertyChangedSignal("Text"):Connect(scaleToolTip)
        
        ToggleButton.MouseButton1Click:Connect(onToggleButtonClick)
        ToggleButton.TouchTap:Connect(onToggleButtonClick)
        ToggleButton.MouseEnter:Connect(onToggleButtonHover)
        ToggleButton.MouseLeave:Connect(onToggleButtonUnhover)
        
        CloseButton.MouseButton1Click:Connect(shutdown)
        CloseButton.TouchTap:Connect(shutdown)
        CloseButton.MouseEnter:Connect(onXButtonHover)
        CloseButton.MouseLeave:Connect(onXButtonUnhover)
        
        table.insert(connections, UserInputService.InputBegan:Connect(backgroundUserInput))
        
        connectResize()
        SimpleSpy3.Enabled = true
        
        schedulerconnect = RunService.Heartbeat:Connect(taskscheduler)
        bringBackOnResize()
        
        SimpleSpy3.Parent = (gethui and gethui()) or (syn and syn.protect_gui and syn.protect_gui(SimpleSpy3)) or CoreGui
        
        logthread(spawn(function()
            local lp = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer
            generation = {
                [OldDebugId(lp)] = 'game:GetService("Players").LocalPlayer',
                [OldDebugId(lp:GetMouse())] = 'game:GetService("Players").LocalPlayer:GetMouse',
                [OldDebugId(game)] = "game",
                [OldDebugId(workspace)] = "workspace"
            }
        end))
    end)
    
    if succeeded then
        getgenv().SimpleSpyExecuted = true
    else
        shutdown()
        ErrorPrompt("An error has occured:\n"..rawtostring(err))
        return
    end
else
    SimpleSpy3:Destroy()
    return
end

function SimpleSpy:newButton(name, description, onClick)
    return newButton(name, description, onClick)
end

----- ИНСТРУМЕНТЫ -----
newButton(
    "Copy",
    function() return "Copy generated code" end,
    function()
        setclipboard(codebox:getString())
        ToolTipLabel.Text = "✓ Code copied"
    end
)

newButton(
    "Remote",
    function() return "Copy remote path" end,
    function()
        if selected and selected.Remote then
            setclipboard(v2s(selected.Remote))
            ToolTipLabel.Text = "✓ Remote copied"
        end
    end
)

newButton(
    "Run",
    function() return "Execute script" end,
    function()
        local Remote = selected and selected.Remote
        if Remote then
            ToolTipLabel.Text = "▶ Executing..."
            xpcall(function()
                local returnvalue
                if Remote:IsA("RemoteEvent") or Remote:IsA("UnreliableRemoteEvent") then
                    returnvalue = Remote:FireServer(unpack(selected.args))
                elseif Remote:IsA("RemoteFunction") then
                    returnvalue = Remote:InvokeServer(unpack(selected.args))
                end
                ToolTipLabel.Text = ("✓ Executed\n%s"):format(v2s(returnvalue))
            end,function(err)
                ToolTipLabel.Text = ("✗ Error\n%s"):format(err)
            end)
            return
        end
        ToolTipLabel.Text = "✗ No remote"
    end
)

newButton(
    "Script",
    function() return "Get calling script" end,
    function()
        if selected then
            if not selected.Source then
                selected.Source = rawget(getfenv(selected.Function),"script")
            end
            setclipboard(v2s(selected.Source))
            ToolTipLabel.Text = "✓ Script copied"
        end
    end
)

newButton(
    "Info",
    function() return "Function info" end,
    function()
        local func = selected and selected.Function
        if func then
            local typeoffunc = typeof(func)
            if typeoffunc ~= 'string' then
                codebox:setRaw("--[[Generating...]]")
                RunService.Heartbeat:Wait()
                local lclosure = islclosure(func)
                local SourceScript = rawget(getfenv(func),"script")
                local CallingScript = selected.Source or nil
                local info = {}
                info = {
                    info = getinfo(func),
                    constants = lclosure and deepclone(getconstants(func)) or "N/A",
                    upvalues = deepclone(getupvalues(func)),
                    script = {
                        SourceScript = SourceScript or 'nil',
                        CallingScript = CallingScript or 'nil'
                    }
                }
                if configs.advancedinfo then
                    local Remote = selected.Remote
                    info["advancedinfo"] = {
                        Metamethod = selected.metamethod,
                        DebugId = {
                            SourceScriptDebugId = SourceScript and typeof(SourceScript) == "Instance" and OldDebugId(SourceScript) or "N/A",
                            CallingScriptDebugId = CallingScript and typeof(SourceScript) == "Instance" and OldDebugId(CallingScript) or "N/A",
                            RemoteDebugId = OldDebugId(Remote)
                        },
                        Protos = lclosure and getprotos(func) or "N/A"
                    }
                    if Remote:IsA("RemoteFunction") then
                        info["advancedinfo"]["OnClientInvoke"] = getcallbackmember and (getcallbackmember(Remote,"OnClientInvoke") or "N/A") or "N/A"
                    elseif getconnections then
                        info["advancedinfo"]["OnClientEvents"] = {}
                        for i,v in next, getconnections(Remote.OnClientEvent) do
                            info["advancedinfo"]["OnClientEvents"][i] = {
                                Function = v.Function or "N/A",
                                State = v.State or "N/A"
                            }
                        end
                    end
                end
                codebox:setRaw("--[[Converting...]]")
                selected.Function = v2v({functionInfo = info})
            end
            codebox:setRaw("-- Function info\n\n"..selected.Function)
            ToolTipLabel.Text = "✓ Info generated"
        else
            ToolTipLabel.Text = "✗ No function"
        end
    end
)

newButton(
    "Clear",
    function() return "Clear logs" end,
    function()
        ToolTipLabel.Text = "Clearing..."
        clear(logs)
        for i,v in next, LogsPanel:GetChildren() do
            if not v:IsA("UIListLayout") then
                v:Destroy()
            end
        end
        codebox:setRaw("")
        selected = nil
        ToolTipLabel.Text = "✓ Logs cleared"
    end
)

newButton(
    "Excl",
    function() return "Exclude remote" end,
    function()
        if selected then
            blacklist[OldDebugId(selected.Remote)] = true
            ToolTipLabel.Text = "✓ Remote excluded"
        end
    end
)

newButton(
    "Block",
    function() return "Block remote" end,
    function()
        if selected then
            blocklist[OldDebugId(selected.Remote)] = true
            ToolTipLabel.Text = "✓ Remote blocked"
        end
    end
)

newButton(
    "ClrB",
    function() return "Clear blocklist" end,
    function()
        blocklist = {}
        ToolTipLabel.Text = "✓ Blocklist cleared"
    end
)

newButton(
    "Decmp",
    function() return "Decompile script" end,
    function()
        if decompile then
            if selected and selected.Source then
                local Source = selected.Source
                if not DecompiledScripts[Source] then
                    codebox:setRaw("--[[Decompiling]]")
                    xpcall(function()
                        local decompiledsource = decompile(Source):gsub("-- Decompiled with the Synapse X Luau decompiler.","")
                        local Sourcev2s = v2s(Source)
                        if (decompiledsource):find("script") and Sourcev2s then
                            DecompiledScripts[Source] = ("local script = %s\n%s"):format(Sourcev2s,decompiledsource)
                        end
                    end,function(err)
                        return codebox:setRaw(("--[[\nError:\n%s\n]]"):format(err))
                    end)
                end
                codebox:setRaw(DecompiledScripts[Source] or "--No source")
                ToolTipLabel.Text = "✓ Decompiled"
            else
                ToolTipLabel.Text = "✗ No source"
            end
        else
            ToolTipLabel.Text = "✗ No decompile"
        end
    end
)

newButton(
    "Func",
    function() return string.format("[%s] Toggle function info", configs.funcEnabled and "ON" : "OFF") end,
    function()
        configs.funcEnabled = not configs.funcEnabled
        ToolTipLabel.Text = string.format("[%s] Function info", configs.funcEnabled and "ON" : "OFF")
    end
)

newButton(
    "Auto",
    function() return string.format("[%s] Auto-block spam", configs.autoblock and "ON" : "OFF") end,
    function()
        configs.autoblock = not configs.autoblock
        ToolTipLabel.Text = string.format("[%s] Auto-block", configs.autoblock and "ON" : "OFF")
        history = {}
        excluding = {}
    end
)

newButton(
    "Caller",
    function() return ("[%s] Log client calls"):format(configs.logcheckcaller and "ON" : "OFF") end,
    function()
        configs.logcheckcaller = not configs.logcheckcaller
        ToolTipLabel.Text = ("[%s] Log calls"):format(configs.logcheckcaller and "ON" : "OFF")
    end
)

newButton(
    "Adv",
    function() return ("[%s] Advanced info"):format(configs.advancedinfo and "ON" : "OFF") end,
    function()
        configs.advancedinfo = not configs.advancedinfo
        ToolTipLabel.Text = ("[%s] Advanced"):format(configs.advancedinfo and "ON" : "OFF")
    end
)

newButton(
    "Discord",
    function() return "Join Discord" end,
    function()
        setclipboard("https://discord.com/invite/AWS6ez9")
        ToolTipLabel.Text = "✓ Discord invite copied"
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
                    args = {code = 'AWS6ez9'}
                })
            })
        end
    end
)

if configs.supersecretdevtoggle then
    newButton(
        "SS",
        function() return "Secret button" end,
        function()
            local SuperSecretFolder = Create("Folder",{Parent = SimpleSpy3})
            local random = listfiles("Music")
            local NotSound = Create("Sound",{
                Parent = SuperSecretFolder,
                Looped = false,
                Volume = 2,
                SoundId = getsynasset(random[math.random(1,#random)])
            })
            NotSound:Play()
        end
    )
end
