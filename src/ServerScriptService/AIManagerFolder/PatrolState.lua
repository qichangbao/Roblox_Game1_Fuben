local Players = game:GetService("Players")
local PathfindingMove = require(script.Parent:WaitForChild("PathfindingMoveModule"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local PatrolState = {}
PatrolState.__index = PatrolState

-- 巡逻状态（使用智能移动，支持台阶爬升）
function PatrolState.new(AIManager, animation)
    local self = setmetatable({}, PatrolState)
    self.AIManager = AIManager
    self.animation = animation
    self.connection = nil
    self.patrolRadius = self.AIManager.monsterInfo.PatrolRadius
    self.maxDisForSpawn = self.AIManager.monsterInfo.MaxDisForSpawn
    self.spawnPosition = self.AIManager.NPC:GetAttribute("SpawnPosition")

    return self
end

--[[
    检测目标位置是否有物品或水
    @param position Vector3 要检测的位置
    @return boolean 如果位置安全返回true，否则返回false
]]
function PatrolState:isPositionSafe(position)
    -- 关键检测：射线检测是否有陆地Part
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {self.AIManager.NPC}
    
    local checkPoints = {
        position, -- 中心点
        position + Vector3.new(1, 0, 0), -- 右
        position + Vector3.new(-1, 0, 0), -- 左
        position + Vector3.new(0, 0, 1), -- 前
        position + Vector3.new(0, 0, -1), -- 后
    }
    
    for i, checkPos in ipairs(checkPoints) do
        local rayOrigin = Vector3.new(checkPos.X, checkPos.Y + 10, checkPos.Z)
        local rayDirection = Vector3.new(0, -40, 0)
        local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
        if not raycastResult then
            -- 没有击中任何Part，说明这里只有水，不安全
            return false
        end
    end
    
    -- 检测目标位置周围是否有物品（检测半径2单位内的物品）
    local itemCheckRadius = 2
    local checkSize = Vector3.new(itemCheckRadius * 2, 4, itemCheckRadius * 2)
    local checkCFrame = CFrame.new(position + Vector3.new(0, 1, 0))
    
    -- 使用GetPartBoundsInBox替代已弃用的GetPartBoundsInRegion
    local partsInRegion = workspace:GetPartBoundsInBox(checkCFrame, checkSize)
    
    for _, part in ipairs(partsInRegion) do
        -- 检测是否是物品（通过检查父级是否有ItemId属性或特定名称模式）
        local parent = part.Parent
        if parent and (parent:GetAttribute("ItemId") or parent.Name:find("Item") or parent.Name:find("物品")) then
            return false
        end
        
        -- 检测是否是工具
        if parent and parent:IsA("Tool") then
            return false
        end
        
        -- 检测是否是掉落的物品模型
        if parent and parent:IsA("Model") and parent:FindFirstChild("Handle") then
            return false
        end
    end
    
    return true
end

--[[
    生成安全的目标位置
    @param npcPosition Vector3 NPC当前位置
    @param patrolRadius number 巡逻半径
    @param maxAttempts number 最大尝试次数
    @return Vector3|nil 安全的目标位置，如果找不到返回nil
]]
function PatrolState:generateSafeTargetPosition(npcPosition, patrolRadius, maxAttempts)
    for attempt = 1, maxAttempts do
        local targetPosition = Vector3.new(
            npcPosition.X + 5 + math.random(-patrolRadius, patrolRadius),
            npcPosition.Y,
            npcPosition.Z + 5 + math.random(-patrolRadius, patrolRadius)
        )
        
        if self:isPositionSafe(targetPosition) then
            return targetPosition
        end
    end
    
    return nil
end

-- 进入巡逻状态
function PatrolState:Enter()
    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        self.AIManager:SetState("Idle")
        return
    end

    local npcPosition = self.AIManager.NPC.HumanoidRootPart.Position
    -- 首先检测怪物是否超出了最大距离
    if (npcPosition - self.spawnPosition).Magnitude > self.maxDisForSpawn then
        self.targetPosition = self.spawnPosition
    else
        -- 尝试生成安全的目标位置，最多尝试3次
        local safePosition = self:generateSafeTargetPosition(npcPosition, self.patrolRadius, 3)
        if safePosition then
            self.targetPosition = safePosition
        else
            -- 如果3次都找不到安全位置，切换为Idle状态
            self.AIManager:SetState("Idle")
            return
        end
    end

    self.connection = PathfindingMove.MoveTo(self.AIManager.NPC, self.targetPosition, function(reached)
        self.AIManager:SetState("Idle")
        return
    end)
    self.AIManager:PlayAnimation(self.animation, true)
end

-- 每帧更新
function PatrolState:Update(dt)
    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        print("HumanoidRootPart not found")
        return
    end

    local npcPos = HumanoidRootPart.CFrame.Position
    -- 如果有玩家进入视野范围，切换到追逐状态
    local visionRange = self.AIManager.monsterInfo.VisionRange
    for _, v in ipairs(Players:GetPlayers()) do
        local character = v.character
        if character then
            local targetHumanoidRootPart = character:FindFirstChild('HumanoidRootPart')
            local targetHumanoid = character:FindFirstChild('Humanoid')
            if targetHumanoidRootPart and targetHumanoid and targetHumanoid.Health > 0 then
                if not Interface.isPointInTerrainWater(targetHumanoidRootPart.Position) then
                    local dis = (targetHumanoidRootPart.CFrame.Position - npcPos).Magnitude
                    if dis <= visionRange then
                        self.AIManager:SetState("Chase")
                        return
                    end
                end
            end
        end
    end
end

-- 退出巡逻状态
function PatrolState:Exit()
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end
end

return PatrolState