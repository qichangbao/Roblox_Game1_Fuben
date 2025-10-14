local ConditionBase = require(script.Parent:WaitForChild("ConditionBase"))

local ItemDropCondition = {}
setmetatable(ItemDropCondition, ConditionBase)
ItemDropCondition.__index = ItemDropCondition

function ItemDropCondition.new(config)
    local self = setmetatable(ConditionBase.new(config), ItemDropCondition)
    
    self.itemId = self.config.ItemId
    
    return self
end

function ItemDropCondition:MonitorPlayer(player)
    -- 检查是否超过最大触发次数
    if self:IsReachingMaxConditions(player) then
        return
    end

    -- 检查冷却时间
    if self:IsReachingCooldown(player) then
        return
    end

    if not self.isSatisfy then
        return
    end
    self:Fire({
        Player = player,
        ConditionItemId = self.itemId,
    })
end

return ItemDropCondition
