local path = game:GetService("ReplicatedStorage").Aero.Shared.ToolSettings.DefaultGun
local fun_name = "Equip"

getgenv().originalfunction = getgenv().originalfunction or {}
if getgenv().originalfunction[path:GetFullName()..fun_name] ~= nil then
    print("Old func found. Restoring...")
    require(path)[fun_name] = getgenv().originalfunction[path:GetFullName()..fun_name]
    getgenv().originalfunction[path:GetFullName()..fun_name] = nil
end
getgenv().originalfunction[path:GetFullName()..fun_name] = require(path)[fun_name]
require(path)[fun_name] = function(...)
    for i,v in pairs(...) do
        print("[\""..i.."\"]", v, "    (type: "..tostring(type(v))..")")
    end
end