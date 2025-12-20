local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local MonsterConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("MonsterConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local DeadState = {}
DeadState.__index = DeadState

-- 死亡状态
function DeadState.new(AIManager)
    local self = setmetatable({}, DeadState)
    self.AIManager = AIManager
    return self
end

function DeadState:Enter()
    -- 播放死亡动画并分析
     self.AIManager:PlayAnimation("dead", false)
     self.AIManager:PlaySound("dead")

    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild("HumanoidRootPart")
    if HumanoidRootPart then
        HumanoidRootPart.Anchored = true
    end

    -- 取消所有追逐
    Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)
    
    -- 触发物品掉落
    local config = MonsterConfig:GetByMonsterId(self.AIManager.monsterInfo.MonsterId)
    if config then
        -- 获取NPC当前位置
        local npcPosition = self.AIManager.NPC:GetPivot().Position
        
        -- 使用高级射线检测获取最佳地面位置
        local ignoreList = {self.AIManager.NPC} -- 忽略NPC本身
        local groundPosition = Interface.getGroundPosition(npcPosition, ignoreList)
        
        -- 在地面位置创建物品
        local itemArray = Interface.GetDropItems(config.DropPlanId)
        if itemArray then
            for _, itemId in ipairs(itemArray) do
                Knit.GetService("ItemService"):CreateItem(itemId, groundPosition, 0, GameConfig.GetItemAttribute(), true)
            end
        end
    end

    task.delay(5, function()
        task.spawn(function()
            if self.AIManager then
                self.AIManager:Destroy()
                self.AIManager = nil
            end
        end)
    end)
end

function DeadState:Update(dt)
end

function DeadState:Exit()
end

return DeadState