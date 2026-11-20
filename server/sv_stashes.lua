-- All paths derive the stash from the server's current character, never a client-supplied name.
w.callback.register('w_management:server:OpenStash', function(src, kind)
    if kind ~= 'job' and kind ~= 'gang' then return false end
    local player = exports.w_lib:FwGetPlayerData(src)
    local role = player and player[kind]
    if not role or role.isboss ~= true then return false end
    local locations = kind == 'job' and Config.BossLocations or Config.GangLocations
    local location = locations[role.name]
    if not location or not location.location then return false end
    local coords = location.location.coords
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - coords) > (Config.PromptDistance + 2.0) then return false end
    local id = (kind == 'job' and 'boss_' or 'gang_') .. role.name
    local slots = kind == 'job' and 25 or 100
    local grade = type(role.grade) == 'table' and role.grade.level or role.grade
    local options = { groups = { [role.name] = tonumber(grade) or 0 }, coords = coords }
    if not exports.w_lib:InvRegisterStash(id, role.label or role.name, slots, 4000000, options) then return false end
    return exports.w_lib:InvOpenStash(src, id)
end)
