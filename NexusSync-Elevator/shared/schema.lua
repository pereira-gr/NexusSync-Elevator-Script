NS = {}
function NS.number(n, lo, hi)
    return type(n) == 'number' and n == n and n >= lo and n <= hi
end
function NS.point(p)
    return type(p) == 'table' and NS.number(p.x,-20000,20000)
        and NS.number(p.y,-20000,20000) and NS.number(p.z,-2000,4000)
end
function NS.distance(a,b)
    return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2)
end
local function text(s, max)
    return type(s) == 'string' and #s > 0 and #s <= max
end
function NS.validate(e)
    if type(e) ~= 'table' or not text(e.id,48) or not e.id:match('^[%w_-]+$')
        or not text(e.name,80) then return false, 'Invalid ID or name.' end
    if not NS.number(e.bucket,0,65535) or e.bucket % 1 ~= 0 then return false, 'Invalid routing bucket.' end
    if type(e.floors) ~= 'table' or #e.floors < 2 or #e.floors > Config.MaxFloors then
        return false, 'Configure between 2 and '..Config.MaxFloors..' floors.'
    end
    if e.screenFade ~= nil and type(e.screenFade) ~= 'boolean' then return false, 'Invalid black-screen option.' end
    local ids = {}
    for _,f in ipairs(e.floors) do
        if type(f) ~= 'table' or not text(f.id,24) or ids[f.id] or not text(f.label,32) then
            return false, 'Each floor needs a unique ID and a label.'
        end
        ids[f.id] = true
        if not NS.point(f.spawn) or not NS.number(f.spawn.h,0,360)
            or not NS.point(f.panel) or not NS.number(f.panel.h,0,360)
            or not NS.number(f.panel.width,0.15,1.0) or not NS.number(f.panel.height,0.3,1.8)
            or not NS.number(f.radius,0.5,3.0) then return false, 'Missing valid positions or dimensions on floor '..f.label end
        if NS.distance(f.spawn,f.panel) > 5 then
            return false, 'Place the screen near the cabin centre.'
        end
        if f.job ~= nil and (type(f.job) ~= 'string' or #f.job > 48) then return false, 'Invalid job.' end
        if not NS.number(f.grade,0,100) or f.grade % 1 ~= 0 then return false, 'Invalid minimum grade.' end

    end
    return true
end
function NS.floor(e,id)
    if type(e) ~= 'table' or type(e.floors) ~= 'table' then return end
    for i,f in ipairs(e.floors) do if f.id == id then return f,i end end
end

function NS.screenFade(e)
    if e.screenFade ~= nil then return e.screenFade end
    return Config.UseScreenFade == true
end
