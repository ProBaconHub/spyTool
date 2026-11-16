-- spyTool/modules/06_function_analyzer.lua

local FunctionAnalyzer = {}

function FunctionAnalyzer:GetInfo(func)
    if typeof(func) ~= "function" then
        return nil
    end
    
    local info = {
        Address = tostring(func):gsub("function: ", ""),
        Name = "anonymous",
        Source = "Unknown",
        LineDefined = 0,
        LastLineDefined = 0,
        NumParams = 0,
        IsVararg = false,
        ClosureType = "Unknown",
        Constants = {},
        Upvalues = {},
        Protos = {},
        ScriptPath = "Unknown",
    }
    
    pcall(function()
        local source, line, name = debug.info(func, "sln")
        if source then info.Source = source end
        if line then info.LineDefined = line end
        if name and name ~= "" then info.Name = name end
    end)
    
    if debug.getinfo then
        pcall(function()
            local dbgInfo = debug.getinfo(func)
            if dbgInfo then
                if dbgInfo.source then info.Source = dbgInfo.source end
                if dbgInfo.short_src then info.Source = dbgInfo.short_src end
                if dbgInfo.name and dbgInfo.name ~= "" then info.Name = dbgInfo.name end
                if dbgInfo.linedefined then info.LineDefined = dbgInfo.linedefined end
                if dbgInfo.lastlinedefined then info.LastLineDefined = dbgInfo.lastlinedefined end
                if dbgInfo.numparams then info.NumParams = dbgInfo.numparams end
                if dbgInfo.is_vararg ~= nil then info.IsVararg = dbgInfo.is_vararg end
                if dbgInfo.what then info.ClosureType = dbgInfo.what end
                if dbgInfo.func then info.Address = tostring(dbgInfo.func):gsub("function: ", "") end
            end
        end)
    end
    
    pcall(function()
        local env = getfenv(func)
        if env and env.script and typeof(env.script) == "Instance" then
            info.ScriptPath = env.script:GetFullName()
        end
    end)
    
    if debug.getconstants then
        pcall(function()
            info.Constants = debug.getconstants(func) or {}
        end)
    end
    
    if debug.getupvalues then
        pcall(function()
            info.Upvalues = debug.getupvalues(func) or {}
        end)
    end
    
    if debug.getprotos then
        pcall(function()
            info.Protos = debug.getprotos(func) or {}
        end)
    end
    
    if islclosure and islclosure(func) then
        info.ClosureType = "Lua"
    elseif iscclosure and iscclosure(func) then
        info.ClosureType = "C"
    end
    
    return info
end

function FunctionAnalyzer:Decompile(func)
    if decompile then
        local success, result = pcall(decompile, func)
        if success then
            return result
        end
    end
    return "-- Decompilation not available or failed"
end

function FunctionAnalyzer:GetScript(func)
    local script = nil
    
    pcall(function()
        local env = getfenv(func)
        if env and env.script then
            script = env.script
        end
    end)
    
    return script
end
