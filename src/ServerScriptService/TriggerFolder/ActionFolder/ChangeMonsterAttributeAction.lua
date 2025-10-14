local ActionBase = require(script.Parent:WaitForChild("ActionBase"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local ChangeMonsterAttributeAction = {}
setmetatable(ChangeMonsterAttributeAction, ActionBase)
ChangeMonsterAttributeAction.__index = ChangeMonsterAttributeAction

function ChangeMonsterAttributeAction.new(config, condition)
    local self = setmetatable(ActionBase.new(config, condition), ChangeMonsterAttributeAction)
    return self
end

function ChangeMonsterAttributeAction:Execute(data)
    ActionBase.Execute(self)
    print("执行ChangeMonsterAttributeAction")
    
    if self.config.AttributeName and self.config.AttributeValue > 0 then
	    Knit.GetService("MonsterService"):ChangeAllMonsterAttribute(self.config.AttributeName, self.config.AttributeValue)
    else
	    Knit.GetService("MonsterService"):ChangeAllMonsterAttribute(self.config.AttributeName)
    end
end

return ChangeMonsterAttributeAction
