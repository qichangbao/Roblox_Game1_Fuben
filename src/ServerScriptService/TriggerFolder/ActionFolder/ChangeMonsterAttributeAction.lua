local ActionBase = require(script.Parent:WaitForChild("ActionBase"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local ChangeMonsterAttributeAction = {}
setmetatable(ChangeMonsterAttributeAction, ActionBase)
ChangeMonsterAttributeAction.__index = ChangeMonsterAttributeAction

function ChangeMonsterAttributeAction.new(config, condition)
    local self = setmetatable(ActionBase.new(config, condition), ChangeMonsterAttributeAction)
    self.duration = self.config.Duration
    return self
end

function ChangeMonsterAttributeAction:Execute(data)
    ActionBase.Execute(self)
    
    Knit.GetService("MonsterService"):ChangeAllMonsterAttribute(self.config.AttributeValue)
    if self.duration and self.duration > 0 then
        task.delay(self.duration, function()
            Knit.GetService("MonsterService"):ChangeAllMonsterAttribute()
        end)
    end
end

return ChangeMonsterAttributeAction
