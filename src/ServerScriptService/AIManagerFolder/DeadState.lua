local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local MonsterConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("MonsterConfig"))
local PlanConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("PlanConfig"))

local DeadState = {}
DeadState.__index = DeadState

-- 射线检测配置
local RAYCAST_DISTANCE = 100 -- 射线检测距离
local GROUND_OFFSET = 0.1 -- 物品距离地面的高度偏移

-- 使用多层射线检测获取真正的地面位置
-- @param startPosition Vector3 起始位置
-- @param ignoreList table 忽略的实例列表
-- @return Vector3 地面位置，如果没有检测到则返回原位置
local function getGroundPosition(startPosition, ignoreList)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = ignoreList or {}
    
    local currentPosition = startPosition
    local totalHeightDrop = 0
    local maxLayers = 5 -- 最多检测5层
    local minHeightDrop = 3 -- 最小高度差要求
    
    for layer = 1, maxLayers do
        -- 从当前位置向下发射射线
        local rayDirection = Vector3.new(0, -RAYCAST_DISTANCE, 0)
        local raycastResult = Workspace:Raycast(currentPosition, rayDirection, raycastParams)
        
        if raycastResult then
            local hitPosition = raycastResult.Position
            local layerHeightDrop = currentPosition.Y - hitPosition.Y
            totalHeightDrop = totalHeightDrop + layerHeightDrop
            
            -- 检查是否是足够厚的地面
            if layerHeightDrop >= minHeightDrop and totalHeightDrop >= minHeightDrop then
                local groundPosition = hitPosition + Vector3.new(0, GROUND_OFFSET, 0)
                return groundPosition
            elseif layerHeightDrop < 0.5 then
                -- 击中了很薄的结构，继续向下检测
                currentPosition = hitPosition - Vector3.new(0, 0.1, 0) -- 稍微向下偏移继续检测
                
                -- 将击中的物体加入忽略列表，避免重复击中
                if raycastResult.Instance then
                    table.insert(raycastParams.FilterDescendantsInstances, raycastResult.Instance)
                end
            else
                -- 找到了有一定厚度的地面
                if totalHeightDrop >= minHeightDrop then
                    local groundPosition = hitPosition + Vector3.new(0, GROUND_OFFSET, 0)
                    return groundPosition
                else
                    -- 高度差不够，继续检测
                    currentPosition = hitPosition - Vector3.new(0, 0.1, 0)
                end
            end
        else
            -- 没有击中任何物体
            print("第", layer, "层未击中任何物体")
            break
        end
    end
    
    -- 所有检测都失败，返回一个安全的地面位置
    local safeGroundPosition = Vector3.new(startPosition.X, startPosition.Y - 10, startPosition.Z)
    return safeGroundPosition
end

-- 死亡状态
function DeadState.new(AIManager, animation)
    local self = setmetatable({}, DeadState)
    self.AIManager = AIManager
    self.animation = animation
    return self
end

function DeadState:Enter()
    print("进入Dead状态")
    
    -- 播放死亡动画并分析
     self.AIManager:PlayAnimation(self.animation, false)
         
    -- 或者完全禁用HumanoidRootPart的动画影响
    local humanoidRootPart = self.AIManager.NPC:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        -- 锁定HumanoidRootPart的位置
        humanoidRootPart.Anchored = true
    end
    
    -- 触发物品掉落
    local monsterInfo = self.AIManager.monsterInfo
    local config = MonsterConfig:GetByMonsterId(monsterInfo.MonsterId)
    if config then
        -- 获取NPC当前位置
        local npcPosition = self.AIManager.NPC:GetPivot().Position
        
        -- 使用高级射线检测获取最佳地面位置
        local ignoreList = {self.AIManager.NPC} -- 忽略NPC本身
        local groundPosition = getGroundPosition(npcPosition, ignoreList)
        
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
    print("退出Dead状态")
    
    -- 确保HumanoidRootPart解锁
    local humanoidRootPart = self.AIManager.NPC:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        humanoidRootPart.Anchored = false
    end
end

return DeadState