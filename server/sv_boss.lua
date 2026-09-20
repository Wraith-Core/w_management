local ws = require('modules.server')
BossAccounts = {}

MySQL.ready(function ()
	local bossmenu = MySQL.query.await('SELECT job_name,amount FROM management_funds WHERE type = "boss"', {})
	if not bossmenu then return end

	for _,v in ipairs(bossmenu) do
		BossAccounts[v.job_name] = v.amount
	end
end)

-- Notifications: title is a dictionary key translated on the client (w.notify → __w_notify),
-- description carries the dynamic part (amount, name, label); a description that is itself a
-- dictionary key (notify.you_were_fired_desc) is translated by the client as well.

-- Withdraw Funds --
RegisterNetEvent("w_bossmenu:server:withdrawMoney", function(amount)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)

	if not Player.PlayerData.job.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Withdraw Money Exploiting') return end

	-- The amount comes from the client: nil / non-numeric / negative values must not reach the account code.
	amount = tonumber(amount)
	if not amount or amount <= 0 then return end

	local job = Player.PlayerData.job.name
	if ws.TransferPlayer(Player, job, amount, false, true) then
		TriggerEvent('w_log:server:CreateLog', 'bossmenu', 'Withdraw Money', "blue", Player.PlayerData.name .. " withdrew $" .. amount .. ' (' .. job .. ')', false)
		w.notify(src, { title = 'notify.withdrawn', description = '$' .. math.groupdigits(amount), type = 'success' })
	else
		w.notify(src, { title = 'notify.account_insufficient', type = 'error' })
	end

	TriggerClientEvent('w_bossmenu:client:OpenMenu', src)
end)

-- Deposit Funds --
RegisterNetEvent("w_bossmenu:server:depositMoney", function(amount)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)

	if not Player.PlayerData.job.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Deposit Money Exploiting') return end

	amount = tonumber(amount)
	if not amount or amount <= 0 then return end

	local job = Player.PlayerData.job.name
	if ws.TransferPlayer(Player, job, amount, false, false) then
		TriggerEvent('w_log:server:CreateLog', 'bossmenu', 'Deposit Money', "blue", Player.PlayerData.name .. " deposited $" .. amount .. ' (' .. job .. ')', false)
		w.notify(src, { title = 'notify.deposited', description = '$' .. math.groupdigits(amount), type = 'success' })
	else
		w.notify(src, { title = 'notify.cash_insufficient', type = 'error' })
	end

	TriggerClientEvent('w_bossmenu:client:OpenMenu', src)
end)

-- Grade Change --
RegisterNetEvent('w_bossmenu:server:GradeUpdate', function(data)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)
	local Employee = WCore.Functions.GetPlayerByCitizenId(data.cid)

	if not Player.PlayerData.job.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Grade Update Exploiting') return end
	if data.grade > Player.PlayerData.job.grade.level then w.notify(src, { title = 'notify.promote_rank_denied', type = 'error' }) return end

	if Employee then
		if Employee.Functions.SetJob(Player.PlayerData.job.name, data.grade) then
			-- grade name in each recipient's own language (SetJob wrote name / name_ar)
			local newJob = Employee.PlayerData.job
			w.notify(src, { title = 'notify.promoted', description = WCore.Shared.GradeName(newJob, src), type = 'success' })
			w.notify(Employee.PlayerData.source, { title = 'notify.you_were_promoted', description = WCore.Shared.GradeName(newJob, Employee.PlayerData.source), type = 'success' })
		else
			w.notify(src, { title = 'notify.grade_missing', type = 'error' })
		end
	else
		w.notify(src, { title = 'notify.citizen_offline', type = 'error' })
	end
	TriggerClientEvent('w_bossmenu:client:OpenMenu', src)
end)

-- Fire Employee --
RegisterNetEvent('w_bossmenu:server:FireEmployee', function(target)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)
	local Employee = WCore.Functions.GetPlayerByCitizenId(target)

	if not Player.PlayerData.job.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Fire Employee Exploiting') return end

	if Employee then
		if target ~= Player.PlayerData.citizenid then
			if Employee.PlayerData.job.grade.level > Player.PlayerData.job.grade.level then w.notify(src, { title = 'notify.fire_denied', type = 'error' }) return end
			if Employee.Functions.SetJob("unemployed", 0) then
				TriggerEvent("w_log:server:CreateLog", "bossmenu", "Job Fire", "red", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname .. ' successfully fired ' .. Employee.PlayerData.charinfo.firstname .. " " .. Employee.PlayerData.charinfo.lastname .. " (" .. Player.PlayerData.job.name .. ")", false)
				w.notify(src, { title = 'notify.employee_fired', description = Employee.PlayerData.charinfo.firstname .. ' ' .. Employee.PlayerData.charinfo.lastname, type = 'success' })
				w.notify(Employee.PlayerData.source, { title = 'notify.you_were_fired', description = 'notify.you_were_fired_desc', type = 'error' })
			else
				w.notify(src, { title = 'notify.error', type = 'error' })
			end
		else
			w.notify(src, { title = 'notify.fire_self', type = 'error' })
		end
	else
		local player = exports.w_lib:FwCharacterRows('citizenid',target)
		if player[1] ~= nil then
			Employee = player[1]
			Employee.job = json.decode(Employee.job)
			if Employee.job.grade.level > Player.PlayerData.job.grade.level then w.notify(src, { title = 'notify.fire_denied', type = 'error' }) return end
			-- Same shape and labels w_core's SetJob writes, taken from the shared job table
			-- (the label and grade name end up in the player's HUD).
			local def = SharedJobs['unemployed'] or {label='Unemployed',grades={}}
			local grade0 = def.grades[0] or def.grades['0'] or {}
			local job = {
				name = 'unemployed',
				label = def.label,
				label_ar = def.label_ar or def.label,
				type = def.type or 'none',
				payment = grade0.payment or 30,
				onduty = def.defaultDuty ~= false,
				isboss = false,
				grade = { name = grade0.name or 'No Grades', name_ar = grade0.name_ar or grade0.name or "بدون رتبة", level = 0 },
			}
			if not exports.w_lib:FwSetOfflineRole(target,'job',job,Player.PlayerData.job.name) then return end
			-- Employee is a database row here (no PlayerData): read the name from the stored charinfo.
			local charinfo = json.decode(Employee.charinfo) or {}
			w.notify(src, { title = 'notify.employee_fired', description = (charinfo.firstname or '?') .. ' ' .. (charinfo.lastname or '?'), type = 'success' })
			TriggerEvent("w_log:server:CreateLog", "bossmenu", "Job Fire", "red", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname .. ' successfully fired ' .. (charinfo.firstname or '?') .. " " .. (charinfo.lastname or '?') .. " (" .. Player.PlayerData.job.name .. ")", false)
		else
			w.notify(src, { title = 'notify.citizen_offline', type = 'error' })
		end
	end
	TriggerClientEvent('w_bossmenu:client:OpenMenu', src)
end)

-- Recruit Player --
RegisterNetEvent('w_bossmenu:server:HireEmployee', function(recruit)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)
	local Target = WCore.Functions.GetPlayer(recruit)

	if not Player.PlayerData.job.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Hire Employee Exploiting') return end

	if Target and Target.Functions.SetJob(Player.PlayerData.job.name, 0) then
		local targetName = Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname
		-- job name in each recipient's own language
		w.notify(src, { title = 'notify.hired', description = targetName .. ' - ' .. WCore.Shared.JobLabel(Player.PlayerData.job, src), type = 'success' })
		w.notify(Target.PlayerData.source, { title = 'notify.you_were_hired', description = WCore.Shared.JobLabel(Player.PlayerData.job, Target.PlayerData.source), type = 'success' })
		TriggerEvent('w_log:server:CreateLog', 'bossmenu', 'Recruit', "lightgreen", (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname).. " successfully recruited " .. targetName .. ' (' .. Player.PlayerData.job.name .. ')', false)
	end
	TriggerClientEvent('w_bossmenu:client:OpenMenu', src)
end)

-- Get Account Info --
-- The job is taken from the requesting player on the server; the client's argument is not trusted.
w.callback.register('w_bossmenu:server:GetAccount', function(source)
	local Player = WCore.Functions.GetPlayer(source)
	if not Player then return 0 end
	return ws.GetAccount(Player.PlayerData.job.name)
end)

-- Get Employees
w.callback.register('w_bossmenu:server:GetEmployees', function(source)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)

	if not Player then return {} end
	if not Player.PlayerData.job.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Get Employees Exploiting') return end

	local jobname = Player.PlayerData.job.name
	local employees = {}
	-- Bound parameter instead of string concatenation; the LIKE only narrows the rows, the
	-- decoded job name decides.
	local players = exports.w_lib:FwCharacterRows('job',jobname)
	for _, value in ipairs(players or {}) do
		local isOnline = WCore.Functions.GetPlayerByCitizenId(value.citizenid)

		if isOnline then
			if isOnline.PlayerData.job.name == jobname then
				employees[#employees+1] = {
					empSource = isOnline.PlayerData.citizenid,
					grade = isOnline.PlayerData.job.grade,
					isboss = isOnline.PlayerData.job.isboss,
					name = '🟢 ' .. isOnline.PlayerData.charinfo.firstname .. ' ' .. isOnline.PlayerData.charinfo.lastname
				}
			end
		else
			local job = json.decode(value.job) or {}
			if job.name == jobname then
				local charinfo = json.decode(value.charinfo) or {}
				-- rows saved before name_ar existed: take the Arabic grade name from the catalogue
				local grade = job.grade or {}
				if not grade.name_ar and SharedJobs[jobname] then
					local grades = SharedJobs[jobname].grades or {}
					local level = tonumber(grade.level) or 0
					local def = grades[level] or grades[tostring(level)]
					grade.name_ar = def and def.name_ar or nil
				end
				employees[#employees+1] = {
					empSource = value.citizenid,
					grade = grade,
					isboss = job.isboss,
					name = '❌ ' .. (charinfo.firstname or '?') .. ' ' .. (charinfo.lastname or '?')
				}
			end
		end
	end
	return employees
end)

-- Society deposits from the jobs (hospital bills, fines): server-side only, never a net event.
AddEventHandler('w_bossmenu:server:addAccountMoney', function(account, amount)
    if type(account) ~= 'string' or type(amount) ~= 'number' or amount <= 0 then return end
    ws.AddMoney(account, amount)
end)
