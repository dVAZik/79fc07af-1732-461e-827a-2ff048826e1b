-- Автоматический оптимизатор арендаторов с полным заполнением и заменой
-- Автор: AI Assistant
-- Версия: 5.0 (Premium UI + ScrollingFrame)

-- Получаем необходимые модули
local Portfolio = require(game:GetService("ReplicatedStorage").Modules.Game.PortfolioController)
local Building = require(game:GetService("ReplicatedStorage").Modules.Data.Building)
local PlayerDataClient = require(game:GetService("ReplicatedStorage").Modules.PlayerDataClient)
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Пути к RemoteEvents и Functions
local NetworkPath = game:GetService("ReplicatedStorage").Modules.NetworkClient

-- Конфигурация
local MIN_STARS = 3  -- Минимум звезд для удержания арендатора
local MIN_STARS_FOR_NEW = 3  -- Минимум звезд для новых заявок
local CHECK_INTERVAL = 15  -- Интервал проверки в секундах
local AUTO_DENY_BAD_APPLICANTS = true  -- Автоматически отклонять плохих (<3 звезд)
local AUTO_ACCEPT_GOOD_APPLICANTS = true  -- Автоматически принимать хороших (≥3 звезд)
local AGGRESSIVE_REPLACEMENT = true  -- Агрессивная замена всех слабых арендаторов

-- Глобальные переменные
local isRunning = false
local cycleCount = 0
local lastPropertyCount = 0
local processedRenters = {}
local processedApplicants = {}
local propertyCache = {}
local statsData = {
    totalProperties = 0,
    occupiedSpots = 0,
    totalSpots = 0,
    totalIncome = 0,
    lastUpdate = os.time(),
    lastIncomeChange = 0,
    bestProperty = nil,
    cycleTime = 0,
    totalReplacements = 0,
    totalAccepted = 0,
    totalEvicted = 0
}

-- Функция для логирования
local function log(message, type)
    local prefix = ""
    if type == "success" then
        prefix = "✅ "
    elseif type == "warning" then
        prefix = "⚠️ "
    elseif type == "error" then
        prefix = "❌ "
    elseif type == "info" then
        prefix = "📌 "
    elseif type == "money" then
        prefix = "💰 "
    elseif type == "spot" then
        prefix = "🔄 "
    elseif type == "evict" then
        prefix = "👋 "
    elseif type == "hire" then
        prefix = "📝 "
    else
        prefix = "📝 "
    end
    
    local timestamp = os.date("%H:%M:%S")
    print(string.format("[%s] %s%s", timestamp, prefix, message))
    
    -- Обновляем лог в GUI если он существует
    if _G.GUILogger then
        _G.GUILogger(message, type)
    end
end

-- Функция расчета общего количества мест в объекте
local function calculateTotalSpots(propertyUID)
    if not propertyUID then return 0 end
    
    local property = Portfolio.GetAll(propertyUID)
    if not property or property.BuildingType == "Empty" then return 0 end
    
    local buildingData = Building[property.BuildingType]
    if not buildingData then return 0 end
    
    local totalSpots = buildingData.Spots or 0
    
    -- Добавляем места от улучшений
    if property.Built then
        for _, upgrade in ipairs(property.Built) do
            if upgrade ~= "Main" and buildingData.Upgrades and buildingData.Upgrades[upgrade] then
                totalSpots = totalSpots + (buildingData.Upgrades[upgrade].AddedRenters or 0)
            end
        end
    end
    
    return totalSpots
end

-- Функция расчета занятых мест
local function calculateOccupiedSpots(propertyUID)
    if not propertyUID then return 0 end
    
    local property = Portfolio.GetAll(propertyUID)
    if not property or not property.Renters then return 0 end
    
    local occupied = 0
    for _ in pairs(property.Renters) do
        occupied = occupied + 1
    end
    
    return occupied
end

-- Функция проверки полностью ли заполнен объект
local function isPropertyFullyOccupied(propertyUID)
    if not propertyUID then return false end
    
    local totalSpots = calculateTotalSpots(propertyUID)
    if totalSpots == 0 then return false end
    
    local occupiedSpots = calculateOccupiedSpots(propertyUID)
    return occupiedSpots >= totalSpots
end

-- Функция проверки есть ли свободные места
local function hasAvailableSpots(propertyUID)
    if not propertyUID then return false end
    
    local totalSpots = calculateTotalSpots(propertyUID)
    local occupiedSpots = calculateOccupiedSpots(propertyUID)
    return occupiedSpots < totalSpots
end

-- Функция расчета свободных мест
local function getAvailableSpotsCount(propertyUID)
    if not propertyUID then return 0 end
    
    local totalSpots = calculateTotalSpots(propertyUID)
    local occupiedSpots = calculateOccupiedSpots(propertyUID)
    return math.max(0, totalSpots - occupiedSpots)
end

-- Функция обновления кэша объектов
local function updatePropertyCache()
    local allProperties = Portfolio.GetPortfolio()
    local newCache = {}
    local newProperties = 0
    
    for propertyUID, property in pairs(allProperties) do
        if propertyUID and property then
            local totalSpots = calculateTotalSpots(propertyUID)
            local occupiedSpots = calculateOccupiedSpots(propertyUID)
            local availableSpots = getAvailableSpotsCount(propertyUID)
            
            newCache[propertyUID] = {
                BuildingType = property.BuildingType,
                District = property.District,
                Address = property.Address,
                Income = property.Income or 0,
                Renters = property.Renters and #property.Renters or 0,
                TotalSpots = totalSpots,
                OccupiedSpots = occupiedSpots,
                AvailableSpots = availableSpots,
                FullyOccupied = isPropertyFullyOccupied(propertyUID),
                UID = propertyUID
            }
            
            -- Проверяем новый ли это объект
            if not propertyCache[propertyUID] and property.BuildingType ~= "Empty" then
                newProperties = newProperties + 1
                log(string.format("Обнаружен новый объект: %s (%s) - %d/%d мест", 
                    propertyUID, property.BuildingType, occupiedSpots, totalSpots), "info")
            end
        end
    end
    
    -- Обновляем счетчик
    if newProperties > 0 then
        log(string.format("🎉 Найдено %d новых объектов!", newProperties), "success")
    end
    
    propertyCache = newCache
    lastPropertyCount = #allProperties
    
    return newProperties
end

-- Функция расчета дохода от арендатора
local function calculateRenterIncome(propertyUID, renter)
    if not propertyUID or not renter then
        return 0
    end
    
    local property = Portfolio.GetAll(propertyUID)
    if not property or property.BuildingType == "Empty" then 
        return 0 
    end
    
    -- Получаем данные о здании
    local buildingData = Building[property.BuildingType]
    if not buildingData then return 0 end
    
    -- Базовый доход
    local baseRent = buildingData.BaseRent or 0
    
    -- Добавляем бонусы от улучшений
    if property.Built then
        for _, upgrade in ipairs(property.Built) do
            if upgrade ~= "Main" and buildingData.Upgrades and buildingData.Upgrades[upgrade] then
                baseRent = baseRent + (buildingData.Upgrades[upgrade].AddedRent or 0)
            end
        end
    end
    
    -- Множитель звезд: 1 звезда = 50%, 5 звезд = 250%
    local starMultiplier = 0.5 + (renter.Stars or 1) * 0.5
    
    -- Бонус от бухгалтера
    local accountantBonus = 1
    local workers = PlayerDataClient.Get("Workers")
    if workers and workers.Accountant then
        accountantBonus = 1 + workers.Accountant * 0.2
    end
    
    local totalIncome = baseRent * starMultiplier * accountantBonus
    return math.floor((totalIncome or 0) * 100) / 100  -- Округляем до 2 знаков
end

-- Функция получения всех заявок отсортированных по доходности (от лучшей к худшей)
local function getAllApplicantsSorted(propertyUID)
    if not propertyUID then return {} end
    
    local property = Portfolio.GetAll(propertyUID)
    if not property or not property.Applicants then return {} end
    
    local applicants = {}
    
    for applicantId, applicant in pairs(property.Applicants) do
        if applicantId and applicant then
            local cacheKey = propertyUID .. "_" .. applicantId
            if not processedApplicants[cacheKey] then
                local income = calculateRenterIncome(propertyUID, applicant)
                if income then
                    table.insert(applicants, {
                        id = applicantId,
                        income = income,
                        stars = applicant.Stars or 1,
                        data = applicant
                    })
                end
            end
        end
    end
    
    -- Сортируем по доходу (от большего к меньшему), затем по звездам
    if #applicants > 0 then
        table.sort(applicants, function(a, b)
            if (a.income or 0) == (b.income or 0) then
                return a.stars > b.stars
            end
            return (a.income or 0) > (b.income or 0)
        end)
    end
    
    return applicants
end

-- Функция получения всех арендаторов отсортированных по доходности (от худшего к лучшему)
local function getAllRentersSorted(propertyUID)
    if not propertyUID then return {} end
    
    local property = Portfolio.GetAll(propertyUID)
    if not property or not property.Renters then return {} end
    
    local renters = {}
    
    for renterId, renter in pairs(property.Renters) do
        if renterId and renter then
            local cacheKey = propertyUID .. "_" .. renterId
            if not processedRenters[cacheKey] then
                local income = calculateRenterIncome(propertyUID, renter)
                if income then
                    table.insert(renters, {
                        id = renterId,
                        income = income,
                        stars = renter.Stars or 1,
                        data = renter
                    })
                end
            end
        end
    end
    
    -- Сортируем по доходу (от меньшего к большему), затем по звездам
    if #renters > 0 then
        table.sort(renters, function(a, b)
            if (a.income or 0) == (b.income or 0) then
                return a.stars < b.stars
            end
            return (a.income or 0) < (b.income or 0)
        end)
    end
    
    return renters
end

-- Функция принятия арендатора
local function acceptApplicant(propertyUID, applicantId)
    if not propertyUID or not applicantId then
        return false, "Неверные параметры"
    end
    
    local args = {[1] = propertyUID, [2] = applicantId}
    local success, result = pcall(function()
        return NetworkPath.FunctionMap.Tenancy.SelectTenant:InvokeServer(unpack(args))
    end)
    
    if success then
        processedApplicants[propertyUID .. "_" .. applicantId] = true
        statsData.totalAccepted = statsData.totalAccepted + 1
        return true, "Успешно принят"
    else
        return false, "Ошибка: " .. tostring(result)
    end
end

-- Функция выселения арендатора
local function evictRenter(propertyUID, renterId)
    if not propertyUID or not renterId then
        return false, "Неверные параметры"
    end
    
    local args = {[1] = propertyUID, [2] = renterId}
    local success, result = pcall(function()
        return NetworkPath.FunctionMap.Tenancy.Evict:InvokeServer(unpack(args))
    end)
    
    if success then
        processedRenters[propertyUID .. "_" .. renterId] = true
        statsData.totalEvicted = statsData.totalEvicted + 1
        return true, "Успешно выселен"
    else
        return false, "Ошибка: " .. tostring(result)
    end
end

-- Функция отклонения заявки
local function denyApplicant(propertyUID, applicantId)
    if not propertyUID or not applicantId then
        return false, "Неверные параметры"
    end
    
    local args = {[1] = propertyUID, [2] = applicantId}
    local success, result = pcall(function()
        return NetworkPath.EventMap.DenyApplicant:FireServer(unpack(args))
    end)
    
    if success then
        processedApplicants[propertyUID .. "_" .. applicantId] = true
        return true, "Успешно отклонена"
    else
        return false, "Ошибка: " .. tostring(result)
    end
end

-- Функция заполнения всех свободных мест лучшими заявками (от 3+ звезд)
local function fillAllAvailableSpots(propertyUID)
    if not propertyUID then return 0, 0 end
    
    local availableSpots = getAvailableSpotsCount(propertyUID)
    if availableSpots <= 0 then return 0, 0 end
    
    local applicants = getAllApplicantsSorted(propertyUID)
    if #applicants == 0 then return 0, 0 end
    
    local acceptedCount = 0
    local totalIncomeGain = 0
    
    log(string.format("  [%s] Ищу заявки от %d⭐ для %d свободных мест", 
        propertyUID, MIN_STARS_FOR_NEW, availableSpots), "spot")
    
    -- Принимаем лучших заявок (от 3+ звезд) пока есть места
    for i = 1, math.min(availableSpots, #applicants) do
        local applicant = applicants[i]
        if applicant and applicant.stars and applicant.stars >= MIN_STARS_FOR_NEW then
            local success, message = acceptApplicant(propertyUID, applicant.id)
            if success then
                acceptedCount = acceptedCount + 1
                totalIncomeGain = totalIncomeGain + (applicant.income or 0)
                log(string.format("  [%s] 📝 Принят %s (%d⭐, +$%.2f)", 
                    propertyUID, applicant.id, applicant.stars, applicant.income or 0), "hire")
                
                -- Небольшая задержка между принятиями
                task.wait(0.3)
            else
                log(string.format("  [%s] ❌ Ошибка при принятии %s: %s", 
                    propertyUID, applicant.id, message), "error")
            end
        else
            log(string.format("  [%s] ⚠️ Пропуск %s (только %d⭐, нужно %d+)", 
                propertyUID, applicant.id, applicant.stars or 0, MIN_STARS_FOR_NEW), "warning")
        end
    end
    
    if acceptedCount > 0 then
        log(string.format("  [%s] ✅ Заполнено %d мест (+$%.2f)", 
            propertyUID, acceptedCount, totalIncomeGain), "success")
    end
    
    return acceptedCount, totalIncomeGain
end

-- Функция полной оптимизации ВСЕХ мест (агрессивная замена)
local function optimizeAllSpotsAggressive(propertyUID)
    if not propertyUID then
        log("Ошибка: propertyUID не указан", "error")
        return 0, 0, 0
    end
    
    local currentRenters = getAllRentersSorted(propertyUID)
    local currentApplicants = getAllApplicantsSorted(propertyUID)
    local totalSpots = calculateTotalSpots(propertyUID)
    
    if #currentRenters == 0 then
        log(string.format("  [%s] Нет арендаторов для оптимизации", propertyUID), "info")
        return 0, 0, 0
    end
    
    if #currentApplicants == 0 then
        log(string.format("  [%s] Нет заявок для сравнения", propertyUID), "info")
        return 0, 0, 0
    end
    
    log(string.format("  [%s] Анализ %d арендаторов и %d заявок...", 
        propertyUID, #currentRenters, #currentApplicants), "info")
    
    local replacementsMade = 0
    local totalIncomeIncrease = 0
    local skippedLowStars = 0
    
    -- Создаем копии для безопасной модификации
    local rentersCopy = {}
    for _, renter in ipairs(currentRenters) do
        table.insert(rentersCopy, renter)
    end
    
    local applicantsCopy = {}
    for _, applicant in ipairs(currentApplicants) do
        table.insert(applicantsCopy, applicant)
    end
    
    -- Сортируем арендаторов от худшего к лучшему
    table.sort(rentersCopy, function(a, b)
        return (a.income or 0) < (b.income or 0)
    end)
    
    -- Сортируем заявки от лучшей к худшей
    table.sort(applicantsCopy, function(a, b)
        return (a.income or 0) > (b.income or 0)
    end)
    
    -- Проходим по всем арендаторам
    for renterIndex = #rentersCopy, 1, -1 do
        local worstRenter = rentersCopy[renterIndex]
        
        if not worstRenter or not worstRenter.income then
            log(string.format("  [%s] Пропуск арендатора: нет данных", propertyUID), "warning")
            break
        end
        
        -- Проверяем звезды текущего арендатора
        if worstRenter.stars and worstRenter.stars < MIN_STARS then
            log(string.format("  [%s] ⭐ Арендатор %s имеет только %d⭐ (минимум %d)", 
                propertyUID, worstRenter.id, worstRenter.stars, MIN_STARS), "info")
        end
        
        -- Ищем лучшую заявку для замены
        local bestReplacement = nil
        local bestReplacementIndex = 0
        
        for applicantIndex = 1, #applicantsCopy do
            local applicant = applicantsCopy[applicantIndex]
            
            if applicant and applicant.income and applicant.stars then
                -- Проверяем, лучше ли заявка и соответствует ли требованиям по звездам
                if applicant.income > worstRenter.income and applicant.stars >= MIN_STARS_FOR_NEW then
                    bestReplacement = applicant
                    bestReplacementIndex = applicantIndex
                    break
                end
            end
        end
        
        -- Если нашли замену
        if bestReplacement then
            local profitDifference = bestReplacement.income - worstRenter.income
            
            log(string.format("  [%s] 🔄 Найдена замена: %s (%d⭐, $%.2f) → %s (%d⭐, $%.2f) [+$%.2f]", 
                propertyUID, worstRenter.id, worstRenter.stars or 0, worstRenter.income,
                bestReplacement.id, bestReplacement.stars, bestReplacement.income, profitDifference), "spot")
            
            -- Выселяем худшего арендатора
            local success1, message1 = evictRenter(propertyUID, worstRenter.id)
            if success1 then
                task.wait(0.5)
                
                -- Принимаем лучшую заявку
                local success2, message2 = acceptApplicant(propertyUID, bestReplacement.id)
                if success2 then
                    replacementsMade = replacementsMade + 1
                    totalIncomeIncrease = totalIncomeIncrease + profitDifference
                    statsData.totalReplacements = statsData.totalReplacements + 1
                    
                    log(string.format("  [%s] ✅ Успешная замена: +$%.2f", propertyUID, profitDifference), "success")
                    
                    -- Удаляем замененных из списков
                    table.remove(rentersCopy, renterIndex)
                    table.remove(applicantsCopy, bestReplacementIndex)
                    
                    -- Небольшая пауза перед следующей заменой
                    task.wait(0.3)
                else
                    log(string.format("  [%s] ❌ Ошибка при принятии: %s", propertyUID, message2), "error")
                end
            else
                log(string.format("  [%s] ❌ Ошибка при выселении: %s", propertyUID, message1), "error")
            end
        else
            -- Проверяем если у арендатора низкий рейтинг
            if worstRenter.stars and worstRenter.stars < MIN_STARS and AGGRESSIVE_REPLACEMENT then
                log(string.format("  [%s] ⚠️ Арендатор %s имеет только %d⭐ (минимум %d)", 
                    propertyUID, worstRenter.id, worstRenter.stars, MIN_STARS), "warning")
                
                -- Ищем ЛЮБУЮ заявку от 3+ звезд
                for applicantIndex = 1, #applicantsCopy do
                    local applicant = applicantsCopy[applicantIndex]
                    
                    if applicant and applicant.stars and applicant.stars >= MIN_STARS_FOR_NEW then
                        log(string.format("  [%s] Замена по звездам: %s (%d⭐) → %s (%d⭐)", 
                            propertyUID, worstRenter.id, worstRenter.stars, 
                            applicant.id, applicant.stars), "info")
                        
                        -- Выселяем арендатора с низкими звездами
                        local success1, message1 = evictRenter(propertyUID, worstRenter.id)
                        if success1 then
                            task.wait(0.5)
                            
                            -- Принимаем новую заявку
                            local success2, message2 = acceptApplicant(propertyUID, applicant.id)
                            if success2 then
                                replacementsMade = replacementsMade + 1
                                totalIncomeIncrease = totalIncomeIncrease + (applicant.income or 0) - (worstRenter.income or 0)
                                statsData.totalReplacements = statsData.totalReplacements + 1
                                skippedLowStars = skippedLowStars + 1
                                
                                log(string.format("  [%s] ✅ Замена по звездам успешна", propertyUID), "success")
                                
                                -- Удаляем замененных из списков
                                table.remove(rentersCopy, renterIndex)
                                table.remove(applicantsCopy, applicantIndex)
                                
                                task.wait(0.3)
                                break
                            else
                                log(string.format("  [%s] ❌ Ошибка при принятии: %s", propertyUID, message2), "error")
                            end
                        else
                            log(string.format("  [%s] ❌ Ошибка при выселении: %s", propertyUID, message1), "error")
                        end
                    end
                end
            end
        end
    end
    
    -- Проверяем наличие свободных мест после замен
    local availableAfter = getAvailableSpotsCount(propertyUID)
    if availableAfter > 0 then
        log(string.format("  [%s] После замен осталось %d свободных мест, заполняю...", 
            propertyUID, availableAfter), "spot")
        
        local filled, incomeGain = fillAllAvailableSpots(propertyUID)
        if filled > 0 then
            log(string.format("  [%s] 📝 Дозаполнено %d мест", propertyUID, filled), "hire")
        end
    end
    
    return replacementsMade, totalIncomeIncrease, skippedLowStars
end

-- Основная функция оптимизации одного объекта
local function optimizeProperty(propertyUID)
    if not propertyUID then
        return "error|Не указан propertyUID"
    end
    
    local property = Portfolio.GetAll(propertyUID)
    if not property or property.BuildingType == "Empty" then
        return "skip_empty"
    end
    
    local buildingData = Building[property.BuildingType]
    if not buildingData or not buildingData.Spots or buildingData.Spots == 0 then
        return "skip_no_spots"
    end
    
    local totalSpots = calculateTotalSpots(propertyUID)
    local occupiedSpots = calculateOccupiedSpots(propertyUID)
    local availableSpots = getAvailableSpotsCount(propertyUID)
    local fullyOccupied = isPropertyFullyOccupied(propertyUID)
    local hasApplicants = property.Applicants and next(property.Applicants)
    
    log(string.format("[%s] %s: %d/%d мест (%d свободно)", 
        propertyUID, property.BuildingType, occupiedSpots, totalSpots, availableSpots), "info")
    
    -- Если нет заявок, пропускаем
    if not hasApplicants then
        log(string.format("  [%s] Нет заявок для обработки", propertyUID), "warning")
        return "no_applicants"
    end
    
    -- СЦЕНАРИЙ 1: Есть свободные места - заполняем лучшими от 3+ звезд
    if availableSpots > 0 then
        log(string.format("  [%s] Есть %d свободных мест, заполняю от %d⭐...", 
            propertyUID, availableSpots, MIN_STARS_FOR_NEW), "spot")
        
        local filled, incomeGain = fillAllAvailableSpots(propertyUID)
        if filled > 0 then
            return string.format("filled|%d|+$%.2f", filled, incomeGain)
        else
            log(string.format("  [%s] Нет подходящих заявок (от %d⭐)", 
                propertyUID, MIN_STARS_FOR_NEW), "warning")
        end
    end
    
    -- СЦЕНАРИЙ 2: Объект полностью заполнен - агрессивная оптимизация
    if fullyOccupied or occupiedSpots > 0 then
        log(string.format("  [%s] Проверка %d занятых мест...", propertyUID, occupiedSpots), "info")
        
        local replaced, incomeIncrease, skipped = optimizeAllSpotsAggressive(propertyUID)
        if replaced > 0 or skipped > 0 then
            return string.format("replaced|%d|+$%.2f|skipped:%d", replaced, incomeIncrease, skipped)
        else
            log(string.format("  [%s] Все арендаторы оптимальны", propertyUID), "info")
        end
    end
    
    -- СЦЕНАРИЙ 3: Автоматическое отклонение плохих заявок (<3 звезд)
    if AUTO_DENY_BAD_APPLICANTS and hasApplicants then
        local deniedCount = 0
        for applicantId, applicant in pairs(property.Applicants) do
            if applicantId and applicant then
                local cacheKey = propertyUID .. "_" .. applicantId
                if not processedApplicants[cacheKey] then
                    local stars = applicant.Stars or 1
                    if stars < 3 then
                        local success, message = denyApplicant(propertyUID, applicantId)
                        if success then
                            deniedCount = deniedCount + 1
                            log(string.format("  [%s] 🗑️ Отклонена плохая заявка %s (%d⭐)", 
                                propertyUID, applicantId, stars), "warning")
                        end
                    end
                end
            end
        end
        
        if deniedCount > 0 then
            return string.format("denied|%d", deniedCount)
        end
    end
    
    return "no_changes"
end

-- Функция расчета общего дохода портфеля
local function calculateTotalPortfolioIncome()
    local allProperties = Portfolio.GetPortfolio()
    local total = 0
    
    for _, property in pairs(allProperties) do
        if property and property.Income then
            total = total + property.Income
        end
    end
    
    return total
end

-- Функция обновления статистики
local function updateStatistics()
    local allProperties = Portfolio.GetPortfolio()
    local totalSpotsAll = 0
    local occupiedSpotsAll = 0
    local totalIncome = 0
    local propertyCount = 0
    local bestPropertyIncome = 0
    local bestProperty = nil
    
    for propertyUID, property in pairs(allProperties) do
        if propertyUID and property then
            propertyCount = propertyCount + 1
            local spots = calculateTotalSpots(propertyUID)
            local occupied = calculateOccupiedSpots(propertyUID)
            totalSpotsAll = totalSpotsAll + spots
            occupiedSpotsAll = occupiedSpotsAll + occupied
            totalIncome = totalIncome + (property.Income or 0)
            
            -- Находим лучший объект
            if property.Income and property.Income > bestPropertyIncome then
                bestPropertyIncome = property.Income
                bestProperty = {
                    UID = propertyUID,
                    Type = property.BuildingType,
                    Income = property.Income,
                    District = property.District
                }
            end
        end
    end
    
    local percentageOccupied = totalSpotsAll > 0 and (occupiedSpotsAll / totalSpotsAll * 100) or 0
    
    statsData.totalProperties = propertyCount
    statsData.occupiedSpots = occupiedSpotsAll
    statsData.totalSpots = totalSpotsAll
    statsData.totalIncome = totalIncome
    statsData.occupancyRate = percentageOccupied
    statsData.bestProperty = bestProperty
    statsData.lastUpdate = os.time()
    
    -- Обновляем GUI если существует
    if _G.UpdateGUIStats then
        _G.UpdateGUIStats(statsData)
    end
    
    return statsData
end

-- Функция оптимизации всего портфеля
local function optimizeAllProperties()
    local cycleStartTime = tick()
    cycleCount = cycleCount + 1
    
    log(string.format("\n🔄 ЦИКЛ ОПТИМИЗАЦИИ #%d", cycleCount), "info")
    log("⚡ Алгоритм: Агрессивная замена + заполнение от 3⭐", "info")
    
    -- Сохраняем доход до оптимизации
    local incomeBefore = calculateTotalPortfolioIncome()
    
    -- Обновляем кэш и проверяем новые объекты
    local newProperties = updatePropertyCache()
    
    local allProperties = Portfolio.GetPortfolio()
    local optimizedCount = 0
    local totalFilled = 0
    local totalReplaced = 0
    
    -- Оптимизируем каждый объект
    for propertyUID, property in pairs(allProperties) do
        if property and property.BuildingType and property.BuildingType ~= "Empty" then
            local result = optimizeProperty(propertyUID)
            
            if result:find("filled|") then
                local parts = result:split("|")
                optimizedCount = optimizedCount + 1
                totalFilled = totalFilled + tonumber(parts[2]) or 0
                log(string.format("[%s] ✅ Заполнено %s мест %s", 
                    propertyUID, parts[2], parts[3]), "success")
            elseif result:find("replaced|") then
                local parts = result:split("|")
                optimizedCount = optimizedCount + 1
                totalReplaced = totalReplaced + (tonumber(parts[2]) or 0)
                log(string.format("[%s] 🔄 Заменено %s арендаторов %s", 
                    propertyUID, parts[2], parts[3]), "spot")
            elseif result:find("denied|") then
                local parts = result:split("|")
                optimizedCount = optimizedCount + 1
                log(string.format("[%s] 🗑️ Отклонено %s плохих заявок", 
                    propertyUID, parts[2]), "warning")
            elseif result:find("error|") then
                log(string.format("[%s] ❌ Ошибка: %s", propertyUID, result), "error")
            end
            
            -- Задержка между объектами
            task.wait(0.2)
        end
    end
    
    -- Обновляем доход после оптимизации
    local incomeAfter = calculateTotalPortfolioIncome()
    local incomeChange = incomeAfter - incomeBefore
    
    -- Очищаем кэш
    for key in pairs(processedRenters) do
        if math.random() < 0.1 then
            processedRenters[key] = nil
        end
    end
    
    for key in pairs(processedApplicants) do
        if math.random() < 0.2 then
            processedApplicants[key] = nil
        end
    end
    
    -- Обновляем статистику
    updateStatistics()
    
    -- Сохраняем время цикла
    statsData.cycleTime = tick() - cycleStartTime
    
    -- Отчет о цикле
    log(string.format("\n📈 РЕЗУЛЬТАТЫ ЦИКЛА #%d:", cycleCount), "info")
    
    if incomeChange > 0 then
        log(string.format("   💰 Прирост дохода: +$%.2f (%.1f%%)", 
            incomeChange, (incomeChange / incomeBefore) * 100), "money")
        statsData.lastIncomeChange = incomeChange
    elseif incomeChange < 0 then
        log(string.format("   ⚠️ Потеря дохода: -$%.2f", math.abs(incomeChange)), "warning")
        statsData.lastIncomeChange = incomeChange
    else
        log("   ➖ Доход не изменился", "info")
        statsData.lastIncomeChange = 0
    end
    
    log(string.format("   🏢 Заполненность: %d/%d мест (%.1f%%)", 
        statsData.occupiedSpots, statsData.totalSpots, statsData.occupancyRate), "info")
    
    if totalFilled > 0 then
        log(string.format("   📝 Новые принятия: %d арендаторов", totalFilled), "hire")
    end
    
    if totalReplaced > 0 then
        log(string.format("   🔄 Заменено: %d арендаторов", totalReplaced), "spot")
    end
    
    if statsData.totalEvicted > 0 then
        log(string.format("   👋 Выселено: %d арендаторов", statsData.totalEvicted), "evict")
    end
    
    if optimizedCount > 0 then
        log(string.format("   ✅ Улучшено объектов: %d", optimizedCount), "success")
    else
        log("   💤 Все объекты уже оптимизированы", "info")
    end
    
    -- Проверяем наличие новых объектов
    if newProperties > 0 then
        log(string.format("   🎯 Обнаружено новых объектов: %d", newProperties), "info")
    end
    
    log(string.format("   ⏱️ Время цикла: %.2f сек", statsData.cycleTime), "info")
    log(string.format("   📊 Всего замен: %d | Принято: %d | Выселено: %d", 
        statsData.totalReplacements, statsData.totalAccepted, statsData.totalEvicted), "info")
    
    return optimizedCount, incomeAfter
end

-- Функция для отслеживания обновлений портфеля
local function setupPortfolioListeners()
    -- Отслеживаем добавление новых объектов
    Portfolio.GetUpdateSignal():Connect(function(propertyUID)
        if propertyUID and not propertyCache[propertyUID] then
            log(string.format("🔔 НОВЫЙ ОБЪЕКТ: %s", propertyUID), "info")
            
            -- Даем время на загрузку данных
            task.wait(1)
            
            -- Оптимизируем новый объект
            if isRunning then
                log(string.format("⚡ Автооптимизация нового объекта: %s", propertyUID), "spot")
                
                -- Ждем еще немного для стабильности
                task.wait(0.5)
                optimizeProperty(propertyUID)
                
                -- Обновляем кэш
                updatePropertyCache()
                updateStatistics()
            end
        end
    end)
    
    -- Отслеживаем новые заявки
    Portfolio.GetApplicantAddedSignal():Connect(function(propertyUID)
        if propertyUID and isRunning and AUTO_ACCEPT_GOOD_APPLICANTS then
            local property = Portfolio.GetAll(propertyUID)
            if property and property.Applicants then
                for applicantId, applicant in pairs(property.Applicants) do
                    if applicantId and applicant then
                        local stars = applicant.Stars or 1
                        if stars >= MIN_STARS_FOR_NEW then
                            log(string.format("🔔 Новая хорошая заявка в %s: %d⭐", propertyUID, stars), "info")
                            
                            -- Проверяем есть ли свободные места
                            if hasAvailableSpots(propertyUID) then
                                task.wait(0.5)
                                local success, message = acceptApplicant(propertyUID, applicantId)
                                if success then
                                    log(string.format("✅ Автопринятие: %s (%d⭐)", applicantId, stars), "success")
                                    updateStatistics()
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    end)
    
    log("👂 Слушатели обновлений активированы", "success")
end

-- Функция для запуска автоматической оптимизации
local function startAutoOptimizer()
    if isRunning then
        log("⚠️ Оптимизатор уже запущен", "warning")
        return
    end
    
    isRunning = true
    log("🤖 АВТООПТИМИЗАТОР ЗАПУЩЕН", "success")
    log(string.format("⚙️ Настройки: Замена от %d⭐ | Новые от %d⭐ | Интервал: %dс", 
        MIN_STARS, MIN_STARS_FOR_NEW, CHECK_INTERVAL), "info")
    log("🎯 Режим: Агрессивная замена всех слабых арендаторов", "info")
    
    -- Обновляем статус в GUI
    if _G.UpdateAutoStatus then
        _G.UpdateAutoStatus(true)
    end
    
    -- Первоначальное обновление кэша и статистики
    updatePropertyCache()
    updateStatistics()
    
    -- Запускаем основной цикл
    while isRunning do
        local startTime = tick()
        
        local optimized, totalIncome = optimizeAllProperties()
        
        -- Если были изменения, обновляем статистику
        if optimized > 0 then
            log(string.format("💰 Оптимизация завершена, новый доход: $%.2f", totalIncome), "money")
        end
        
        local elapsedTime = tick() - startTime
        local waitTime = math.max(1, CHECK_INTERVAL - elapsedTime)
        
        if isRunning then
            log(string.format("⏳ Следующая проверка через %.1f секунд...", waitTime), "info")
            
            -- Ожидание с возможностью прерывания
            for i = 1, math.floor(waitTime) do
                if not isRunning then break end
                task.wait(1)
            end
        end
    end
    
    log("⏹️ АВТООПТИМИЗАТОР ОСТАНОВЛЕН", "warning")
    
    -- Обновляем статус в GUI
    if _G.UpdateAutoStatus then
        _G.UpdateAutoStatus(false)
    end
end

-- Функция для разовой оптимизации
local function quickOptimize()
    log("⚡ ЗАПУСК БЫСТРОЙ ОПТИМИЗАЦИИ", "info")
    log("🎯 Алгоритм: Проверка всех мест + замена слабых", "info")
    updatePropertyCache()
    updateStatistics()
    optimizeAllProperties()
    log("✅ БЫСТРАЯ ОПТИМИЗАЦИЯ ЗАВЕРШЕНА", "success")
end

-- Функция для остановки
local function stopOptimizer()
    isRunning = false
    log("🛑 ЗАПРОС ОСТАНОВКИ ОПТИМИЗАТОРА", "warning")
end

-- Функция для принудительного заполнения всех свободных мест
local function forceFillAllSpots()
    log("🚀 ПРИНУДИТЕЛЬНОЕ ЗАПОЛНЕНИЕ ВСЕХ СВОБОДНЫХ МЕСТ", "spot")
    log("📝 Принимаю заявки от 3+ звезд", "info")
    
    local allProperties = Portfolio.GetPortfolio()
    local totalFilled = 0
    local totalIncomeGain = 0
    
    for propertyUID, property in pairs(allProperties) do
        if propertyUID and property and property.BuildingType and property.BuildingType ~= "Empty" then
            if hasAvailableSpots(propertyUID) then
                local filled, incomeGain = fillAllAvailableSpots(propertyUID)
                totalFilled = totalFilled + filled
                totalIncomeGain = totalIncomeGain + incomeGain
                task.wait(0.3)
            end
        end
    end
    
    if totalFilled > 0 then
        log(string.format("✅ Заполнено %d свободных мест (+$%.2f)", totalFilled, totalIncomeGain), "success")
        updateStatistics()
    else
        log("💤 Все места уже заполнены или нет подходящих заявок", "info")
    end
end

-- Функция для агрессивной замены всех слабых арендаторов
local function aggressiveReplaceAll()
    log("💥 АГРЕССИВНАЯ ЗАМЕНА ВСЕХ СЛАБЫХ АРЕНДАТОРОВ", "spot")
    log("⚡ Замена арендаторов <3⭐ и низкого дохода", "info")
    
    local allProperties = Portfolio.GetPortfolio()
    local totalReplaced = 0
    local totalIncomeIncrease = 0
    
    for propertyUID, property in pairs(allProperties) do
        if propertyUID and property and property.BuildingType and property.BuildingType ~= "Empty" then
            local replaced, incomeIncrease, skipped = optimizeAllSpotsAggressive(propertyUID)
            totalReplaced = totalReplaced + replaced
            totalIncomeIncrease = totalIncomeIncrease + incomeIncrease
            task.wait(0.5)
        end
    end
    
    if totalReplaced > 0 then
        log(string.format("✅ Заменено %d арендаторов (+$%.2f)", totalReplaced, totalIncomeIncrease), "success")
        updateStatistics()
    else
        log("💤 Все арендаторы уже оптимальны", "info")
    end
end

-- Функция создания Premium Mobile UI с ScrollingFrame
local function createPremiumMobileUI()
    local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    
    -- Удаляем старый GUI если есть
    local oldGUI = PlayerGui:FindFirstChild("RenterOptimizerPremiumUI")
    if oldGUI then oldGUI:Destroy() end
    
    -- Создаем новый GUI
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "RenterOptimizerPremiumUI"
    ScreenGui.Parent = PlayerGui
    
    -- Основной контейнер (Draggable)
    local MainContainer = Instance.new("Frame")
    MainContainer.Size = UDim2.new(0, 340, 0, 500)
    MainContainer.Position = UDim2.new(0.5, -170, 0.5, -250)
    MainContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    MainContainer.BackgroundTransparency = 0.05
    MainContainer.BorderSizePixel = 0
    MainContainer.ClipsDescendants = true
    MainContainer.Parent = ScreenGui
    
    -- Скругление углов (скрываем острые края)
    local ContainerCorner = Instance.new("UICorner")
    ContainerCorner.CornerRadius = UDim.new(0, 20)
    ContainerCorner.Parent = MainContainer
    
    -- Внутренняя маска для скрытия углов у дочерних элементов
    local ContainerMask = Instance.new("Frame")
    ContainerMask.Size = UDim2.new(1, 0, 1, 0)
    ContainerMask.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    ContainerMask.BorderSizePixel = 0
    ContainerMask.ClipsDescendants = true
    ContainerMask.Parent = MainContainer
    
    local MaskCorner = Instance.new("UICorner")
    MaskCorner.CornerRadius = UDim.new(0, 20)
    MaskCorner.Parent = ContainerMask
    
    -- Эффект градиента фона
    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 40)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 20, 35)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 30))
    })
    Gradient.Rotation = 45
    Gradient.Parent = ContainerMask
    
    -- Тень с мягкими краями
    local Shadow = Instance.new("ImageLabel")
    Shadow.Size = UDim2.new(1, 20, 1, 20)
    Shadow.Position = UDim2.new(0, -10, 0, -10)
    Shadow.BackgroundTransparency = 1
    Shadow.Image = "rbxassetid://1316045217"
    Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.ImageTransparency = 0.85
    Shadow.ScaleType = Enum.ScaleType.Slice
    Shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    Shadow.Parent = MainContainer
    
    -- Заголовок с иконкой (Draggable область)
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 55)
    Header.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    Header.BorderSizePixel = 0
    Header.Parent = ContainerMask
    
    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 20)
    HeaderCorner.Parent = Header
    
    -- Верхний градиент заголовка
    local HeaderGradient = Instance.new("UIGradient")
    HeaderGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 70)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 50))
    })
    HeaderGradient.Parent = Header
    
    -- Иконка робота
    local RobotIcon = Instance.new("ImageLabel")
    RobotIcon.Size = UDim2.new(0, 45, 0, 45)
    RobotIcon.Position = UDim2.new(0, 10, 0.5, -22.5)
    RobotIcon.BackgroundTransparency = 1
    RobotIcon.Image = "rbxassetid://3926305904"
    RobotIcon.ImageRectOffset = Vector2.new(964, 324)
    RobotIcon.ImageRectSize = Vector2.new(36, 36)
    RobotIcon.ImageColor3 = Color3.fromRGB(100, 200, 255)
    RobotIcon.Parent = Header
    
    -- Заголовок
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0.6, 0, 0, 30)
    Title.Position = UDim2.new(0, 65, 0, 8)
    Title.BackgroundTransparency = 1
    Title.Text = "🤖 АВТООПТИМИЗАТОР"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header
    
    -- Подзаголовок версии
    local Subtitle = Instance.new("TextLabel")
    Subtitle.Size = UDim2.new(0.6, 0, 0, 20)
    Subtitle.Position = UDim2.new(0, 65, 0, 30)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Text = "Premium v5.0"
    Subtitle.TextColor3 = Color3.fromRGB(180, 200, 255)
    Subtitle.Font = Enum.Font.Gotham
    Subtitle.TextSize = 12
    Subtitle.TextXAlignment = Enum.TextXAlignment.Left
    Subtitle.Parent = Header
    
    -- Индикатор статуса
    local StatusIndicator = Instance.new("Frame")
    StatusIndicator.Size = UDim2.new(0, 14, 0, 14)
    StatusIndicator.Position = UDim2.new(1, -60, 0.5, -7)
    StatusIndicator.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    StatusIndicator.BorderSizePixel = 0
    StatusIndicator.Name = "StatusIndicator"
    
    local StatusCorner = Instance.new("UICorner")
    StatusCorner.CornerRadius = UDim.new(1, 0)
    StatusCorner.Parent = StatusIndicator
    
    local StatusGlow = Instance.new("ImageLabel")
    StatusGlow.Size = UDim2.new(1, 6, 1, 6)
    StatusGlow.Position = UDim2.new(0, -3, 0, -3)
    StatusGlow.BackgroundTransparency = 1
    StatusGlow.Image = "rbxassetid://4996891970"
    StatusGlow.ImageColor3 = Color3.fromRGB(255, 50, 50)
    StatusGlow.ImageTransparency = 0.6
    StatusGlow.Parent = StatusIndicator
    
    StatusIndicator.Parent = Header
    
    -- Кнопка свернуть/развернуть
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(0, 40, 0, 40)
    ToggleButton.Position = UDim2.new(1, -45, 0.5, -20)
    ToggleButton.BackgroundTransparency = 1
    ToggleButton.Text = "▼"
    ToggleButton.TextColor3 = Color3.fromRGB(200, 220, 255)
    ToggleButton.Font = Enum.Font.GothamBold
    ToggleButton.TextSize = 22
    ToggleButton.Name = "ToggleButton"
    ToggleButton.Parent = Header
    
    -- Основной ScrollingFrame для содержимого
    local MainScrollingFrame = Instance.new("ScrollingFrame")
    MainScrollingFrame.Size = UDim2.new(1, 0, 1, -60)
    MainScrollingFrame.Position = UDim2.new(0, 0, 0, 55)
    MainScrollingFrame.BackgroundTransparency = 1
    MainScrollingFrame.BorderSizePixel = 0
    MainScrollingFrame.ScrollBarThickness = 4
    MainScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 150, 255)
    MainScrollingFrame.ScrollBarImageTransparency = 0.7
    MainScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 800)
    MainScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    MainScrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    MainScrollingFrame.Parent = ContainerMask
    
    -- Контейнер для элементов внутри ScrollingFrame
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(1, 0, 0, 800)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainScrollingFrame
    
    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 10)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = ContentContainer
    
    -- Карточка статистики
    local StatsCard = Instance.new("Frame")
    StatsCard.Size = UDim2.new(1, -20, 0, 160)
    StatsCard.Position = UDim2.new(0, 10, 0, 0)
    StatsCard.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
    StatsCard.BorderSizePixel = 0
    StatsCard.LayoutOrder = 1
    
    local StatsCorner = Instance.new("UICorner")
    StatsCorner.CornerRadius = UDim.new(0, 15)
    StatsCorner.Parent = StatsCard
    
    local StatsStroke = Instance.new("UIStroke")
    StatsStroke.Color = Color3.fromRGB(100, 150, 255)
    StatsStroke.Thickness = 1.5
    StatsStroke.Transparency = 0.3
    StatsStroke.Parent = StatsCard
    
    StatsCard.Parent = ContentContainer
    
    -- Заголовок статистики
    local StatsTitle = Instance.new("TextLabel")
    StatsTitle.Size = UDim2.new(1, 0, 0, 35)
    StatsTitle.BackgroundTransparency = 1
    StatsTitle.Text = "📊 СТАТИСТИКА В РЕАЛЬНОМ ВРЕМЕНИ"
    StatsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    StatsTitle.Font = Enum.Font.GothamBold
    StatsTitle.TextSize = 14
    StatsTitle.Parent = StatsCard
    
    -- Сетка для статистики (2 колонки)
    local StatsGrid = Instance.new("Frame")
    StatsGrid.Size = UDim2.new(1, -20, 1, -45)
    StatsGrid.Position = UDim2.new(0, 10, 0, 35)
    StatsGrid.BackgroundTransparency = 1
    StatsGrid.Parent = StatsCard
    
    -- Функция создания элемента статистики
    local function createStatItem(name, value, color, icon, position, size)
        local frame = Instance.new("Frame")
        frame.Size = size or UDim2.new(0.48, -5, 0, 28)
        frame.Position = position
        frame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        frame.BorderSizePixel = 0
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame
        
        local iconLabel = Instance.new("TextLabel")
        iconLabel.Size = UDim2.new(0, 25, 1, 0)
        iconLabel.BackgroundTransparency = 1
        iconLabel.Text = icon
        iconLabel.TextColor3 = color
        iconLabel.Font = Enum.Font.GothamBold
        iconLabel.TextSize = 14
        iconLabel.Parent = frame
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.4, -30, 1, 0)
        nameLabel.Position = UDim2.new(0, 25, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = name
        nameLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 11
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = frame
        
        local valueLabel = Instance.new("TextLabel")
        valueLabel.Size = UDim2.new(0.6, 0, 1, 0)
        valueLabel.Position = UDim2.new(0.4, 0, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = value
        valueLabel.TextColor3 = color
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 12
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.Name = "Value"
        valueLabel.Parent = frame
        
        return frame, valueLabel
    end
    
    -- Создаем элементы статистики (первая строка)
    local incomeFrame, incomeStat = createStatItem("Доход:", "$0.00", 
        Color3.fromRGB(100, 255, 100), "💰", UDim2.new(0, 0, 0, 0))
    incomeFrame.Parent = StatsGrid
    
    local propertiesFrame, propertiesStat = createStatItem("Объекты:", "0", 
        Color3.fromRGB(100, 200, 255), "🏢", UDim2.new(0.52, 5, 0, 0))
    propertiesFrame.Parent = StatsGrid
    
    -- Вторая строка
    local occupancyFrame, occupancyStat = createStatItem("Заполнено:", "0%", 
        Color3.fromRGB(255, 200, 100), "📈", UDim2.new(0, 0, 0, 33))
    occupancyFrame.Parent = StatsGrid
    
    local cycleFrame, cycleStat = createStatItem("Цикл:", "#0", 
        Color3.fromRGB(200, 100, 255), "🔄", UDim2.new(0.52, 5, 0, 33))
    cycleFrame.Parent = StatsGrid
    
    -- Третья строка
    local changeFrame, changeStat = createStatItem("Изменение:", "+$0.00", 
        Color3.fromRGB(255, 255, 100), "📊", UDim2.new(0, 0, 0, 66))
    changeFrame.Parent = StatsGrid
    
    local timeFrame, timeStat = createStatItem("Время:", "0.00s", 
        Color3.fromRGB(100, 255, 255), "⏱️", UDim2.new(0.52, 5, 0, 66))
    timeFrame.Parent = StatsGrid
    
    -- Четвертая строка (полная ширина)
    local replacementsFrame, replacementsStat = createStatItem("Всего замен:", "0", 
        Color3.fromRGB(255, 150, 100), "👥", UDim2.new(0, 0, 0, 99), UDim2.new(1, 0, 0, 28))
    replacementsFrame.Parent = StatsGrid
    
    -- Карточка лучшего объекта
    local BestPropertyCard = Instance.new("Frame")
    BestPropertyCard.Size = UDim2.new(1, -20, 0, 90)
    BestPropertyCard.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
    BestPropertyCard.BorderSizePixel = 0
    BestPropertyCard.LayoutOrder = 2
    
    local BestCorner = Instance.new("UICorner")
    BestCorner.CornerRadius = UDim.new(0, 15)
    BestCorner.Parent = BestPropertyCard
    
    local BestStroke = Instance.new("UIStroke")
    BestStroke.Color = Color3.fromRGB(255, 200, 100)
    BestStroke.Thickness = 1.5
    BestStroke.Transparency = 0.3
    BestStroke.Parent = BestPropertyCard
    
    BestPropertyCard.Parent = ContentContainer
    
    local BestTitle = Instance.new("TextLabel")
    BestTitle.Size = UDim2.new(1, 0, 0, 30)
    BestTitle.BackgroundTransparency = 1
    BestTitle.Text = "🏆 ЛУЧШИЙ ОБЪЕКТ"
    BestTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    BestTitle.Font = Enum.Font.GothamBold
    BestTitle.TextSize = 14
    BestTitle.Parent = BestPropertyCard
    
    local BestInfo = Instance.new("TextLabel")
    BestInfo.Size = UDim2.new(1, -20, 0.7, -30)
    BestInfo.Position = UDim2.new(0, 10, 0, 30)
    BestInfo.BackgroundTransparency = 1
    BestInfo.Text = "Загрузка данных..."
    BestInfo.TextColor3 = Color3.fromRGB(200, 210, 230)
    BestInfo.Font = Enum.Font.Gotham
    BestInfo.TextSize = 11
    BestInfo.TextWrapped = true
    BestInfo.TextXAlignment = Enum.TextXAlignment.Left
    BestInfo.Name = "BestInfo"
    BestInfo.Parent = BestPropertyCard
    
    -- Панель управления
    local ControlCard = Instance.new("Frame")
    ControlCard.Size = UDim2.new(1, -20, 0, 180)
    ControlCard.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
    ControlCard.BorderSizePixel = 0
    ControlCard.LayoutOrder = 3
    
    local ControlCorner = Instance.new("UICorner")
    ControlCorner.CornerRadius = UDim.new(0, 15)
    ControlCorner.Parent = ControlCard
    
    ControlCard.Parent = ContentContainer
    
    local ControlTitle = Instance.new("TextLabel")
    ControlTitle.Size = UDim2.new(1, 0, 0, 35)
    ControlTitle.BackgroundTransparency = 1
    ControlTitle.Text = "🎮 УПРАВЛЕНИЕ"
    ControlTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    ControlTitle.Font = Enum.Font.GothamBold
    ControlTitle.TextSize = 14
    ControlTitle.Parent = ControlCard
    
    -- Контейнер для кнопок управления
    local ButtonsContainer = Instance.new("Frame")
    ButtonsContainer.Size = UDim2.new(1, -20, 1, -45)
    ButtonsContainer.Position = UDim2.new(0, 10, 0, 35)
    ButtonsContainer.BackgroundTransparency = 1
    ButtonsContainer.Parent = ControlCard
    
    -- Функция создания красивой кнопки
    local function createControlButton(text, icon, color, position, callback)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0.48, -5, 0, 60)
        button.Position = position
        button.BackgroundColor3 = color
        button.Text = ""
        button.AutoButtonColor = true
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = button
        
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Thickness = 1.5
        stroke.Transparency = 0.5
        stroke.Parent = button
        
        -- Градиент для кнопки
        local buttonGradient = Instance.new("UIGradient")
        buttonGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, color),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(
                math.floor(color.r * 200),
                math.floor(color.g * 200),
                math.floor(color.b * 200)
            ))
        })
        buttonGradient.Rotation = 90
        buttonGradient.Parent = button
        
        -- Эффект при наведении
        local hoverEffect = Instance.new("Frame")
        hoverEffect.Size = UDim2.new(1, 0, 1, 0)
        hoverEffect.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        hoverEffect.BackgroundTransparency = 0.9
        hoverEffect.Visible = false
        hoverEffect.Parent = button
        
        button.MouseEnter:Connect(function()
            hoverEffect.Visible = true
            local tween = TweenService:Create(button, TweenInfo.new(0.2), {Size = UDim2.new(0.48, 0, 0, 62)})
            tween:Play()
        end)
        
        button.MouseLeave:Connect(function()
            hoverEffect.Visible = false
            local tween = TweenService:Create(button, TweenInfo.new(0.2), {Size = UDim2.new(0.48, -5, 0, 60)})
            tween:Play()
        end)
        
        -- Иконка
        local iconLabel = Instance.new("TextLabel")
        iconLabel.Size = UDim2.new(0, 35, 0, 35)
        iconLabel.Position = UDim2.new(0, 10, 0.5, -17.5)
        iconLabel.BackgroundTransparency = 1
        iconLabel.Text = icon
        iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        iconLabel.Font = Enum.Font.GothamBold
        iconLabel.TextSize = 20
        iconLabel.Parent = button
        
        -- Текст
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, -50, 1, 0)
        textLabel.Position = UDim2.new(0, 45, 0, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = text
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.Font = Enum.Font.Gotham
        textLabel.TextSize = 13
        textLabel.TextXAlignment = Enum.TextXAlignment.Left
        textLabel.Parent = button
        
        -- Подсветка при клике
        button.MouseButton1Click:Connect(function()
            local clickEffect = Instance.new("Frame")
            clickEffect.Size = UDim2.new(1, 0, 1, 0)
            clickEffect.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            clickEffect.BackgroundTransparency = 0.7
            clickEffect.Parent = button
            
            local tween = TweenService:Create(clickEffect, TweenInfo.new(0.3), {BackgroundTransparency = 1})
            tween:Play()
            tween.Completed:Connect(function()
                clickEffect:Destroy()
            end)
            
            if callback then
                task.spawn(callback)
            end
        end)
        
        button.Parent = ButtonsContainer
        return button
    end
    
    -- Создаем кнопки управления (2x2 сетка)
    local autoButton = createControlButton("АВТОРЕЖИМ", "▶", Color3.fromRGB(0, 180, 0), 
        UDim2.new(0, 0, 0, 0), function()
            if not isRunning then
                task.spawn(startAutoOptimizer)
            end
        end)
    
    local quickButton = createControlButton("БЫСТРАЯ", "⚡", Color3.fromRGB(255, 150, 0), 
        UDim2.new(0.52, 5, 0, 0), quickOptimize)
    
    local fillButton = createControlButton("ЗАПОЛНИТЬ", "🚀", Color3.fromRGB(0, 150, 255), 
        UDim2.new(0, 0, 0, 65), forceFillAllSpots)
    
    local aggressiveButton = createControlButton("АГРЕССИВНО", "💥", Color3.fromRGB(255, 100, 100), 
        UDim2.new(0.52, 5, 0, 65), aggressiveReplaceAll)
    
    -- Карточка логов
    local LogCard = Instance.new("Frame")
    LogCard.Size = UDim2.new(1, -20, 0, 150)
    LogCard.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    LogCard.BorderSizePixel = 0
    LogCard.LayoutOrder = 4
    
    local LogCorner = Instance.new("UICorner")
    LogCorner.CornerRadius = UDim.new(0, 15)
    LogCorner.Parent = LogCard
    
    LogCard.Parent = ContentContainer
    
    local LogTitle = Instance.new("TextLabel")
    LogTitle.Size = UDim2.new(1, 0, 0, 30)
    LogTitle.BackgroundTransparency = 1
    LogTitle.Text = "📝 ПОСЛЕДНИЕ СОБЫТИЯ"
    LogTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    LogTitle.Font = Enum.Font.GothamBold
    LogTitle.TextSize = 14
    LogTitle.Parent = LogCard
    
    -- ScrollingFrame для логов
    local LogScrollingFrame = Instance.new("ScrollingFrame")
    LogScrollingFrame.Size = UDim2.new(1, -10, 1, -40)
    LogScrollingFrame.Position = UDim2.new(0, 5, 0, 30)
    LogScrollingFrame.BackgroundTransparency = 1
    LogScrollingFrame.BorderSizePixel = 0
    LogScrollingFrame.ScrollBarThickness = 3
    LogScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 150, 255)
    LogScrollingFrame.ScrollBarImageTransparency = 0.7
    LogScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    LogScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    LogScrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    LogScrollingFrame.Parent = LogCard
    
    local LogContainer = Instance.new("Frame")
    LogContainer.Size = UDim2.new(1, 0, 0, 0)
    LogContainer.BackgroundTransparency = 1
    LogContainer.Parent = LogScrollingFrame
    
    local LogListLayout = Instance.new("UIListLayout")
    LogListLayout.Padding = UDim.new(0, 5)
    LogListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    LogListLayout.Parent = LogContainer
    
    -- Буфер для логов
    local logBuffer = {}
    local maxLogs = 8
    
    -- Функция обновления логов в GUI
    _G.GUILogger = function(message, type)
        local timestamp = os.date("%H:%M")
        local color = Color3.fromRGB(200, 210, 230)
        
        if type == "success" then
            color = Color3.fromRGB(100, 255, 100)
        elseif type == "error" then
            color = Color3.fromRGB(255, 100, 100)
        elseif type == "warning" then
            color = Color3.fromRGB(255, 200, 100)
        elseif type == "money" then
            color = Color3.fromRGB(100, 255, 255)
        elseif type == "spot" then
            color = Color3.fromRGB(100, 200, 255)
        elseif type == "hire" then
            color = Color3.fromRGB(255, 150, 100)
        elseif type == "evict" then
            color = Color3.fromRGB(255, 100, 200)
        end
        
        -- Создаем новый лог элемент
        local logFrame = Instance.new("Frame")
        logFrame.Size = UDim2.new(1, 0, 0, 25)
        logFrame.BackgroundTransparency = 1
        logFrame.LayoutOrder = 1
        
        -- Сдвигаем старые логи вниз
        for _, child in ipairs(LogContainer:GetChildren()) do
            if child:IsA("Frame") then
                child.LayoutOrder = child.LayoutOrder + 1
            end
        end
        
        local timeLabel = Instance.new("TextLabel")
        timeLabel.Size = UDim2.new(0, 40, 1, 0)
        timeLabel.BackgroundTransparency = 1
        timeLabel.Text = string.format("[%s]", timestamp)
        timeLabel.TextColor3 = Color3.fromRGB(150, 160, 180)
        timeLabel.Font = Enum.Font.Gotham
        timeLabel.TextSize = 10
        timeLabel.TextXAlignment = Enum.TextXAlignment.Left
        timeLabel.Parent = logFrame
        
        local messageLabel = Instance.new("TextLabel")
        messageLabel.Size = UDim2.new(1, -45, 1, 0)
        messageLabel.Position = UDim2.new(0, 40, 0, 0)
        messageLabel.BackgroundTransparency = 1
        messageLabel.Text = message
        messageLabel.TextColor3 = color
        messageLabel.Font = Enum.Font.Gotham
        messageLabel.TextSize = 11
        messageLabel.TextXAlignment = Enum.TextXAlignment.Left
        messageLabel.TextWrapped = true
        messageLabel.Parent = logFrame
        
        logFrame.Parent = LogContainer
        
        -- Удаляем старые логи если слишком много
        task.wait()
        local children = LogContainer:GetChildren()
        for i = #children, maxLogs + 1, -1 do
            local child = children[i]
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        -- Прокручиваем к самому новому логу
        task.wait(0.05)
        LogScrollingFrame.CanvasPosition = Vector2.new(0, LogScrollingFrame.AbsoluteCanvasSize.Y)
    end
    
    -- Функция обновления статистики в GUI
    _G.UpdateGUIStats = function(data)
        incomeStat.Text = string.format("$%.2f", data.totalIncome)
        propertiesStat.Text = tostring(data.totalProperties)
        occupancyStat.Text = string.format("%.1f%%", data.occupancyRate)
        cycleStat.Text = "#" .. tostring(cycleCount)
        
        if data.lastIncomeChange > 0 then
            changeStat.Text = string.format("+$%.2f", data.lastIncomeChange)
            changeStat.TextColor3 = Color3.fromRGB(100, 255, 100)
        elseif data.lastIncomeChange < 0 then
            changeStat.Text = string.format("-$%.2f", math.abs(data.lastIncomeChange))
            changeStat.TextColor3 = Color3.fromRGB(255, 100, 100)
        else
            changeStat.Text = "$0.00"
            changeStat.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
        
        timeStat.Text = string.format("%.2fs", data.cycleTime)
        replacementsStat.Text = tostring(data.totalReplacements)
        
        if data.bestProperty then
            BestInfo.Text = string.format("%s\n💰 $%.2f | 🏘️ %s", 
                data.bestProperty.Type or "Неизвестно",
                data.bestProperty.Income or 0,
                data.bestProperty.District or "Неизвестно")
        else
            BestInfo.Text = "Нет данных об объектах"
        end
    end
    
    -- Функция обновления статуса авторежима
    _G.UpdateAutoStatus = function(running)
        if running then
            StatusIndicator.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
            StatusGlow.ImageColor3 = Color3.fromRGB(50, 255, 50)
            autoButton.TextLabel.Text = "ПАУЗА"
        else
            StatusIndicator.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            StatusGlow.ImageColor3 = Color3.fromRGB(255, 50, 50)
            autoButton.TextLabel.Text = "АВТОРЕЖИМ"
        end
    end
    
    -- Функционал Drag and Drop
    local dragging = false
    local dragStart
    local startPosition
    
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPosition = MainContainer.Position
            
            -- Эффект при захвате
            local tween = TweenService:Create(MainContainer, TweenInfo.new(0.1), {
                BackgroundTransparency = 0.15,
                Size = UDim2.new(0, 345, 0, 505)
            })
            tween:Play()
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            MainContainer.Position = startPosition + UDim2.new(0, delta.X, 0, delta.Y)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            
            -- Эффект при отпускании
            local tween = TweenService:Create(MainContainer, TweenInfo.new(0.1), {
                BackgroundTransparency = 0.05,
                Size = UDim2.new(0, 340, 0, 500)
            })
            tween:Play()
        end
    end)
    
    -- Функционал сворачивания/разворачивания
    local isMinimized = false
    local originalSize = MainContainer.Size
    local minimizedSize = UDim2.new(0, 340, 0, 55)
    
    ToggleButton.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        
        if isMinimized then
            -- Сворачиваем
            ToggleButton.Text = "▲"
            local tween = TweenService:Create(MainContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = minimizedSize
            })
            tween:Play()
            ContainerMask.Visible = false
        else
            -- Разворачиваем
            ToggleButton.Text = "▼"
            local tween = TweenService:Create(MainContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = originalSize
            })
            tween:Play()
            ContainerMask.Visible = true
        end
    end)
    
    -- Анимация появления
    MainContainer.BackgroundTransparency = 1
    MainContainer.Size = UDim2.new(0, 0, 0, 0)
    ContainerMask.Visible = false
    
    local openTween = TweenService:Create(MainContainer, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = originalSize,
        BackgroundTransparency = 0.05
    })
    openTween:Play()
    
    openTween.Completed:Connect(function()
        ContainerMask.Visible = true
        log("🎮 Premium интерфейс создан", "success")
        log("👆 Перетаскивайте за верхнюю панель", "info")
        log("📱 Адаптировано для мобильных устройств", "info")
    end)
    
    -- Пульсация индикатора статуса
    task.spawn(function()
        while ScreenGui.Parent do
            local tween = TweenService:Create(StatusGlow, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, true), {
                ImageTransparency = 0.3
            })
            tween:Play()
            task.wait(1)
        end
    end)
    
    -- Автоматическое обновление размера ScrollingFrame
    task.spawn(function()
        while ScreenGui.Parent do
            task.wait(1)
            MainScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, ContentContainer.AbsoluteSize.Y)
        end
    end)
    
    return ScreenGui
end

-- Инициализация
print("\n" .. string.rep("=", 70))
print("🏢 АВТООПТИМИЗАТОР АРЕНДАТОРОВ ВЕРСИЯ 5.0")
print("🎯 PREMIUM UI + SCROLLINGFRAME EDITION")
print(string.rep("=", 70))
print("📁 NetworkClient путь:", NetworkPath:GetFullName())
print("⚙️ Настройки:")
print("   Удержание от: " .. MIN_STARS .. "⭐")
print("   Новые от: " .. MIN_STARS_FOR_NEW .. "⭐")
print("   Интервал: " .. CHECK_INTERVAL .. "с")
print("   Режим: Агрессивная замена слабых арендаторов")
print("   🎨 Premium интерфейс с ScrollingFrame")
print("   📱 Полная адаптация для телефонов")
print("   👆 Drag & Drop + сворачивание")
print(string.rep("=", 70))

-- Устанавливаем слушатели обновлений
setupPortfolioListeners()

-- Создаем Premium UI
createPremiumMobileUI()

-- Автоматический старт через 3 секунды
task.wait(3)
log("✅ Система инициализирована", "success")
log("💡 Алгоритм: Проверка каждого места + замена слабых", "info")
log("📝 Новые заявки: Принимаются от 3+ звезд", "info")
log("👋 Старые арендаторы: Заменяются если <3⭐ или низкий доход", "info")

-- Автозапуск через 5 секунд
task.wait(5)
if not isRunning then
    log("🚀 Автозапуск оптимизатора...", "info")
    task.spawn(startAutoOptimizer)
end

-- Экспортируем функции
_G.quickOptimize = quickOptimize
_G.startAutoOptimizer = startAutoOptimizer
_G.stopOptimizer = stopOptimizer
_G.forceFillAllSpots = forceFillAllSpots
_G.aggressiveReplaceAll = aggressiveReplaceAll
_G.updatePropertyCache = updatePropertyCache

return {
    quickOptimize = quickOptimize,
    startAutoOptimizer = startAutoOptimizer,
    stopOptimizer = stopOptimizer,
    forceFillAllSpots = forceFillAllSpots,
    aggressiveReplaceAll = aggressiveReplaceAll,
    updatePropertyCache = updatePropertyCache,
    optimizeProperty = optimizeProperty,
    updateStatistics = updateStatistics
}
