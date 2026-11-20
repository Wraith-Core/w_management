Config = {}

-- Library prompt (w.prompt.at) shown at each boss / gang location: the key name
-- (w_lib rawKeys vocabulary, upper-case) and how close the player must stand, in metres.
Config.PromptKey = 'J'
Config.PromptDistance = 1.5

-- blip.label is a dictionary key (locales/en.json, locales/ar.json); the map name and the
-- prompt text are translated with it in the player's language.
Config.BossLocations = {
    ['police'] = {
        blip = { showBlip = true, label = 'blip.boss', icon = 1321928545, size = 0.5 },
        location = { coords = vec3(-276.76, 804.58, 119.34) }
    }
}

Config.GangLocations = {
    ['example'] = {
        blip = { showBlip = true, label = 'blip.gang', icon = 1321928545, size = 0.5 },
        location = { coords = vec3(-63.73, -392.59, 72.22) }
    }
}

---------------------------------------------

SharedJobs = exports.w_lib:FwGetSharedJobs() or {}
SharedGangs = exports.w_lib:FwGetSharedGangs() or {}

function RefreshSharedRoles()
    if next(SharedJobs) == nil then
        SharedJobs = exports.w_lib:FwGetSharedJobs() or {}
    end
    if next(SharedGangs) == nil then
        SharedGangs = exports.w_lib:FwGetSharedGangs() or {}
    end
end
