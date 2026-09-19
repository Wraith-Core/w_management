-- Definitions and role checks belong to the server; w_lib selects the active bag.
RegisterNetEvent('w_bossmenu:client:Stash', function()
    w.callback.await('w_management:server:OpenStash', false, 'job')
end)

-- Job name for the menu titles in the player's language (upper-case has no effect on Arabic)
local function JobTitle()
    return string.upper(WCore.Shared.JobLabel(PlayerJob))
end

-- Menus / Inputs --
RegisterNetEvent('w_bossmenu:client:OpenMenu', function()
    if not PlayerJob.name or not PlayerJob.isboss then return end
    local bossMenu = {
        {
            title = locale('boss.manage_employees'),
            description = locale('boss.manage_employees_desc'),
            icon = "fa-solid fa-list",
            event = "w_bossmenu:client:employeelist",
        },
        {
            title = locale('boss.hire'),
            description = locale('boss.hire_desc'),
            icon = "fa-solid fa-hand-holding",
            event = "w_bossmenu:client:HireMenu",
        },
        {
            title = locale('common.storage'),
            description = locale('boss.storage_desc'),
            icon = "fa-solid fa-box-open",
            event = "w_bossmenu:client:Stash",
        },
        {
            title = locale('common.outfits'),
            description = locale('boss.outfits_desc'),
            icon = "fa-solid fa-shirt",
            event = "w_management:client:Wardrobe",
        },
        {
            title = locale('common.money'),
            description = locale('boss.money_desc'),
            icon = "fa-solid fa-sack-dollar",
            event = "w_bossmenu:client:SocietyMenu",
        },
    }

    w.registerContext({
        id = 'boss_menu',
        title = locale('boss.menu_title', JobTitle()),
        options = bossMenu
    })
    w.showContext('boss_menu')
end)

RegisterNetEvent('w_bossmenu:client:employeelist', function()
    local EmployeesMenu = {}
    local employees = w.callback.triggerServer('w_bossmenu:server:GetEmployees', PlayerJob.name) or {}

    for _, v in pairs(employees) do
        EmployeesMenu[#EmployeesMenu + 1] = {
            title = v.name,
            description = WCore.Shared.GradeName(v.grade),
            icon = "fa-solid fa-circle-user",
            event = "w_bossmenu:client:ManageEmployee",
            args = { player = v, work = PlayerJob }
        }
    end

    w.registerContext({
        id = 'employee_list',
        title = locale('boss.employees_title', JobTitle()),
        menu = 'boss_menu',
        options = EmployeesMenu
    })
    w.showContext('employee_list')
end)

RegisterNetEvent('w_bossmenu:client:ManageEmployee', function(data)
    local EmployeeMenu = {}

    local definition = SharedJobs[data.work.name] or {}
    local grades = definition.grades or {}
    local levels = {}
    for key in pairs(grades) do if tonumber(key) then levels[#levels + 1] = tonumber(key) end end
    table.sort(levels)
    for _, x in ipairs(levels) do
        local info = grades[x] or grades[tostring(x)]
        EmployeeMenu[#EmployeeMenu + 1] = {
            title  = WCore.Shared.GradeName(info),
            description = locale('common.grade', x),
            serverEvent = "w_bossmenu:server:GradeUpdate",
            icon = "fa-solid fa-file-pen",
            args = { cid = data.player.empSource, grade = tonumber(x), gradename = info.name }
        }
    end

    EmployeeMenu[#EmployeeMenu + 1] = {
        title = locale('boss.fire'),
        icon = "fa-solid fa-user-large-slash",
        serverEvent = "w_bossmenu:server:FireEmployee",
        args = data.player.empSource
    }

    EmployeeMenu[#EmployeeMenu + 1] = {
        title = locale('common.return'),
        icon = "fa-solid fa-angle-left",
        event = "w_bossmenu:client:OpenMenu",
    }

    w.registerContext({
        id = 'manage_employee',
        title = locale('common.manage_title', data.player.name, JobTitle()),
        menu = 'boss_menu',
        options = EmployeeMenu
    })
    w.showContext('manage_employee')
end)

RegisterNetEvent('w_bossmenu:client:HireMenu', function()
    local HireMenu = {}
    local players = w.callback.triggerServer('w_management:server:GetPlayers') or {}

    for _, v in pairs(players) do
        if v then -- the server callback already leaves the requesting player out
            HireMenu[#HireMenu + 1] = {
                title = v.name,
                description = locale('common.citizen_info', v.citizenid, v.sourceplayer),
                icon = "fa-solid fa-user-check",
                serverEvent = "w_bossmenu:server:HireEmployee",
                args = v.sourceplayer
            }
        end
    end

    w.registerContext({
        id = 'hire_menu',
        title = locale('boss.hire_title', JobTitle()),
        menu = 'boss_menu',
        options = HireMenu
    })
    w.showContext('hire_menu')
end)

RegisterNetEvent('w_bossmenu:client:SocietyMenu', function()
    local account = w.callback.triggerServer('w_bossmenu:server:GetAccount', PlayerJob.name) or 0
    local balance = math.groupdigits(account)
    local SocietyMenu = {
        {
            title = locale('common.deposit'),
            icon = "fa-solid fa-money-bill-transfer",
            description = locale('common.deposit_desc'),
            event = "w_bossmenu:client:SocetyDeposit",
            args = balance
        },
        {
            title = locale('common.withdraw'),
            icon = "fa-solid fa-money-bill-transfer",
            description = locale('common.withdraw_desc'),
            event = "w_bossmenu:client:SocetyWithDraw",
            args = balance
        },
        {
            title = locale('common.return'),
            icon = "fa-solid fa-angle-left",
            event = "w_bossmenu:client:OpenMenu",
        },
    }

    w.registerContext({
        id = 'society_menu',
        title = locale('common.balance_title', balance, JobTitle()),
        menu = 'boss_menu',
        options = SocietyMenu
    })
    w.showContext('society_menu')
end)

RegisterNetEvent('w_bossmenu:client:SocetyDeposit', function(balance)
    local deposit = w.inputDialog(locale('common.available_balance', balance), {
        { type = 'number', label = locale('common.amount'), description = locale('common.deposit_funds'), required = true },
    })
    if deposit then
        if not deposit[1] then return end
        TriggerServerEvent("w_bossmenu:server:depositMoney", tonumber(deposit[1]))
    end
end)

RegisterNetEvent('w_bossmenu:client:SocetyWithDraw', function(balance)
    local withdraw = w.inputDialog(locale('common.available_balance', balance), {
        { type = 'number', label = locale('common.amount'), description = locale('common.withdraw_funds'), required = true },
    })
    if withdraw then
        if not withdraw[1] then return end
        TriggerServerEvent("w_bossmenu:server:withdrawMoney", tonumber(withdraw[1]))
    end
end)
