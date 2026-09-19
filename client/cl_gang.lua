-- Definitions and role checks belong to the server; w_lib selects the active bag.
RegisterNetEvent('w_gangmenu:client:Stash', function()
    w.callback.await('w_management:server:OpenStash', false, 'gang')
end)

-- Gang name for the menu titles in the player's language (upper-case has no effect on Arabic)
local function GangTitle()
    return string.upper(WCore.Shared.JobLabel(PlayerGang))
end

-- Menus / Inputs --
RegisterNetEvent('w_gangmenu:client:OpenMenu', function()
    if not PlayerGang.name or not PlayerGang.isboss then return end
    local gangMenu = {
        {
            title = locale('gang.manage_members'),
            icon = "fa-solid fa-list",
            description = locale('gang.manage_members_desc'),
            event = "w_gangmenu:client:ManageGang",
        },
        {
            title = locale('gang.recruit'),
            icon = "fa-solid fa-hand-holding",
            description = locale('gang.recruit_desc'),
            event = "w_gangmenu:client:HireMembers",
        },
        {
            title = locale('common.storage'),
            icon = "fa-solid fa-box-open",
            description = locale('gang.storage_desc'),
            event = "w_gangmenu:client:Stash",
        },
        {
            title = locale('common.outfits'),
            description = locale('gang.outfits_desc'),
            icon = "fa-solid fa-shirt",
            event = "w_management:client:Wardrobe",
        },
        {
            title = locale('common.money'),
            icon = "fa-solid fa-sack-dollar",
            description = locale('gang.money_desc'),
            event = "w_gangmenu:client:SocietyMenu",
        },
    }

    w.registerContext({
        id = 'gang_menu',
        title = locale('gang.menu_title', GangTitle()),
        options = gangMenu
    })
    w.showContext('gang_menu')
end)

RegisterNetEvent('w_gangmenu:client:ManageGang', function()
    local GangMembersMenu = {}
    local gangMembers = w.callback.triggerServer('w_gangmenu:server:GetEmployees', PlayerGang.name) or {}

    for _, v in pairs(gangMembers) do
        GangMembersMenu[#GangMembersMenu + 1] = {
            title = v.name,
            description = WCore.Shared.GradeName(v.grade),
            icon = "fa-solid fa-circle-user",
            event = "w_gangmenu:lient:ManageMember",
            args = {
                player = v,
                work = PlayerGang
            }
        }
    end

    w.registerContext({
        id = 'manage_gang_members',
        title = locale('gang.members_title', GangTitle()),
        menu = 'gang_menu',
        options = GangMembersMenu
    })
    w.showContext('manage_gang_members')
end)

RegisterNetEvent('w_gangmenu:lient:ManageMember', function(data)
    local MemberMenu = {}

    local definition = SharedGangs[data.work.name] or {}
    local grades = definition.grades or {}
    local levels = {}
    for key in pairs(grades) do if tonumber(key) then levels[#levels + 1] = tonumber(key) end end
    table.sort(levels)
    for _, k in ipairs(levels) do
        local v = grades[k] or grades[tostring(k)]
        MemberMenu[#MemberMenu + 1] = {
            title = WCore.Shared.GradeName(v),
            description = locale('common.grade', k),
            serverEvent = "w_gangmenu:server:GradeUpdate",
            icon = "fa-solid fa-file-pen",
            args = {
                cid = data.player.empSource,
                grade = tonumber(k),
                gradename = v.name
            }
        }
    end

    MemberMenu[#MemberMenu + 1] = {
        title = locale('gang.fire'),
        icon = "fa-solid fa-user-large-slash",
        serverEvent = "w_gangmenu:server:FireMember",
        args = data.player.empSource
    }

    MemberMenu[#MemberMenu + 1] = {
        title = locale('common.return'),
        icon = "fa-solid fa-angle-left",
        event = "w_gangmenu:client:OpenMenu",
    }

    w.registerContext({
        id = 'gang_members',
        title = locale('common.manage_title', data.player.name, GangTitle()),
        menu = 'gang_menu',
        options = MemberMenu
    })
    w.showContext('gang_members')
end)

RegisterNetEvent('w_gangmenu:client:HireMembers', function()
    local HireMembersMenu = {}
    local players = w.callback.triggerServer('w_management:server:GetPlayers') or {}

    for _, v in pairs(players) do
        if v then -- the server callback already leaves the requesting player out
            HireMembersMenu[#HireMembersMenu + 1] = {
                title = v.name,
                description = locale('common.citizen_info', v.citizenid, v.sourceplayer),
                icon = "fa-solid fa-user-check",
                serverEvent = "w_gangmenu:server:HireMember",
                args = v.sourceplayer
            }
        end
    end

    w.registerContext({
        id = 'hire_gang_members',
        title = locale('gang.recruit_title', GangTitle()),
        menu = 'gang_menu',
        options = HireMembersMenu
    })
    w.showContext('hire_gang_members')
end)

RegisterNetEvent('w_gangmenu:client:SocietyMenu', function()
    local account = w.callback.triggerServer('w_gangmenu:server:GetAccount', PlayerGang.name) or 0
    local balance = math.groupdigits(account)
    local SocietyMenu = {
        {
            title = locale('common.deposit'),
            icon = "fa-solid fa-money-bill-transfer",
            description = locale('common.deposit_desc'),
            event = "w_gangmenu:client:SocietyDeposit",
            args = balance
        },
        {
            title = locale('common.withdraw'),
            icon = "fa-solid fa-money-bill-transfer",
            description = locale('common.withdraw_desc'),
            event = "w_gangmenu:client:SocietyWithdraw",
            args = balance
        },
        {
            title = locale('common.return'),
            icon = "fa-solid fa-angle-left",
            event = "w_gangmenu:client:OpenMenu",
        },
    }

    w.registerContext({
        id = 'gang_society',
        title = locale('common.balance_title', balance, GangTitle()),
        menu = 'gang_menu',
        options = SocietyMenu
    })
    w.showContext('gang_society')
end)

RegisterNetEvent('w_gangmenu:client:SocietyDeposit', function(balance)
    local deposit = w.inputDialog(locale('common.available_balance', balance), {
        { type = 'number', label = locale('common.amount'), description = locale('common.deposit_funds'), required = true },
    })
    if deposit then
        if not deposit[1] then return end
        TriggerServerEvent("w_gangmenu:server:depositMoney", tonumber(deposit[1]))
    end
end)

RegisterNetEvent('w_gangmenu:client:SocietyWithdraw', function(balance)
    local withdraw = w.inputDialog(locale('common.available_balance', balance), {
        { type = 'number', label = locale('common.amount'), description = locale('common.withdraw_funds'), required = true },
    })
    if withdraw then
        if not withdraw[1] then return end
        TriggerServerEvent("w_gangmenu:server:withdrawMoney", tonumber(withdraw[1]))
    end
end)
