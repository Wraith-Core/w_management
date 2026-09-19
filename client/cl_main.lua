local wc = require('modules.client')

RegisterNetEvent('w_management:client:Wardrobe', function()
    exports.w_creators:OpenWardrobe()
end)

local function PlayerLoad()
    PlayerGang = WCore.Functions.GetPlayerData().gang or {}
    PlayerJob = WCore.Functions.GetPlayerData().job or {}
    wc.GangLocations()
    wc.BossLocations()
end

local function PlayerUnload()
    PlayerGang = {}
    PlayerJob = {}
    wc.CleanupGangLocations()
    wc.CleanupBossLocations()
end

-- Resource / Player Events --
AddEventHandler('onResourceStart', function(resource) if resource == GetCurrentResourceName() then PlayerLoad() end end)
AddEventHandler('onResourceStop', function(resource) if resource == GetCurrentResourceName() then PlayerUnload() end end)
RegisterNetEvent('WCore:Client:OnPlayerLoaded', function() PlayerLoad() end)
RegisterNetEvent('WCore:Client:OnGangUpdate', function(InfoGang) PlayerGang = InfoGang wc.GangLocations() end)
RegisterNetEvent('WCore:Client:OnJobUpdate', function(JobInfo) PlayerJob = JobInfo wc.BossLocations() end)

-- Language switch: reload the dictionary, then rebuild the blips and prompt labels.
-- Context menus are built on open, so they pick the new language up by themselves.
AddEventHandler('w_lib:setLocale', function(key)
    w.locale(key)
    wc.GangLocations()
    wc.BossLocations()
end)
