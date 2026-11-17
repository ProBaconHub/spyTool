-- spyTool/modules/06_function_analyzer.lua

local FunctionAnalyzer = {}

local function rawDebugInfo(fn, what)
    local bypass = SpyStealth and SpyStealth.DebugInfoBypass
    if type(bypass) == "function" then
        local ok, a, b, c = pcall(bypass, fn, what)
        if ok then
            return a, b, c
        end
    end
    if type(debug.info) == "function" then
        local ok, a, b, c = pcall(debug.info, fn, what)
        if ok then
            return a, b, c
        end
    end
    return nil
end

local function isInternalSource(source)
    if type(source) ~= "string" or source == "" then
        return true
    end
    if source == "[C]" or source == "=[C]" then
        return false
    end
    local lower = source:lower()
    return lower:find("spytool", 1, true) ~= nil
        or lower:find("probaconhub", 1, true) ~= nil
end

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

    local source, line, name = rawDebugInfo(func, "sln")
    if type(source) == "string" and source ~= "" and not isInternalSource(source) then
        info.Source = source
    end
    if type(line) == "number" then
        info.LineDefined = line
    end
    if type(name) == "string" and name ~= "" then
        info.Name = name
    end

    if debug.getinfo then
        pcall(function()
            local dbgInfo = debug.getinfo(func)
            if not dbgInfo then
                return
            end
            local src = dbgInfo.short_src or dbgInfo.source
            if type(src) == "string" and src ~= "" and not isInternalSource(src) then
                info.Source = src
            end
            if dbgInfo.name and dbgInfo.name ~= "" then
                info.Name = dbgInfo.name
            end
            if dbgInfo.linedefined then
                info.LineDefined = dbgInfo.linedefined
            end
            if dbgInfo.lastlinedefined then
                info.LastLineDefined = dbgInfo.lastlinedefined
            end
            if dbgInfo.numparams then
                info.NumParams = dbgInfo.numparams
            end
            if dbgInfo.is_vararg ~= nil then
                info.IsVararg = dbgInfo.is_vararg
            end
            if dbgInfo.what then
                info.ClosureType = dbgInfo.what
            end
        end)
    end

    pcall(function()
        local env = getfenv(func)
        if env and typeof(env.script) == "Instance" then
            info.ScriptPath = env.script:GetFullName()
        end
    end)

    if (info.ScriptPath == "Unknown" or info.ScriptPath == "") and typeof(getcallingscript) == "function" then
        pcall(function()
            local scriptInst = getcallingscript()
            if typeof(scriptInst) == "Instance" then
                info.ScriptPath = scriptInst:GetFullName()
            end
        end)
    end

    if (info.Source == "Unknown" or isInternalSource(info.Source)) and info.ScriptPath ~= "Unknown" then
        info.Source = info.ScriptPath
    end

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

    local numParams, isVararg = rawDebugInfo(func, "a")
    if type(numParams) == "number" then
        info.NumParams = numParams
    end
    if isVararg ~= nil then
        info.IsVararg = isVararg and true or false
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
