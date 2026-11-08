
if GetCurrentResourceName() ~= "brancosdev-CityWorks" then
    error(string.format(
        "\n^1[brancosdev-CityWorks] HATA: Bu script yalnizca 'brancosdev-CityWorks' klasor adi ile calisir.^0\n" ..
        "^1Mevcut isim: '%s' — Script durduruldu.^0",
        GetCurrentResourceName()
    ), 0)
    return
end

local onDuty = false
local currentTask = nil
local taskBlip = nil
local isDoingAction = false
local currentLevel = 1
local activeVehicle = nil
local savedOutfit = nil
local isWearingUniform = false
local hasTrashBag = false
local trashBagProp = nil
local roadHasCone = false
local placedRoadCones = {}
local roadConesPlacedCount = 0
local requiredRoadCones = 3
local hasRoadConeInHand = false
local roadConeInHandProp = nil

-- Framework Nesneleri
local QBCore = nil

Citizen.CreateThread(function()
    if GetResourceState("qb-core") == "started" then
        pcall(function() QBCore = exports['qb-core']:GetCoreObject() end)
    end
end)

-- Canlı Oturum İstatistikleri (NUI için)
local sessionEarnings = 0
local sessionCompletedTasks = 0
local dutyStartTimestamp = 0
local recentRewards = {}

-- Dinamik Etkileşim Türü Belirleyici (qb-target, ox_target veya drawtext)
function GetActiveInteraction()
    local setting = Config.InteractionType or "auto"
    if setting == "auto" then
        if GetResourceState("ox_target") == "started" and exports.ox_target then
            return "ox_target"
        elseif GetResourceState("qb-target") == "started" and exports['qb-target'] then
            return "qb-target"
        else
            return "drawtext"
        end
    elseif setting == "ox_target" then
        if GetResourceState("ox_target") == "started" and exports.ox_target then
            return "ox_target"
        end
        return "drawtext"
    elseif setting == "qb-target" then
        if GetResourceState("qb-target") == "started" and exports['qb-target'] then
            return "qb-target"
        end
        return "drawtext"
    end
    return "drawtext"
end

-- ==========================================
-- KALICI GLOBAL ARAÇ TARGET ETKİLEŞİMLERİ (ALT MENÜSÜ)
-- ==========================================
local function IsNearVehicleTrunk(veh)
    if not veh or not DoesEntityExist(veh) then return false end
    local trunkCoords = GetVehicleTrunkCoords(veh)
    if not trunkCoords then return false end
    local pCoords = GetEntityCoords(PlayerPedId())
    return #(pCoords - trunkCoords) <= 3.2
end

function RemoveGlobalVehicleTargets()
    pcall(function()
        if exports['qb-target'] then
            exports['qb-target']:RemoveGlobalVehicle("Bagajdan Duba Al")
            exports['qb-target']:RemoveGlobalVehicle("Dubayı Bagaja Geri Koy")
            exports['qb-target']:RemoveGlobalVehicle("Çöpü At")
        end
    end)
    pcall(function()
        if exports.ox_target then
            exports.ox_target:removeGlobalVehicle('cityworks_take_cone_global')
            exports.ox_target:removeGlobalVehicle('cityworks_return_cone_global')
            exports.ox_target:removeGlobalVehicle('cityworks_throw_trash_global')
        end
    end)
end

Citizen.CreateThread(function()
    Citizen.Wait(1200)
    -- Olası eski / mükerrer kayıtları temizle
    RemoveGlobalVehicleTargets()
    
    local inter = GetActiveInteraction()
    
    if inter == "ox_target" then
        pcall(function()
            if exports.ox_target then
                exports.ox_target:addGlobalVehicle({
                    {
                        name = 'cityworks_take_cone_global',
                        icon = 'fas fa-shield-alt',
                        label = 'Bagajdan Duba Al',
                        onSelect = function(data)
                            TakeConeFromTruck()
                        end,
                        canInteract = function(entity)
                            if not onDuty or not currentTask or currentTask.type ~= "road" then return false end
                            if activeVehicle and DoesEntityExist(activeVehicle) and entity ~= activeVehicle then return false end
                            if not IsNearVehicleTrunk(entity) then return false end
                            return not roadHasCone and not hasRoadConeInHand
                        end,
                        distance = 2.5
                    },
                    {
                        name = 'cityworks_return_cone_global',
                        icon = 'fas fa-undo',
                        label = 'Dubayı Bagaja Geri Koy',
                        onSelect = function(data)
                            ReturnConeToTruck()
                        end,
                        canInteract = function(entity)
                            if not onDuty or not currentTask or currentTask.type ~= "road" then return false end
                            if activeVehicle and DoesEntityExist(activeVehicle) and entity ~= activeVehicle then return false end
                            if not IsNearVehicleTrunk(entity) then return false end
                            return hasRoadConeInHand
                        end,
                        distance = 2.5
                    },
                    {
                        name = 'cityworks_throw_trash_global',
                        icon = 'fas fa-truck-loading',
                        label = 'Çöpü At',
                        onSelect = function(data)
                            ThrowTrashInTruck()
                        end,
                        canInteract = function(entity)
                            if not onDuty or not currentTask or currentTask.type ~= "trash" then return false end
                            if activeVehicle and DoesEntityExist(activeVehicle) and entity ~= activeVehicle then return false end
                            if not IsNearVehicleTrunk(entity) then return false end
                            return hasTrashBag
                        end,
                        distance = 2.5
                    }
                })
            end
        end)
    elseif inter == "qb-target" then
        pcall(function()
            if exports['qb-target'] then
                exports['qb-target']:AddGlobalVehicle({
                    options = {
                        {
                            type = "client",
                            action = function(entity)
                                TakeConeFromTruck()
                            end,
                            icon = "fas fa-shield-alt",
                            label = "Bagajdan Duba Al",
                            canInteract = function(entity)
                                if not onDuty or not currentTask or currentTask.type ~= "road" then return false end
                                if activeVehicle and DoesEntityExist(activeVehicle) and entity ~= activeVehicle then return false end
                                if not IsNearVehicleTrunk(entity) then return false end
                                return not roadHasCone and not hasRoadConeInHand
                            end
                        },
                        {
                            type = "client",
                            action = function(entity)
                                ReturnConeToTruck()
                            end,
                            icon = "fas fa-undo",
                            label = "Dubayı Bagaja Geri Koy",
                            canInteract = function(entity)
                                if not onDuty or not currentTask or currentTask.type ~= "road" then return false end
                                if activeVehicle and DoesEntityExist(activeVehicle) and entity ~= activeVehicle then return false end
                                if not IsNearVehicleTrunk(entity) then return false end
                                return hasRoadConeInHand
                            end
                        },
                        {
                            type = "client",
                            action = function(entity)
                                ThrowTrashInTruck()
                            end,
                            icon = "fas fa-truck-loading",
                            label = "Çöpü At",
                            canInteract = function(entity)
                                if not onDuty or not currentTask or currentTask.type ~= "trash" then return false end
                                if activeVehicle and DoesEntityExist(activeVehicle) and entity ~= activeVehicle then return false end
                                if not IsNearVehicleTrunk(entity) then return false end
                                return hasTrashBag
                            end
                        }
                    },
                    distance = 2.5
                })
            end
        end)
    end
end)

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        local factor = (string.len(text)) / 370
        
        SetTextScale(0.32, 0.32)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 150)
    end
end

function Notify(text, type)
    if not type then type = "info" end

    local system = Config.NotifySystem or "auto"
    if system == "auto" then
        if GetResourceState("ox_lib") == "started" and lib and lib.notify then
            system = "ox_lib"
        elseif GetResourceState("qbx_core") == "started" and exports.qbx_core then
            system = "qbox"
        elseif GetResourceState("qb-core") == "started" then
            system = "qbcore"
        elseif GetResourceState("okokNotify") == "started" then
            system = "okok"
        else
            system = "custom"
        end
    end

    if system == "qbcore" then
        if not QBCore and exports['qb-core'] then
            pcall(function() QBCore = exports['qb-core']:GetCoreObject() end)
        end
        if QBCore and QBCore.Functions and QBCore.Functions.Notify then
            QBCore.Functions.Notify(text, type)
        else
            TriggerEvent("QBCore:Notify", text, type)
        end
    elseif system == "qbox" then
        if exports.qbx_core then
            exports.qbx_core:Notify(text, type)
        elseif lib and lib.notify then
            lib.notify({ title = 'CityWorks', description = text, type = type })
        else
            TriggerEvent("QBCore:Notify", text, type)
        end
    elseif system == "ox_lib" then
        if lib and lib.notify then
            lib.notify({ title = 'CityWorks', description = text, type = type })
        else
            text = string.gsub(text, "~[a-z]~", "")
            SendNUIMessage({
                action = "notify",
                text = text,
                type = type
            })
        end
    elseif system == "okok" then
        if exports['okokNotify'] then
            exports['okokNotify']:Alert("CityWorks", text, 4000, type)
        else
            text = string.gsub(text, "~[a-z]~", "")
            SendNUIMessage({
                action = "notify",
                text = text,
                type = type
            })
        end
    elseif system == "custom" then
        text = string.gsub(text, "~[a-z]~", "")
        SendNUIMessage({
            action = "notify",
            text = text,
            type = type
        })
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString(text)
        DrawNotification(false, true)
    end
end

RegisterNetEvent("cityworks:client:frameworkError")
AddEventHandler("cityworks:client:frameworkError", function(msg)
    Notify(msg, "error")
end)

local function SaveCurrentOutfit()
    local ped = PlayerPedId()
    savedOutfit = { components = {}, props = {} }
    for i = 0, 11 do
        savedOutfit.components[i] = {
            drawable = GetPedDrawableVariation(ped, i),
            texture = GetPedTextureVariation(ped, i),
            palette = GetPedPaletteVariation(ped, i)
        }
    end
    for i = 0, 7 do
        savedOutfit.props[i] = {
            drawable = GetPedPropIndex(ped, i),
            texture = GetPedPropTextureIndex(ped, i)
        }
    end
end

local function RestoreOutfit()
    if not savedOutfit then return end
    local ped = PlayerPedId()
    for i = 0, 11 do
        SetPedComponentVariation(ped, i, savedOutfit.components[i].drawable, savedOutfit.components[i].texture, savedOutfit.components[i].palette)
    end
    for i = 0, 7 do
        if savedOutfit.props[i].drawable == -1 then
            ClearPedProp(ped, i)
        else
            SetPedPropIndex(ped, i, savedOutfit.props[i].drawable, savedOutfit.props[i].texture, true)
        end
    end
    savedOutfit = nil
    isWearingUniform = false
end

RegisterNetEvent("cityworks:client:syncLevel")
AddEventHandler("cityworks:client:syncLevel", function(level)
    currentLevel = level
end)

RegisterNetEvent("cityworks:client:levelUp")
AddEventHandler("cityworks:client:levelUp", function(newLevel, newTitle)
    currentLevel = newLevel
    Notify(string.format("TEBRİKLER! LEVEL ATLADIN!\nYeni Seviye: Seviye %d - %s", newLevel, newTitle), "success")
    
    SendNUIMessage({
        action = "levelUp",
        level = newLevel,
        levelTitle = newTitle
    })
end)

-- ==========================================
-- MERKEZ VE NPC ETKİLEŞİMİ
-- ==========================================
local centerNPC = nil

Citizen.CreateThread(function()
    if Config.Center.Blip.Enabled then
        local blip = AddBlipForCoord(Config.Center.NPC.Coords.x, Config.Center.NPC.Coords.y, Config.Center.NPC.Coords.z)
        SetBlipSprite(blip, Config.Center.Blip.Sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.Center.Blip.Scale)
        SetBlipColour(blip, Config.Center.Blip.Color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Center.Blip.Name)
        EndTextCommandSetBlipName(blip)
    end
    
    if Config.Center.NPC.Enabled then
        local npcHash = GetHashKey(Config.Center.NPC.Model)
        RequestModel(npcHash)
        while not HasModelLoaded(npcHash) do
            Citizen.Wait(10)
        end
        
        local cx = Config.Center.NPC.Coords.x
        local cy = Config.Center.NPC.Coords.y
        local cz = Config.Center.NPC.Coords.z - 0.98

        centerNPC = CreatePed(4, npcHash, cx, cy, cz, Config.Center.NPC.Heading, false, true)
        SetEntityAsMissionEntity(centerNPC, true, true)
        SetEntityHeading(centerNPC, Config.Center.NPC.Heading)
        FreezeEntityPosition(centerNPC, true)
        SetEntityInvincible(centerNPC, true)
        SetBlockingOfNonTemporaryEvents(centerNPC, true)
        SetPedCanRagdoll(centerNPC, false)
        TaskStartScenarioInPlace(centerNPC, "WORLD_HUMAN_CLIPBOARD", 0, true)
        SetModelAsNoLongerNeeded(npcHash)
        
        local inter = GetActiveInteraction()
        if inter == "qb-target" then
            pcall(function()
                exports['qb-target']:AddTargetEntity(centerNPC, {
                    options = {
                        {
                            type = "client",
                            action = function()
                                TriggerServerEvent("cityworks:server:requestMenu")
                            end,
                            icon = "fas fa-clipboard-list",
                            label = "CityWorks Merkezi",
                        }
                    },
                    distance = Config.Center.NPC.InteractDistance
                })
            end)
        elseif inter == "ox_target" then
            pcall(function()
                exports.ox_target:addLocalEntity(centerNPC, {
                    {
                        name = 'cityworks_center',
                        icon = 'fas fa-clipboard-list',
                        label = 'CityWorks Merkezi',
                        onSelect = function()
                            TriggerServerEvent("cityworks:server:requestMenu")
                        end
                    }
                })
            end)
        end
    end
end)

function GetVehicleTrunkCoords(veh)
    if not veh or not DoesEntityExist(veh) then return nil end
    local minDim, maxDim = GetModelDimensions(GetEntityModel(veh))
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, minDim.y - 0.6, 0.2)
end

function RemoveTrashBag()
    hasTrashBag = false
    if trashBagProp and DoesEntityExist(trashBagProp) then
        DetachEntity(trashBagProp, true, true)
        DeleteEntity(trashBagProp)
        trashBagProp = nil
    end
    local ped = PlayerPedId()
    if IsEntityPlayingAnim(ped, "missfbi4prepp1", "_idle_garbage_man", 3) or IsEntityPlayingAnim(ped, "missfbi4prepp1", "_bag_walk_garbage_man", 3) then
        ClearPedTasks(ped)
    end
end

-- Yol Konileri Temizleme
function RemoveRoadCones()
    if roadConeInHandProp and DoesEntityExist(roadConeInHandProp) then
        DeleteObject(roadConeInHandProp)
        DeleteEntity(roadConeInHandProp)
        roadConeInHandProp = nil
    end
    hasRoadConeInHand = false
    for _, cone in ipairs(placedRoadCones) do
        if DoesEntityExist(cone) then
            DeleteObject(cone)
            DeleteEntity(cone)
        end
    end
    placedRoadCones = {}
    roadConesPlacedCount = 0
    roadHasCone = false
end

-- Temizlik ve Güvenli Kapanış
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    
    SetNuiFocus(false, false)
    RemoveTrashBag()
    
    if centerNPC and DoesEntityExist(centerNPC) then
        pcall(function()
            if exports['qb-target'] then
                exports['qb-target']:RemoveTargetEntity(centerNPC)
            end
            if exports.ox_target then
                exports.ox_target:removeLocalEntity(centerNPC, 'cityworks_center')
            end
        end)
        DeleteEntity(centerNPC)
    end
    
    if activeVehicle and DoesEntityExist(activeVehicle) then
        DeleteEntity(activeVehicle)
    end
    
    if taskBlip then
        RemoveBlip(taskBlip)
    end
    
    pcall(function()
        if exports['qb-target'] then
            exports['qb-target']:RemoveZone("cityworks_task")
        end
        if exports.ox_target then
            exports.ox_target:removeZone("cityworks_task")
        end
    end)
    
    RemoveGlobalVehicleTargets()
    RemoveRoadCones()
    
    if isWearingUniform then
        RestoreOutfit()
    end
end)

-- Karakter Değiştirme / Çıkışta Mesaiyi ve Görevi Sıfırlama
local function ResetPlayerJobState()
    if onDuty then
        onDuty = false
        dutyStartTimestamp = 0
        if currentTask then
            CancelTask()
        end
        if activeVehicle and DoesEntityExist(activeVehicle) then
            DeleteEntity(activeVehicle)
            activeVehicle = nil
        end
        if isWearingUniform then
            RestoreOutfit()
        end
        SendNUIMessage({
            action = "updateDuty",
            onDuty = false
        })
    end
end

RegisterNetEvent("QBCore:Client:OnPlayerUnload", ResetPlayerJobState)
RegisterNetEvent("qbx_core:client:playerLoggedOut", ResetPlayerJobState)
RegisterNetEvent("qbx_core:client:onPlayerLogout", ResetPlayerJobState)

-- Klasik DrawText Etkileşim Döngüsü
Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local inter = GetActiveInteraction()
        
        if inter == "drawtext" then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local dist = #(playerCoords - vector3(Config.Center.NPC.Coords.x, Config.Center.NPC.Coords.y, Config.Center.NPC.Coords.z))

            if dist < Config.Center.NPC.DrawDistance then
                sleep = 0
                
                if dist < Config.Center.NPC.InteractDistance then
                    DrawText3D(Config.Center.NPC.Coords.x, Config.Center.NPC.Coords.y, Config.Center.NPC.Coords.z + 1.0, "[E] CityWorks Merkezi")

                    if IsControlJustReleased(0, 38) then
                        TriggerServerEvent("cityworks:server:requestMenu")
                    end
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

-- Mesai Durumunu Değiştir
function ToggleDuty()
    onDuty = not onDuty
    TriggerServerEvent("cityworks:server:toggleDuty", onDuty)

    if onDuty then
        dutyStartTimestamp = GetGameTimer()
        Notify("Mesaiye başladınız! İyi çalışmalar.", "success")
        if currentTask then
            CancelTask()
        end
    else
        dutyStartTimestamp = 0
        Notify("Mesainizi bitirdiniz.", "error")
        CancelTask()
        
        if activeVehicle and DoesEntityExist(activeVehicle) then
            DeleteEntity(activeVehicle)
            activeVehicle = nil
        end
        
        if isWearingUniform then
            RestoreOutfit()
        end
    end

    -- UI açıkken canlı güncelleme gönder
    SendNUIMessage({
        action = "updateDuty",
        onDuty = onDuty,
        dutyStartTime = dutyStartTimestamp
    })
end

-- ==========================================
-- NUI MENÜ AÇILIŞ VE İLETİŞİM
-- ==========================================
local currentMugshotHandle = nil

local function GetPlayerMugshot()
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end

    -- Varsa önceki kaydı temizle
    if currentMugshotHandle and IsPedheadshotValid(currentMugshotHandle) then
        UnregisterPedheadshot(currentMugshotHandle)
        currentMugshotHandle = nil
    end

    -- Önce transparan headshot dene, olmazsa normal headshot al
    local handle = RegisterPedheadshotTransparent(ped)
    if not handle or handle == 0 then
        handle = RegisterPedheadshot(ped)
    end
    if not handle or handle == 0 then return nil end

    local startTime = GetGameTimer()
    while not IsPedheadshotReady(handle) do
        Citizen.Wait(20)
        if GetGameTimer() - startTime > 3500 then
            UnregisterPedheadshot(handle)
            return nil
        end
    end

    if not IsPedheadshotValid(handle) then
        UnregisterPedheadshot(handle)
        return nil
    end

    currentMugshotHandle = handle
    local txd = GetPedheadshotTxdString(handle)
    if txd and txd ~= "" then
        -- FiveM NUI TXD URL formatı
        return string.format("https://nui-img/%s/%s?v=%d", txd, txd, GetGameTimer())
    end
    return nil
end

RegisterNetEvent("cityworks:client:openMenu")
AddEventHandler("cityworks:client:openMenu", function(level, xp, charName)
    currentLevel = level
    local currentXP = xp
    local playerName = charName or "Saha Personeli"
    local avatarUrl = GetPlayerMugshot()
    
    local levelTitle = (Config.Levels[level] and Config.Levels[level].Title) or "Stajyer"
    local isMax = (level >= #Config.Levels)
    local nextXP = isMax and 0 or (Config.Levels[level + 1] and Config.Levels[level + 1].XP or 0)
    local nextTitle = isMax and "Maksimum Seviye" or (Config.Levels[level + 1] and Config.Levels[level + 1].Title or "Maksimum Seviye")
    local baseXP = (Config.Levels[level] and Config.Levels[level].XP) or 0
    
    local currentTaskName = "Yok"
    if currentTask and Config.Tasks[currentTask.type] then
        currentTaskName = Config.Tasks[currentTask.type].Name
    end
    
    local tasksData = {}
    for _, type in ipairs(Config.TaskTypes) do
        local tCfg = Config.Tasks[type]
        if tCfg then
            local ptCount = (tCfg.Locations and tCfg.Locations[1] and #tCfg.Locations[1]) or 3
            table.insert(tasksData, {
                type = type,
                name = tCfg.Name,
                reqLevel = tCfg.RequiredLevel,
                unlocked = (tCfg.RequiredLevel <= currentLevel),
                rewardMin = tCfg.Reward.MoneyMin,
                rewardMax = tCfg.Reward.MoneyMax,
                xpMin = tCfg.Reward.XPMin,
                xpMax = tCfg.Reward.XPMax,
                pointCount = ptCount
            })
        end
    end
    
    local vehiclesData = {}
    for _, vCfg in ipairs(Config.Vehicles) do
        table.insert(vehiclesData, {
            name = vCfg.Name,
            model = vCfg.Model,
            reqLevel = vCfg.RequiredLevel,
            taskType = vCfg.TaskType,
            unlocked = (vCfg.RequiredLevel <= currentLevel)
        })
    end
    
    local uniformsData = {}
    for _, uCfg in ipairs(Config.Uniforms) do
        table.insert(uniformsData, {
            id = uCfg.ID,
            name = uCfg.Name,
            reqLevel = uCfg.RequiredLevel,
            unlocked = (uCfg.RequiredLevel <= currentLevel)
        })
    end
    
    local hasVehicle = (activeVehicle ~= nil and DoesEntityExist(activeVehicle))
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "open",
        onDuty = onDuty,
        dutyStartTime = dutyStartTimestamp,
        currentTask = currentTaskName,
        currentTaskType = currentTask and currentTask.type or nil,
        currentTaskStep = currentTask and currentTask.currentPointIndex or 0,
        currentTaskMaxSteps = currentTask and currentTask.maxPoints or 0,
        level = currentLevel,
        levelTitle = levelTitle,
        xp = currentXP,
        baseXP = baseXP,
        nextXP = nextXP,
        nextLevelTitle = nextTitle,
        nextTitle = nextTitle,
        isMax = isMax,
        tasks = tasksData,
        hasVehicle = hasVehicle,
        vehicles = vehiclesData,
        hasUniform = isWearingUniform,
        uniforms = uniformsData,
        sessionEarnings = sessionEarnings,
        sessionCompletedTasks = sessionCompletedTasks,
        recentRewards = recentRewards,
        playerName = playerName,
        avatarUrl = avatarUrl
    })
end)

RegisterNUICallback("close", function(data, cb)
    SetNuiFocus(false, false)
    if currentMugshotHandle then
        UnregisterPedheadshot(currentMugshotHandle)
        currentMugshotHandle = nil
    end
    cb("ok")
end)

RegisterNUICallback("toggleDuty", function(data, cb)
    ToggleDuty()
    cb("ok")
end)

RegisterNUICallback("startTask", function(data, cb)
    if not onDuty then
        Notify("Görev seçmek için önce mesaiye başlamalısınız!", "error")
        cb("ok")
        return
    end
    if not isWearingUniform then
        Notify("Göreve başlamak için önce iş kıyafetinizi giymelisiniz!", "error")
        cb("ok")
        return
    end
    
    if currentTask then
        CancelTask()
    end
    
    StartNewTask(data.type)
    cb("ok")
end)

RegisterNUICallback("cancelCurrentTask", function(data, cb)
    if currentTask then
        CancelTask()
        Notify("Mevcut görev iptal edildi.", "info")
        SendNUIMessage({
            action = "updateTaskState",
            currentTask = "Yok",
            currentTaskType = nil,
            currentTaskStep = 0,
            currentTaskMaxSteps = 0
        })
    end
    cb("ok")
end)

RegisterNUICallback("spawnVehicle", function(data, cb)
    if not onDuty then 
        Notify("Araç çıkarmak için önce mesaiye başlamalısınız!", "error")
        cb("ok")
        return 
    end
    
    if activeVehicle and DoesEntityExist(activeVehicle) then 
        Notify("Zaten kullanımda olan bir iş aracınız var!", "error")
        cb("ok")
        return 
    end
    
    local model = data.model
    local hash = GetHashKey(model)
    
    local allowed = false
    local vehicleConfig = nil
    for _, v in ipairs(Config.Vehicles) do
        if v.Model == model and v.RequiredLevel <= currentLevel then
            allowed = true
            vehicleConfig = v
            break
        end
    end
    if not allowed then 
        Notify("Bu aracı çıkarmak için seviyeniz yetersiz!", "error")
        cb("ok")
        return 
    end
    
    if not currentTask then
        Notify("Araç çıkarmak için önce bir göreve başlamalısınız!", "error")
        cb("ok")
        return
    end
    
    if vehicleConfig.TaskType and vehicleConfig.TaskType ~= currentTask.type then
        Notify("Bu araç, seçtiğiniz görev türü için uygun değil!", "error")
        cb("ok")
        return
    end
    
    local spawn = Config.VehicleSpawn
    if IsAnyVehicleNearPoint(spawn.coords.x, spawn.coords.y, spawn.coords.z, 3.0) then
        Notify("Araç çıkarma alanı dolu! Lütfen alanı boşaltın.", "error")
        cb("ok")
        return
    end
    
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Citizen.Wait(10)
    end
    
    activeVehicle = CreateVehicle(hash, spawn.coords.x, spawn.coords.y, spawn.coords.z, spawn.heading, true, false)
    SetEntityAsMissionEntity(activeVehicle, true, true)
    SetVehicleEngineOn(activeVehicle, true, true, false)
    
    local plate = "CW" .. tostring(math.random(1000, 9999))
    SetVehicleNumberPlateText(activeVehicle, plate)
    
    -- Anahtar Verme Entegrasyonu (Qbox, QBCore, Standalone)
    if GetResourceState("qbx_vehiclekeys") == "started" and exports['qbx_vehiclekeys'] then
        pcall(function() exports['qbx_vehiclekeys']:GiveKeys(activeVehicle) end)
    end
    if GetResourceState("qb-vehiclekeys") == "started" then
        TriggerEvent("vehiclekeys:client:SetOwner", plate)
        TriggerServerEvent("qb-vehiclekeys:server:AcquireVehicleKeys", plate)
    end
    if GetResourceState("wasabi_carlock") == "started" and exports['wasabi_carlock'] then
        pcall(function() exports['wasabi_carlock']:GiveKey(plate) end)
    end
    if GetResourceState("qs-vehiclekeys") == "started" and exports['qs-vehiclekeys'] then
        pcall(function() exports['qs-vehiclekeys']:GiveKeys(plate, model) end)
    end
    if GetResourceState("cd_garage") == "started" then
        TriggerEvent('cd_garage:AddKeys', exports['cd_garage']:GetPlate(activeVehicle))
    end
    -- Her halükarda aracın kapısını açık tut
    SetVehicleDoorsLocked(activeVehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(activeVehicle, false)
    
    -- Yakıt Entegrasyonu (ox_fuel, ps-fuel, LegacyFuel, native)
    if GetResourceState("ox_fuel") == "started" and exports['ox_fuel'] then
        pcall(function() exports['ox_fuel']:setFuel(activeVehicle, 100.0) end)
    elseif GetResourceState("ps-fuel") == "started" and exports['ps-fuel'] then
        pcall(function() exports['ps-fuel']:SetFuel(activeVehicle, 100.0) end)
    elseif GetResourceState("LegacyFuel") == "started" and exports['LegacyFuel'] then
        pcall(function() exports['LegacyFuel']:SetFuel(activeVehicle, 100.0) end)
    else
        SetVehicleFuelLevel(activeVehicle, 100.0)
    end
    
    Notify("İş aracı başarıyla çıkarıldı! Anahtarlar teslim edildi.", "success")
    SetModelAsNoLongerNeeded(hash)
    
    SendNUIMessage({
        action = "updateVehicle",
        hasVehicle = true
    })
    
    cb("ok")
end)

RegisterNUICallback("returnVehicle", function(data, cb)
    if activeVehicle and DoesEntityExist(activeVehicle) then
        DeleteEntity(activeVehicle)
        activeVehicle = nil
        Notify("İş aracı başarıyla teslim edildi.", "success")
        
        SendNUIMessage({
            action = "updateVehicle",
            hasVehicle = false
        })
    else
        Notify("Teslim edilecek aktif bir araç bulunamadı.", "error")
    end
    cb("ok")
end)

RegisterNUICallback("wearUniform", function(data, cb)
    if not onDuty then
        Notify("Kıyafet giymek için önce mesaiye başlamalısınız!", "error")
        cb("ok")
        return
    end

    if isWearingUniform then 
        Notify("Zaten bir iş kıyafeti giyiyorsunuz!", "warning")
        cb("ok")
        return 
    end
    
    local id = data.id
    local selectedUniform = nil
    for _, u in ipairs(Config.Uniforms) do
        if u.ID == id and u.RequiredLevel <= currentLevel then
            selectedUniform = u
            break
        end
    end
    
    if not selectedUniform then 
        Notify("Bu kıyafet için seviyeniz yetersiz!", "error")
        cb("ok")
        return 
    end
    
    SaveCurrentOutfit()
    
    local ped = PlayerPedId()
    local isMale = (GetEntityModel(ped) == GetHashKey("mp_m_freemode_01"))
    local outfitData = isMale and selectedUniform.Male or selectedUniform.Female
    
    if outfitData then
        RequestAnimDict("clothingtie")
        while not HasAnimDictLoaded("clothingtie") do Citizen.Wait(10) end
        TaskPlayAnim(ped, "clothingtie", "try_tie_neutral_a", 8.0, -8.0, 2500, 51, 0, false, false, false)
        Notify("Kıyafetiniz giydiriliyor...", "info")
        
        Citizen.SetTimeout(2000, function()
            if outfitData.Components then
                for k, v in pairs(outfitData.Components) do
                    SetPedComponentVariation(ped, k, v.drawable, v.texture, 0)
                end
            end
            if outfitData.Props then
                for k, v in pairs(outfitData.Props) do
                    if v.drawable == -1 then
                        ClearPedProp(ped, k)
                    else
                        SetPedPropIndex(ped, k, v.drawable, v.texture, true)
                    end
                end
            end
            isWearingUniform = true
            Notify("İş kıyafeti giyildi, iyi çalışmalar!", "success")
            ClearPedTasks(ped)
            
            SendNUIMessage({
                action = "updateUniform",
                hasUniform = true
            })
        end)
    end
    
    cb("ok")
end)

RegisterNUICallback("returnUniform", function(data, cb)
    if isWearingUniform then
        RestoreOutfit()
        Notify("Kendi sivil kıyafetlerinize döndünüz.", "info")
        SendNUIMessage({
            action = "updateUniform",
            hasUniform = false
        })
    else
        Notify("Üzerinizde çıkarılacak iş kıyafeti yok.", "info")
    end
    cb("ok")
end)

-- ==========================================
-- GÖREV MOTORU
-- ==========================================
function StartNewTask(forcedType)
    if not onDuty then return end
    
    local selectedType = forcedType
    local taskConfig = Config.Tasks[selectedType]
    if not taskConfig then return end
    
    if taskConfig.RequiredLevel > currentLevel then
        Notify("Bu görev için seviyeniz yetersiz!", "error")
        return
    end
    
    local locs = taskConfig.Locations
    local randomZoneIndex = math.random(1, #locs)
    local selectedZone = locs[randomZoneIndex]
    
    currentTask = {
        type = selectedType,
        points = selectedZone,
        currentPointIndex = 1,
        maxPoints = #selectedZone
    }
    
    UpdateTaskBlip()
    UpdateTaskTarget()
    
    Notify(string.format("Yeni Görev: %s! GPS işaretlendi, bölgeye intikal edin.", taskConfig.Name), "warning")
    TriggerServerEvent("cityworks:server:taskStarted", selectedType)
    
    SendNUIMessage({
        action = "updateTaskState",
        currentTask = taskConfig.Name,
        currentTaskType = selectedType,
        currentTaskStep = 1,
        currentTaskMaxSteps = #selectedZone
    })
end


function TakeConeFromTruck()
    if isDoingAction or hasRoadConeInHand or not onDuty or not currentTask then return end
    if currentTask.type ~= "road" then return end
    
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        Notify("Duba almak için araçtan inmelisiniz!", "warning")
        return
    end
    
    local targetVeh = activeVehicle
    if not targetVeh or not DoesEntityExist(targetVeh) then
        local pCoords = GetEntityCoords(ped)
        targetVeh = GetClosestVehicle(pCoords.x, pCoords.y, pCoords.z, 8.0, 0, 70)
    end
    
    if not targetVeh or not DoesEntityExist(targetVeh) then
        Notify("Yakında bir iş aracı bulunamadı!", "error")
        return
    end
    
    local trunkCoords = GetVehicleTrunkCoords(targetVeh)
    local pCoords = GetEntityCoords(ped)
    if trunkCoords and #(pCoords - trunkCoords) > 4.5 then
        Notify("Aracın arkasına / bagajına daha yakın olmalısınız!", "warning")
        return
    end
    
    isDoingAction = true
    FreezeEntityPosition(ped, true)
    TaskTurnPedToFaceEntity(ped, targetVeh, 500)
    Citizen.Wait(500)
    
    local animDict = "pickup_object"
    RequestAnimDict(animDict)
    local t = 0
    while not HasAnimDictLoaded(animDict) and t < 50 do
        Citizen.Wait(10)
        t = t + 1
    end
    TaskPlayAnim(ped, animDict, "pickup_low", 8.0, -8.0, 1500, 0, 0, false, false, false)
    Citizen.Wait(1200)
    
    local coneModel = GetHashKey("prop_roadcone02a")
    RequestModel(coneModel)
    t = 0
    while not HasModelLoaded(coneModel) and t < 50 do
        Citizen.Wait(10)
        t = t + 1
    end
    
    local carryDict = "anim@heists@box_carry@"
    RequestAnimDict(carryDict)
    t = 0
    while not HasAnimDictLoaded(carryDict) and t < 50 do
        Citizen.Wait(10)
        t = t + 1
    end
    
    local cCoords = GetEntityCoords(ped)
    roadConeInHandProp = CreateObject(coneModel, cCoords.x, cCoords.y, cCoords.z, true, true, true)
    SetEntityCollision(roadConeInHandProp, false, false)
    
    -- Dubayı iki elle önde kucakta/göğüs hizasında dik ve gerçekçi tutma
    -- Bone 60309 = SKEL_Spine3 (Gövde/Göğüs kemiği)
    local bone = GetPedBoneIndex(ped, 60309)
    AttachEntityToEntity(roadConeInHandProp, ped, bone,
        0.05, 0.38, -0.05,    -- xyz pozisyon (önde, göğüs/karın hizası)
        0.0, 0.0, 0.0,        -- xyz rotasyon (tamamen dik, tabanı altta)
        true, true, false, true, 1, true)
    
    hasRoadConeInHand = true
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    SetModelAsNoLongerNeeded(coneModel)
    
    -- İki elle önde taşıma animasyonu (yürürken de oynar)
    TaskPlayAnim(ped, carryDict, "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
    
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    Notify(string.format("Bagajdan duba alındı (%d / %d)! Çukurun etrafına yerleştirin.", roadConesPlacedCount + 1, requiredRoadCones), "success")
    
    UpdateTaskBlip()
    UpdateTaskTarget()
    
    SendNUIMessage({
        action = "updateTaskState",
        currentTask = string.format("Yol Bakımı: Duba Yerleştir (%d/%d)", roadConesPlacedCount, requiredRoadCones),
        currentTaskType = "road",
        currentTaskStep = currentTask.currentPointIndex,
        currentTaskMaxSteps = currentTask.maxPoints
    })
    
    isDoingAction = false
end

function ReturnConeToTruck()
    if isDoingAction or not hasRoadConeInHand or not onDuty or not currentTask then return end
    
    local ped = PlayerPedId()
    isDoingAction = true
    FreezeEntityPosition(ped, true)
    
    local animDict = "pickup_object"
    RequestAnimDict(animDict)
    local t = 0
    while not HasAnimDictLoaded(animDict) and t < 50 do
        Citizen.Wait(10)
        t = t + 1
    end
    TaskPlayAnim(ped, animDict, "pickup_low", 8.0, -8.0, 1500, 0, 0, false, false, false)
    Citizen.Wait(1200)
    
    if roadConeInHandProp and DoesEntityExist(roadConeInHandProp) then
        DeleteObject(roadConeInHandProp)
        DeleteEntity(roadConeInHandProp)
        roadConeInHandProp = nil
    end
    hasRoadConeInHand = false
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    Notify("Dubayı iş aracının bagajına geri koydunuz.", "info")
    
    UpdateTaskBlip()
    UpdateTaskTarget()
    
    isDoingAction = false
end


local function GiveTrashBag()
    local ped = PlayerPedId()
    local model = GetHashKey("prop_cs_street_binbag_01")
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Citizen.Wait(10)
        timeout = timeout + 1
    end
    
    local animDict = "missfbi4prepp1"
    RequestAnimDict(animDict)
    timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 100 do
        Citizen.Wait(10)
        timeout = timeout + 1
    end
    
    local pCoords = GetEntityCoords(ped)
    trashBagProp = CreateObject(model, pCoords.x, pCoords.y, pCoords.z, true, true, true)
    SetEntityCollision(trashBagProp, false, false)
    
    local bone = GetPedBoneIndex(ped, 28422)
    AttachEntityToEntity(trashBagProp, ped, bone, 0.0, 0.04, -0.02, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    TaskPlayAnim(ped, animDict, "_idle_garbage_man", 8.0, -8.0, -1, 49, 0, false, false, false)
    hasTrashBag = true
    
    UpdateTaskBlip()
    UpdateTaskTarget()
    
    Notify("Çöp torbası alındı! Aracın arkasına/bagajına gidip çöpü atın.", "success")
    
    SendNUIMessage({
        action = "updateTaskState",
        currentTask = "Çöp Toplama (Yükleme)",
        currentTaskType = "trash",
        currentTaskStep = currentTask and currentTask.currentPointIndex or 1,
        currentTaskMaxSteps = currentTask and currentTask.maxPoints or 3
    })
end

function ThrowTrashInTruck()
    if isDoingAction or not hasTrashBag or not onDuty or not currentTask then return end
    
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        Notify("Çöpü atmak için araçtan inmelisiniz!", "warning")
        return
    end
    
    local targetVeh = activeVehicle
    if not targetVeh or not DoesEntityExist(targetVeh) then
        local pCoords = GetEntityCoords(ped)
        targetVeh = GetClosestVehicle(pCoords.x, pCoords.y, pCoords.z, 8.0, 0, 70)
    end
    
    if not targetVeh or not DoesEntityExist(targetVeh) then
        Notify("Çöpü atabileceğiniz bir iş aracı yakında bulunamadı!", "error")
        return
    end
    
    local trunkCoords = GetVehicleTrunkCoords(targetVeh)
    local pCoords = GetEntityCoords(ped)
    if trunkCoords and #(pCoords - trunkCoords) > 4.5 then
        Notify("Aracın arkasına / bagajına daha yakın olmalısınız!", "warning")
        return
    end
    
    isDoingAction = true
    FreezeEntityPosition(ped, true)
    TaskTurnPedToFaceEntity(ped, targetVeh, 500)
    Citizen.Wait(500)
    
    local animDict = "missfbi4prepp1"
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Citizen.Wait(10) end
    
    TaskPlayAnim(ped, animDict, "_bag_throw_garbage_man", 8.0, -8.0, 1500, 0, 0, false, false, false)
    Citizen.Wait(1100)
    
    RemoveTrashBag()
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    
    PlaySoundFrontend(-1, "Pickup_Carats", "HUD_AWARDS", 1)
    
    if not onDuty or not currentTask or IsEntityDead(ped) then
        isDoingAction = false
        return
    end
    
    local taskType = currentTask.type
    local taskConfig = Config.Tasks[taskType]
    
    currentTask.currentPointIndex = currentTask.currentPointIndex + 1
    
    if currentTask.currentPointIndex > currentTask.maxPoints then
        CompleteTask()
    else
        Notify(string.format("CityWorks: Çöp yüklendi! [%d / %d] Tamamlandı. Sıradaki çöp kutusuna gidin.", currentTask.currentPointIndex - 1, currentTask.maxPoints), "info")
        UpdateTaskBlip()
        UpdateTaskTarget()
        
        SendNUIMessage({
            action = "updateTaskState",
            currentTask = taskConfig.Name,
            currentTaskType = taskType,
            currentTaskStep = currentTask.currentPointIndex,
            currentTaskMaxSteps = currentTask.maxPoints
        })
    end
    
    isDoingAction = false
end

function UpdateTaskBlip()
    if taskBlip then RemoveBlip(taskBlip) end
    if not currentTask or not currentTask.points or not currentTask.points[currentTask.currentPointIndex] then return end
    
    local taskConfig = Config.Tasks[currentTask.type]
    local targetCoords = nil
    local blipName = taskConfig.Blip.Name
    
    if currentTask.type == "trash" and hasTrashBag then
        local targetVeh = activeVehicle
        if not targetVeh or not DoesEntityExist(targetVeh) then
            local pCoords = GetEntityCoords(PlayerPedId())
            targetVeh = GetClosestVehicle(pCoords.x, pCoords.y, pCoords.z, 20.0, 0, 70)
        end
        if targetVeh and DoesEntityExist(targetVeh) then
            targetCoords = GetVehicleTrunkCoords(targetVeh)
            blipName = "Çöp Aracı (Bagaj / Yükleme)"
        else
            targetCoords = currentTask.points[currentTask.currentPointIndex].coords
        end
    elseif currentTask.type == "road" then
        targetCoords = currentTask.points[currentTask.currentPointIndex].coords
        blipName = taskConfig.Blip.Name
    else
        targetCoords = currentTask.points[currentTask.currentPointIndex].coords
    end
    
    if not targetCoords then return end
    
    taskBlip = AddBlipForCoord(targetCoords.x, targetCoords.y, targetCoords.z)
    SetBlipSprite(taskBlip, taskConfig.Blip.Sprite)
    SetBlipColour(taskBlip, taskConfig.Blip.Color)
    SetBlipScale(taskBlip, taskConfig.Blip.Scale)
    SetBlipRoute(taskBlip, true)
    SetBlipRouteColour(taskBlip, taskConfig.Blip.Color)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(blipName)
    EndTextCommandSetBlipName(taskBlip)
end

function UpdateTaskTarget()
    local currentTargetName = "cityworks_task"
    local inter = GetActiveInteraction()
    
    pcall(function()
        if exports['qb-target'] then
            exports['qb-target']:RemoveZone(currentTargetName)
        end
        if exports.ox_target then
            exports.ox_target:removeZone(currentTargetName)
        end
    end)
    
    if not currentTask or not currentTask.points or not currentTask.points[currentTask.currentPointIndex] then return end
    
    local taskType = currentTask.type
    local actionLabel = "İşi Gerçekleştir"
    local actionIcon = "fas fa-wrench"
    
    if taskType == "trash" then
        actionLabel = "Çöpü Karıştır"
        actionIcon = "fas fa-trash-alt"
    elseif taskType == "road" then
        if roadHasCone then
            actionLabel = "Çukuru Onar (Asfalt & Kompresör)"
            actionIcon = "fas fa-road"
        elseif hasRoadConeInHand then
            actionLabel = string.format("Dubayı Yerleştir (%d / %d)", roadConesPlacedCount + 1, requiredRoadCones)
            actionIcon = "fas fa-shield-alt"
        else
            actionLabel = string.format("Bagajdan Duba Al (%d / %d Gerekiyor)", roadConesPlacedCount, requiredRoadCones)
            actionIcon = "fas fa-triangle-exclamation"
        end
    elseif taskType == "electric" then
        actionLabel = "Elektrik Arızasını Onar"
        actionIcon = "fas fa-bolt"
    end
    
    local currentCoords = currentTask.points[currentTask.currentPointIndex].coords
    
    if inter == "qb-target" then
        pcall(function()
            exports['qb-target']:AddBoxZone(currentTargetName, currentCoords, 3.2, 3.2, {
                name = currentTargetName,
                heading = 0,
                debugPoly = false,
                minZ = currentCoords.z - 2.0,
                maxZ = currentCoords.z + 2.0,
            }, {
                options = {
                    {
                        type = "client",
                        action = function()
                            DoTaskAction()
                        end,
                        icon = actionIcon,
                        label = actionLabel,
                    }
                },
                distance = 3.5
            })
        end)
    elseif inter == "ox_target" then
        pcall(function()
            exports.ox_target:addSphereZone({
                coords = currentCoords,
                radius = 2.5,
                name = currentTargetName,
                debug = false,
                options = {
                    {
                        name = currentTargetName,
                        icon = actionIcon,
                        label = actionLabel,
                        onSelect = function()
                            DoTaskAction()
                        end,
                        distance = 3.5
                    }
                }
            })
        end)
    end
end

function CancelTask()
    if taskBlip then
        RemoveBlip(taskBlip)
        taskBlip = nil
    end
    RemoveTrashBag()
    RemoveRoadCones()
    currentTask = nil
    isDoingAction = false
    UpdateTaskTarget()

    -- UI'a görevi temizle
    SendNUIMessage({
        action = "updateTaskState",
        currentTask = "Yok",
        currentTaskType = nil,
        currentTaskStep = 0,
        currentTaskMaxSteps = 0
    })
end

function CompleteTask()
    if not currentTask then return end
    local completedType = currentTask.type
    CancelTask()
    
    TriggerServerEvent("cityworks:server:taskCompleted", completedType)

    -- Görev bittiğinde oyuncuyu merkeze (NPC) yönlendir
    if Config.Center and Config.Center.NPC and Config.Center.NPC.Coords then
        local cx = Config.Center.NPC.Coords.x
        local cy = Config.Center.NPC.Coords.y
        local cz = Config.Center.NPC.Coords.z
        
        taskBlip = AddBlipForCoord(cx, cy, cz)
        SetBlipSprite(taskBlip, 566)
        SetBlipColour(taskBlip, 2) -- Yeşil
        SetBlipScale(taskBlip, 0.9)
        SetBlipRoute(taskBlip, true)
        SetBlipRouteColour(taskBlip, 2)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("CityWorks Merkezi (Görevi Teslim Et)")
        EndTextCommandSetBlipName(taskBlip)
    end
end

-- Sunucudan gelen ödülü işle ve NUI'a aktar
RegisterNetEvent("cityworks:client:showReward")
AddEventHandler("cityworks:client:showReward", function(money, xp, taskName)
    sessionEarnings = sessionEarnings + (money or 0)
    sessionCompletedTasks = sessionCompletedTasks + 1
    
    local timeStr = GetClockHours() .. ":" .. string.format("%02d", GetClockMinutes())
    
    table.insert(recentRewards, 1, {
        taskName = taskName or "CityWorks Görevi",
        money = money or 0,
        xp = xp or 0,
        time = timeStr
    })
    
    if #recentRewards > 6 then
        table.remove(recentRewards, #recentRewards)
    end
    
    Notify(string.format("İŞ TAMAMLANDI!\n+$%d  |  +%d XP\nMerkeze dönerek mesaiyi bitirebilir veya yeni iş alabilirsiniz.", money, xp), "success")
    
    SendNUIMessage({
        action = "updateStats",
        sessionEarnings = sessionEarnings,
        sessionCompletedTasks = sessionCompletedTasks,
        recentRewards = recentRewards
    })
end)

function DoTaskAction()
    if isDoingAction or not onDuty or not currentTask then return end
    
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        Notify("Bu işlemi yapmak için araçtan inmelisiniz!", "warning")
        return
    end
    
    if IsEntityDead(ped) then return end
    
    local taskType = currentTask.type
    local taskConfig = Config.Tasks[taskType]
    if not taskConfig then return end
    
    isDoingAction = true
    
    Citizen.CreateThread(function()
        FreezeEntityPosition(ped, true)
        
        -- Animasyon
        if taskType == "trash" then
            TaskStartScenarioInPlace(ped, "PROP_HUMAN_BUM_BIN", 0, true)
            Citizen.Wait(3500)
            ClearPedTasks(ped)
            FreezeEntityPosition(ped, false)
            
            -- Bekleme sonrası güvenlik kontrolü
            if not onDuty or not currentTask or IsEntityDead(ped) then
                isDoingAction = false
                return
            end
            
            GiveTrashBag()
            isDoingAction = false
            return
        elseif taskType == "road" then
            if not roadHasCone then
                if not hasRoadConeInHand then
                    Notify("Önce iş aracının bagajına giderek duba almalısınız!", "warning")
                    FreezeEntityPosition(ped, false)
                    isDoingAction = false
                    return
                end
                
                -- 1. AŞAMA: Eldeki Tekil Dubayı Yere Yerleştirme
                local animDict = "pickup_object"
                RequestAnimDict(animDict)
                local t = 0
                while not HasAnimDictLoaded(animDict) and t < 50 do
                    Citizen.Wait(10)
                    t = t + 1
                end
                TaskPlayAnim(ped, animDict, "pickup_low", 8.0, -8.0, 1800, 0, 0, false, false, false)
                Citizen.Wait(1300)
                
                -- Eldeki dubayı sil
                if roadConeInHandProp and DoesEntityExist(roadConeInHandProp) then
                    DeleteObject(roadConeInHandProp)
                    DeleteEntity(roadConeInHandProp)
                    roadConeInHandProp = nil
                end
                hasRoadConeInHand = false
                
                -- Çukurun etrafına kademeli olarak dubayı yere koy
                local coneModel = GetHashKey("prop_roadcone02a")
                RequestModel(coneModel)
                t = 0
                while not HasModelLoaded(coneModel) and t < 50 do
                    Citizen.Wait(10)
                    t = t + 1
                end
                
                local taskPt = currentTask.points[currentTask.currentPointIndex].coords
                -- Çukuru çevreleyen 3 koni noktası (önden, yandan, arkadan yolu kapatır)
                local coneLayout = {
                    vector3(taskPt.x + 1.8, taskPt.y - 0.8, taskPt.z),
                    vector3(taskPt.x - 1.8, taskPt.y + 0.8, taskPt.z),
                    vector3(taskPt.x + 0.2, taskPt.y + 2.0, taskPt.z)
                }
                
                roadConesPlacedCount = roadConesPlacedCount + 1
                local pos = coneLayout[roadConesPlacedCount] or vector3(taskPt.x + (roadConesPlacedCount * 0.8), taskPt.y, taskPt.z)
                
                local cone = CreateObject(coneModel, pos.x, pos.y, pos.z + 0.5, true, false, false)
                PlaceObjectOnGroundProperly(cone)
                SetEntityAsMissionEntity(cone, true, true)
                FreezeEntityPosition(cone, true)
                table.insert(placedRoadCones, cone)
                SetModelAsNoLongerNeeded(coneModel)
                
                ClearPedTasks(ped)
                FreezeEntityPosition(ped, false)
                PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
                
                if roadConesPlacedCount >= requiredRoadCones then
                    roadHasCone = true
                    Notify("Yol tamamen dubalarla kapatıldı ve güvenlik sağlandı! Şimdi çukuru onarın.", "success")
                else
                    Notify(string.format("Duba yerleştirildi (%d / %d)! Kalan dubaları almak için araca dönün.", roadConesPlacedCount, requiredRoadCones), "info")
                end
                
                UpdateTaskBlip()
                UpdateTaskTarget()
                
                SendNUIMessage({
                    action = "updateTaskState",
                    currentTask = roadHasCone and "Yol Bakımı (Çukur Onarımı)" or string.format("Yol Bakımı: Duba Yerleştir (%d/%d)", roadConesPlacedCount, requiredRoadCones),
                    currentTaskType = "road",
                    currentTaskStep = currentTask.currentPointIndex,
                    currentTaskMaxSteps = currentTask.maxPoints
                })
                
                isDoingAction = false
                return
            else
                -- 2. AŞAMA: Gerçekçi Asfalt / Çukur Onarımı (Pnömatik Kırıcı - Jackhammer Animasyonu)
                Notify("Asfalt onarımı ve çukur doldurma işlemi başlatıldı...", "info")
                TaskStartScenarioInPlace(ped, "WORLD_HUMAN_CONST_DRILL", 0, true)
                Citizen.Wait(7000)
                ClearPedTasksImmediately(ped)
                ClearPedTasks(ped)
                FreezeEntityPosition(ped, false)
                
                -- Drill / Pnömatik Kırıcı objesinin yola düşmesini engelle ve sil
                Citizen.Wait(100)
                local pCoords = GetEntityCoords(ped)
                local drillHashes = {
                    GetHashKey("prop_tool_jackham"),
                    GetHashKey("prop_tool_drill")
                }
                for _, dHash in ipairs(drillHashes) do
                    local obj = GetClosestObjectOfType(pCoords.x, pCoords.y, pCoords.z, 3.0, dHash, false, false, false)
                    if obj and DoesEntityExist(obj) then
                        SetEntityAsMissionEntity(obj, true, true)
                        DeleteObject(obj)
                        DeleteEntity(obj)
                    end
                end
                
                -- Dubaları kaldır ve yolu aç
                RemoveRoadCones()
                roadHasCone = false
                PlaySoundFrontend(-1, "Pickup_Carats", "HUD_AWARDS", 1)
            end
        elseif taskType == "electric" then
            TaskStartScenarioInPlace(ped, "WORLD_HUMAN_WELDING", 0, true)
            Citizen.Wait(6000)
        end
        
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
        
        -- BEKLEME SONRASI GÜVENLİK KONTROLÜ (Nil hatası önleme)
        if not onDuty or not currentTask or IsEntityDead(ped) then
            isDoingAction = false
            return
        end
        
        currentTask.currentPointIndex = currentTask.currentPointIndex + 1
        
        if currentTask.currentPointIndex > currentTask.maxPoints then
            CompleteTask()
        else
            Notify(string.format("CityWorks: %s [%d / %d] Tamamlandı.", taskConfig.Name, currentTask.currentPointIndex - 1, currentTask.maxPoints), "info")
            UpdateTaskBlip()
            UpdateTaskTarget()
            
            SendNUIMessage({
                action = "updateTaskState",
                currentTask = taskConfig.Name,
                currentTaskType = taskType,
                currentTaskStep = currentTask.currentPointIndex,
                currentTaskMaxSteps = currentTask.maxPoints
            })
        end
        
        isDoingAction = false
    end)
end

-- Marker ve DrawText Döngüsü
Citizen.CreateThread(function()
    while true do
        local sleep = 1500
        
        if onDuty and currentTask and not isDoingAction then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local inter = GetActiveInteraction()
            local taskType = currentTask.type
            local taskConfig = Config.Tasks[taskType]
            
            if currentTask.points and currentTask.points[currentTask.currentPointIndex] then
                -- Görev noktasında yerdeki zemin halkası (Çukurun tam yerini gösterir)
                local currentCoords = currentTask.points[currentTask.currentPointIndex].coords
                local dist = #(playerCoords - currentCoords)
                
                if dist < taskConfig.Marker.DrawDistance then
                    sleep = 0
                    DrawMarker(
                        taskConfig.Marker.Type, 
                        currentCoords.x, currentCoords.y, currentCoords.z + 0.5, 
                        0.0, 0.0, 0.0, 
                        180.0, 0.0, 0.0, 
                        taskConfig.Marker.Size.x, taskConfig.Marker.Size.y, taskConfig.Marker.Size.z, 
                        taskConfig.Marker.Color.r, taskConfig.Marker.Color.g, taskConfig.Marker.Color.b, taskConfig.Marker.Color.a, 
                        true, true, 2, true, nil, nil, false
                    )
                end
            end
        end
        
        Citizen.Wait(sleep)
    end
end)

-- Nesne taşırken araç kontrollerini kısıtlama thread'i
Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        if hasTrashBag or hasRoadConeInHand then
            sleep = 0
            local ped = PlayerPedId()
            -- Araca binmeyi engelle
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 75, true)
            
            if IsDisabledControlJustPressed(0, 23) then
                if hasRoadConeInHand then
                    Notify("Elinizdeki dubayı önce yere yerleştirmelisiniz!", "warning")
                else
                    Notify("Elinizdeki çöpü önce aracın arkasına/bagajına atmalısınız!", "warning")
                end
            end
            
            if hasTrashBag and not IsEntityPlayingAnim(ped, "missfbi4prepp1", "_idle_garbage_man", 3) and not isDoingAction then
                TaskPlayAnim(ped, "missfbi4prepp1", "_idle_garbage_man", 8.0, -8.0, -1, 49, 0, false, false, false)
            elseif hasRoadConeInHand and not IsEntityPlayingAnim(ped, "anim@heists@box_carry@", "idle", 3) and not isDoingAction then
                TaskPlayAnim(ped, "anim@heists@box_carry@", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
            end
        end
        Citizen.Wait(sleep)
    end
end)

exports("IsOnDuty", function()
    return onDuty
end)
