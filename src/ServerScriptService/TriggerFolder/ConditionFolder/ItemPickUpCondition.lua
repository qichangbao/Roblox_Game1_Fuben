local ConditionBase = require(script.Parent:WaitForChild("ConditionBase"))

local ItemPickUpCondition = {}
setmetatable(ItemPickUpCondition, ConditionBase)
ItemPickUpCondition.__index = ItemPickUpCondition

function ItemPickUpCondition.new(config)
    local self = setmetatable(ConditionBase.new(config), ItemPickUpCondition)
    
    self.itemId = self.config.ItemId
    
    return self
end

function ItemPickUpCondition:MonitorPlayer(player)
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

return ItemPickUpCondition