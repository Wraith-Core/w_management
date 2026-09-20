
-- Get Closest Players --
w.callback.register('w_management:server:GetPlayers', function(source)
	local src = source
	local PlayerPed = GetPlayerPed(src)
	local pCoords = GetEntityCoords(PlayerPed)
	local players = WCore.Functions.GetPlayers()
	local ClosestPlayers = {}

	for _, v in pairs(players) do
		local targetped = GetPlayerPed(v)
		local tCoords = GetEntityCoords(targetped)
		local dist = #(pCoords - tCoords)
		if PlayerPed ~= targetped and dist < 10 then
			local ped = WCore.Functions.GetPlayer(v)
			ClosestPlayers[#ClosestPlayers+1] = {
				id = v,
				coords = GetEntityCoords(targetped),
				name = ped.PlayerData.charinfo.firstname .. " " .. ped.PlayerData.charinfo.lastname,
				citizenid = ped.PlayerData.citizenid,
				sources = GetPlayerPed(ped.PlayerData.source),
				sourceplayer = ped.PlayerData.source
			}
		end
	end
	return ClosestPlayers
end)

local ws = {}

local function ready()
    return GetResourceState('w_centralbank') == 'started' and exports.w_centralbank:IsReady()
end
local function accountId(account, gang)
    return (gang and 'gang:' or 'society:') .. tostring(account)
end
local function ensure(account, gang)
    if not ready() then return nil end
    local id = accountId(account, gang)
    if not exports.w_centralbank:EnsureAccount(id, tostring(account), gang and 'gang' or 'society') then return nil end
    return id
end
local function projection(account, gang)
    local value = exports.w_centralbank:GetBalance(accountId(account, gang))
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
    local ok, reason = exports.w_centralbank:AdjustAccount(id, amount, 'management-adjustment')
    if ok then projection(account, gang) end
    return ok, reason
end
function ws.GetAccount(account)
    local id = ensure(account, false)
    return id and exports.w_centralbank:GetBalance(id) or 0
end
function ws.GetGangAccount(account)
    local id = ensure(account, true)
    return id and exports.w_centralbank:GetBalance(id) or 0
end
function ws.AddMoney(account, amount) amount=tonumber(amount);return amount and amount > 0 and adjust(account, amount, false) or false end
function ws.RemoveMoney(account, amount) amount=tonumber(amount);return amount and amount > 0 and adjust(account, -amount, false) or false end
function ws.AddGangMoney(account, amount) amount=tonumber(amount);return amount and amount > 0 and adjust(account, amount, true) or false end
function ws.RemoveGangMoney(account, amount) amount=tonumber(amount);return amount and amount > 0 and adjust(account, -amount, true) or false end
function ws.TransferPlayer(player, account, amount, gang, withdraw)
    amount = tonumber(amount)
    if not player or not amount or amount ~= amount or amount <= 0 or amount == math.huge then return false end
    local id = ensure(account, gang)
    if not id then return false end
    local wallet = 'player:' .. player.PlayerData.citizenid .. ':cash'
    local ok, reason = exports.w_centralbank:Transfer(withdraw and id or wallet, withdraw and wallet or id, amount, 'management-transfer')
    if ok then projection(account, gang) end
    return ok, reason
end
exports('AddMoney', ws.AddMoney)
exports('AddGangMoney', ws.AddGangMoney)
exports('RemoveMoney', ws.RemoveMoney)
exports('RemoveGangMoney', ws.RemoveGangMoney)
exports('GetAccount', ws.GetAccount)
exports('GetGangAccount', ws.GetGangAccount)
return ws
