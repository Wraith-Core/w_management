
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

function ws.GetAccount(account)
	return BossAccounts[account] or 0
end

function ws.AddMoney(account, amount)
	if not BossAccounts[account] then
		BossAccounts[account] = 0
	end

	BossAccounts[account] = BossAccounts[account] + amount
	MySQL.insert('INSERT INTO management_funds (job_name, amount, type) VALUES (:job_name, :amount, :type) ON DUPLICATE KEY UPDATE amount = :amount',
		{
			['job_name'] = account,
			['amount'] = BossAccounts[account],
			['type'] = 'boss'
		})
end

function ws.RemoveMoney(account, amount)
	local isRemoved = false
	if amount > 0 then
		if not BossAccounts[account] then
			BossAccounts[account] = 0
		end

		if BossAccounts[account] >= amount then
			BossAccounts[account] = BossAccounts[account] - amount
			isRemoved = true
		end

		MySQL.update('UPDATE management_funds SET amount = ? WHERE job_name = ? and type = "boss"', { BossAccounts[account], account })
	end
	return isRemoved
end

function ws.GetGangAccount(account)
	return GangAccounts[account] or 0
end

function ws.AddGangMoney(account, amount)
	if not GangAccounts[account] then
		GangAccounts[account] = 0
	end

	GangAccounts[account] = GangAccounts[account] + amount
	MySQL.insert('INSERT INTO management_funds (job_name, amount, type) VALUES (:job_name, :amount, :type) ON DUPLICATE KEY UPDATE amount = :amount',
		{
			['job_name'] = account,
			['amount'] = GangAccounts[account],
			['type'] = 'gang'
		})
end

function ws.RemoveGangMoney(account, amount)
	local isRemoved = false
	if amount > 0 then
		if not GangAccounts[account] then
			GangAccounts[account] = 0
		end

		if GangAccounts[account] >= amount then
			GangAccounts[account] = GangAccounts[account] - amount
			isRemoved = true
		end

		MySQL.update('UPDATE management_funds SET amount = ? WHERE job_name = ? and type = "gang"', { GangAccounts[account], account })
	end
	return isRemoved
end

-- The manifest's server_exports: the functions live in this module, so they are exported here.
exports('AddMoney', ws.AddMoney)
exports('AddGangMoney', ws.AddGangMoney)
exports('RemoveMoney', ws.RemoveMoney)
exports('RemoveGangMoney', ws.RemoveGangMoney)
exports('GetAccount', ws.GetAccount)
exports('GetGangAccount', ws.GetGangAccount)

return ws
