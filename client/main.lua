Elevator = { data={}, states={}, revision=0, editing=false }
local ui, cam, travelling, travelToken = nil,nil,false,0
local textures = {}
local closingCams = {}
local function vec(p) return vector3(p.x,p.y,p.z) end
function Elevator.notify(msg) SendNUIMessage({action='toast',message=msg}) end
RegisterNetEvent('ns_elevator:notify',Elevator.notify)
function Elevator.close()
    ui=nil
    SetNuiFocus(false,false)
    SendNUIMessage({action='close'})
    if cam then
        local previous=cam
        cam=nil
        closingCams[previous]=true
        RenderScriptCams(false,true,450,true,true)
        CreateThread(function()
            Wait(450)
            if closingCams[previous] then DestroyCam(previous,false); closingCams[previous]=nil end
        end)
    end
end
function Elevator.canInteract(id)
    local state=Elevator.states[id]
    return not ui and not next(closingCams) and not travelling and not Elevator.editing and state and state.phase=='idle'
        and not IsPedInAnyVehicle(PlayerPedId(),false) and not IsEntityDead(PlayerPedId())
end
local function cleanupWorld()
    for _,t in pairs(textures) do DestroyDui(t.dui) end
    textures={}

end
RegisterNetEvent('ns_elevator:sync',function(data,states,revision)
    cleanupWorld()
    Elevator.data,Elevator.states,Elevator.revision=data,states,revision
    if ui then Elevator.close() end
    TriggerEvent('ns_elevator:targetsRefresh')
end)
RegisterNetEvent('ns_elevator:state',function(id,state)
    Elevator.states[id]=state
    if ui and ui.id == id then
        SendNUIMessage({action='state',state=state})
        if state.phase == 'moving' then Elevator.close() end
    end
end)
function Elevator.openPanel(id,f)
    if travelling or Elevator.editing or ui or next(closingCams) or IsPedInAnyVehicle(PlayerPedId(),false) then return end
    if NS.distance(GetEntityCoords(PlayerPedId()),f.panel)>Config.InteractDistance+0.3 then return end
    local e,s=Elevator.data[id],Elevator.states[id]
    if not s or s.phase ~= 'idle' then return Elevator.notify('The elevator is moving. Please wait.') end
    ui={id=id,floor=f.id}
    local p=f.panel
    local a=math.rad(p.h)
    local normal=vector3(-math.sin(a),math.cos(a),0)
    local eye=vec(p)+normal*0.8
    cam=CreateCam('DEFAULT_SCRIPTED_CAMERA',true)
    SetCamCoord(cam,eye.x,eye.y,eye.z)
    PointCamAtCoord(cam,p.x,p.y,p.z)
    SetCamFov(cam,55.0)
    RenderScriptCams(true,true,650,true,true)
    CreateThread(function()
        Wait(650)
        if not ui or ui.id ~= id or ui.floor ~= f.id then return end
        SetNuiFocus(true,true)
        SendNUIMessage({action='panel',elevator=e,floor=f.id,state=s})
    end)
end
RegisterNUICallback('close',function(_,cb)
    Elevator.close(); Elevator.editing=false; cb({ok=true})
end)
RegisterNUICallback('selectFloor',function(data,cb)
    if ui and type(data.id)=='string' then
        local id,from=ui.id,ui.floor
        Elevator.close()
        TriggerServerEvent('ns_elevator:travel',id,from,data.id)
    end
    cb({ok=true})
end)
local origin, standingOffset, travelPed, tripId
local travelFade, ownsFade, arriving = false,false,false
function Elevator.isTravelling() return travelling end
local function releaseTravel(instant)
    travelToken=travelToken+1
    travelling=false
    ClearFocus()
    if travelPed and DoesEntityExist(travelPed) then
        SetEntityVelocity(travelPed,0.0,0.0,0.0)
        FreezeEntityPosition(travelPed,false)
    end
    travelPed=nil
    arriving=false
    if ownsFade then DoScreenFadeIn(instant and 0 or Config.FadeDuration); ownsFade=false end
    if tripId then TriggerServerEvent('ns_elevator:finished',tripId);tripId=nil end
end
-- A short ray finds this interior's floor, never a roof far above the configured level.
local function groundAt(p,ped)
    local ray=StartShapeTestRay(p.x,p.y,p.z+0.25,p.x,p.y,p.z-2.0,17,ped,7)
    local status,hit,point,normal
    local deadline=GetGameTimer()+250
    repeat
        Wait(0)
        status,hit,point,normal=GetShapeTestResult(ray)
    until status~=1 or GetGameTimer()>=deadline
    if status==2 and (hit==1 or hit==true) and normal and normal.z>0.65 then return point.z end
end
RegisterNetEvent('ns_elevator:depart',function(duration,destination,screenFade,id)
    if travelling then return end
    tripId=id
    travelFade=screenFade==nil and Config.UseScreenFade==true or screenFade==true
    Elevator.close(); Elevator.editing=false; travelling=true; travelToken=travelToken+1
    local token=travelToken
    travelPed=PlayerPedId()
    local coords=GetEntityCoords(travelPed)
    origin={x=coords.x,y=coords.y,z=coords.z,h=GetEntityHeading(travelPed)}
    standingOffset=0.95
    ClearPedTasksImmediately(travelPed)
    SetEntityVelocity(travelPed,0.0,0.0,0.0)
    FreezeEntityPosition(travelPed,true)
    CreateThread(function()
        local floor=groundAt(origin,travelPed)
        if floor and travelling and travelToken==token then standingOffset=math.max(0.5,math.min(1.2,origin.z-floor)) end
    end)
    CreateThread(function()
        local deadline=GetGameTimer()+duration
        while travelling and travelToken==token and GetGameTimer()<deadline do
            if destination then RequestCollisionAtCoord(destination.x,destination.y,destination.z) end
            Wait(50)
        end
        if not travelling or travelToken~=token then return end
        -- Recover if the server stops responding while a trip is pending.
        Wait(Config.CollisionTimeout+Config.FadeDuration+3000)
        if travelling and travelToken==token then
            if origin then SetEntityCoordsNoOffset(travelPed,origin.x,origin.y,origin.z,false,false,false) end
            releaseTravel()
        end
    end)
end)
RegisterNetEvent('ns_elevator:cancel',function()releaseTravel()end)
RegisterNetEvent('ns_elevator:arrive',function(p)
    if not travelling or not travelPed or arriving then return end
    arriving=true
    local token,ped=travelToken,travelPed
    CreateThread(function()
        if travelToken~=token then return end
        if not NS.point(p) or not NS.number(p.h,0,360) or ped~=PlayerPedId() or not DoesEntityExist(ped) or IsEntityDead(ped) then releaseTravel();return end
        FreezeEntityPosition(ped,true)
        -- Only own fades initiated here, so other resources keep control of their fades.
        if travelFade and not IsScreenFadedOut() and not IsScreenFadingOut() then
            ownsFade=true
            DoScreenFadeOut(Config.FadeDuration)
            local fadeDeadline=GetGameTimer()+Config.FadeDuration+500
            while not IsScreenFadedOut() and GetGameTimer()<fadeDeadline do
                Wait(0)
                if travelToken~=token then return end
            end
            if not IsScreenFadedOut() then
                Elevator.notify('Screen transition failed. Trip cancelled.')
                releaseTravel();return
            end
        end
        SetFocusPosAndVel(p.x,p.y,p.z,0.0,0.0,0.0)
        RequestCollisionAtCoord(p.x,p.y,p.z)
        -- Keep the player at the origin until the destination floor has loaded.
        local deadline=GetGameTimer()+Config.CollisionTimeout
        local ground
        repeat
            if travelToken~=token then return end
            RequestCollisionAtCoord(p.x,p.y,p.z)
            ground=groundAt(p,ped)
            if not ground then Wait(25) end
        until ground or GetGameTimer()>=deadline
        if travelToken~=token then return end
        if not ground then
            Elevator.notify('The destination floor did not load. Trip cancelled.')
            releaseTravel()
            return
        end
        ClearPedTasksImmediately(ped)
        SetEntityVelocity(ped,0.0,0.0,0.0)
        SetEntityCoordsNoOffset(ped,p.x,p.y,ground+standingOffset,false,false,false)
        SetEntityHeading(ped,p.h)
        SetGameplayCamRelativeHeading(0.0)
        SetGameplayCamRelativePitch(0.0,1.0)
        Wait(100)
        if travelToken~=token then return end
        ClearFocus()
        if travelToken==token then releaseTravel() end
    end)
end)
-- UVW values must be Lua floats: integer bit patterns collapse texture sampling.
function Elevator.drawScreen(p,txd)
    local a=math.rad(p.h)
    local right=vector3(math.cos(a),math.sin(a),0)*p.width/2
    local up=vector3(0,0,p.height/2)
    local c=vec(p)
    -- Viewed from the wall normal, +right is the viewer's LEFT. Flip U, not V.
    local tl,tr,bl,br=c-right+up,c+right+up,c-right-up,c+right-up
    DrawTexturedPoly(tl.x,tl.y,tl.z,tr.x,tr.y,tr.z,bl.x,bl.y,bl.z,255,255,255,255,txd,'screen',1.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,1.0)
    DrawTexturedPoly(tr.x,tr.y,tr.z,br.x,br.y,br.z,bl.x,bl.y,bl.z,255,255,255,255,txd,'screen',0.0,0.0,1.0,0.0,1.0,1.0,1.0,1.0,1.0)
end
local function help(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0,false,true,-1)
end
function Elevator.help(msg) help(msg) end
-- At most eight nearby browser textures, released again when leaving the area.
CreateThread(function()
    while true do
        local pos=GetEntityCoords(PlayerPedId())
        local candidates={}
        for id,e in pairs(Elevator.data) do
            for _,f in ipairs(e.floors) do
                local distance=NS.distance(pos,f.panel)
                if distance<Config.RenderDistance then
                    candidates[#candidates+1]={id=id,e=e,f=f,distance=distance,key=id..':'..f.id}
                end
            end
        end
        table.sort(candidates,function(a,b) return a.distance<b.distance end)
        local wanted={}
        for i=1,math.min(8,#candidates) do
            local item=candidates[i]; wanted[item.key]=true
            if not textures[item.key] then
                local name='ns_elev_'..item.id..'_'..i..'_'..GetGameTimer()
                local payload=json.encode({action='panel',elevator=item.e,floor=item.f.id,state=Elevator.states[item.id] or {phase='idle'}})
                local encoded=payload:gsub('([^%w%-_%.~])',function(c) return ('%%%02X'):format(c:byte()) end)
                local dui=CreateDui('https://cfx-nui-'..GetCurrentResourceName()..'/web/index.html?world=1&payload='..encoded,480,880)
                local txd=CreateRuntimeTxd(name)
                textures[item.key]={dui=dui,name=name,panel=item.f.panel,txd=txd}
            end
            local t=textures[item.key]
            if IsDuiAvailable(t.dui) then
                if not t.ready then
                    CreateRuntimeTextureFromDuiHandle(t.txd,'screen',GetDuiHandle(t.dui)); t.ready=true
                end
                SendDuiMessage(t.dui,json.encode({action='panel',elevator=item.e,floor=item.f.id,state=Elevator.states[item.id]}))
            end
        end
        for key,t in pairs(textures) do if not wanted[key] then DestroyDui(t.dui); textures[key]=nil end end
        Wait(1000)
    end
end)
CreateThread(function()
    Wait(1000); TriggerServerEvent('ns_elevator:syncRequest')
    while true do
        local sleep=350
        local pos=GetEntityCoords(PlayerPedId())
        for key,t in pairs(textures) do
            sleep=0
            if t.ready and key~=Elevator.previewKey then Elevator.drawScreen(t.panel,t.name) end
        end
        if ui then
            sleep=0
            local e=Elevator.data[ui.id]; local f=e and NS.floor(e,ui.floor)
            if not f or NS.distance(pos,f.panel)>Config.InteractDistance+0.5 or IsEntityDead(PlayerPedId()) then Elevator.close() end
            DisableControlAction(0,30,true); DisableControlAction(0,31,true)
            DisablePlayerFiring(PlayerId(),true)
        end
        if travelling then sleep=0; DisableAllControlActions(0) end
        Wait(sleep)
    end
end)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    SetNuiFocus(false,false)
    RenderScriptCams(false,false,0,true,true)
    if cam then DestroyCam(cam,false);cam=nil end
    for handle in pairs(closingCams) do DestroyCam(handle,false) end
    closingCams={}
    cleanupWorld()
    if travelling then releaseTravel(true) end
end)
