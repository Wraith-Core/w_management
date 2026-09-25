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
-- data.cid is the citizen id the employee list carries. The list shows offline employees too, so
-- the id is resolved (w.citizen) and the grade written on the live player or on the saved row.
RegisterNetEvent('w_bossmenu:server:GradeUpdate', function(data)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)
	if not Player then return end

	if not Player.PlayerData.job.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Grade Update Exploiting') return end
	local grade = type(data) == 'table' and math.tointeger(tonumber(data.grade)) or nil
	if not grade or grade < 0 then return end
	if grade > Player.PlayerData.job.grade.level then w.notify(src, { title = 'notify.promote_rank_denied', type = 'error' }) return end

	local jobName = Player.PlayerData.job.name
	local who, reason = w.citizen.resolve(data.cid)
	local current, Employee
	if who then current, Employee = ws.RoleOf(who, 'job') end

	if not who then
		w.notify(src, { title = ws.CitizenReason(reason), type = 'error' })
	elseif not current or current.name ~= jobName then
		-- the event names any citizen id: only a member of the boss's own job changes grade here
		w.notify(src, { title = 'notify.not_member', type = 'error' })
	elseif (tonumber(current.grade and current.grade.level) or 0) > Player.PlayerData.job.grade.level then
		-- the same rule as a dismissal: nobody rewrites the grade of someone above him
		w.notify(src, { title = 'notify.grade_denied', type = 'error' })
	elseif Employee then
		if Employee.Functions.SetJob(jobName, grade) then
			-- grade name in each recipient's own language (SetJob wrote name / name_ar)
			local newJob = Employee.PlayerData.job
			w.notify(src, { title = 'notify.promoted', description = WCore.Shared.GradeName(newJob, src), type = 'success' })
			w.notify(Employee.PlayerData.source, { title = 'notify.you_were_promoted', description = WCore.Shared.GradeName(newJob, Employee.PlayerData.source), type = 'success' })
		else
			w.notify(src, { title = 'notify.grade_missing', type = 'error' })
		end
	else
		-- offline: the table SetJob would write, onto his saved row, only while he still holds this job
		local role = ws.RoleFor('job', jobName, grade)
		if not role then
			w.notify(src, { title = 'notify.grade_missing', type = 'error' })
		elseif exports.w_lib:FwSetOfflineRole(who.citizenid, 'job', role, jobName) then
			w.notify(src, { title = 'notify.promoted', description = WCore.Shared.GradeName(role, src), type = 'success' })
		else
			w.notify(src, { title = 'notify.error', type = 'error' })
		end
	end
	TriggerClientEvent('w_bossmenu:client:OpenMenu', src)
end)

-- Fire Employee --
-- `target` is the citizen id the employee list carries (online or not: w.citizen decides).
RegisterNetEvent('w_bossmenu:server:FireEmployee', function(target)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)
	if not Player then return end

	if not Player.PlayerData.job.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Fire Employee Exploiting') return end

	local jobName = Player.PlayerData.job.name
	local bossName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
	local who, reason = w.citizen.resolve(target)
	local current, Employee
	if who then current, Employee = ws.RoleOf(who, 'job') end

	if not who then
		w.notify(src, { title = ws.CitizenReason(reason), type = 'error' })
	elseif who.citizenid == Player.PlayerData.citizenid then
		w.notify(src, { title = 'notify.fire_self', type = 'error' })
	elseif not current or current.name ~= jobName then
		-- only a member of the boss's own job: the event names any citizen id
		w.notify(src, { title = 'notify.not_member', type = 'error' })
	elseif (tonumber(current.grade and current.grade.level) or 0) > Player.PlayerData.job.grade.level then
		w.notify(src, { title = 'notify.fire_denied', type = 'error' })
	elseif Employee then
		if Employee.Functions.SetJob("unemployed", 0) then
			local employeeName = Employee.PlayerData.charinfo.firstname .. " " .. Employee.PlayerData.charinfo.lastname
			TriggerEvent("w_log:server:CreateLog", "bossmenu", "Job Fire", "red", bossName .. ' successfully fired ' .. employeeName .. " [" .. who.citizenid .. "] (" .. jobName .. ")", false)
			w.notify(src, { title = 'notify.employee_fired', description = employeeName, type = 'success' })
			w.notify(Employee.PlayerData.source, { title = 'notify.you_were_fired', description = 'notify.you_were_fired_desc', type = 'error' })
		else
			w.notify(src, { title = 'notify.error', type = 'error' })
		end
	else
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
		-- written only while the saved row still holds this job (he may have changed it meanwhile)
		if exports.w_lib:FwSetOfflineRole(who.citizenid,'job',job,jobName) then
			local employeeName = (who.name and who.name ~= '') and who.name or who.citizenid
			w.notify(src, { title = 'notify.employee_fired', description = employeeName, type = 'success' })
			TriggerEvent("w_log:server:CreateLog", "bossmenu", "Job Fire", "red", bossName .. ' successfully fired ' .. employeeName .. " [" .. who.citizenid .. "] (" .. jobName .. ")", false)
		else
			w.notify(src, { title = 'notify.error', type = 'error' })
		end
	end
	TriggerClientEvent('w_bossmenu:client:OpenMenu', src)
end)

-- Recruit Player --
-- `recruit` is the server id of a player the nearby picker listed. The character on that seat is
-- named by his citizen id from here on (the log), and he must still be near the boss.
RegisterNetEvent('w_bossmenu:server:HireEmployee', function(recruit)
	local src = source
	local Player = WCore.Functions.GetPlayer(src)
	if not Player then return end

	if not Player.PlayerData.job.isboss then exports.w_lib:FwNativeCoreCall('ExploitBan',src, 'Hire Employee Exploiting') return end

	local jobName = Player.PlayerData.job.name
	local who = w.citizen.fromSource(recruit)
	local Target = who and WCore.Functions.GetPlayer(who.source)
	if not Target or who.source == src then
		w.notify(src, { title = 'notify.citizen_offline', type = 'error' })
	elseif not ws.IsNear(src, who.source) then
		w.notify(src, { title = 'notify.too_far', type = 'error' })
	elseif Target.PlayerData.job.name == jobName then
		-- SetJob(job, 0) on a member would drop him to the lowest grade
		w.notify(src, { title = 'notify.already_member', type = 'error' })
	elseif Target.Functions.SetJob(jobName, 0) then
		local targetName = Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname
		-- job name in each recipient's own language
		w.notify(src, { title = 'notify.hired', description = targetName .. ' - ' .. WCore.Shared.JobLabel(Player.PlayerData.job, src), type = 'success' })
		w.notify(Target.PlayerData.source, { title = 'notify.you_were_hired', description = WCore.Shared.JobLabel(Player.PlayerData.job, Target.PlayerData.source), type = 'success' })
		TriggerEvent('w_log:server:CreateLog', 'bossmenu', 'Recruit', "lightgreen", (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname).. " successfully recruited " .. targetName .. " [" .. who.citizenid .. "]" .. ' (' .. jobName .. ')', false)
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
