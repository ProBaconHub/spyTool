-- spyTool/modules/03_parser.lua

local parse
local getInstancePathFromParser
local parseLoadSuccess = pcall(function()
    local isCyclic; isCyclic = function(tbl, visited)
        visited = visited or {}
        if visited[tbl] then return true end
        visited[tbl] = true
        for _, value in pairs(tbl) do
            if type(value) == "table" then if isCyclic(value, visited) then return true end end
        end
        return false
    end
    local clean_string = function(str)
        local cleanTable = {['"'] = '\\"', ['\\'] = '\\\\', ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r"}
        for i = 0, 31 do
            if not cleanTable[string.char(i)] then
                cleanTable[string.char(i)] = "\\" .. string.format("%03d", i)
            end
        end
        for i = 127, 255 do
            cleanTable[string.char(i)] = "\\" .. string.format("%03d", i)
        end
        return (string.gsub(tostring(str), "[\"\\\0-\31\127-\255]", cleanTable))
    end
    local function isSimpleIdentifierName(name)
        if type(name) ~= "string" or name == "" then
            return false
        end
        if name:find(".", 1, true) then
            return false
        end
        return string.match(name, "^[%a_][%w_]*$") ~= nil
    end
    local get_instance_path = function(obj)
    	local path = ""
    	while obj do
    		if obj == game then
    			path = "game"..path
    			break
    		end
    		local indexName
    		local objName = tostring(obj.Name or "Unknown")
    		local objClass = "Instance"
    		pcall(function()
    			local cn = obj.ClassName
    			if type(cn) == "string" then
    				objClass = cn
    			end
    		end)

    		if isSimpleIdentifierName(objName) then
    			indexName = "." .. objName
    		else
                local escapedName = clean_string(objName)
    			indexName = '["' .. escapedName .. '"]'
    		end
    		if obj.Parent then
    			local success, hasChild = pcall(function() return obj.Parent:FindFirstChild(objName) end)
    			if success and hasChild and obj.Parent:FindFirstChild(objName) ~= obj then
    				local parCh = obj.Parent:GetChildren()
    				local fcInd = table.find(parCh, obj) or "nil"
    				indexName = ":GetChildren()["..fcInd.."]"
    			elseif obj.Parent == game and objClass then
    				indexName = ':GetService("'..objClass..'")'
    			end
    		elseif obj.Parent == nil then
    			local getnil = "local getNil = function(name, class) for _, v in next, getnilinstances() do if v.ClassName == class and v.Name == name then return v end end end"
    			local gotnil = "\n\ngetNil(\"%s\", \"%s\")"
    			indexName = getnil .. gotnil:format(objName, objClass)
    		end
    		path = indexName..path
    		obj = obj.Parent
    	end
        local lp = game.Players.LocalPlayer
        if lp and lp.Name then
            if path:sub(1, 27 + #lp.Name) == "game:GetService(\"Players\")." .. lp.Name then path = path:gsub("game:GetService%(\"Players\"%)." .. lp.Name, "game:GetService(\"Players\").LocalPlayer", 1) end
            if path:sub(1, 29 + #lp.Name) == "game:GetService(\"Workspace\")." .. lp.Name then path = path:gsub("game:GetService%(\"Workspace\"%)." .. lp.Name, "game:GetService(\"Players\").LocalPlayer.Character", 1) end
        end
    	local checkValid = pcall(function() local a = loadstring("return " .. path)() end)
        if not checkValid then path = "nil --[[ Invalid Path ]] " end
        return path
    end
    getInstancePathFromParser = get_instance_path
    local format_value = function(v)
        local vType = typeof(v)
        if vType == "string" then
            return '"' .. clean_string(v) .. '"'
        elseif vType == "number" then
            if v == math.huge then
                return "math.huge"
            elseif v == -math.huge then
                return "-math.huge"
            else
                return tostring(v)
            end
        elseif vType == "Instance" then
            return get_instance_path(v)
        elseif vType == "Color3" then
            return string.format("Color3.new(%s, %s, %s)", v.R, v.G, v.B)
        elseif vType == "BrickColor" then
            return string.format('BrickColor.new("%s")', tostring(v))
        elseif vType == "Vector3" then
            return string.format("Vector3.new(%s, %s, %s)", v.X, v.Y, v.Z)
        elseif vType == "Vector2" then
            return string.format("Vector2.new(%s, %s)", v.X, v.Y)
        elseif vType == "CFrame" then
            return "CFrame.new(" .. tostring(v) .. ")"
        elseif vType == "UDim2" then
            return "UDim2.new(" .. tostring(v):gsub("[%[%]]", "") .. ")"
        elseif vType == "UDim" then
            return "UDim.new(" .. tostring(v):gsub("[%[%]]", "") .. ")"
        elseif vType == "EnumItem" then
            return tostring(v)
        elseif vType == "NumberRange" then
            return "NumberRange.new(" .. tostring(v):gsub(" ", ", ") .. ")"
        elseif vType == "Rect" then
            return "Rect.new(" .. tostring(v) .. ")"
        else
            local str = tostring(v)
            if type(str) == "string" and str:match("^RaycastResult%s*{") then
                return '"' .. clean_string(str) .. '"' .. ' --[[ RaycastResult ]]'
            end
            if type(str) == "string" and str:match("^Connection") then
                return '\"' .. clean_string(str) .. '\"' .. ' --[[ Connection ]]'
            end
            if vType == "thread" or vType == "userdata" or vType == "function" or str:match("0x%x+$") then
                return '"' .. clean_string(str) .. '"'
            end
            return str
        end
    end
    local format_key = function(k)
        local kType = typeof(k)
        if kType == "string" then
            if isSimpleIdentifierName(k) then
                return k
            else
                return '["' .. clean_string(k) .. '"]'
            end
        else
            return "[" .. format_value(k) .. "]"
        end
    end
    local loops = 0
    local parse_workers = {} 
    local create_worker_index = function(parser)
        local current_index = #parse_workers + 1
        parse_workers[current_index] = parser
        return current_index
    end
    local parser; parser = function(tbl, indent, visited, ...)
        local extra = {...}
        local do_not_check_cyclic = extra[2]
        if not do_not_check_cyclic then
            if visited[tbl] then
                return indent .. "--[[ cyclic table detected ]]"
            end
            visited[tbl] = true
        end
        loops += 1
        if extra[1] and loops >= 1000 then
            loops = 0
            RunService.Stepped:Wait()
        end
        local prasing_lines = {}
        for i,v in pairs(tbl) do
            local formatted_key = format_key(i)
            if typeof(v) == "table" then
                local this_line = string.format("%s%s = {\n", indent, formatted_key)
                local new_worker = create_worker_index(parser)
                this_line ..= parse_workers[new_worker](v, indent .. "    ", visited, ...)
                this_line ..= "\n" .. indent .. "},"
                table.insert(prasing_lines, this_line)
            elseif typeof(v) == "function" then
                local success, result = pcall(function() return getfenv(v).script end)
                local the_source = tostring(debug.info(v, "s") or "unknown")
                if success and get_instance_path(result) ~= "" and get_instance_path(result) ~= nil then 
                    the_source = get_instance_path(result) 
                end
                the_source = the_source:gsub("%-%-%[%[", ""):gsub("%]%]", "") 

                local numArgs, isVariadic = debug.info(v, "a")
                local argInfo = string.format("args: %d%s", numArgs or 0, isVariadic and "..." or "")

                table.insert(prasing_lines, string.format("%s%s = %s, --[[ %s | Called by %s ]]", indent, formatted_key, format_value(v), argInfo, the_source))
            else
                table.insert(prasing_lines, string.format("%s%s = %s,", indent, formatted_key, format_value(v)))
            end
        end
        return table.concat(prasing_lines, "\n")
    end
    parse = function(tbl, halt, do_not_check_cyclic)
        if not tbl or type(tbl) ~= "table" then
            return tbl
        end
        parse_workers = {}
        loops = 0
        local parsed_content = "{\n"
        local worker_index = create_worker_index(parser)
        parsed_content ..= parse_workers[worker_index](tbl, "    ", {}, halt, do_not_check_cyclic)
        parsed_content ..= "\n}"
        parse_workers = {}
        return parsed_content
    end
end)

if not parseLoadSuccess or not parse then
    parse = function(value)
        if typeof(value) ~= "table" then
            return tostring(value)
        end
        
        local function serialize(tbl, indent)
            indent = indent or 0
            local spaces = string.rep("    ", indent)
            local nextSpaces = string.rep("    ", indent + 1)
            
            local isArray = true
            local count = 0
            for k, _ in pairs(tbl) do
                count = count + 1
                if type(k) ~= "number" or k ~= count then
                    isArray = false
                end
            end
            
            if count == 0 then
                return "{}"
            end
            
            local parts = {}
            
            if isArray then
                for i, v in ipairs(tbl) do
                    local valStr
                    if type(v) == "table" then
                        valStr = serialize(v, indent + 1)
                    elseif type(v) == "string" then
                        valStr = '"' .. v:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
                    else
                        valStr = tostring(v)
                    end
                    table.insert(parts, nextSpaces .. valStr)
                end
            else
                for k, v in pairs(tbl) do
                    local keyStr
                    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                        keyStr = k
                    else
                        keyStr = "[" .. (type(k) == "string" and ('"' .. k .. '"') or tostring(k)) .. "]"
                    end
                    
                    local valStr
                    if type(v) == "table" then
                        valStr = serialize(v, indent + 1)
                    elseif type(v) == "string" then
                        valStr = '"' .. v:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
                    else
                        valStr = tostring(v)
                    end
                    
                    table.insert(parts, nextSpaces .. keyStr .. " = " .. valStr)
                end
            end
            
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. spaces .. "}"
        end
        
        return serialize(value, 0)
    end
end
