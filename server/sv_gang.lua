local ws = require('modules.server')
GangAccounts = {}

MySQL.ready(function ()
	local gangmenu = MySQL.query.await('SELECT job_name,amount FROM management_funds WHERE type = "gang"', {})
	if not gangmenu then return end

	for _,v in ipairs(gangmenu) do
		GangAccounts[v.job_name] = v.amount
	end
end)

-- Notifications: title is a dictionary key translated on the client (w.notify → __w_notify),
-- description carries the dynamic part (amount, name, label); a description that is itself a
-- dictionary key is translated by the client as well.

RegisterNetEvent("w_gangmenu:server:withdrawMoney", function(amount)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)

	if not Player.PlayerData.gang.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Withdraw Money Exploiting') return end

	-- The amount comes from the client: nil / non-numeric / negative values must not reach the account code.
	amount = tonumber(amount)
	if not amount or amount <= 0 then return end

	local gang = Player.PlayerData.gang.name
	if ws.RemoveGangMoney(gang, amount) then
		Player.Functions.AddMoney("cash", amount, 'Gang menu withdraw')
		TriggerEvent('w_log:server:CreateLog', 'gangmenu', 'Withdraw Money', 'yellow', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' successfully withdrew $' .. amount .. ' (' .. gang .. ')', false)
		w.notify(src, { title = 'notify.withdrawn', description = '$' .. math.groupdigits(amount), type = 'success' })
	else
		w.notify(src, { title = 'notify.account_insufficient', type = 'error' })
	end

	TriggerClientEvent('w_gangmenu:client:OpenMenu', src)
end)

RegisterNetEvent("w_gangmenu:server:depositMoney", function(amount)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)

	if not Player.PlayerData.gang.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Deposit Money Exploiting') return end

	amount = tonumber(amount)
	if not amount or amount <= 0 then return end

	if Player.Functions.RemoveMoney("cash", amount) then
		local gang = Player.PlayerData.gang.name
		ws.AddGangMoney(gang, amount)
		TriggerEvent('w_log:server:CreateLog', 'gangmenu', 'Deposit Money', 'yellow', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' successfully deposited $' .. amount .. ' (' .. gang .. ')', false)
		w.notify(src, { title = 'notify.deposited', description = '$' .. math.groupdigits(amount), type = 'success' })
	else
		w.notify(src, { title = 'notify.cash_insufficient', type = 'error' })
	end

	TriggerClientEvent('w_gangmenu:client:OpenMenu', src)
end)

-- Grade Change
RegisterNetEvent('w_gangmenu:server:GradeUpdate', function(data)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)
	local Employee = WCore.Functions.GetPlayerByCitizenId(data.cid)

	if not Player.PlayerData.gang.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Grade Update Exploiting') return end
	if data.grade > Player.PlayerData.gang.grade.level then w.notify(src, { title = 'notify.promote_rank_denied', type = 'error' }) return end

	if Employee then
		if Employee.Functions.SetGang(Player.PlayerData.gang.name, data.grade) then
			-- grade name in each recipient's own language (SetGang wrote name / name_ar)
			local newGang = Employee.PlayerData.gang
			w.notify(src, { title = 'notify.promoted', description = WCore.Shared.GradeName(newGang, src), type = 'success' })
			w.notify(Employee.PlayerData.source, { title = 'notify.you_were_promoted', description = WCore.Shared.GradeName(newGang, Employee.PlayerData.source), type = 'success' })
		else
			w.notify(src, { title = 'notify.grade_missing', type = 'error' })
		end
	else
		w.notify(src, { title = 'notify.citizen_offline', type = 'error' })
	end
	TriggerClientEvent('w_gangmenu:client:OpenMenu', src)
end)

-- Fire Member
RegisterNetEvent('w_gangmenu:server:FireMember', function(target)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)
	local Employee = WCore.Functions.GetPlayerByCitizenId(target)

	if not Player.PlayerData.gang.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Fire Employee Exploiting') return end

	if Employee then
		if target ~= Player.PlayerData.citizenid then
			if Employee.PlayerData.gang.grade.level > Player.PlayerData.gang.grade.level then w.notify(src, { title = 'notify.fire_denied', type = 'error' }) return end
			if Employee.Functions.SetGang("none", '0') then
				TriggerEvent("w_log:server:CreateLog", "gangmenu", "Gang Fire", "orange", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname .. ' successfully fired ' .. Employee.PlayerData.charinfo.firstname .. " " .. Employee.PlayerData.charinfo.lastname .. " (" .. Player.PlayerData.gang.name .. ")", false)
				w.notify(src, { title = 'notify.gang_member_fired', description = Employee.PlayerData.charinfo.firstname .. ' ' .. Employee.PlayerData.charinfo.lastname, type = 'success' })
				w.notify(Employee.PlayerData.source, { title = 'notify.you_were_expelled', type = 'error' })
			else
				w.notify(src, { title = 'notify.error', type = 'error' })
			end
		else
			w.notify(src, { title = 'notify.gang_fire_self', type = 'error' })
		end
	else
		local player = exports.w_lib:FwCharacterRows('citizenid',target)
		if player[1] ~= nil then
			Employee = player[1]
			Employee.gang = json.decode(Employee.gang)
			-- Compare gang grades (the online branch above does); the job grade was a copy-paste slip.
			if Employee.gang.grade.level > Player.PlayerData.gang.grade.level then w.notify(src, { title = 'notify.fire_denied', type = 'error' }) return end
			-- Same shape and labels w_core's SetGang writes, taken from the shared gang table
			-- (the label and grade name end up in the player's HUD).
			local def = SharedGangs['none'] or {label='None',grades={}}
			local grade0 = def.grades[0] or def.grades['0'] or {}
			local gang = {
				name = 'none',
				label = def.label,
				label_ar = def.label_ar or def.label,
				isboss = false,
				grade = { name = grade0.name or 'No Grades', name_ar = grade0.name_ar or grade0.name or "بدون رتبة", level = 0 },
			}
			if not exports.w_lib:FwSetOfflineRole(target,'gang',gang,Player.PlayerData.gang.name) then return end
			-- Employee is a database row here (no PlayerData): read the name from the stored charinfo.
			local charinfo = json.decode(Employee.charinfo) or {}
			w.notify(src, { title = 'notify.gang_member_fired', description = (charinfo.firstname or '?') .. ' ' .. (charinfo.lastname or '?'), type = 'success' })
			TriggerEvent("w_log:server:CreateLog", "gangmenu", "Gang Fire", "orange", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname .. ' successfully fired ' .. (charinfo.firstname or '?') .. " " .. (charinfo.lastname or '?') .. " (" .. Player.PlayerData.gang.name .. ")", false)
		else
			w.notify(src, { title = 'notify.citizen_offline', type = 'error' })
		end
	end
	TriggerClientEvent('w_gangmenu:client:OpenMenu', src)
end)

-- Recruit Player
RegisterNetEvent('w_gangmenu:server:HireMember', function(recruit)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)
	local Target = WCore.Functions.GetPlayer(recruit)

	if not Player.PlayerData.gang.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Hire Employee Exploiting') return end

	if Target and Target.Functions.SetGang(Player.PlayerData.gang.name, 0) then
		local targetName = Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname
		-- gang name in each recipient's own language
		w.notify(src, { title = 'notify.gang_recruited', description = targetName .. ' - ' .. WCore.Shared.JobLabel(Player.PlayerData.gang, src), type = 'success' })
		w.notify(Target.PlayerData.source, { title = 'notify.you_were_recruited', description = WCore.Shared.JobLabel(Player.PlayerData.gang, Target.PlayerData.source), type = 'success' })
		TriggerEvent('w_log:server:CreateLog', 'gangmenu', 'Recruit', 'yellow', (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname).. ' successfully recruited ' .. targetName .. ' (' .. Player.PlayerData.gang.name .. ')', false)
	end
	TriggerClientEvent('w_gangmenu:client:OpenMenu', src)
end)

-- Get Account Info --
-- The gang is taken from the requesting player on the server; the client's argument is not trusted.
w.callback.register('w_gangmenu:server:GetAccount', function(source)
	local Player = WCore.Functions.GetPlayer(source)
	if not Player then return 0 end
	return ws.GetGangAccount(Player.PlayerData.gang.name)
end)

-- Get Employees
w.callback.register('w_gangmenu:server:GetEmployees', function(source)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)

	if not Player then return {} end
	if not Player.PlayerData.gang.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Get Employees Exploiting') return end

	local gangname = Player.PlayerData.gang.name
	local employees = {}
	-- Bound parameter instead of string concatenation; the LIKE only narrows the rows, the
	-- decoded gang name decides.
	local players = exports.w_lib:FwCharacterRows('gang',gangname)
	for _, value in ipairs(players or {}) do
		local isOnline = WCore.Functions.GetPlayerByCitizenId(value.citizenid)

		if isOnline then
			if isOnline.PlayerData.gang.name == gangname then
				employees[#employees+1] = {
					empSource = isOnline.PlayerData.citizenid,
					grade = isOnline.PlayerData.gang.grade,
					isboss = isOnline.PlayerData.gang.isboss,
					name = '🟢 ' .. isOnline.PlayerData.charinfo.firstname .. ' ' .. isOnline.PlayerData.charinfo.lastname
				}
			end
		else
			local gang = json.decode(value.gang) or {}
			if gang.name == gangname then
				local charinfo = json.decode(value.charinfo) or {}
				-- rows saved before name_ar existed: take the Arabic grade name from the catalogue
				local grade = gang.grade or {}
				if not grade.name_ar and SharedGangs[gangname] then
					local grades = SharedGangs[gangname].grades or {}
					local level = tonumber(grade.level) or 0
					local def = grades[level] or grades[tostring(level)]
					grade.name_ar = def and def.name_ar or nil
				end
				employees[#employees+1] = {
					empSource = value.citizenid,
					grade = grade,
					isboss = gang.isboss,
					name = '❌ ' .. (charinfo.firstname or '?') .. ' ' .. (charinfo.lastname or '?')
				}
			end
		end
	end
	return employees
end)
