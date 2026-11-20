local wc = require('modules.client')

RegisterNetEvent('w_management:client:Wardrobe', function()
    exports.w_creators:OpenWardrobe()
end)

local function PlayerLoad()
    RefreshSharedRoles()
    local pd = exports.w_lib:FwGetPlayerData() or {}
    PlayerGang = pd.gang or {}
    PlayerJob = pd.job or {}
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
exports.w_lib:FwOnCharacterLoaded(function() PlayerLoad() end)
exports.w_lib:FwOnCharacterUnloaded(function() PlayerUnload() end)
exports.w_lib:FwOnGangUpdate(function(InfoGang)
    PlayerGang = InfoGang or {}
    if PlayerGang.isboss ~= true then lib.hideContext() end
    wc.GangLocations()
end)
exports.w_lib:FwOnJobUpdate(function(JobInfo)
    PlayerJob = JobInfo or {}
    if PlayerJob.isboss ~= true then lib.hideContext() end
    wc.BossLocations()
end)

-- Language switch: reload the dictionary, then rebuild the blips and prompt labels.
-- Context menus are built on open, so they pick the new language up by themselves.
AddEventHandler('w_lib:setLocale', function(key)
    w.locale(key)
    wc.GangLocations()
    wc.BossLocations()
end)
