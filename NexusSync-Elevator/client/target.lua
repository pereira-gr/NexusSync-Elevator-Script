local zones,provider={},nil
local function detect()
    if (Config.Target=='auto' or Config.Target=='ox_target') and GetResourceState('ox_target')=='started' then return 'ox_target' end
    if (Config.Target=='auto' or Config.Target=='qb-target') and GetResourceState('qb-target')=='started' then return 'qb-target' end
end
local function clear()
    if provider and GetResourceState(provider)=='started' then
        for _,zone in ipairs(zones) do
            if provider=='ox_target' then exports.ox_target:removeZone(zone,true)
            else exports['qb-target']:RemoveZone(zone) end
        end
    end
    zones={};provider=nil
end
local function rebuild()
    clear()
    provider=detect()
    if not provider then return end
    for id,e in pairs(Elevator.data) do
        for _,f in ipairs(e.floors) do
            local liftId,floor=id,f
            local p=floor.panel
            local name='ns_elevator:'..liftId..':'..floor.id
            local function allowed()
                return Elevator.canInteract(liftId)
                    and NS.distance(GetEntityCoords(PlayerPedId()),p)<=Config.InteractDistance
            end
            local function select() Elevator.openPanel(liftId,floor) end
            if provider=='ox_target' then
                zones[#zones+1]=exports.ox_target:addSphereZone({
                    name=name,coords=vector3(p.x,p.y,p.z),radius=math.max(Config.TargetRadius,p.width/2,p.height/2),
                    debug=false,drawSprite=true,
                    options={{name=name,label='Select floor',icon='fas fa-elevator',
                        distance=Config.InteractDistance,canInteract=allowed,onSelect=select}}
                })
            else
                exports['qb-target']:AddCircleZone(name,vector3(p.x,p.y,p.z),math.max(Config.TargetRadius,p.width/2,p.height/2),
                    {name=name,useZ=true,debugPoly=false},
                    {options={{label='Select floor',icon='fas fa-elevator',canInteract=allowed,action=select}},
                        distance=Config.InteractDistance})
                zones[#zones+1]=name
            end
        end
    end
end
AddEventHandler('ns_elevator:targetsRefresh',rebuild)
CreateThread(function()
    local warned=false
    while true do
        local selected=detect()
        if selected~=provider then rebuild() end
        if not selected and not warned then
            print('^3[NexusSync-Elevator] Start ox_target or qb-target to interact with the screens.^0')
            warned=true
        elseif selected then warned=false end
        Wait(1000)
    end
end)
AddEventHandler('onClientResourceStop',function(name)
    if name==GetCurrentResourceName() then clear()
    elseif name==provider then zones={};provider=nil end
end)
