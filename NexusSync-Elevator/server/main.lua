local elevators, states, rate, riders = {}, {}, {}, {}
local revision, loaded, tripSequence = 0, false, 0
local function notify(src,msg) TriggerClientEvent('ns_elevator:notify',src,msg) end
local function throttle(src,key,ms)
    rate[src] = rate[src] or {}
    local now = GetGameTimer()
    if rate[src][key] and now-rate[src][key] < ms then return false end
    rate[src][key] = now
    return true
end
local function admin(src) return src > 0 and IsPlayerAceAllowed(src,Config.AdminAce) end
local function snapshot(src)
    TriggerClientEvent('ns_elevator:sync',src,elevators,states,revision)
end
local function finishRider(player)
    local rider=riders[player]
    if not rider then return end
    riders[player]=nil
    for _,other in pairs(riders) do if other.id==rider.id then return end end
    if states[rider.id] then
        states[rider.id].phase='idle'
        TriggerClientEvent('ns_elevator:state',-1,rider.id,states[rider.id])
    end
end
RegisterNetEvent('ns_elevator:finished',function(trip)
    local rider=riders[source]
    if rider and rider.trip==trip and rider.arriving then finishRider(source) end
end)
local function publish(id) TriggerClientEvent('ns_elevator:state',-1,id,states[id]) end
local function near(src,e,p,r)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetPlayerRoutingBucket(src) == e.bucket
        and NS.distance(GetEntityCoords(ped),p) <= r
end
local function save(nextData)
    local list = {}
    for _,e in pairs(nextData) do list[#list+1] = e end
    table.sort(list,function(a,b) return a.id < b.id end)
    local raw = json.encode({revision=revision+1,elevators=list})
    local old = LoadResourceFile(GetCurrentResourceName(),Config.DataFile)
    if old and not SaveResourceFile(GetCurrentResourceName(),'data/elevators.backup.json',old,-1) then return false end
    if not SaveResourceFile(GetCurrentResourceName(),Config.DataFile,raw,-1) then return false end
    revision = revision+1
    elevators = nextData
    return true
end
CreateThread(function()
    local raw = LoadResourceFile(GetCurrentResourceName(),Config.DataFile)
    local ok,data = pcall(json.decode,raw or '')
    if not ok or type(data) ~= 'table' or type(data.elevators) ~= 'table' then
        print('^1[NexusSync-Elevator] Invalid JSON. Fix the file before restarting; saving is disabled.^0')
        return
    end
    for _,e in ipairs(data.elevators) do
        local valid,reason = NS.validate(e)
        if not valid or elevators[e.id] then
            elevators = {}; print('^1[NexusSync-Elevator] Invalid configuration: '..(reason or 'duplicate ID')..'^0'); return
        end
        elevators[e.id] = e
        states[e.id] = {phase='idle'}
    end
    revision = tonumber(data.revision) or 0
    loaded = true
    snapshot(-1)
end)
RegisterNetEvent('ns_elevator:syncRequest',function()
    if loaded and throttle(source,'sync',2000) then snapshot(source) end
end)
RegisterNetEvent('ns_elevator:creator',function()
    local src=source
    if not admin(src) then return notify(src,'You do not have permission to use the creator.') end
    if not loaded then return notify(src,'Invalid server configuration. Check the console.') end
    TriggerClientEvent('ns_elevator:creatorOpen',src,elevators,revision,{screenFade=Config.UseScreenFade==true,maxFloors=Config.MaxFloors})
end)
RegisterNetEvent('ns_elevator:save',function(e,rev)
    local src=source
    if not admin(src) or not loaded or not throttle(src,'save',1000) then return end
    local function result(ok,message)
        TriggerClientEvent('ns_elevator:saveResult',src,ok,message,revision)
    end
    if rev ~= revision then return result(false,'Another administrator changed the data. Select the elevator again to reload it.') end
    local ok,reason = NS.validate(e)
    if not ok then return result(false,reason) end
    if states[e.id] and states[e.id].phase ~= 'idle' then return result(false,'Wait for the trip to finish.') end
    local count=0; local nextData={}
    for id,entry in pairs(elevators) do nextData[id]=entry; count=count+1 end
    if not nextData[e.id] and count >= Config.MaxElevators then return result(false,'Elevator limit reached.') end
    nextData[e.id]=e
    if not save(nextData) then return result(false,'Could not save the JSON file to disk.') end
    states[e.id]={phase='idle'}
    snapshot(-1); result(true,'Elevator saved and active.')
end)
RegisterNetEvent('ns_elevator:delete',function(id,rev)
    local src=source
    if not admin(src) or not loaded or type(id) ~= 'string' or not throttle(src,'save',1000) then return end
    local function result(ok,msg) TriggerClientEvent('ns_elevator:saveResult',src,ok,msg,revision) end
    if rev ~= revision then return result(false,'Outdated data. Select the elevator again to reload it.') end
    if not elevators[id] then return result(false,'Elevator not found.') end
    if states[id].phase ~= 'idle' then return result(false,'Wait for the elevator to stop.') end
    local nextData={}
    for key,e in pairs(elevators) do if key ~= id then nextData[key]=e end end
    if not save(nextData) then return result(false,'Failed to save to disk.') end
    states[id]=nil; snapshot(-1); result(true,'Elevator deleted.')
end)
RegisterNetEvent('ns_elevator:travel',function(id,fromId,toId)
    local src=source
    if type(id) ~= 'string' or type(fromId) ~= 'string' or type(toId) ~= 'string' or not throttle(src,'use',1000) then return end
    local e,s=elevators[id],states[id]
    local from,to=e and NS.floor(e,fromId),e and NS.floor(e,toId)
    if not from or not to or fromId == toId then return end
    if not near(src,e,from.panel,Config.InteractDistance+0.8) or not near(src,e,from.spawn,from.radius) then return end
    if s.phase ~= 'idle' or riders[src] then return notify(src,'The elevator is moving. Please wait.') end
    if GetVehiclePedIsIn(GetPlayerPed(src),false) ~= 0 then return end
    if not Bridge.allowed(src,from) or not Bridge.allowed(src,to) then return notify(src,'You do not have access to the selected floor.') end
    local passengers={}
    for _,pid in ipairs(GetPlayers()) do
        local player=tonumber(pid)
        if near(player,e,from.spawn,from.radius) and not riders[player] and GetVehiclePedIsIn(GetPlayerPed(player),false) == 0 then
            if not Bridge.allowed(player,to) then return notify(src,'A passenger does not have access to the destination. Trip cancelled.') end
            passengers[#passengers+1]=player
        end
    end
    if #passengers == 0 then return end
    tripSequence=tripSequence+1
    local trip=tripSequence
    s.phase='moving'; publish(id)
    for _,player in ipairs(passengers) do
        riders[player]={id=id,ped=GetPlayerPed(player),trip=trip,arriving=false}
        TriggerClientEvent('ns_elevator:depart',player,Config.TravelDuration,to.spawn,NS.screenFade(e),trip)
    end
    SetTimeout(Config.TravelDuration,function()
        for _,player in ipairs(passengers) do
            local rider=riders[player]
            if rider and rider.trip == trip and rider.ped == GetPlayerPed(player) and near(player,e,from.spawn,from.radius+0.5) then
                local ped=rider.ped
                local p=GetEntityCoords(ped)
                local angle=math.rad(to.spawn.h-from.spawn.h)
                local dx,dy=p.x-from.spawn.x,p.y-from.spawn.y
                local arrival={x=to.spawn.x+dx*math.cos(angle)-dy*math.sin(angle),
                    y=to.spawn.y+dx*math.sin(angle)+dy*math.cos(angle),z=to.spawn.z,h=to.spawn.h}
                -- Send an authorised destination once; the client places the ped after loading the floor.
                rider.arriving=true
                TriggerClientEvent('ns_elevator:arrive',player,arrival)
            elseif rider and rider.trip==trip then
                finishRider(player)
                TriggerClientEvent('ns_elevator:cancel',player)
            end
        end
        -- Reserve the elevator until all clients finish loading, or the recovery timeout expires.
        SetTimeout(Config.CollisionTimeout+Config.FadeDuration+3000,function()
            for _,player in ipairs(passengers) do
                if riders[player] and riders[player].trip==trip then
                    finishRider(player)
                    TriggerClientEvent('ns_elevator:cancel',player)
                end
            end
        end)
    end)
end)
AddEventHandler('playerDropped',function() rate[source]=nil; finishRider(source) end)
