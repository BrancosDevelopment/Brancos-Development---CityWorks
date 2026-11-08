-- ==========================================
-- RESOURCE İSİM KİLİDİ
-- ==========================================
if GetCurrentResourceName() ~= "brancosdev-CityWorks" then
    error(string.format(
        "\n^1[brancosdev-CityWorks] HATA: Bu script yalnizca 'brancosdev-CityWorks' klasor adi ile calisir.^0\n" ..
        "^1Mevcut isim: '%s' — Script durduruldu.^0",
        GetCurrentResourceName()
    ), 0)
    return
end

local ActiveFramework = "none"
local FrameworkReady = false
local QBCore = nil

local function InitFramework()
    local chosen = Config.Framework or "auto"

    if chosen == "auto" then
        -- 1. Qbox (qbx_core)
        if GetResourceState("qbx_core") == "started" then
            ActiveFramework = "qbox"
            FrameworkReady = true
            print("^2[CityWorks] Aktif Altyapi Otomatik Algilandi: Qbox (qbx_core)^0")
            return
        end

        -- 2. QBCore (qb-core)
        if GetResourceState("qb-core") == "started" then
            pcall(function() QBCore = exports['qb-core']:GetCoreObject() end)
            if QBCore then
                ActiveFramework = "qbcore"
                FrameworkReady = true
                print("^2[CityWorks] Aktif Altyapi Otomatik Algilandi: QBCore (qb-core)^0")
                return
            end
        end

        -- 3. Standalone Fallback
        ActiveFramework = "standalone"
        FrameworkReady = true
        print("^3[CityWorks] Altyapi bulunamadi. Standalone (FiveM License Modu) aktif.^0")
        return
    elseif chosen == "qbox" then
        if GetResourceState("qbx_core") == "started" then
            ActiveFramework = "qbox"
            FrameworkReady = true
            print("^2[CityWorks] Aktif Altyapi: Qbox (qbx_core)^0")
            return
        else
            FrameworkReady = false
            ActiveFramework = "none"
            print("^1====================================================================^0")
            print("^1[CityWorks HATA] Config.Framework = 'qbox' secildi fakat sunucuda 'qbx_core' calismiyor!^0")
            if GetResourceState("qb-core") == "started" then
                print("^3[CityWorks IPUCU] Sunucunuzda 'qb-core' tespit edildi! Config.Framework = 'qbcore' veya 'auto' yapin.^0")
            end
            print("^1Hatali altyapi nedeniyle CityWorks scripti guvenlik amaciyla DURDURULDU.^0")
            print("^1====================================================================^0")
            return
        end
    elseif chosen == "qbcore" then
        if GetResourceState("qb-core") == "started" then
            pcall(function() QBCore = exports['qb-core']:GetCoreObject() end)
            if QBCore then
                ActiveFramework = "qbcore"
                FrameworkReady = true
                print("^2[CityWorks] Aktif Altyapi: QBCore (qb-core)^0")
                return
            end
        end
        FrameworkReady = false
        ActiveFramework = "none"
        print("^1====================================================================^0")
        print("^1[CityWorks HATA] Config.Framework = 'qbcore' secildi fakat sunucuda 'qb-core' calismiyor!^0")
        if GetResourceState("qbx_core") == "started" then
            print("^3[CityWorks IPUCU] Sunucunuzda 'qbx_core' tespit edildi! Config.Framework = 'qbox' veya 'auto' yapin.^0")
        end
        print("^1Hatali altyapi nedeniyle CityWorks scripti guvenlik amaciyla DURDURULDU.^0")
        print("^1====================================================================^0")
        return
    elseif chosen == "standalone" then
        ActiveFramework = "standalone"
        FrameworkReady = true
        print("^3[CityWorks] Aktif Altyapi: Standalone (FiveM License Modu)^0")
        return
    else
        print(string.format("^1[CityWorks HATA] Gecersiz altyapi degeri: '%s'. 'auto', 'qbcore', 'qbox' veya 'standalone' kullanin.^0", tostring(chosen)))
    end
end

CreateThread(function()
    InitFramework()
end)

local onDutyPlayers = {}
local playerXP = {}
local playerLevel = {}
local playerLoaded = {}

-- XP'den mevcut seviyeyi hesapla
local function GetLevelFromXP(xp)
    local level = 1
    for i = 5, 1, -1 do
        if Config.Levels[i] and xp >= Config.Levels[i].XP then
            level = i
            break
        end
    end
    return level
end

-- Oyuncunun kimlik anahtarını bul (Qbox/QBCore: CitizenID, Standalone: License)
local function GetIdentifier(src)
    if not src or src == 0 then return nil end

    -- Qbox
    if ActiveFramework == "qbox" and exports.qbx_core then
        local player = exports.qbx_core:GetPlayer(src)
        if player then
            if player.PlayerData and player.PlayerData.citizenid then
                return player.PlayerData.citizenid
            elseif player.citizenid then
                return player.citizenid
            end
        end
    end

    -- QBCore
    if ActiveFramework == "qbcore" then
        if not QBCore and exports['qb-core'] then
            pcall(function() QBCore = exports['qb-core']:GetCoreObject() end)
        end
        if QBCore then
            local player = QBCore.Functions.GetPlayer(src)
            if player then
                if player.PlayerData and player.PlayerData.citizenid then
                    return player.PlayerData.citizenid
                elseif player.citizenid then
                    return player.citizenid
                end
            end
        end
    end

    -- Standalone / Fallback olarak FiveM License
    local rawIdentifiers = GetPlayerIdentifiers(src)
    if rawIdentifiers then
        for _, v in ipairs(rawIdentifiers) do
            if string.match(v, "^license:") then
                return v
            end
        end
        for _, v in ipairs(rawIdentifiers) do
            if string.match(v, "^license2:") then
                return v
            end
        end
    end

    if GetPlayerIdentifierByType then
        local licenseByType = GetPlayerIdentifierByType(src, 'license')
        if licenseByType then return licenseByType end
    end

    return nil
end

-- Oyuncuya para ödülünü ver (Qbox, QBCore veya Standalone)
local function GivePlayerMoney(src, amount)
    if not amount or amount <= 0 then return false end
    local account = Config.MoneyAccount or "cash"

    -- Önce ox_inventory kontrol et (QBCore veya Qbox olsa bile ox_inventory kurulu olabilir)
    if account == "cash" and GetResourceState("ox_inventory") == "started" and exports.ox_inventory then
        local success = pcall(function()
            exports.ox_inventory:AddItem(src, 'money', amount)
        end)
        if success then return true end
    end

    -- 1. Qbox
    if ActiveFramework == "qbox" or (exports.qbx_core and exports.qbx_core:GetPlayer(src)) then
        local player = exports.qbx_core and exports.qbx_core:GetPlayer(src)
        if player then
            if exports.qbx_core.AddMoney then
                local ok = pcall(function() exports.qbx_core:AddMoney(src, account, amount, "cityworks-task-reward") end)
                if ok then return true end
            end
            if player.Functions and player.Functions.AddMoney then
                player.Functions.AddMoney(account, amount, "cityworks-task-reward")
                return true
            end
        end
    end

    -- 2. QBCore
    if ActiveFramework == "qbcore" or (exports['qb-core'] and exports['qb-core']:GetCoreObject()) then
        if not QBCore and exports['qb-core'] then
            pcall(function() QBCore = exports['qb-core']:GetCoreObject() end)
        end
        if QBCore then
            local player = QBCore.Functions.GetPlayer(src)
            if player and player.Functions and player.Functions.AddMoney then
                player.Functions.AddMoney(account, amount, "cityworks-task-reward")
                return true
            end
        end
    end

    -- 3. Standalone / ox_inventory
    if GetResourceState("ox_inventory") == "started" and exports.ox_inventory then
        local success = pcall(function()
            exports.ox_inventory:AddItem(src, 'money', amount)
        end)
        if success then return true end
    end

    print(string.format("^1[CityWorks HATA] Oyuncu %s icin para verilemedi ($%d)! Framework veya envanter uyusmazligi.^0", src, amount))
    return false
end

-- Oyuncu verilerini veritabanına kaydet
local function SavePlayer(src)
    if not playerLoaded[src] then return end
    local identifier = GetIdentifier(src)
    if not identifier then return end
    
    local xp = playerXP[src] or 0
    local level = playerLevel[src] or 1
    
    exports.oxmysql:execute('UPDATE cityworks_users SET xp = @xp, level = @level WHERE identifier = @identifier', {
        ['@identifier'] = identifier,
        ['@xp'] = xp,
        ['@level'] = level
    })
end

-- Oyuncu verilerini veritabanından çek (veya yeni kayıt oluştur)
local function LoadPlayer(src, cb)
    if playerLoaded[src] then
        if cb then cb() end
        return
    end
    
    local identifier = GetIdentifier(src)
    if not identifier then 
        if cb then cb() end
        return 
    end
    
    exports.oxmysql:execute('SELECT xp, level FROM cityworks_users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(result)
        if result and result[1] then
            -- Kayıt bulundu, değerleri yükle
            playerXP[src] = tonumber(result[1].xp) or 0
            playerLevel[src] = tonumber(result[1].level) or 1
            playerLoaded[src] = true
            if cb then cb() end
        else
            -- Kayıt yoksa, yeni oluştur
            exports.oxmysql:execute('INSERT INTO cityworks_users (identifier, xp, level) VALUES (@identifier, @xp, @level)', {
                ['@identifier'] = identifier,
                ['@xp'] = 0,
                ['@level'] = 1
            }, function()
                playerXP[src] = 0
                playerLevel[src] = 1
                playerLoaded[src] = true
                if cb then cb() end
            end)
        end
    end)
end

local function GetCharacterName(src)
    if not src or src == 0 then return "Saha Personeli" end
    -- Qbox
    if ActiveFramework == "qbox" and exports.qbx_core then
        local player = exports.qbx_core:GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.charinfo then
            local fn = player.PlayerData.charinfo.firstname or ""
            local ln = player.PlayerData.charinfo.lastname or ""
            if fn ~= "" or ln ~= "" then
                return string.format("%s %s", fn, ln):gsub("^%s*(.-)%s*$", "%1")
            end
        end
    end
    -- QBCore
    if ActiveFramework == "qbcore" or (exports['qb-core'] and exports['qb-core']:GetCoreObject()) then
        if not QBCore and exports['qb-core'] then
            pcall(function() QBCore = exports['qb-core']:GetCoreObject() end)
        end
        if QBCore then
            local player = QBCore.Functions.GetPlayer(src)
            if player and player.PlayerData and player.PlayerData.charinfo then
                local fn = player.PlayerData.charinfo.firstname or ""
                local ln = player.PlayerData.charinfo.lastname or ""
                if fn ~= "" or ln ~= "" then
                    return string.format("%s %s", fn, ln):gsub("^%s*(.-)%s*$", "%1")
                end
            end
        end
    end
    return GetPlayerName(src) or "Saha Personeli"
end

-- NUI Menüsü istendiğinde (NPC etkileşiminde) önce oyuncu verisini yükle/al
RegisterNetEvent("cityworks:server:requestMenu")
AddEventHandler("cityworks:server:requestMenu", function()
    local src = source
    if not FrameworkReady then
        TriggerClientEvent("cityworks:client:frameworkError", src, "CityWorks altyapı uyumsuzluğu nedeniyle devre dışı bırakıldı! Sunucu konsolunu kontrol edin.")
        return
    end

    LoadPlayer(src, function()
        if not playerXP[src] then playerXP[src] = 0 end
        if not playerLevel[src] then playerLevel[src] = GetLevelFromXP(playerXP[src]) end
        
        local charName = GetCharacterName(src)
        TriggerClientEvent("cityworks:client:openMenu", src, playerLevel[src], playerXP[src], charName)
    end)
end)

-- Mesai Başlat / Bitir
RegisterNetEvent("cityworks:server:toggleDuty")
AddEventHandler("cityworks:server:toggleDuty", function(dutyStatus)
    local src = source
    if not FrameworkReady then return end

    if dutyStatus then
        LoadPlayer(src, function()
            onDutyPlayers[src] = {
                activeTask = nil
            }
            TriggerClientEvent("cityworks:client:syncLevel", src, playerLevel[src])
            print(string.format("[CityWorks] Oyuncu %s mesaiye basladi. (Level: %d, XP: %d)", src, playerLevel[src], playerXP[src]))
        end)
    else
        onDutyPlayers[src] = nil
        print(string.format("[CityWorks] Oyuncu %s mesaiyi bitirdi.", src))
    end
end)

-- Hile Koruması: Görevin başladığını ve başlangıç zamanını kaydet
RegisterNetEvent("cityworks:server:taskStarted")
AddEventHandler("cityworks:server:taskStarted", function(taskType)
    local src = source
    if not FrameworkReady then return end

    if onDutyPlayers[src] then
        onDutyPlayers[src].activeTask = taskType
        onDutyPlayers[src].startTime = os.time()
    end
end)

-- Görev Tamamlama, Para Ödülü, XP ve Seviye hesaplama
RegisterNetEvent("cityworks:server:taskCompleted")
AddEventHandler("cityworks:server:taskCompleted", function(taskType)
    local src = source
    if not FrameworkReady then return end
    
    if onDutyPlayers[src] and onDutyPlayers[src].activeTask == taskType then
        local now = os.time()
        local startTime = onDutyPlayers[src].startTime or 0
        local elapsed = now - startTime
        
        -- Hile koruması: Görevin en azından mantıklı bir sürede (en az 8 saniye) tamamlanması gerekir
        if elapsed < 8 then
            print(string.format("^1[CityWorks - GÜVENLİK] Oyuncu %s görevi (%s) imkansız bir sürede (%d saniye) tamamlamaya çalıştı! İşlem reddedildi.^0", src, tostring(taskType), elapsed))
            return
        end

        local taskConfig = Config.Tasks[taskType]
        if not taskConfig or not taskConfig.Reward then return end
        
        local rewardMoney = math.random(taskConfig.Reward.MoneyMin, taskConfig.Reward.MoneyMax)
        local rewardXP = math.random(taskConfig.Reward.XPMin, taskConfig.Reward.XPMax)
        
        local oldLevel = playerLevel[src] or 1
        playerXP[src] = (playerXP[src] or 0) + rewardXP
        
        local newLevel = GetLevelFromXP(playerXP[src])
        playerLevel[src] = newLevel
        
        -- Ödül spam'ını engelle
        onDutyPlayers[src].activeTask = nil
        onDutyPlayers[src].startTime = nil
        
        -- ★ Para ödülünü oyuncu bakiyesine ekle (QBCore / Qbox / Standalone)
        GivePlayerMoney(src, rewardMoney)
        
        -- ★ XP ve Seviyeyi anında veritabanına kaydet
        SavePlayer(src)
        
        -- İstemciye ödül bildirimini gönder
        TriggerClientEvent("cityworks:client:showReward", src, rewardMoney, rewardXP, taskConfig.Name)
        
        -- Eğer seviye atladıysa
        if newLevel > oldLevel then
            local newTitle = Config.Levels[newLevel] and Config.Levels[newLevel].Title or "Yetkili"
            TriggerClientEvent("cityworks:client:levelUp", src, newLevel, newTitle)
            print(string.format("[CityWorks] Oyuncu %s LEVEL ATLADI! Yeni Level: %d - %s", src, newLevel, newTitle))
        end
        
        print(string.format("[CityWorks] Oyuncu %s gorev (%s) tamamladi. Kazanc: $%d | +%d XP (Toplam XP: %d)", src, taskType, rewardMoney, rewardXP, playerXP[src]))
    else
        print(string.format("[CityWorks] UYARI (GUVENLIK): Oyuncu %s yetkisiz veya tekrarlanan gorev (%s) tamamlamaya calisti!", src, tostring(taskType)))
    end
end)

-- Oyuncu oturumunu temizleme fonksiyonu (Çoklu karakter ve çıkış desteği)
local function CleanupPlayerSession(src)
    if not src then return end
    SavePlayer(src)
    
    if onDutyPlayers[src] then onDutyPlayers[src] = nil end
    if playerXP[src] then playerXP[src] = nil end
    if playerLevel[src] then playerLevel[src] = nil end
    if playerLoaded[src] then playerLoaded[src] = nil end
end

-- Oyuncu oyundan çıkarken verilerini kaydet ve belleği temizle
AddEventHandler("playerDropped", function(reason)
    CleanupPlayerSession(source)
end)

-- QBCore Karakter Değiştirme / Çıkış
RegisterNetEvent("QBCore:Server:OnPlayerUnload", function()
    CleanupPlayerSession(source)
end)

-- Qbox Karakter Değiştirme / Çıkış (farklı qbx sürümleriyle tam uyumlu)
RegisterNetEvent("qbx_core:server:playerUnloaded", function()
    CleanupPlayerSession(source)
end)
RegisterNetEvent("qbx_core:server:onPlayerLogout", function()
    CleanupPlayerSession(source)
end)
RegisterNetEvent("qbx_core:server:playerLoggedOut", function()
    CleanupPlayerSession(source)
end)

exports("GetActiveFramework", function()
    return ActiveFramework
end)
