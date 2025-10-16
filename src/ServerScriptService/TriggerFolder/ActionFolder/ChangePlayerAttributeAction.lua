local ActionBase = require(script.Parent:WaitForChild("ActionBase"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local ChangePlayerAttributeAction = {}
setmetatable(ChangePlayerAttributeAction, ActionBase)
ChangePlayerAttributeAction.__index = ChangePlayerAttributeAction

function ChangePlayerAttributeAction.new(config, condition)
    local self = setmetatable(ActionBase.new(config, condition), ChangePlayerAttributeAction)
    self.duration = self.config.Duration
    return self
end

function ChangePlayerAttributeAction:Execute(data)
    ActionBase.Execute(self)
    
    Knit.GetService("PlayerService"):ChangePlayerAttribute(data.Player, self.config.AttributeName, self.config.AttributeValue)
    if self.duration and self.duration > 0 then
        task.delay(self.duration, function()
            Knit.GetService("PlayerService"):ChangePlayerAttribute(data.Player, self.config.AttributeName)
        end)
    end
end

return ChangePlayerAttributeAction
