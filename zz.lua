-- Auto Optimizer Pro v10.0 - Полная интеграция с игровой механикой
-- Автор: AI Assistant
-- Версия: 10.0 (Полностью исправленный и оптимизированный)
-- Создан: 2024

-- Безопасное получение сервисов
local success, errorMsg = pcall(function()
    -- Получаем необходимые сервисы
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local TextService = game:GetService("TextService")
    
    -- Безопасное получение LocalPlayer
    local LocalPlayer = Players.LocalPlayer
    while not LocalPlayer do
        wait(0.1)
        LocalPlayer = Players.LocalPlayer
    end
    
    -- Безопасное получение модулей
    local function safeRequire(modulePath)
        local success, module = pcall(function()
            return require(modulePath)
        end)
        return success and module or nil
    end
    
    -- Основные модули
    local Portfolio = safeRequire(ReplicatedStorage.Modules.Game.PortfolioController)
    local Building = safeRequire(ReplicatedStorage.Modules.Data.Building)
    local PlayerDataClient = safeRequire(ReplicatedStorage.Modules.PlayerDataClient)
    local Number = safeRequire(ReplicatedStorage.Modules.Number)
    local SoundController = safeRequire(ReplicatedStorage.Modules.SoundController)
    local Invoker = safeRequire(ReplicatedStorage.Modules.UI.Invoker)
    
    -- Если модули не загрузились, создаем заглушки
    if not Portfolio then
        Portfolio = {
            GetPortfolio = function() return {} end,
            GetAll = function() return nil end,
            Accept = function() end,
            Evict = function() end,
            Deny = function() end
        }
        warn("Portfolio module not found, using stub")
    end
    
    if not Building then
        Building = {}
        warn("Building module not found, using stub")
    end
    
    if not PlayerDataClient then
        PlayerDataClient = {
            Get = function() return 0 end,
            Loaded = function() return true end
        }
        warn("PlayerDataClient module not found, using stub")
    end
    
    if not Number then
        Number = {
            shortennumber = function(num) return tostring(num) end
        }
        warn("Number module not found, using stub")
    end
    
    if not Invoker then
        Invoker = {
            Clicked = function() end
        }
        warn("Invoker module not found, using stub")
    end

    -- Конфигурация (можно редактировать)
    local Config = {
        -- Настройки звезд
        MIN_STARS_FOR_REPLACEMENT = 5,
        MIN_STARS_FOR_NEW = 5,
        MAX_STARS = 6,
        
        -- Настройки банка
        AUTO_DEPOSIT_ENABLED = true,
        DEPOSIT_THRESHOLD = 1000000,
        KEEP_CASH_AMOUNT = 100000,
        AUTO_CLAIM_BANK_INTEREST = true,
        
        -- Общие настройки
        CHECK_INTERVAL = 5,
        AUTO_DENY_BAD_APPLICANTS = true,
        AUTO_ACCEPT_GOOD_APPLICANTS = true,
        AGGRESSIVE_REPLACEMENT = true,
        PRIORITIZE_HIGHER_STARS = true,
        ONLY_5_6_STARS = true,
        
        -- Уведомления
        SHOW_NOTIFICATIONS = true,
        PLAY_SOUNDS = true,
        
        -- Визуальные настройки
        GUI_OPACITY = 0.95,
        GUI_THEME = "Dark",
        ANIMATIONS_ENABLED = true
    }

    -- Глобальные переменные
    local isRunning = false
    local isGUIVisible = true
    local cycleCount = 0
    local processedRenters = {}
    local processedApplicants = {}
    local lastUpdateTime = 0
    local guiElements = {}
    local dataUpdateConnection = nil
    local tabContents = {}
    local currentTab = "stats"
    local logs = {}
    local MAX_LOGS = 50
    local dragDetector = nil

    -- Статистика
    local statsData = {
        totalProperties = 0,
        totalValue = 0,
        totalIncome = 0,
        totalExpenses = 0,
        netProfit = 0,
        totalRenters = 0,
        occupiedSpots = 0,
        totalSpots = 0,
        occupancyRate = 0,
        averageStars = 0,
        fiveStarRenters = 0,
        sixStarRenters = 0,
        lowStarRenters = 0,
        cashBalance = 0,
        bankBalance = 0,
        bankToCollect = 0,
        interestRate = 0,
        maxTimeLevel = 0,
        buildingTypes = {},
        totalBuildings = 0,
        totalReplacements = 0,
        totalAccepted = 0,
        totalEvicted = 0,
        totalStarsImproved = 0,
        bankDepositsMade = 0,
        interestCollected = 0,
        totalDeposited = 0,
        sessionProfit = 0,
        cycleTime = 0
    }

    -- Цветовая схема
    local Colors = {
        Dark = {
            Background = Color3.fromRGB(15, 15, 25),
            Secondary = Color3.fromRGB(30, 30, 45),
            Tertiary = Color3.fromRGB(40, 40, 60),
            Text = Color3.fromRGB(255, 255, 255),
            SubText = Color3.fromRGB(200, 210, 230),
            Success = Color3.fromRGB(100, 255, 100),
            Error = Color3.fromRGB(255, 100, 100),
            Warning = Color3.fromRGB(255, 200, 100),
            Info = Color3.fromRGB(100, 200, 255),
            Money = Color3.fromRGB(100, 255, 100),
            Accent = Color3.fromRGB(100, 150, 255)
        },
        Light = {
            Background = Color3.fromRGB(240, 240, 245),
            Secondary = Color3.fromRGB(220, 220, 230),
            Tertiary = Color3.fromRGB(200, 200, 210),
            Text = Color3.fromRGB(20, 20, 30),
            SubText = Color3.fromRGB(80, 90, 110),
            Success = Color3.fromRGB(0, 180, 0),
            Error = Color3.fromRGB(220, 0, 0),
            Warning = Color3.fromRGB(220, 150, 0),
            Info = Color3.fromRGB(0, 150, 220),
            Money = Color3.fromRGB(0, 180, 0),
            Accent = Color3.fromRGB(0, 120, 220)
        }
    }

    local currentColors = Colors[Config.GUI_THEME] or Colors.Dark

    -- Функция форматирования чисел
    local function formatNumber(num)
        if not num then return "0" end
        num = tonumber(num) or 0
        return Number.shortennumber(num, 1, false) or tostring(num)
    end

    -- Функция логирования
    local function log(message, type)
        local timestamp = os.date("%H:%M:%S")
        local logEntry = {
            time = timestamp,
            message = message,
            type = type or "info"
        }
        
        table.insert(logs, 1, logEntry)
        
        if #logs > MAX_LOGS then
            table.remove(logs, MAX_LOGS + 1)
        end
        
        print(string.format("[AutoOptimizer] %s: %s", timestamp, message))
        
        -- Обновляем GUI логов если открыта вкладка
        if guiElements.logContainer and currentTab == "logs" then
            updateLogsGUI()
        end
    end

    -- Функция показа уведомления
    local function showNotification(title, message, color)
        if not Config.SHOW_NOTIFICATIONS then return end
        
        pcall(function()
            if Invoker and Invoker.Clicked then
                Invoker.Clicked("Notification", color or "Blue", title or "Auto Optimizer", message)
            end
        end)
    end

    -- Функция обновления всех данных
    local function updateGameData()
        pcall(function()
            -- Данные игрока
            statsData.cashBalance = PlayerDataClient.Get("Cash") or 0
            statsData.bankBalance = PlayerDataClient.Get("BankBalance") or 0
            statsData.bankToCollect = PlayerDataClient.Get("BankToCollect") or 0
            statsData.interestRate = PlayerDataClient.Get("InterestLevel") or 0
            statsData.maxTimeLevel = PlayerDataClient.Get("MaxTimeLevel") or 0
            
            if statsData.interestRate then
                statsData.interestRate = statsData.interestRate * 0.005 + 0.005
            end
            
            -- Данные портфеля
            local portfolio = Portfolio.GetPortfolio() or {}
            local totalProperties = 0
            local totalValue = 0
            local totalIncome = 0
            local totalExpenses = 0
            local totalRenters = 0
            local occupiedSpots = 0
            local totalSpots = 0
            local totalStars = 0
            local fiveStarCount = 0
            local sixStarCount = 0
            local lowStarCount = 0
            
            for propertyUID, property in pairs(portfolio) do
                if property and property.BuildingType and property.BuildingType ~= "Empty" then
                    totalProperties = totalProperties + 1
                    totalValue = totalValue + (property.Value or 0)
                    totalIncome = totalIncome + (property.Income or 0)
                    totalExpenses = totalExpenses + (property.Expenses or 0)
                    
                    if property.Renters then
                        local renterCount = 0
                        for renterId, renter in pairs(property.Renters) do
                            if renterId and renter then
                                renterCount = renterCount + 1
                                local stars = renter.Stars or 1
                                totalStars = totalStars + stars
                                
                                if stars == 5 then
                                    fiveStarCount = fiveStarCount + 1
                                elseif stars == 6 then
                                    sixStarCount = sixStarCount + 1
                                elseif stars < 5 then
                                    lowStarCount = lowStarCount + 1
                                end
                            end
                        end
                        totalRenters = totalRenters + renterCount
                        occupiedSpots = occupiedSpots + renterCount
                    end
                    
                    local buildingData = Building[property.BuildingType]
                    if buildingData then
                        local spots = buildingData.Spots or 0
                        if property.Built then
                            for _, upgrade in ipairs(property.Built) do
                                if upgrade ~= "Main" and buildingData.Upgrades and buildingData.Upgrades[upgrade] then
                                    spots = spots + (buildingData.Upgrades[upgrade].AddedRenters or 0)
                                end
                            end
                        end
                        totalSpots = totalSpots + spots
                    end
                end
            end
            
            -- Обновление статистики
            statsData.totalProperties = totalProperties
            statsData.totalValue = totalValue
            statsData.totalIncome = totalIncome
            statsData.totalExpenses = totalExpenses
            statsData.netProfit = totalIncome - totalExpenses
            statsData.totalRenters = totalRenters
            statsData.occupiedSpots = occupiedSpots
            statsData.totalSpots = totalSpots
            statsData.occupancyRate = totalSpots > 0 and (occupiedSpots / totalSpots * 100) or 0
            statsData.averageStars = totalRenters > 0 and (totalStars / totalRenters) or 0
            statsData.fiveStarRenters = fiveStarCount
            statsData.sixStarRenters = sixStarCount
            statsData.lowStarRenters = lowStarCount
            
            -- Обновление GUI
            updateStatsGUI()
            updateBankGUI()
        end)
    end

    -- Функция расчета мест
    local function calculateTotalSpots(property)
        if not property or property.BuildingType == "Empty" then return 0 end
        
        local buildingData = Building[property.BuildingType]
        if not buildingData then return 0 end
        
        local totalSpots = buildingData.Spots or 0
        
        if property.Built then
            for _, upgrade in ipairs(property.Built) do
                if upgrade ~= "Main" and buildingData.Upgrades and buildingData.Upgrades[upgrade] then
                    totalSpots = totalSpots + (buildingData.Upgrades[upgrade].AddedRenters or 0)
                end
            end
        end
        
        return totalSpots
    end

    -- Функция проверки звезд
    local function isValidStars(stars, minStars)
        if not stars then return false end
        local min = minStars or Config.MIN_STARS_FOR_NEW
        return stars >= min and stars <= Config.MAX_STARS
    end

    -- Функция получения заявок
    local function getAllApplicantsSorted(propertyUID)
        if not propertyUID then return {} end
        
        local property = Portfolio.GetAll(propertyUID)
        if not property or not property.Applicants then return {} end
        
        local applicants = {}
        
        for applicantId, applicant in pairs(property.Applicants) do
            if applicantId and applicant then
                local cacheKey = propertyUID .. "_" .. applicantId
                if not processedApplicants[cacheKey] then
                    local stars = applicant.Stars or 1
                    if isValidStars(stars, Config.MIN_STARS_FOR_NEW) then
                        table.insert(applicants, {
                            id = applicantId,
                            stars = stars,
                            data = applicant
                        })
                    end
                end
            end
        end
        
        if #applicants > 0 then
            table.sort(applicants, function(a, b)
                if a.stars ~= b.stars then
                    return a.stars > b.stars
                end
                return a.id < b.id
            end)
        end
        
        return applicants
    end

    -- Функция получения арендаторов
    local function getAllRentersSorted(propertyUID)
        if not propertyUID then return {} end
        
        local property = Portfolio.GetAll(propertyUID)
        if not property or not property.Renters then return {} end
        
        local renters = {}
        
        for renterId, renter in pairs(property.Renters) do
            if renterId and renter then
                local cacheKey = propertyUID .. "_" .. renterId
                if not processedRenters[cacheKey] then
                    local stars = renter.Stars or 1
                    table.insert(renters, {
                        id = renterId,
                        stars = stars,
                        data = renter
                    })
                end
            end
        end
        
        if #renters > 0 then
            table.sort(renters, function(a, b)
                return a.stars < b.stars
            end)
        end
        
        return renters
    end

    -- Функция принятия арендатора
    local function acceptApplicant(propertyUID, applicantId)
        if not propertyUID or not applicantId then return false, "Invalid params" end
        
        local success, result = pcall(function()
            if Portfolio and Portfolio.Accept then
                Portfolio.Accept(propertyUID, applicantId)
                return true
            else
                return false, "Portfolio.Accept not available"
            end
        end)
        
        if success then
            processedApplicants[propertyUID .. "_" .. applicantId] = true
            statsData.totalAccepted = (statsData.totalAccepted or 0) + 1
            return true, "Accepted"
        else
            return false, "Error: " .. tostring(result)
        end
    end

    -- Функция выселения арендатора
    local function evictRenter(propertyUID, renterId)
        if not propertyUID or not renterId then return false, "Invalid params" end
        
        local success, result = pcall(function()
            if Portfolio and Portfolio.Evict then
                Portfolio.Evict(propertyUID, renterId)
                return true
            else
                return false, "Portfolio.Evict not available"
            end
        end)
        
        if success then
            processedRenters[propertyUID .. "_" .. renterId] = true
            statsData.totalEvicted = (statsData.totalEvicted or 0) + 1
            return true, "Evicted"
        else
            return false, "Error: " .. tostring(result)
        end
    end

    -- Функция отклонения заявки
    local function denyApplicant(propertyUID, applicantId)
        if not propertyUID or not applicantId then return false, "Invalid params" end
        
        local success, result = pcall(function()
            if Portfolio and Portfolio.Deny then
                Portfolio.Deny(propertyUID, applicantId)
                return true
            else
                return false, "Portfolio.Deny not available"
            end
        end)
        
        if success then
            processedApplicants[propertyUID .. "_" .. applicantId] = true
            return true, "Denied"
        else
            return false, "Error: " .. tostring(result)
        end
    end

    -- Функция депозита в банк
    local function autoDepositToBank()
        if not Config.AUTO_DEPOSIT_ENABLED then return false end
        
        local cash = statsData.cashBalance or 0
        local bankBalance = statsData.bankBalance or 0
        local maxBalance = 1000000000000
        
        if cash > Config.DEPOSIT_THRESHOLD then
            local amountToDeposit = cash - Config.KEEP_CASH_AMOUNT
            
            if bankBalance + amountToDeposit > maxBalance then
                amountToDeposit = maxBalance - bankBalance
            end
            
            if amountToDeposit > 0 then
                pcall(function()
                    if Invoker and Invoker.Clicked then
                        Invoker.Clicked("Deposit", amountToDeposit)
                    end
                    
                    statsData.bankDepositsMade = (statsData.bankDepositsMade or 0) + 1
                    statsData.totalDeposited = (statsData.totalDeposited or 0) + amountToDeposit
                    
                    log(string.format("Депозит: $%s в банк", formatNumber(amountToDeposit)), "money")
                    showNotification("💰 Банк", string.format("Депозит: $%s", formatNumber(amountToDeposit)), "Blue")
                    
                    if Config.PLAY_SOUNDS and SoundController and SoundController.PlaySound then
                        SoundController.PlaySound("SmallSuccessA")
                    end
                    
                    return true
                end)
            end
        end
        
        return false
    end

    -- Функция сбора процентов
    local function claimBankInterest()
        if not Config.AUTO_CLAIM_BANK_INTEREST then return false end
        
        local toCollect = statsData.bankToCollect or 0
        
        if toCollect > 0 then
            pcall(function()
                if Invoker and Invoker.Clicked then
                    Invoker.Clicked("ClaimInterest")
                end
                
                statsData.interestCollected = (statsData.interestCollected or 0) + toCollect
                
                log(string.format("Проценты: $%s собрано", formatNumber(toCollect)), "money")
                showNotification("💰 Банк", string.format("Проценты: $%s", formatNumber(toCollect)), "Blue")
                
                if Config.PLAY_SOUNDS and SoundController and SoundController.PlaySound then
                    SoundController.PlaySound("Reward")
                end
                
                return true
            end)
        end
        
        return false
    end

    -- Функция оптимизации здания
    local function optimizeProperty(propertyUID)
        if not propertyUID then return "error" end
        
        local property = Portfolio.GetAll(propertyUID)
        if not property or property.BuildingType == "Empty" then return "skip_empty" end
        
        local totalSpots = calculateTotalSpots(property)
        local currentRenters = getAllRentersSorted(propertyUID)
        local currentApplicants = getAllApplicantsSorted(propertyUID)
        
        -- Заполнение свободных мест
        if #currentRenters < totalSpots and #currentApplicants > 0 then
            local spotsToFill = totalSpots - #currentRenters
            local filled = 0
            
            for i = 1, math.min(spotsToFill, #currentApplicants) do
                local applicant = currentApplicants[i]
                if applicant and applicant.stars >= Config.MIN_STARS_FOR_NEW then
                    local success, msg = acceptApplicant(propertyUID, applicant.id)
                    if success then
                        filled = filled + 1
                        log(string.format("%s: Принят %d⭐", propertyUID, applicant.stars), "hire")
                        task.wait(0.1) -- Уменьшил время ожидания
                    end
                end
            end
            
            if filled > 0 then
                return string.format("filled|%d", filled)
            end
        end
        
        -- Замена арендаторов
        if #currentRenters > 0 and #currentApplicants > 0 then
            local replaced = 0
            
            -- Находим худшего арендатора
            local worstRenter = currentRenters[1]
            if worstRenter then
                -- Ищем лучшего аппликанта
                for _, applicant in ipairs(currentApplicants) do
                    if applicant.stars > worstRenter.stars then
                        -- Выселяем старого
                        local success1, msg1 = evictRenter(propertyUID, worstRenter.id)
                        if success1 then
                            task.wait(0.2)
                            
                            -- Принимаем нового
                            local success2, msg2 = acceptApplicant(propertyUID, applicant.id)
                            if success2 then
                                replaced = replaced + 1
                                statsData.totalReplacements = (statsData.totalReplacements or 0) + 1
                                statsData.totalStarsImproved = (statsData.totalStarsImproved or 0) + (applicant.stars - worstRenter.stars)
                                
                                log(string.format("%s: Замена %d⭐ → %d⭐", propertyUID, worstRenter.stars, applicant.stars), "spot")
                                
                                task.wait(0.1)
                                break
                            end
                        end
                    end
                end
            end
            
            if replaced > 0 then
                return string.format("replaced|%d", replaced)
            end
        end
        
        -- Отклонение плохих заявок
        if Config.AUTO_DENY_BAD_APPLICANTS then
            local denied = 0
            for applicantId, applicant in pairs(property.Applicants or {}) do
                local stars = applicant.Stars or 1
                if stars < Config.MIN_STARS_FOR_NEW then
                    local success, msg = denyApplicant(propertyUID, applicantId)
                    if success then
                        denied = denied + 1
                    end
                end
            end
            
            if denied > 0 then
                return string.format("denied|%d", denied)
            end
        end
        
        return "no_changes"
    end

    -- Основная функция оптимизации
    local function optimizeAllProperties()
        local cycleStartTime = tick()
        cycleCount = cycleCount + 1
        
        log(string.format("ЦИКЛ #%d - МИН ЗВЕЗДЫ: %d", cycleCount, Config.MIN_STARS_FOR_NEW), "info")
        
        -- Обновление данных
        updateGameData()
        
        -- Операции с банком
        if Config.AUTO_CLAIM_BANK_INTEREST then
            claimBankInterest()
        end
        
        if Config.AUTO_DEPOSIT_ENABLED then
            autoDepositToBank()
        end
        
        local optimizedCount = 0
        local totalFilled = 0
        local totalReplaced = 0
        
        -- Оптимизация всех зданий
        local portfolio = Portfolio.GetPortfolio() or {}
        for propertyUID, property in pairs(portfolio) do
            if property and property.BuildingType and property.BuildingType ~= "Empty" then
                local result = optimizeProperty(propertyUID)
                
                if result:find("filled|") then
                    local filled = tonumber(result:match("filled|(%d+)")) or 0
                    optimizedCount = optimizedCount + 1
                    totalFilled = totalFilled + filled
                elseif result:find("replaced|") then
                    local replaced = tonumber(result:match("replaced|(%d+)")) or 0
                    optimizedCount = optimizedCount + 1
                    totalReplaced = totalReplaced + replaced
                end
                
                task.wait(0.05) -- Уменьшил время ожидания
            end
        end
        
        -- Обновление статистики
        statsData.cycleTime = tick() - cycleStartTime
        statsData.lastOptimizationTime = os.time()
        lastUpdateTime = os.time()
        
        -- Логирование
        if totalFilled > 0 then
            log(string.format("Заполнено: %d мест", totalFilled), "success")
        end
        if totalReplaced > 0 then
            log(string.format("Заменено: %d арендаторов", totalReplaced), "spot")
        end
        if optimizedCount == 0 then
            log("Все здания оптимизированы", "info")
        end
        
        updateStatsGUI()
        
        return optimizedCount
    end

    -- UI Drag Detector
    local UIDragDetector = {}
    UIDragDetector.__index = UIDragDetector

    function UIDragDetector.new(frame, dragButton)
        local self = setmetatable({}, UIDragDetector)
        
        self.frame = frame
        self.dragButton = dragButton or frame
        self.dragging = false
        self.dragInput = nil
        self.dragStart = nil
        self.startPos = nil
        
        self.connection1 = self.dragButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                self.dragging = true
                self.dragStart = input.Position
                self.startPos = self.frame.Position
                
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        self.dragging = false
                    end
                end)
            end
        end)
        
        self.connection2 = self.dragButton.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                self.dragInput = input
            end
        end)
        
        self.connection3 = UserInputService.InputChanged:Connect(function(input)
            if input == self.dragInput and self.dragging then
                local delta = input.Position - self.dragStart
                self.frame.Position = UDim2.new(
                    self.startPos.X.Scale,
                    self.startPos.X.Offset + delta.X,
                    self.startPos.Y.Scale,
                    self.startPos.Y.Offset + delta.Y
                )
            end
        end)
        
        return self
    end

    function UIDragDetector:Destroy()
        if self.connection1 then self.connection1:Disconnect() end
        if self.connection2 then self.connection2:Disconnect() end
        if self.connection3 then self.connection3:Disconnect() end
    end

    -- Функция создания элемента GUI
    local function createElement(className, properties)
        local element = Instance.new(className)
        for prop, value in pairs(properties) do
            if prop ~= "Parent" and prop ~= "Children" then
                if pcall(function() return element[prop] end) then
                    element[prop] = value
                end
            end
        end
        return element
    end

    -- Функция создания карточки статистики
    local function createStatCard(parent, label, defaultValue, isMoney, layoutOrder)
        local card = createElement("Frame", {
            Name = label .. "Card",
            Size = UDim2.new(1, -20, 0, 40),
            BackgroundColor3 = currentColors.Tertiary,
            BorderSizePixel = 0,
            LayoutOrder = layoutOrder,
            Parent = parent
        })
        
        createElement("UICorner", {
            CornerRadius = UDim.new(0, 8),
            Parent = card
        })
        
        local labelText = createElement("TextLabel", {
            Size = UDim2.new(0.6, -5, 1, 0),
            Position = UDim2.new(0, 10, 0, 0),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = currentColors.SubText,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card
        })
        
        local valueText = createElement("TextLabel", {
            Size = UDim2.new(0.4, 0, 1, 0),
            Position = UDim2.new(0.6, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = defaultValue or "0",
            TextColor3 = isMoney and currentColors.Money or currentColors.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = card
        })
        
        createElement("UIPadding", {
            PaddingRight = UDim.new(0, 10),
            Parent = valueText
        })
        
        return valueText
    end

    -- Обновление GUI статистики
    local function updateStatsGUI()
        if not guiElements.statsContainer or currentTab ~= "stats" then return end
        
        pcall(function()
            if guiElements.cashLabel then guiElements.cashLabel.Text = "$" .. formatNumber(statsData.cashBalance) end
            if guiElements.bankLabel then guiElements.bankLabel.Text = "$" .. formatNumber(statsData.bankBalance) end
            if guiElements.bankToCollectLabel then guiElements.bankToCollectLabel.Text = "$" .. formatNumber(statsData.bankToCollect) end
            if guiElements.totalIncomeLabel then guiElements.totalIncomeLabel.Text = "$" .. formatNumber(statsData.totalIncome) .. "/час" end
            if guiElements.netProfitLabel then guiElements.netProfitLabel.Text = "$" .. formatNumber(statsData.netProfit) .. "/час" end
            if guiElements.propertiesLabel then guiElements.propertiesLabel.Text = tostring(statsData.totalProperties) end
            if guiElements.totalValueLabel then guiElements.totalValueLabel.Text = "$" .. formatNumber(statsData.totalValue) end
            if guiElements.totalRentersLabel then guiElements.totalRentersLabel.Text = tostring(statsData.totalRenters) end
            if guiElements.averageStarsLabel then guiElements.averageStarsLabel.Text = string.format("%.1f", statsData.averageStars) end
            if guiElements.fiveStarLabel then guiElements.fiveStarLabel.Text = tostring(statsData.fiveStarRenters) end
            if guiElements.sixStarLabel then guiElements.sixStarLabel.Text = tostring(statsData.sixStarRenters) end
            if guiElements.lowStarLabel then guiElements.lowStarLabel.Text = tostring(statsData.lowStarRenters) end
            if guiElements.occupiedSpotsLabel then guiElements.occupiedSpotsLabel.Text = string.format("%d/%d", statsData.occupiedSpots, statsData.totalSpots) end
            if guiElements.occupancyLabel then guiElements.occupancyLabel.Text = string.format("%.1f%%", statsData.occupancyRate) end
            if guiElements.replacementsLabel then guiElements.replacementsLabel.Text = tostring(statsData.totalReplacements) end
            if guiElements.acceptedLabel then guiElements.acceptedLabel.Text = tostring(statsData.totalAccepted) end
            if guiElements.evictedLabel then guiElements.evictedLabel.Text = tostring(statsData.totalEvicted) end
            if guiElements.bankDepositsLabel then guiElements.bankDepositsLabel.Text = tostring(statsData.bankDepositsMade) end
            if guiElements.interestCollectedLabel then guiElements.interestCollectedLabel.Text = "$" .. formatNumber(statsData.interestCollected) end
            if guiElements.cycleCountLabel then guiElements.cycleCountLabel.Text = tostring(cycleCount) end
            
            if guiElements.lastUpdateLabel then
                local timeDiff = os.time() - lastUpdateTime
                local minutes = math.floor(timeDiff / 60)
                local seconds = timeDiff % 60
                guiElements.lastUpdateLabel.Text = string.format("%d:%02d", minutes, seconds)
            end
        end)
    end

    -- Получение цвета для типа лога
    local function getLogColor(type)
        if type == "success" then return currentColors.Success
        elseif type == "error" then return currentColors.Error
        elseif type == "warning" then return currentColors.Warning
        elseif type == "money" then return currentColors.Money
        elseif type == "spot" then return currentColors.Info
        elseif type == "hire" then return Color3.fromRGB(255, 150, 100)
        else return currentColors.SubText end
    end

    -- Обновление GUI логов
    local function updateLogsGUI()
        if not guiElements.logContainer or currentTab ~= "logs" then return end
        
        pcall(function()
            -- Очищаем контейнер
            for _, child in ipairs(guiElements.logContainer:GetChildren()) do
                if child:IsA("Frame") and child.Name ~= "ControlsFrame" then
                    child:Destroy()
                end
            end
            
            -- Добавляем логи
            for i, logEntry in ipairs(logs) do
                local logFrame = createElement("Frame", {
                    Size = UDim2.new(1, -10, 0, 30),
                    BackgroundColor3 = currentColors.Tertiary,
                    LayoutOrder = i + 1
                })
                
                createElement("UICorner", {
                    CornerRadius = UDim.new(0, 6),
                    Parent = logFrame
                })
                
                local timeLabel = createElement("TextLabel", {
                    Size = UDim2.new(0, 60, 1, 0),
                    BackgroundTransparency = 1,
                    Text = "[" .. logEntry.time .. "]",
                    TextColor3 = currentColors.SubText,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = logFrame
                })
                
                createElement("UIPadding", {
                    PaddingLeft = UDim.new(0, 5),
                    Parent = timeLabel
                })
                
                local messageLabel = createElement("TextLabel", {
                    Size = UDim2.new(1, -65, 1, 0),
                    Position = UDim2.new(0, 65, 0, 0),
                    BackgroundTransparency = 1,
                    Text = logEntry.message,
                    TextColor3 = getLogColor(logEntry.type),
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Parent = logFrame
                })
                
                logFrame.Parent = guiElements.logContainer
            end
        end)
    end

    -- Создание вкладки настроек
    local function createSettingsTab()
        local settingsContainer = createElement("ScrollingFrame", {
            Name = "SettingsContainer",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = currentColors.Accent,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false
        })
        
        tabContents.settings = settingsContainer
        
        local layout = createElement("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = settingsContainer
        })
        
        -- Секция: Настройки звезд
        local starsSection = createElement("Frame", {
            Size = UDim2.new(1, -20, 0, 150),
            BackgroundColor3 = currentColors.Tertiary,
            LayoutOrder = 1
        })
        
        createElement("UICorner", {
            CornerRadius = UDim.new(0, 8),
            Parent = starsSection
        })
        
        createElement("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = "⭐ НАСТРОЙКИ ЗВЕЗД",
            TextColor3 = currentColors.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = starsSection
        })
        
        createElement("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
            Parent = starsSection:FindFirstChild("TextLabel")
        })
        
        -- Функция создания слайдера
        local function createSlider(label, minValue, maxValue, defaultValue, callback)
            local sliderFrame = createElement("Frame", {
                Size = UDim2.new(1, -20, 0, 50),
                BackgroundTransparency = 1,
                LayoutOrder = 1
            })
            
            local labelText = createElement("TextLabel", {
                Size = UDim2.new(0.5, 0, 0.5, 0),
                BackgroundTransparency = 1,
                Text = label,
                TextColor3 = currentColors.SubText,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = sliderFrame
            })
            
            local valueText = createElement("TextLabel", {
                Size = UDim2.new(0.2, 0, 0.5, 0),
                Position = UDim2.new(0.5, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(defaultValue),
                TextColor3 = currentColors.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                Parent = sliderFrame
            })
            
            local sliderBar = createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 4),
                Position = UDim2.new(0, 0, 1, -10),
                BackgroundColor3 = currentColors.Secondary,
                Parent = sliderFrame
            })
            
            createElement("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = sliderBar
            })
            
            local sliderFill = createElement("Frame", {
                Size = UDim2.new((defaultValue - minValue) / (maxValue - minValue), 0, 1, 0),
                BackgroundColor3 = currentColors.Accent,
                Parent = sliderBar
            })
            
            createElement("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = sliderFill
            })
            
            local sliderButton = createElement("TextButton", {
                Size = UDim2.new(0, 20, 0, 20),
                Position = UDim2.new((defaultValue - minValue) / (maxValue - minValue), -10, 0.5, -10),
                BackgroundColor3 = currentColors.Text,
                Text = "",
                Parent = sliderBar
            })
            
            createElement("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = sliderButton
            })
            
            local dragging = false
            
            sliderButton.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                end
            end)
            
            sliderButton.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                end
            end)
            
            UserInputService.InputChanged:Connect(function(input)
                if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    local xPos = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
                    local value = math.floor(minValue + (maxValue - minValue) * xPos)
                    
                    valueText.Text = tostring(value)
                    sliderFill.Size = UDim2.new(xPos, 0, 1, 0)
                    sliderButton.Position = UDim2.new(xPos, -10, 0.5, -10)
                    
                    if callback then
                        callback(value)
                    end
                end
            end)
            
            return sliderFrame
        end
        
        -- Создание слайдеров внутри секции
        local starsLayout = createElement("UIListLayout", {
            Padding = UDim.new(0, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = starsSection
        })
        
        createElement("UIPadding", {
            PaddingTop = UDim.new(0, 35),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            Parent = starsSection
        })
        
        createSlider("Мин звезды (новые):", 1, 6, Config.MIN_STARS_FOR_NEW, function(value)
            Config.MIN_STARS_FOR_NEW = value
            log(string.format("Мин звезды (новые) установлено: %d", value), "info")
        end).Parent = starsSection
        
        createSlider("Мин звезды (замена):", 1, 6, Config.MIN_STARS_FOR_REPLACEMENT, function(value)
            Config.MIN_STARS_FOR_REPLACEMENT = value
            log(string.format("Мин звезды (замена) установлено: %d", value), "info")
        end).Parent = starsSection
        
        starsSection.Parent = settingsContainer
        
        -- Секция: Настройки банка
        local bankSection = createElement("Frame", {
            Size = UDim2.new(1, -20, 0, 180),
            BackgroundColor3 = currentColors.Tertiary,
            LayoutOrder = 2
        })
        
        createElement("UICorner", {
            CornerRadius = UDim.new(0, 8),
            Parent = bankSection
        })
        
        createElement("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = "💰 НАСТРОЙКИ БАНКА",
            TextColor3 = currentColors.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = bankSection
        })
        
        createElement("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
            Parent = bankSection:FindFirstChild("TextLabel")
        })
        
        createElement("UIPadding", {
            PaddingTop = UDim.new(0, 35),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            Parent = bankSection
        })
        
        local bankLayout = createElement("UIListLayout", {
            Padding = UDim.new(0, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = bankSection
        })
        
        createSlider("Порог депозита:", 1000, 10000000, Config.DEPOSIT_THRESHOLD, function(value)
            Config.DEPOSIT_THRESHOLD = value
            log(string.format("Порог депозита установлен: $%s", formatNumber(value)), "info")
        end).Parent = bankSection
        
        createSlider("Оставлять наличных:", 1000, 500000, Config.KEEP_CASH_AMOUNT, function(value)
            Config.KEEP_CASH_AMOUNT = value
            log(string.format("Оставлять наличных установлено: $%s", formatNumber(value)), "info")
        end).Parent = bankSection
        
        bankSection.Parent = settingsContainer
        
        -- Секция: Чекбоксы
        local checkboxesSection = createElement("Frame", {
            Size = UDim2.new(1, -20, 0, 250),
            BackgroundColor3 = currentColors.Tertiary,
            LayoutOrder = 3
        })
        
        createElement("UICorner", {
            CornerRadius = UDim.new(0, 8),
            Parent = checkboxesSection
        })
        
        createElement("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = "⚙️ ОБЩИЕ НАСТРОЙКИ",
            TextColor3 = currentColors.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = checkboxesSection
        })
        
        createElement("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
            Parent = checkboxesSection:FindFirstChild("TextLabel")
        })
        
        createElement("UIPadding", {
            PaddingTop = UDim.new(0, 35),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            Parent = checkboxesSection
        })
        
        local checkboxesLayout = createElement("UIListLayout", {
            Padding = UDim.new(0, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = checkboxesSection
        })
        
        -- Функция создания чекбокса
        local function createCheckbox(label, defaultValue, callback)
            local checkboxFrame = createElement("Frame", {
                Size = UDim2.new(1, -20, 0, 30),
                BackgroundTransparency = 1,
                LayoutOrder = 1
            })
            
            local labelText = createElement("TextLabel", {
                Size = UDim2.new(0.7, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = label,
                TextColor3 = currentColors.SubText,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = checkboxFrame
            })
            
            local checkButton = createElement("TextButton", {
                Size = UDim2.new(0, 25, 0, 25),
                Position = UDim2.new(1, -30, 0.5, -12.5),
                BackgroundColor3 = defaultValue and currentColors.Success or currentColors.Error,
                Text = defaultValue and "✓" or "✗",
                TextColor3 = currentColors.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                Parent = checkboxFrame
            })
            
            createElement("UICorner", {
                CornerRadius = UDim.new(0, 5),
                Parent = checkButton
            })
            
            checkButton.MouseButton1Click:Connect(function()
                defaultValue = not defaultValue
                checkButton.BackgroundColor3 = defaultValue and currentColors.Success or currentColors.Error
                checkButton.Text = defaultValue and "✓" or "✗"
                
                if callback then
                    callback(defaultValue)
                end
            end)
            
            return checkboxFrame
        end
        
        createCheckbox("Авто-депозит", Config.AUTO_DEPOSIT_ENABLED, function(value)
            Config.AUTO_DEPOSIT_ENABLED = value
            log("Авто-депозит: " .. (value and "ВКЛ" or "ВЫКЛ"), "info")
        end).Parent = checkboxesSection
        
        createCheckbox("Авто-проценты", Config.AUTO_CLAIM_BANK_INTEREST, function(value)
            Config.AUTO_CLAIM_BANK_INTEREST = value
            log("Авто-проценты: " .. (value and "ВКЛ" or "ВЫКЛ"), "info")
        end).Parent = checkboxesSection
        
        createCheckbox("Отклонять плохих", Config.AUTO_DENY_BAD_APPLICANTS, function(value)
            Config.AUTO_DENY_BAD_APPLICANTS = value
            log("Отклонять плохих: " .. (value and "ВКЛ" or "ВЫКЛ"), "info")
        end).Parent = checkboxesSection
        
        createCheckbox("Только 5-6⭐", Config.ONLY_5_6_STARS, function(value)
            Config.ONLY_5_6_STARS = value
            log("Только 5-6⭐: " .. (value and "ВКЛ" or "ВЫКЛ"), "info")
        end).Parent = checkboxesSection
        
        createCheckbox("Уведомления", Config.SHOW_NOTIFICATIONS, function(value)
            Config.SHOW_NOTIFICATIONS = value
            log("Уведомления: " .. (value and "ВКЛ" or "ВЫКЛ"), "info")
        end).Parent = checkboxesSection
        
        createCheckbox("Звуки", Config.PLAY_SOUNDS, function(value)
            Config.PLAY_SOUNDS = value
            log("Звуки: " .. (value and "ВКЛ" or "ВЫКЛ"), "info")
        end).Parent = checkboxesSection
        
        checkboxesSection.Parent = settingsContainer
        
        -- Кнопки сброса настроек
        local resetSection = createElement("Frame", {
            Size = UDim2.new(1, -20, 0, 120),
            BackgroundColor3 = currentColors.Tertiary,
            LayoutOrder = 4
        })
        
        createElement("UICorner", {
            CornerRadius = UDim.new(0, 8),
            Parent = resetSection
        })
        
        createElement("UIPadding", {
            Padding = UDim.new(0, 10),
            Parent = resetSection
        })
        
        local resetLayout = createElement("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = resetSection
        })
        
        local function createResetButton(text, color, callback)
            local button = createElement("TextButton", {
                Size = UDim2.new(1, 0, 0, 35),
                BackgroundColor3 = color,
                Text = text,
                TextColor3 = currentColors.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                LayoutOrder = 1
            })
            
            createElement("UICorner", {
                CornerRadius = UDim.new(0, 8),
                Parent = button
            })
            
            button.MouseButton1Click:Connect(function()
                if callback then
                    callback()
                end
            end)
            
            return button
        end
        
        createResetButton("🔄 Сбросить настройки", currentColors.Warning, function()
            Config.MIN_STARS_FOR_REPLACEMENT = 5
            Config.MIN_STARS_FOR_NEW = 5
            Config.AUTO_DEPOSIT_ENABLED = true
            Config.DEPOSIT_THRESHOLD = 1000000
            Config.KEEP_CASH_AMOUNT = 100000
            Config.AUTO_CLAIM_BANK_INTEREST = true
            Config.AUTO_DENY_BAD_APPLICANTS = true
            Config.ONLY_5_6_STARS = true
            Config.SHOW_NOTIFICATIONS = true
            Config.PLAY_SOUNDS = true
            
            log("Настройки сброшены к значениям по умолчанию", "info")
            showNotification("Настройки", "Настройки сброшены", "Blue")
            
            -- Перезагружаем вкладку настроек
            settingsContainer:Destroy()
            createSettingsTab()
            settingsContainer.Parent = guiElements.contentFrame
            tabContents.settings = settingsContainer
            switchTab(currentTab)
        end).Parent = resetSection
        
        createResetButton("💾 Сохранить настройки", currentColors.Success, function()
            log("Настройки сохранены", "success")
            showNotification("Настройки", "Настройки сохранены", "Green")
        end).Parent = resetSection
        
        resetSection.Parent = settingsContainer
        
        return settingsContainer
    end

    -- Создание вкладки логов
    local function createLogsTab()
        local logsContainer = createElement("ScrollingFrame", {
            Name = "LogsContainer",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = currentColors.Accent,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false
        })
        
        tabContents.logs = logsContainer
        
        local layout = createElement("UIListLayout", {
            Padding = UDim.new(0, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = logsContainer
        })
        
        guiElements.logContainer = logsContainer
        
        -- Кнопки управления логами
        local controlsFrame = createElement("Frame", {
            Name = "ControlsFrame",
            Size = UDim2.new(1, -20, 0, 40),
            BackgroundColor3 = currentColors.Tertiary,
            LayoutOrder = 0
        })
        
        createElement("UICorner", {
            CornerRadius = UDim.new(0, 8),
            Parent = controlsFrame
        })
        
        createElement("UIPadding", {
            Padding = UDim.new(0, 5),
            Parent = controlsFrame
        })
        
        local clearButton = createElement("TextButton", {
            Size = UDim2.new(0.5, -5, 1, -10),
            Position = UDim2.new(0, 5, 0, 5),
            BackgroundColor3 = currentColors.Error,
            Text = "Очистить логи",
            TextColor3 = currentColors.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            Parent = controlsFrame
        })
        
        createElement("UICorner", {
            CornerRadius = UDim.new(0, 6),
            Parent = clearButton
        })
        
        local exportButton = createElement("TextButton", {
            Size = UDim2.new(0.5, -5, 1, -10),
            Position = UDim2.new(0.5, 0, 0, 5),
            BackgroundColor3 = currentColors.Info,
            Text = "Экспорт",
            TextColor3 = currentColors.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            Parent = controlsFrame
        })
        
        createElement("UICorner", {
            CornerRadius = UDim.new(0, 6),
            Parent = exportButton
        })
        
        clearButton.MouseButton1Click:Connect(function()
            logs = {}
            updateLogsGUI()
            log("Логи очищены", "info")
        end)
        
        exportButton.MouseButton1Click:Connect(function()
            local logText = ""
            for _, logEntry in ipairs(logs) do
                logText = logText .. string.format("[%s] %s\n", logEntry.time, logEntry.message)
            end
            
            pcall(function()
                setclipboard(logText)
            end)
            
            log("Логи скопированы в буфер обмена", "success")
            showNotification("Логи", "Логи скопированы", "Green")
        end)
        
        controlsFrame.Parent = logsContainer
        
        return logsContainer
    end

    -- Обновление GUI банка
    local function updateBankGUI()
        if not guiElements.bankBalanceInfo then return end
        
        pcall(function()
            guiElements.bankBalanceInfo.Text = "$" .. formatNumber(statsData.bankBalance)
            guiElements.bankToCollectInfo.Text = "$" .. formatNumber(statsData.bankToCollect)
            guiElements.interestRateInfo.Text = string.format("%.3f%%", (statsData.interestRate or 0) * 100)
            guiElements.maxTimeInfo.Text = string.format("%dч", statsData.maxTimeLevel or 0)
        end)
    end

    -- Создание вкладки банка
    local function createBankTab()
        local bankContainer = createElement("ScrollingFrame", {
            Name = "BankContainer",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = currentColors.Accent,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false
        })
        
        tabContents.bank = bankContainer
        
        local layout = createElement("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = bankContainer
        })
        
        -- Информация о банке
        local infoSection = createElement("Frame", {
            Size = UDim2.new(1, -20, 0, 180),
            BackgroundColor3 = currentColors.Tertiary,
            LayoutOrder = 1
        })
        
        createElement("UICorner", {
            CornerRadius = UDim.new(0, 8),
            Parent = infoSection
        })
        
        createElement("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = "🏦 ИНФОРМАЦИЯ О БАНКЕ",
            TextColor3 = currentColors.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = infoSection
        })
        
        createElement("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
            Parent = infoSection:FindFirstChild("TextLabel")
        })
        
        createElement("UIPadding", {
            PaddingTop = UDim.new(0, 35),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            Parent = infoSection
        })
        
        local infoLayout = createElement("UIListLayout", {
            Padding = UDim.new(0, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = infoSection
        })
        
        local function createBankInfo(label, value, isMoney)
            local infoFrame = createElement("Frame", {
                Size = UDim2.new(1, -20, 0, 30),
                BackgroundTransparency = 1,
                LayoutOrder = 1
            })
            
            local labelText = createElement("TextLabel", {
                Size = UDim2.new(0.6, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = label,
                TextColor3 = currentColors.SubText,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = infoFrame
            })
            
            local valueText = createElement("TextLabel", {
                Size = UDim2.new(0.4, 0, 1, 0),
                Position = UDim2.new(0.6, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = value,
                TextColor3 = isMoney and currentColors.Money or currentColors.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = infoFrame
            })
            
            return infoFrame, valueText
        end
        
        local bankInfo1, guiElements.bankBalanceInfo = createBankInfo("Баланс:", "$0", true)
        bankInfo1.LayoutOrder = 1
        bankInfo1.Parent = infoSection
        
        local bankInfo2, guiElements.bankToCollectInfo = createBankInfo("К сбору:", "$0", true)
        bankInfo2.LayoutOrder = 2
        bankInfo2.Parent = infoSection
        
        local bankInfo3, guiElements.interestRateInfo = createBankInfo("Процентная ставка:", "0%", false)
        bankInfo3.LayoutOrder = 3
        bankInfo3.Parent = infoSection
        
        local bankInfo4, guiElements.maxTimeInfo = createBankInfo("Макс. время:", "0ч", false)
        bankInfo4.LayoutOrder = 4
        bankInfo4.Parent = infoSection
        
        infoSection.Parent = bankContainer
        
        -- Управление банком
        local controlSection = createElement("Frame", {
            Size = UDim2.new(1, -20, 0, 200),
            BackgroundColor3 = currentColors.Tertiary,
            LayoutOrder = 2
        })
        
        createElement("UICorner", {
            CornerRadius = UDim.new(0, 8),
            Parent = controlSection
        })
        
        createElement("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = "🎯 УПРАВЛЕНИЕ БАНКОМ",
            TextColor3 = currentColors.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = controlSection
        })
        
        createElement("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
            Parent = controlSection:FindFirstChild("TextLabel")
        })
        
        createElement("UIPadding", {
            PaddingTop = UDim.new(0, 35),
            Padding = UDim.new(0, 10),
            Parent = controlSection
        })
        
        local controlLayout = createElement("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = controlSection
        })
        
        local function createBankButton(text, color, callback)
            local button = createElement("TextButton", {
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundColor3 = color,
                Text = text,
                TextColor3 = currentColors.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                LayoutOrder = 1
            })
            
            createElement("UICorner", {
                CornerRadius = UDim.new(0, 8),
                Parent = button
            })
            
            button.MouseButton1Click:Connect(function()
                if callback then
                    callback()
                end
            end)
            
            return button
        end
        
        createBankButton("💰 Собрать проценты", currentColors.Success, function()
            claimBankInterest()
            updateGameData()
        end).Parent = controlSection
        
        createBankButton("💳 Сделать депозит", currentColors.Info, function()
            autoDepositToBank()
            updateGameData()
        end).Parent = controlSection
        
        createBankButton("📈 Обновить банк", currentColors.Accent, function()
            updateGameData()
            log("Данные банка обновлены", "info")
        end).Parent = controlSection
        
        controlSection.Parent = bankContainer
        
        return bankContainer
    end

    -- Функция переключения вкладок
    local function switchTab(tabId)
        currentTab = tabId
        
        -- Скрываем все вкладки
        for id, container in pairs(tabContents) do
            if container then
                container.Visible = false
            end
        end
        
        -- Показываем выбранную вкладку
        if tabContents[tabId] then
            tabContents[tabId].Visible = true
        end
        
        -- Обновляем кнопки вкладок
        if guiElements.tabButtons then
            for id, button in pairs(guiElements.tabButtons) do
                if button then
                    button.BackgroundColor3 = id == tabId and currentColors.Accent or currentColors.Tertiary
                end
            end
        end
        
        -- Обновляем данные если нужно
        if tabId == "stats" then
            updateStatsGUI()
        elseif tabId == "logs" then
            updateLogsGUI()
        elseif tabId == "bank" then
            updateBankGUI()
        end
    end

    -- Создание основного GUI
    local function createModernGUI()
        local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
        
        -- Удаляем старый GUI
        local oldGUI = PlayerGui:FindFirstChild("AutoOptimizerPro")
        if oldGUI then oldGUI:Destroy() end
        
        -- Создаем ScreenGui
        local screenGui = createElement("ScreenGui", {
            Name = "AutoOptimizerPro",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            Parent = PlayerGui
        })
        
        -- Основной контейнер
        local mainContainer = createElement("Frame", {
            Name = "MainContainer",
            Size = UDim2.new(0.35, 0, 0.7, 0),
            Position = UDim2.new(0.65, 0, 0.15, 0),
            BackgroundColor3 = currentColors.Background,
            BackgroundTransparency = 1 - Config.GUI_OPACITY,
            BorderSizePixel = 0,
            ClipsDescendants = true
        })
        
        createElement("UICorner", {
            CornerRadius = UDim.new(0, 12),
            Parent = mainContainer
        })
        
        createElement("UIStroke", {
            Color = currentColors.Accent,
            Thickness = 2,
            Parent = mainContainer
        })
        
        -- Drag Detector для всего контейнера
        dragDetector = UIDragDetector.new(mainContainer)
        
        -- Верхняя панель
        local topBar = createElement("Frame", {
            Name = "TopBar",
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = currentColors.Secondary,
            BorderSizePixel = 0,
            Parent = mainContainer
        })
        
        createElement("UICorner", {
            CornerRadius = UDim.new(0, 12),
            Parent = topBar
        })
        
        local title = createElement("TextLabel", {
            Size = UDim2.new(0.7, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "⚡ AUTO OPTIMIZER v10.0",
            TextColor3 = currentColors.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = topBar
        })
        
        createElement("UIPadding", {
            PaddingLeft = UDim.new(0, 15),
            Parent = title
        })
        
        -- Кнопки управления окном
        local closeButton = createElement("TextButton", {
            Size = UDim2.new(0, 30, 0, 30),
            Position = UDim2.new(1, -35, 0.5, -15),
            BackgroundTransparency = 1,
            Text = "✕",
            TextColor3 = currentColors.Error,
            Font = Enum.Font.GothamBold,
            TextSize = 18,
            Parent = topBar
        })
        
        local minimizeButton = createElement("TextButton", {
            Size = UDim2.new(0, 30, 0, 30),
            Position = UDim2.new(1, -70, 0.5, -15),
            BackgroundTransparency = 1,
            Text = "🗕",
            TextColor3 = currentColors.SubText,
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            Parent = topBar
        })
        
        -- Статус
        local statusLabel = createElement("TextLabel", {
            Size = UDim2.new(0.25, 0, 1, 0),
            Position = UDim2.new(0.75, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = "⏹ СТОП",
            TextColor3 = currentColors.Error,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = topBar
        })
        
        createElement("UIPadding", {
            PaddingRight = UDim.new(0, 10),
            Parent = statusLabel
        })
        
        guiElements.statusLabel = statusLabel
        
        -- Панель вкладок
        local tabBar = createElement("Frame", {
            Name = "TabBar",
            Size = UDim2.new(1, 0, 0, 40),
            Position = UDim2.new(0, 0, 0, 40),
            BackgroundColor3 = currentColors.Tertiary,
            BorderSizePixel = 0,
            Parent = mainContainer
        })
        
        local tabs = {
            {id = "stats", text = "📊 Статистика"},
            {id = "settings", text = "⚙️ Настройки"},
            {id = "bank", text = "💰 Банк"},
            {id = "logs", text = "📝 Логи"}
        }
        
        guiElements.tabButtons = {}
        
        for i, tab in ipairs(tabs) do
            local tabButton = createElement("TextButton", {
                Size = UDim2.new(1 / #tabs, 0, 1, 0),
                Position = UDim2.new((i-1) / #tabs, 0, 0, 0),
                BackgroundColor3 = tab.id == currentTab and currentColors.Accent or currentColors.Tertiary,
                Text = tab.text,
                TextColor3 = currentColors.Text,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                Name = tab.id .. "Tab",
                Parent = tabBar
            })
            
            tabButton.MouseButton1Click:Connect(function()
                switchTab(tab.id)
            end)
            
            guiElements.tabButtons[tab.id] = tabButton
        end
        
        -- Контейнер для контента
        local contentFrame = createElement("Frame", {
            Name = "ContentFrame",
            Size = UDim2.new(1, 0, 1, -80),
            Position = UDim2.new(0, 0, 0, 80),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = mainContainer
        })
        
        guiElements.contentFrame = contentFrame
        
        -- Создаем вкладку статистики
        local statsContainer = createElement("ScrollingFrame", {
            Name = "StatsContainer",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = currentColors.Accent,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Parent = contentFrame
        })
        
        tabContents.stats = statsContainer
        guiElements.statsContainer = statsContainer
        
        local statsLayout = createElement("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = statsContainer
        })
        
        createElement("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            Parent = statsContainer
        })
        
        -- Создаем карточки статистики
        local statCards = {
            {label = "Наличные:", id = "cashLabel", money = true},
            {label = "Банк:", id = "bankLabel", money = true},
            {label = "Банк %:", id = "bankToCollectLabel", money = true},
            {label = "Доход/час:", id = "totalIncomeLabel", money = true},
            {label = "Чистая прибыль:", id = "netProfitLabel", money = true},
            {label = "Объекты:", id = "propertiesLabel", money = false},
            {label = "Стоимость:", id = "totalValueLabel", money = true},
            {label = "Арендаторы:", id = "totalRentersLabel", money = false},
            {label = "Ср. звезды:", id = "averageStarsLabel", money = false},
            {label = "5⭐:", id = "fiveStarLabel", money = false},
            {label = "6⭐:", id = "sixStarLabel", money = false},
            {label = "Низкие:", id = "lowStarLabel", money = false},
            {label = "Занято:", id = "occupiedSpotsLabel", money = false},
            {label = "Заполненность:", id = "occupancyLabel", money = false},
            {label = "Замены:", id = "replacementsLabel", money = false},
            {label = "Принято:", id = "acceptedLabel", money = false},
            {label = "Выселено:", id = "evictedLabel", money = false},
            {label = "Депозиты:", id = "bankDepositsLabel", money = false},
            {label = "Проценты:", id = "interestCollectedLabel", money = true},
            {label = "Циклы:", id = "cycleCountLabel", money = false},
            {label = "Обновлено:", id = "lastUpdateLabel", money = false}
        }
        
        for i, card in ipairs(statCards) do
            guiElements[card.id] = createStatCard(statsContainer, card.label, "0", card.money, i)
        end
        
        -- Кнопки управления внизу
        local bottomButtons = createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 120),
            BackgroundTransparency = 1,
            LayoutOrder = 999
        })
        
        createElement("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            Parent = bottomButtons
        })
        
        local buttonsLayout = createElement("UIListLayout", {
            Padding = UDim.new(0, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = bottomButtons
        })
        
        local function createActionButton(text, color, callback)
            local button = createElement("TextButton", {
                Size = UDim2.new(1, 0, 0, 35),
                BackgroundColor3 = color,
                Text = text,
                TextColor3 = currentColors.Text,
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                LayoutOrder = 1
            })
            
            createElement("UICorner", {
                CornerRadius = UDim.new(0, 8),
                Parent = button
            })
            
            button.MouseButton1Click:Connect(function()
                if callback then
                    callback()
                end
            end)
            
            return button
        end
        
        local startButton = createActionButton("🚀 ЗАПУСТИТЬ АВТООПТИМИЗАЦИЮ", Color3.fromRGB(0, 180, 0), function()
            if not isRunning then
                startAutoOptimizer()
            else
                stopOptimizer()
            end
        end)
        startButton.Parent = bottomButtons
        
        createActionButton("⚡ БЫСТРАЯ ОПТИМИЗАЦИЯ", Color3.fromRGB(255, 150, 0), quickOptimize).Parent = bottomButtons
        createActionButton("💰 БЫСТРЫЙ ДЕПОЗИТ", Color3.fromRGB(0, 150, 255), autoDepositToBank).Parent = bottomButtons
        createActionButton("🔄 ОБНОВИТЬ ДАННЫЕ", Color3.fromRGB(100, 100, 200), updateGameData).Parent = bottomButtons
        
        bottomButtons.Parent = statsContainer
        
        -- Создаем другие вкладки
        local settingsContainer = createSettingsTab()
        settingsContainer.Parent = contentFrame
        tabContents.settings = settingsContainer
        
        local bankContainer = createBankTab()
        bankContainer.Parent = contentFrame
        tabContents.bank = bankContainer
        
        local logsContainer = createLogsTab()
        logsContainer.Parent = contentFrame
        tabContents.logs = logsContainer
        
        -- Обработчики кнопок
        closeButton.MouseButton1Click:Connect(function()
            screenGui:Destroy()
            isGUIVisible = false
            if dragDetector then
                dragDetector:Destroy()
            end
        end)
        
        minimizeButton.MouseButton1Click:Connect(function()
            if mainContainer.Size == UDim2.new(0.35, 0, 0.7, 0) then
                mainContainer.Size = UDim2.new(0, 60, 0, 60)
                mainContainer.Position = UDim2.new(1, -70, 1, -70)
                topBar.Visible = false
                tabBar.Visible = false
                contentFrame.Visible = false
                minimizeButton.Text = "🗖"
            else
                mainContainer.Size = UDim2.new(0.35, 0, 0.7, 0)
                mainContainer.Position = UDim2.new(0.65, 0, 0.15, 0)
                topBar.Visible = true
                tabBar.Visible = true
                contentFrame.Visible = true
                minimizeButton.Text = "🗕"
            end
        end)
        
        -- Функция обновления статуса
        local function updateStatus()
            if isRunning then
                guiElements.statusLabel.Text = "▶ РАБОТАЕТ"
                guiElements.statusLabel.TextColor3 = currentColors.Success
                startButton.Text = "⏸ ПАУЗА"
            else
                guiElements.statusLabel.Text = "⏹ СТОП"
                guiElements.statusLabel.TextColor3 = currentColors.Error
                startButton.Text = "🚀 ЗАПУСТИТЬ"
            end
        end
        
        guiElements.updateStatus = updateStatus
        
        -- Инициализация
        guiElements.initialized = true
        lastUpdateTime = os.time()
        
        -- Анимация появления
        if Config.ANIMATIONS_ENABLED then
            mainContainer.Size = UDim2.new(0, 0, 0, 0)
            mainContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
            
            local openTween = TweenService:Create(mainContainer, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
                Size = UDim2.new(0.35, 0, 0.7, 0),
                Position = UDim2.new(0.65, 0, 0.15, 0)
            })
            openTween:Play()
            
            openTween.Completed:Connect(function()
                log("Auto Optimizer PRO v10.0 загружен", "success")
                log("Добро пожаловать! Интерфейс готов к работе.", "info")
                updateGameData()
                updateStatus()
                switchTab("stats")
            end)
        else
            log("Auto Optimizer PRO v10.0 загружен", "success")
            updateGameData()
            updateStatus()
            switchTab("stats")
        end
        
        return screenGui
    end

    -- Функция быстрой оптимизации
    local function quickOptimize()
        log("⚡ ЗАПУСК БЫСТРОЙ ОПТИМИЗАЦИИ", "info")
        updateGameData()
        local optimized = optimizeAllProperties()
        log(string.format("Быстрая оптимизация завершена (%d объектов)", optimized), "success")
        showNotification("Быстрая оптимизация", "Завершена успешно", "Green")
    end

    -- Функция запуска автооптимизации
    local function startAutoOptimizer()
        if isRunning then
            stopOptimizer()
            return
        end
        
        isRunning = true
        if guiElements.updateStatus then
            guiElements.updateStatus()
        end
        
        log("🚀 АВТООПТИМИЗАТОР ЗАПУЩЕН", "success")
        showNotification("Auto Optimizer", "Автооптимизатор запущен", "Green")
        
        -- Основной цикл оптимизации
        task.spawn(function()
            while isRunning do
                local startTime = tick()
                
                local optimized = optimizeAllProperties()
                
                local elapsedTime = tick() - startTime
                local waitTime = math.max(1, Config.CHECK_INTERVAL - elapsedTime)
                
                if isRunning then
                    for i = 1, math.floor(waitTime) do
                        if not isRunning then break end
                        task.wait(1)
                    end
                end
            end
            
            log("АВТООПТИМИЗАТОР ОСТАНОВЛЕН", "warning")
            showNotification("Auto Optimizer", "Автооптимизатор остановлен", "Red")
            if guiElements.updateStatus then
                guiElements.updateStatus()
            end
        end)
    end

    -- Функция остановки
    local function stopOptimizer()
        isRunning = false
        log("ЗАПРОС ОСТАНОВКИ ОПТИМИЗАТОРА", "warning")
        if guiElements.updateStatus then
            guiElements.updateStatus()
        end
    end

    -- Инициализация
    local function initialize()
        log("Начало инициализации Auto Optimizer...", "info")
        
        -- Ждем загрузки игры
        local loaded = false
        for i = 1, 30 do -- 30 секунд таймаут
            if PlayerDataClient and PlayerDataClient.Loaded and PlayerDataClient.Loaded() then
                loaded = true
                break
            end
            wait(1)
        end
        
        if not loaded then
            log("Не удалось загрузить PlayerDataClient, продолжаем с заглушками", "warning")
        end
        
        -- Создаем GUI
        createModernGUI()
        
        -- Настраиваем слушателей данных
        dataUpdateConnection = RunService.Heartbeat:Connect(function()
            if os.time() - lastUpdateTime >= 5 then
                updateGameData()
                lastUpdateTime = os.time()
            end
        end)
        
        -- Автозапуск через 5 секунды
        wait(5)
        if not isRunning then
            task.spawn(startAutoOptimizer)
        end
        
        log("Система инициализирована и работает", "success")
    end

    -- Запуск инициализации
    task.spawn(initialize)

    -- Экспорт функций
    return {
        quickOptimize = quickOptimize,
        startAutoOptimizer = startAutoOptimizer,
        stopOptimizer = stopOptimizer,
        updateGameData = updateGameData,
        getConfig = function() return Config end,
        setConfig = function(key, value)
            if Config[key] ~= nil then
                Config[key] = value
                return true
            end
            return false
        end,
        isRunning = function() return isRunning end,
        getStats = function() return statsData end,
        showNotification = showNotification,
        log = log
    }
end)

if not success then
    warn("Ошибка при загрузке Auto Optimizer:", errorMsg)
    print("Попытка загрузки в безопасном режиме...")
    
    -- Безопасный режим с минимальным функционалом
    local function safeMode()
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "AutoOptimizerSafe"
        screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 300, 0, 150)
        frame.Position = UDim2.new(0.5, -150, 0.5, -75)
        frame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        frame.Parent = screenGui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = frame
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 40)
        title.BackgroundTransparency = 1
        title.Text = "⚠️ Auto Optimizer (Safe Mode)"
        title.TextColor3 = Color3.fromRGB(255, 200, 100)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 16
        title.Parent = frame
        
        local message = Instance.new("TextLabel")
        message.Size = UDim2.new(1, -20, 0, 60)
        message.Position = UDim2.new(0, 10, 0, 50)
        message.BackgroundTransparency = 1
        message.Text = "Ошибка загрузки полной версии.\nПроверьте консоль для подробностей."
        message.TextColor3 = Color3.fromRGB(255, 255, 255)
        message.Font = Enum.Font.Gotham
        message.TextSize = 12
        message.TextWrapped = true
        message.Parent = frame
        
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 100, 0, 30)
        closeBtn.Position = UDim2.new(0.5, -50, 1, -40)
        closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        closeBtn.Text = "Закрыть"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 14
        closeBtn.Parent = frame
        
        local corner2 = Instance.new("UICorner")
        corner2.CornerRadius = UDim.new(0, 8)
        corner2.Parent = closeBtn
        
        closeBtn.MouseButton1Click:Connect(function()
            screenGui:Destroy()
        end)
        
        print("Auto Optimizer запущен в безопасном режиме")
    end
    
    task.spawn(safeMode)
end
