local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local MonsterConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("MonsterConfig"))
local PlanConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("PlanConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local DeadState = {}
DeadState.__index = DeadState

-- 死亡状态
function DeadState.new(AIManager, animation)
    local self = setmetatable({}, DeadState)
    self.AIManager = AIManager
    self.animation = animation
    return self
end

function DeadState:Enter()
    -- 播放死亡动画并分析
     self.AIManager:PlayAnimation(self.animation, false)
    
    -- 触发物品掉落
    local monsterInfo = self.AIManager.monsterInfo
    local config = MonsterConfig:GetByMonsterId(monsterInfo.MonsterId)
    if config then
        -- 获取NPC当前位置
        local npcPosition = self.AIManager.NPC:GetPivot().Position
        
        -- 使用高级射线检测获取最佳地面位置
        local ignoreList = {self.AIManager.NPC} -- 忽略NPC本身
        local groundPosition = Interface.getGroundPosition(npcPosition, ignoreList)
        
    -- 在地面位置创建物品
        local planData = PlanConfig:GetByPlanId(config.DropPlanId)
        if planData then
            Knit.GetService("ItemService"):CreateItemByPlan(planData, groundPosition)
            print("在位置创建物品:", groundPosition)
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
    -- 确保HumanoidRootPart解锁
    local humanoidRootPart = self.AIManager.NPC:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        humanoidRootPart.Anchored = false
    end
end

return DeadState