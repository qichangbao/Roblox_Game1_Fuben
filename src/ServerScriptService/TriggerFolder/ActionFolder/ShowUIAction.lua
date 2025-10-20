local ReplicatedStorage = game:WaitForChild("ReplicatedStorage")
local ActionBase = require(script.Parent:WaitForChild("ActionBase"))
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local ShowUIAction = {}
setmetatable(ShowUIAction, ActionBase)
ShowUIAction.__index = ShowUIAction

function ShowUIAction.new(config, condition)
    local self = setmetatable(ActionBase.new(config, condition), ShowUIAction)
    self.UI = config.UI
    return self
end

function ShowUIAction:Execute(data)
    ActionBase.Execute(self)

    print("执行ShowUIAction")
    -- 显示UI
    Knit.GetService("ClientUIService"):ShowUIAll(self.UI)
end

return ShowUIAction