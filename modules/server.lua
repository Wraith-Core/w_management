
-- Get Closest Players --
w.callback.register('w_management:server:GetPlayers', function(source)
	local src = source
	local PlayerPed = GetPlayerPed(src)
	local pCoords = GetEntityCoords(PlayerPed)
	local players = exports.w_lib:FwGetOnlinePlayers() or {}
	local ClosestPlayers = {}

	for v, pd in pairs(players) do
		local targetped = GetPlayerPed(v)
		local tCoords = GetEntityCoords(targetped)
		local dist = #(pCoords - tCoords)
		-- a seat whose character left play (a logout to the selection) has no PlayerData to list
		if pd and PlayerPed ~= targetped and dist < 10 then
			ClosestPlayers[#ClosestPlayers+1] = {
				id = v,
				coords = GetEntityCoords(targetped),
				name = (pd.charinfo and pd.charinfo.firstname or '') .. " " .. (pd.charinfo and pd.charinfo.lastname or ''),
				citizenid = pd.citizenid,
				sources = GetPlayerPed(pd.source),
				sourceplayer = pd.source
			}
		end
	end
	return ClosestPlayers
end)

local ws = {}

function ws.GetPlayer(src)
    return exports.w_lib:FwGetPlayerData(src)
end

local function ready()
    return exports.w_lib:EconIsReady()
end
local function accountId(account, gang)
    return (gang and 'gang:' or 'society:') .. tostring(account)
end
local function ensure(account, gang)
    if not ready() then return nil end
    local id = accountId(account, gang)
    if not exports.w_lib:EconEnsureAccount(id, tostring(account), gang and 'gang' or 'society') then return nil end
    return id
end
local function projection(account, gang)
    local value = exports.w_lib:EconGetBalance(accountId(account, gang))
    if value == nil then return end
    local cache = gang and GangAccounts or BossAccounts
    if cache then cache[account] = value end
    -- Projection only; every consumer reads the central ledger.
    MySQL.update('UPDATE management_funds SET amount = ? WHERE job_name = ? AND type = ?',
        { value, account, gang and 'gang' or 'boss' })
end
local function adjust(account, amount, gang)
    amount = tonumber(amount)
    if not amount or amount ~= amount or math.abs(amount) == math.huge then return false end
    local id = ensure(account, gang)
    if not id then return false end
    local ok, reason = exports.w_lib:EconAdjustAccount(id, amount, 'management-adjustment')
    if ok then projection(account, gang) end
    return ok, reason
end
function ws.GetAccount(account)
    local id = ensure(account, false)
    return id and exports.w_lib:EconGetBalance(id) or 0
end
function ws.GetGangAccount(account)
    local id = ensure(account, true)
    return id and exports.w_lib:EconGetBalance(id) or 0
end
function ws.AddMoney(account, amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end
    return adjust(account, amount, false)
end
function ws.RemoveMoney(account, amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end
    return adjust(account, -amount, false)
end
function ws.AddGangMoney(account, amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end
    return adjust(account, amount, true)
end
function ws.RemoveGangMoney(account, amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end
    return adjust(account, -amount, true)
end
function ws.TransferPlayer(player, account, amount, gang, withdraw)
    amount = tonumber(amount)
    if not player or not amount or amount ~= amount or amount <= 0 or amount == math.huge then return false end
    local id = ensure(account, gang)
    if not id then return false end
    local cid = player.citizenid or (player.PlayerData and player.PlayerData.citizenid)
    if not cid then return false end
    local wallet = 'player:' .. cid .. ':cash'
    local ok, reason = exports.w_lib:EconTransfer(withdraw and id or wallet, withdraw and wallet or id, amount, 'management-transfer')
    if ok then projection(account, gang) end
    return ok, reason
end
-- ---- members by citizen id (w_lib's w.citizen) ---------------------------------
-- The boss and gang menus name a member by his citizen id (the member list carries it) and list
-- offline members too. w.citizen says whether he is in the game right now, so a promotion or a
-- dismissal reaches an offline member through his saved row instead of "not in town".

--- The job / gang table a character holds now: the live player's while he plays, else the one
--- his saved row holds. The live player snapshot comes back as the second value (nil offline).
---@param who table a w.citizen target
---@param kind string 'job' | 'gang'
---@return table? role
---@return table? player
function ws.RoleOf(who, kind)
    if who.online then
        local player = exports.w_lib:FwGetPlayerData(who.source)
        if player then return player[kind], player end
    end
    local row = who.row
    if type(row) ~= 'table' then
        local rows = exports.w_lib:FwCharacterRows('citizenid', who.citizenid)
        row = type(rows) == 'table' and rows[1] or nil
    end
    local raw = type(row) == 'table' and row[kind] or nil
    if type(raw) == 'string' then
        local ok, decoded = pcall(json.decode, raw)
        raw = ok and decoded or nil
    end
    return type(raw) == 'table' and raw or nil, nil
end

--- The table the framework writes for this role and grade (catalogue labels and grade
--- names), for a character who is offline. nil when the catalogue has no such grade.
---@param kind string 'job' | 'gang'
---@param name string
---@param grade integer
---@return table?
function ws.RoleFor(kind, name, grade)
    RefreshSharedRoles()
    local def = (kind == 'job' and SharedJobs or SharedGangs)[name]
    if not def then return nil end
    local grades = def.grades or {}
    local g = grades[grade] or grades[tostring(grade)]
    if not g then return nil end
    local role = {
        name = name, label = def.label, label_ar = def.label_ar or def.label, isboss = g.isboss or false,
        grade = { name = g.name, name_ar = g.name_ar or g.name, level = grade },
    }
    if kind == 'job' then
        role.type = def.type or 'none'
        role.payment = g.payment or 30
        role.onduty = def.defaultDuty ~= false
    end
    return role
end

--- This resource's notification key for a w.citizen failure ('invalid_id' | 'not_found').
---@param reason string?
---@return string
function ws.CitizenReason(reason)
    return reason == 'invalid_id' and 'notify.citizen_invalid' or 'notify.citizen_not_found'
end

-- how far (metres) the recruit may stand when the hire arrives: the picker lists players within
-- 10 m, and he may take a few steps while the boss reads the menu
local RECRUIT_REACH = 15.0

--- Is the recruit still near the boss? The picker only offered nearby players, but the event
--- carries any server id a client puts in it.
---@param a integer
---@param b integer
---@return boolean
function ws.IsNear(a, b)
    if GetPlayerRoutingBucket(a) ~= GetPlayerRoutingBucket(b) then return false end
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if not pa or pa == 0 or not pb or pb == 0 then return false end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= RECRUIT_REACH
end

exports('AddMoney', ws.AddMoney)
exports('AddGangMoney', ws.AddGangMoney)
exports('RemoveMoney', ws.RemoveMoney)
exports('RemoveGangMoney', ws.RemoveGangMoney)
exports('GetAccount', ws.GetAccount)
exports('GetGangAccount', ws.GetGangAccount)
return ws
