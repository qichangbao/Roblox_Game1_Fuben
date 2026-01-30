local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local PathfindingMove = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("PathfindingMove"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))

local PatrolState = {}
PatrolState.__index = PatrolState

-- 巡逻状态（使用智能移动，支持台阶爬升）
function PatrolState.new(AIManager)
    local self = setmetatable({}, PatrolState)
    self.AIManager = AIManager
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
    local landId = Knit.GetService("IslandService"):GetIslandId()
    if not landId or landId == 0 then return false end
    local land = workspace:FindFirstChild(landId)
    if not land then return false end

    -- 关键检测：射线检测是否有陆地Part
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Include
    raycastParams.FilterDescendantsInstances = {land}

    local rayOrigin = Vector3.new(position.X, position.Y + 10, position.Z)
    local rayDirection = Vector3.new(0, -40, 0)
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if not raycastResult then return false end
    
    -- 检测目标位置周围是否有物品（检测半径2单位内的物品）
    local itemCheckRadius = 2
    local checkSize = Vector3.new(itemCheckRadius * 2, 4, itemCheckRadius * 2)
    local checkCFrame = CFrame.new(position)
    local partsInRegion = workspace:GetPartBoundsInBox(checkCFrame, checkSize)
    for _, part in ipairs(partsInRegion) do
        -- 检测是否是物品（通过检查父级是否有ItemId属性或特定名称模式）
        local parent = part.Parent
        if not parent then continue end
        local itemId = parent:GetAttribute("ItemId")
        if not itemId then continue end
        local itemInfo = ItemConfig:GetByItemId(itemId)
        if not itemInfo then continue end
        if itemInfo.ItemType == GameConfig.ItemType.Chest then return false end
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
    for _ = 1, maxAttempts do
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
    self.AIManager:PlayAnimation("walk", true)
    self.AIManager:PlaySound("walk", true)
end

-- 每帧更新
function PatrolState:Update(dt)
    local target = self.AIManager:FindVisionRangeTarget()
    if target then
        self.AIManager:SetState("Chase")
        return
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