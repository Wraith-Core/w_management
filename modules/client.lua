local GangBlips = {}
local BossBlips = {}
local GangPrompts = {}     -- id → w.prompt.at record
local BossPrompts = {}
-- PlayerData is an empty table until character load, so job/gang can be nil here
local initialPd = exports.w_lib:FwGetPlayerData() or {}
PlayerJob = initialPd.job or {}
PlayerGang = initialPd.gang or {}

local wc = {}

-- Blip + library proximity prompt for one location; labels come from the dictionary.
-- The prompt only shows while the player is the boss of the matching job / gang.
local function createLocation(id, cfg, event, blips, prompts, canInteract)
    local coords = cfg.location.coords
    local name = locale(cfg.blip.label)
    if cfg.blip.showBlip then
        blips[id] = w.blip.create(coords, name, cfg.blip.icon, nil, nil, cfg.blip.size)
    end
    prompts[id] = w.prompt.at({
        coords = coords,
        distance = Config.PromptDistance,
        title = name,
        prompts = {
            {
                key = Config.PromptKey,
                label = locale('prompt.open', name),
                hold = false,
                onComplete = function() TriggerEvent(event) end,
            },
        },
        canInteract = canInteract,
    })
end

local function removeLocation(id, blips, prompts)
    if blips[id] and DoesBlipExist(blips[id]) then RemoveBlip(blips[id]) end
    blips[id] = nil
    if prompts[id] then prompts[id].remove() end
    prompts[id] = nil
end

local function isGangBoss(gang)
    return PlayerGang.name == gang and PlayerGang.isboss == true
end

local function isJobBoss(job)
    return PlayerJob.name == job and PlayerJob.isboss == true
end

function wc.GangLocations()
    -- Clear everything first: the blips and prompts are rebuilt for the current gang and
    -- language, and cleaning up inside the loop would remove entries created a moment earlier.
    wc.CleanupGangLocations()

    for q, r in pairs(Config.GangLocations) do
        if isGangBoss(q) then
            createLocation('gang_' .. q, r, 'w_gangmenu:client:OpenMenu', GangBlips, GangPrompts,
                function() return isGangBoss(q) end)
        end
    end
end

function wc.CleanupGangLocations()
    for q in pairs(Config.GangLocations) do
        removeLocation('gang_' .. q, GangBlips, GangPrompts)
    end
end

function wc.BossLocations()
    wc.CleanupBossLocations()

    for q, r in pairs(Config.BossLocations) do
        if isJobBoss(q) then
            createLocation('boss_' .. q, r, 'w_bossmenu:client:OpenMenu', BossBlips, BossPrompts,
                function() return isJobBoss(q) end)
        end
    end
end

function wc.CleanupBossLocations()
    for q in pairs(Config.BossLocations) do
        removeLocation('boss_' .. q, BossBlips, BossPrompts)
    end
end

return wc
