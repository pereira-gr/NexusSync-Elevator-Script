fx_version 'cerulean'
game 'gta5'
author 'NexusSync'
name 'NexusSync-Elevator'
description 'Elevators with 3D screens and an in-game creator'
version '1.1.0'
shared_scripts { 'config.lua', 'shared/schema.lua' }
server_scripts { 'server/bridge.lua', 'server/main.lua' }
client_scripts { 'client/main.lua', 'client/target.lua', 'client/creator.lua' }
ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/app.js', 'web/fonts/*.ttf' }
dependency '/onesync'
