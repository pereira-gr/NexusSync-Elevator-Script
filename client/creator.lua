local placing=false
local previewTexture
local function destroyPreview()
    if previewTexture then DestroyDui(previewTexture.dui);previewTexture=nil end
    Elevator.previewKey=nil
    placing=false
    SendNUIMessage({action='placementEnd'})
end
RegisterCommand(Config.CreatorCommand,function()
    if placing or Elevator.isTravelling() then return end
    TriggerServerEvent('ns_elevator:creator')
end,false)
RegisterNetEvent('ns_elevator:creatorOpen',function(data,revision,defaults)
    if placing then return end
    Elevator.close()
    Elevator.editing=true
    SetNuiFocus(true,true)
    SendNUIMessage({action='creator',elevators=data,revision=revision,defaults=defaults})
end)
RegisterNetEvent('ns_elevator:saveResult',function(ok,message,revision)
    SendNUIMessage({action='saveResult',ok=ok,message=message,revision=revision,elevators=Elevator.data})
    Elevator.notify(message)
end)
local function point(v) return {x=v.x,y=v.y,z=v.z} end
local function raycast()
    local origin=GetGameplayCamCoord()
    local rotation=GetGameplayCamRot(2)
    local z,x=math.rad(rotation.z),math.rad(rotation.x)
    local dir=vector3(-math.sin(z)*math.cos(x),math.cos(z)*math.cos(x),math.sin(x))
    local target=origin+dir*8.0
    local ray=StartShapeTestRay(origin.x,origin.y,origin.z,target.x,target.y,target.z,17,PlayerPedId(),7)
    local status,hit,coords,normal
    local deadline=GetGameTimer()+250
    repeat Wait(0); status,hit,coords,normal=GetShapeTestResult(ray) until status~=1 or GetGameTimer()>=deadline
    return status==2 and (hit==1 or hit==true),coords,normal
end
-- Screen-local adjustment: arrows move relative to the face, not world axes.
function Elevator.adjustPreview(p,horizontal,vertical,depth,rotation)
    local a=math.rad(p.h)
    p.x=p.x-math.cos(a)*horizontal-math.sin(a)*depth
    p.y=p.y-math.sin(a)*horizontal+math.cos(a)*depth
    p.z=p.z+vertical
    p.h=(p.h+rotation)%360
end
local function makePreview(e,f,p)
    local payload=json.encode({action='panel',elevator=e,floor=f.id,state={phase='idle'}})
    local encoded=payload:gsub('([^%w%-_%.~])',function(c)return ('%%%02X'):format(c:byte())end)
    local name='ns_preview_'..GetGameTimer()
    local dui=CreateDui('https://cfx-nui-'..GetCurrentResourceName()..'/web/index.html?world=1&payload='..encoded,480,880)
    previewTexture={dui=dui,name=name,txd=CreateRuntimeTxd(name),ready=false,panel=p}
end
RegisterNUICallback('capture',function(data,cb)
    if not Elevator.editing or placing then cb({ok=false});return end
    cb({ok=true})
    if data.kind=='spawn' then
        if IsPedFalling(PlayerPedId()) or IsPedJumping(PlayerPedId()) or IsPedInAnyVehicle(PlayerPedId(),false) then
            return Elevator.notify('Stand still on the floor to save the arrival position.')
        end
        local p=point(GetEntityCoords(PlayerPedId()))
        p.h=GetEntityHeading(PlayerPedId())
        SendNUIMessage({action='captured',kind='spawn',value=p})
        return
    end
    if data.kind~='panel' or type(data.elevator)~='table' then return end
    local e=data.elevator
    local f=NS.floor(e,data.floor)
    if not f then return end
    placing=true;SetNuiFocus(false,false)
    Elevator.previewKey=e.id..':'..f.id
    SendNUIMessage({action='placing'})
    CreateThread(function()
        local p
        if NS.point(f.panel) then
            p={x=f.panel.x,y=f.panel.y,z=f.panel.z,h=NS.number(f.panel.h,0,360) and f.panel.h or 0,width=NS.number(f.panel.width,0.15,1.0) and f.panel.width or 0.32,height=NS.number(f.panel.height,0.3,1.8) and f.panel.height or 0.59}
        else
            local hit,pos,normal=raycast()
            if hit and math.abs(normal.z)<0.25 then
                p=point(pos+normal*0.02)
                p.h=(math.deg(math.atan(-normal.x,normal.y))+360)%360
            else
                p=point(GetOffsetFromEntityInWorldCoords(PlayerPedId(),0.0,1.0,0.7))
                p.h=(GetEntityHeading(PlayerPedId())+180)%360
            end
            p.width=0.32;p.height=0.59
        end
        if not placing then return end
        makePreview(e,f,p)
        local confirmed=false
        local lastUpdate=0
        while placing and Elevator.editing do
            DisablePlayerFiring(PlayerId(),true)
            for _,control in ipairs({24,25,38,44,10,11,14,15,16,17,172,173,174,175,191,201,177,200}) do
                DisableControlAction(0,control,true)
            end
            if IsEntityDead(PlayerPedId()) then break end
            local fine=IsControlPressed(0,21)
            local dt=math.min(GetFrameTime(),0.05)
            local step=(fine and 0.03 or 0.25)*dt
            local function held(id)return IsDisabledControlPressed(0,id) and 1 or 0 end
            local depth=(held(10)-held(11))*step
            if IsDisabledControlJustPressed(0,15) then depth=depth+(fine and 0.002 or 0.01) end
            if IsDisabledControlJustPressed(0,14) then depth=depth-(fine and 0.002 or 0.01) end
            Elevator.adjustPreview(p,(held(175)-held(174))*step,(held(172)-held(173))*step,depth,
                (held(44)-held(38))*(fine and 5.0 or 35.0)*dt)
            if IsDisabledControlJustReleased(0,201) or IsDisabledControlJustReleased(0,191) then
                if NS.point(p) and (not f.spawn or NS.distance(p,f.spawn)<=5.0) then confirmed=true;break
                else Elevator.notify('Keep the screen within 5 metres of the arrival position.') end
            end
            if IsDisabledControlJustReleased(0,177) or IsDisabledControlJustReleased(0,200) then break end
            local t=previewTexture
            if t and IsDuiAvailable(t.dui) then
                if not t.ready then CreateRuntimeTextureFromDuiHandle(t.txd,'screen',GetDuiHandle(t.dui));t.ready=true end
                Elevator.drawScreen(p,t.name)
            end
            if GetGameTimer()-lastUpdate>100 then
                SendNUIMessage({action='placementUpdate',position=p,fine=fine})
                lastUpdate=GetGameTimer()
            end
            Wait(0)
        end
        destroyPreview()
        if Elevator.editing then
            SetNuiFocus(true,true)
            SendNUIMessage({action='captured',kind='panel',value=confirmed and p or nil})
        end
    end)
end)
RegisterNUICallback('save',function(data,cb)
    if Elevator.editing and not placing then TriggerServerEvent('ns_elevator:save',data.elevator,data.revision) end
    cb({ok=true})
end)
RegisterNUICallback('delete',function(data,cb)
    if Elevator.editing and not placing then TriggerServerEvent('ns_elevator:delete',data.id,data.revision) end
    cb({ok=true})
end)
AddEventHandler('onResourceStop',function(name)
    if name==GetCurrentResourceName() then destroyPreview() end
end)
