local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TriggerConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("TriggerConfig"))

local TriggerFolder = script.Parent
local ConditionFolder = TriggerFolder:WaitForChild("ConditionFolder")
local ItemPickUpCondition = require(ConditionFolder:WaitForChild("ItemPickUpCondition"))
local ItemDropCondition = require(ConditionFolder:WaitForChild("ItemDropCondition"))

local ActionFolder = TriggerFolder:WaitForChild("ActionFolder")
local ChangeMonsterAttributeAction = require(ActionFolder:WaitForChild("ChangeMonsterAttributeAction"))
local ChangePlayerAttributeAction = require(ActionFolder:WaitForChild("ChangePlayerAttributeAction"))
local CreateMonsterAction = require(ActionFolder:WaitForChild("CreateMonsterAction"))
local ShowUIAction = require(ActionFolder:WaitForChild("ShowUIAction"))

local TriggerManager = {}

local _allConditions = {}   -- 所有条件
function TriggerManager.new()
    local self = setmetatable({}, { __index = TriggerManager })

    self:Init()

    for _, player in game.Players:GetPlayers() do
        for _, condition in ipairs(_allConditions) do
            condition:StartMonitoring(player)
        end
    end
    return self
end

-- 加载条件
function TriggerManager:Init()
    -- 遍历所有触发器配置
    for _, triggerConfig in ipairs(TriggerConfig) do
        local condition
        
        -- 根据触发器类型创建相应的触发器实例
        if triggerConfig.ConditionType == "ItemPickUp" then
            condition = ItemPickUpCondition.new(triggerConfig)
        elseif triggerConfig.ConditionType == "ItemDrop" then
            condition = ItemDropCondition.new(triggerConfig)
        else
            warn("未知的触发器类型:", triggerConfig.ConditionType)
            continue
        end
        table.insert(_allConditions, condition)

        local action
        if triggerConfig.Action then
            action = self:InitAction(triggerConfig.Action, condition)
        end
        
        -- 连接触发器事件
        condition:Connect(function(data)
            -- 执行关联动作
            if action then
                action:Execute(data)
            end
        end)
    end

    game:GetService("RunService").Heartbeat:Connect(function()
        for _, condition in ipairs(_allConditions) do
            for _, v in pairs(game.Players:GetPlayers()) do
                condition:MonitorPlayer(v)
            end
        end
    end)
end

-- 加载动作
function TriggerManager:InitAction(actionConfig, condition)
    local action
    if actionConfig.ActionType == "ChangeMonsterAttribute" then
        action = ChangeMonsterAttributeAction.new(actionConfig, condition)
    elseif actionConfig.ActionType == "ChangePlayerAttribute" then
        action = ChangePlayerAttributeAction.new(actionConfig, condition)
    elseif actionConfig.ActionType == "CreateMonster" then
        action = CreateMonsterAction.new(actionConfig, condition)
    elseif actionConfig.ActionType == "ShowUI" then
        action = ShowUIAction.new(actionConfig, condition)
    else
        warn("未知的动作类型:", actionConfig.ActionType)
        return nil
    end

    return action
end

function TriggerManager:PickUpItem(player, itemId)
    for _, condition in ipairs(_allConditions) do
        if condition.config.ConditionType == "ItemPickUp" and condition.itemId == itemId then
            condition.isSatisfy = true
            condition:MonitorPlayer(player)
        end
    end
end

function TriggerManager:DropItem(player, itemId)
    for _, condition in ipairs(_allConditions) do
        if condition.config.ConditionType == "ItemDrop" and condition.itemId == itemId then
            condition.isSatisfy = true
            condition:MonitorPlayer(player)
        end
    end
end

game.Players.PlayerAdded:Connect(function(player)
    for _, condition in ipairs(_allConditions) do
        condition:StartMonitoring(player)
    end
end)

game.Players.PlayerRemoving:Connect(function(player)
    for _, condition in ipairs(_allConditions) do
        condition:StopMonitoring(player)
    end
end)

return TriggerManager