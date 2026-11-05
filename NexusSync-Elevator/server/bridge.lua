Bridge = {}
function Bridge.job(src)
    local framework = Config.Framework
    if framework == 'auto' then
        framework = GetResourceState('qbx_core') == 'started' and 'qbox'
            or GetResourceState('qb-core') == 'started' and 'qbcore'
            or GetResourceState('es_extended') == 'started' and 'esx' or 'standalone'
    end
    local ok,job = pcall(function()
        if framework == 'qbox' then
            local p = exports.qbx_core:GetPlayer(src)
            return p and p.PlayerData.job
        elseif framework == 'qbcore' then
            local p = exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
            return p and p.PlayerData.job
        elseif framework == 'esx' then
            local p = exports.es_extended:getSharedObject().GetPlayerFromId(src)
            return p and p.getJob()
        end
    end)
    if not ok or not job then return nil,0 end
    return job.name, tonumber(type(job.grade) == 'table' and job.grade.level or job.grade) or 0
end
function Bridge.allowed(src,f)
    if not f.job or f.job == '' then return true end
    local name,grade = Bridge.job(src)
    return name == f.job and grade >= f.grade
end
