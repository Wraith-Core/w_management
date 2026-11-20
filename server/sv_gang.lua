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
	local Player = ws.GetPlayer(src)
	if not Player or not Player.gang then return end

	if not Player.gang.isboss then w.notify(src, { title = 'notify.not_boss', type = 'error' }) return end

	-- The amount comes from the client: nil / non-numeric / negative values must not reach the account code.
	amount = tonumber(amount)
	if not amount or amount <= 0 then return end

	local gang = Player.gang.name
	if ws.TransferPlayer(Player, gang, amount, true, true) then
		TriggerEvent('w_log:server:CreateLog', 'gangmenu', 'Withdraw Money', 'yellow', (Player.charinfo.firstname or '') .. ' ' .. (Player.charinfo.lastname or '') .. ' successfully withdrew $' .. amount .. ' (' .. gang .. ')', false)
		w.notify(src, { title = 'notify.withdrawn', description = '$' .. math.groupdigits(amount), type = 'success' })
	else
		w.notify(src, { title = 'notify.account_insufficient', type = 'error' })
	end

	TriggerClientEvent('w_gangmenu:client:OpenMenu', src)
end)

RegisterNetEvent("w_gangmenu:server:depositMoney", function(amount)
	local src = source
	local Player = ws.GetPlayer(src)
	if not Player or not Player.gang then return end

	if not Player.gang.isboss then w.notify(src, { title = 'notify.not_boss', type = 'error' }) return end

	amount = tonumber(amount)
	if not amount or amount <= 0 then return end

	local gang = Player.gang.name
	if ws.TransferPlayer(Player, gang, amount, true, false) then
		TriggerEvent('w_log:server:CreateLog', 'gangmenu', 'Deposit Money', 'yellow', (Player.charinfo.firstname or '') .. ' ' .. (Player.charinfo.lastname or '') .. ' successfully deposited $' .. amount .. ' (' .. gang .. ')', false)
		w.notify(src, { title = 'notify.deposited', description = '$' .. math.groupdigits(amount), type = 'success' })
	else
		w.notify(src, { title = 'notify.cash_insufficient', type = 'error' })
	end

	TriggerClientEvent('w_gangmenu:client:OpenMenu', src)
end)

-- Grade Change
-- data.cid is the citizen id the member list carries. The list shows offline members too, so the
-- id is resolved (w.citizen) and the grade written on the live player or on the saved row.
RegisterNetEvent('w_gangmenu:server:GradeUpdate', function(data)
	local src = source
	local Player = ws.GetPlayer(src)
	if not Player or not Player.gang then return end

	if not Player.gang.isboss then w.notify(src, { title = 'notify.not_boss', type = 'error' }) return end
	local grade = type(data) == 'table' and math.tointeger(tonumber(data.grade)) or nil
	if not grade or grade < 0 then return end
	if grade > Player.gang.grade.level then w.notify(src, { title = 'notify.promote_rank_denied', type = 'error' }) return end

	local gangName = Player.gang.name
	local who, reason = w.citizen.resolve(data.cid)
	local current, Employee
	if who then current, Employee = ws.RoleOf(who, 'gang') end

	if not who then
		w.notify(src, { title = ws.CitizenReason(reason), type = 'error' })
	elseif not current or current.name ~= gangName then
		-- the event names any citizen id: only a member of the leader's own gang changes grade here
		w.notify(src, { title = 'notify.not_member', type = 'error' })
	elseif (tonumber(current.grade and current.grade.level) or 0) > Player.gang.grade.level then
		w.notify(src, { title = 'notify.grade_denied', type = 'error' })
	elseif Employee then
		if exports.w_lib:FwSetGang(Employee.source, gangName, grade) then
			-- grade name in each recipient's own language (SetGang wrote name / name_ar)
			local updated = ws.GetPlayer(Employee.source)
			local newGang = updated and updated.gang or ws.RoleFor('gang', gangName, grade)
			w.notify(src, { title = 'notify.promoted', description = exports.w_lib:FwGradeName(newGang, src), type = 'success' })
			w.notify(Employee.source, { title = 'notify.you_were_promoted', description = exports.w_lib:FwGradeName(newGang, Employee.source), type = 'success' })
		else
			w.notify(src, { title = 'notify.grade_missing', type = 'error' })
		end
	else
		-- offline: the table SetGang would write, onto his saved row, only while he is still a member
		local role = ws.RoleFor('gang', gangName, grade)
		if not role then
			w.notify(src, { title = 'notify.grade_missing', type = 'error' })
		elseif exports.w_lib:FwSetOfflineRole(who.citizenid, 'gang', role, gangName) then
			w.notify(src, { title = 'notify.promoted', description = exports.w_lib:FwGradeName(role, src), type = 'success' })
		else
			w.notify(src, { title = 'notify.error', type = 'error' })
		end
	end
	TriggerClientEvent('w_gangmenu:client:OpenMenu', src)
end)

-- Fire Member
-- `target` is the citizen id the member list carries (online or not: w.citizen decides).
RegisterNetEvent('w_gangmenu:server:FireMember', function(target)
	local src = source
	local Player = ws.GetPlayer(src)
	if not Player or not Player.gang then return end

	if not Player.gang.isboss then w.notify(src, { title = 'notify.not_boss', type = 'error' }) return end

	local gangName = Player.gang.name
	local bossName = (Player.charinfo.firstname or '') .. " " .. (Player.charinfo.lastname or '')
	local who, reason = w.citizen.resolve(target)
	local current, Employee
	if who then current, Employee = ws.RoleOf(who, 'gang') end

	if not who then
		w.notify(src, { title = ws.CitizenReason(reason), type = 'error' })
	elseif who.citizenid == Player.citizenid then
		w.notify(src, { title = 'notify.gang_fire_self', type = 'error' })
	elseif not current or current.name ~= gangName then
		-- only a member of the leader's own gang: the event names any citizen id
		w.notify(src, { title = 'notify.not_member', type = 'error' })
	elseif (tonumber(current.grade and current.grade.level) or 0) > Player.gang.grade.level then
		w.notify(src, { title = 'notify.fire_denied', type = 'error' })
	elseif Employee then
		if exports.w_lib:FwSetGang(Employee.source, "none", 0) then
			local memberName = (Employee.charinfo.firstname or '') .. " " .. (Employee.charinfo.lastname or '')
			TriggerEvent("w_log:server:CreateLog", "gangmenu", "Gang Fire", "orange", bossName .. ' successfully fired ' .. memberName .. " [" .. who.citizenid .. "] (" .. gangName .. ")", false)
			w.notify(src, { title = 'notify.gang_member_fired', description = memberName, type = 'success' })
			w.notify(Employee.source, { title = 'notify.you_were_expelled', type = 'error' })
		else
			w.notify(src, { title = 'notify.error', type = 'error' })
		end
	else
		-- Same shape and labels SetGang writes, taken from the shared gang table
		-- (the label and grade name end up in the player's HUD).
		RefreshSharedRoles()
		local def = SharedGangs['none'] or {label='None',grades={}}
		local grade0 = def.grades[0] or def.grades['0'] or {}
		local gang = {
			name = 'none',
			label = def.label,
			label_ar = def.label_ar or def.label,
			isboss = false,
			grade = { name = grade0.name or 'No Grades', name_ar = grade0.name_ar or grade0.name or "بدون رتبة", level = 0 },
		}
		-- written only while the saved row still holds this gang (he may have left meanwhile)
		if exports.w_lib:FwSetOfflineRole(who.citizenid,'gang',gang,gangName) then
			local memberName = (who.name and who.name ~= '') and who.name or who.citizenid
			w.notify(src, { title = 'notify.gang_member_fired', description = memberName, type = 'success' })
			TriggerEvent("w_log:server:CreateLog", "gangmenu", "Gang Fire", "orange", bossName .. ' successfully fired ' .. memberName .. " [" .. who.citizenid .. "] (" .. gangName .. ")", false)
		else
			w.notify(src, { title = 'notify.error', type = 'error' })
		end
	end
	TriggerClientEvent('w_gangmenu:client:OpenMenu', src)
end)

-- Recruit Player
-- `recruit` is the server id of a player the nearby picker listed. The character on that seat is
-- named by his citizen id from here on (the log), and he must still be near the leader.
RegisterNetEvent('w_gangmenu:server:HireMember', function(recruit)
	local src = source
	local Player = ws.GetPlayer(src)
	if not Player or not Player.gang then return end

	if not Player.gang.isboss then w.notify(src, { title = 'notify.not_boss', type = 'error' }) return end

	local gangName = Player.gang.name
	local who = w.citizen.fromSource(recruit)
	local Target = who and ws.GetPlayer(who.source)
	if not Target or who.source == src then
		w.notify(src, { title = 'notify.citizen_offline', type = 'error' })
	elseif not ws.IsNear(src, who.source) then
		w.notify(src, { title = 'notify.too_far', type = 'error' })
	elseif Target.gang.name == gangName then
		-- SetGang(gang, 0) on a member would drop him to the lowest grade
		w.notify(src, { title = 'notify.already_member', type = 'error' })
	elseif exports.w_lib:FwSetGang(Target.source, gangName, 0) then
		local targetName = (Target.charinfo.firstname or '') .. ' ' .. (Target.charinfo.lastname or '')
		-- gang name in each recipient's own language
		w.notify(src, { title = 'notify.gang_recruited', description = targetName .. ' - ' .. exports.w_lib:FwJobLabel(Player.gang, src), type = 'success' })
		w.notify(Target.source, { title = 'notify.you_were_recruited', description = exports.w_lib:FwJobLabel(Player.gang, Target.source), type = 'success' })
		TriggerEvent('w_log:server:CreateLog', 'gangmenu', 'Recruit', 'yellow', ((Player.charinfo.firstname or '') .. ' ' .. (Player.charinfo.lastname or '')).. ' successfully recruited ' .. targetName .. " [" .. who.citizenid .. "]" .. ' (' .. gangName .. ')', false)
	end
	TriggerClientEvent('w_gangmenu:client:OpenMenu', src)
end)

-- Get Account Info --
-- The gang is taken from the requesting player on the server; the client's argument is not trusted.
w.callback.register('w_gangmenu:server:GetAccount', function(source)
	local Player = ws.GetPlayer(source)
	if not Player or not Player.gang then return 0 end
	return ws.GetGangAccount(Player.gang.name)
end)

-- Get Employees
w.callback.register('w_gangmenu:server:GetEmployees', function(source)
	local src = source
	local Player = ws.GetPlayer(src)

	if not Player or not Player.gang then return {} end
	if not Player.gang.isboss then w.notify(src, { title = 'notify.not_boss', type = 'error' }) return end

	RefreshSharedRoles()
	local gangname = Player.gang.name
	local employees = {}
	-- Bound parameter instead of string concatenation; the LIKE only narrows the rows, the
	-- decoded gang name decides.
	local players = exports.w_lib:FwCharacterRows('gang',gangname)
	for _, value in ipairs(players or {}) do
		local isOnline = exports.w_lib:FwGetPlayerByCitizenId(value.citizenid)

		if isOnline then
			if isOnline.gang.name == gangname then
				employees[#employees+1] = {
					empSource = isOnline.citizenid,
					grade = isOnline.gang.grade,
					isboss = isOnline.gang.isboss,
					name = '🟢 ' .. (isOnline.charinfo.firstname or '') .. ' ' .. (isOnline.charinfo.lastname or '')
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
