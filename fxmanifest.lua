fx_version 'cerulean'
version '1.0.4'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'W_Management'

-- @w_lib/init.lua must load before any script that uses w / require / cache
shared_scripts { '@w_lib/init.lua', 'config.lua' }
client_scripts { 'client/*.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/*.lua' }

-- Library modules preloaded on both sides; 'locale' loads locales/<key>.json at start.
w_lib { 'locale' }

-- modules/client.lua and modules/server.lua are loaded once through require() (w_lib's
-- consumer-relative loader). The client module must be listed as a file, not a script:
-- the client only downloads declared files, so LoadResourceFile (which require uses)
-- returns nothing for an undeclared one. The server reads it straight from disk.
files {
    'modules/client.lua',
    'locales/*.json',
}

server_exports {
    'AddMoney',
    'AddGangMoney',
    'RemoveMoney',
    'RemoveGangMoney',
    'GetAccount',
    'GetGangAccount',
}

lua54 'yes'

-- The library resolves the host core and inventory.
dependencies { 'w_lib' }
