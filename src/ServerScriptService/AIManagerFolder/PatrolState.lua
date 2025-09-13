local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")

local PatrolState = {}
PatrolState.__index = PatrolState

-- 巡逻状态（无Humanoid寻路版本）
function PatrolState.new(AIManager, animation)
    local self = setmetatable({}, PatrolState)
    self.AIManager = AIManager
    self.animation = animation
    self.Path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        WaypointSpacing = 4,
        Costs = {
            Water = 20
        }
    })
    self.waypoints = {}
    self.currentWaypointIndex = 1
    self.isMoving = false
    self.moveTween = nil
    self.isFound = false
    return self
end

-- 进入巡逻状态
function PatrolState:Enter()
    print("进入Patrol状态（无Humanoid寻路）")
    self.AIManager:PlayAnimation(self.animation, true)
    
    -- 重置状态
    self.waypoints = {}
    self.currentWaypointIndex = 1
    self.isMoving = false
    
    -- 停止之前的移动动画
    if self.moveTween then
        self.moveTween:Cancel()
        self.moveTween = nil
    end
    
    -- 计算目标位置
    local npcPos = self.AIManager.NPC.HumanoidRootPart.CFrame.Position
    local maxDisForSpawn = self.AIManager.NPC:GetAttribute("MaxDisForSpawn")
    local patrolRadius = self.AIManager.NPC:GetAttribute("PatrolRadius")
    local spawnPosition = self.AIManager.NPC:GetAttribute("SpawnPosition")
    
    local targetPos
    if (spawnPosition - npcPos).Magnitude > maxDisForSpawn then
        targetPos = spawnPosition
    else
        targetPos = npcPos + Vector3.new(
            math.random(-patrolRadius, patrolRadius),
            0,
            math.random(-patrolRadius, patrolRadius)
        )
    end
    
    -- 地面检测，确保目标点在地面上
    targetPos = self:GetGroundPosition(targetPos)
    
    -- 计算寻路路径
    self:CalculatePath(npcPos, targetPos)
end

-- 更新巡逻状态
function PatrolState:Update(dt)
    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        return
    end

    if self.isFound then
        return
    end
    
    -- 如果没有路径点或已完成所有路径点，切换到Idle状态
    if #self.waypoints == 0 or self.currentWaypointIndex > #self.waypoints then
        self.AIManager:SetState("Idle")
        return
    end
    
    -- 如果当前没有在移动，开始移动到下一个路径点
    if not self.isMoving then
        self:MoveToNextWaypoint()
    end
end

-- 退出巡逻状态
function PatrolState:Exit()
    print("退出Patrol状态")
    
    -- 停止移动动画
    if self.moveTween then
        self.moveTween:Cancel()
        self.moveTween = nil
    end
    
    -- 重置状态
    self.isMoving = false
    self.waypoints = {}
    self.currentWaypointIndex = 1
end

-- 获取地面位置（射线检测）
function PatrolState:GetGroundPosition(targetPos)
    local rayOrigin = targetPos + Vector3.new(0, 50, 0)
    local rayDirection = Vector3.new(0, -100, 0)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {self.AIManager.NPC}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if raycastResult then
        return Vector3.new(targetPos.X, raycastResult.Position.Y, targetPos.Z)
    else
        return targetPos
    end
end

-- 计算寻路路径
function PatrolState:CalculatePath(startPos, endPos)
    self.isFound = true
    local success, errorMessage = pcall(function()
        self.Path:ComputeAsync(startPos, endPos)
    end)
    
    if success and self.Path.Status == Enum.PathStatus.Success then
        self.waypoints = self.Path:GetWaypoints()
        self.currentWaypointIndex = 1
        print("路径计算成功，共", #self.waypoints, "个路径点")
    else
        warn("路径计算失败:", errorMessage or "未知错误")
        -- 如果寻路失败，直接移动到目标位置
        self.waypoints = {
            {Position = endPos, Action = Enum.PathWaypointAction.Walk}
        }
        self.currentWaypointIndex = 1
    end
    self.isFound = false
end

-- 移动到下一个路径点
function PatrolState:MoveToNextWaypoint()
    if self.currentWaypointIndex > #self.waypoints then
        return
    end
    
    local HumanoidRootPart = self.AIManager.NPC.HumanoidRootPart
    local currentPos = HumanoidRootPart.CFrame.Position
    local waypoint = self.waypoints[self.currentWaypointIndex]
    local targetPos = waypoint.Position
    
    -- 检查是否已经接近当前路径点
    if (currentPos - targetPos).Magnitude < 3 then
        self.currentWaypointIndex = self.currentWaypointIndex + 1
        return
    end
    
    -- 计算移动时间（基于距离和速度）
    local distance = (targetPos - currentPos).Magnitude
    local speed = self.AIManager.NPC:GetAttribute("WalkSpeed")
    local moveTime = distance / speed
    
    -- 处理跳跃路径点
    if waypoint.Action == Enum.PathWaypointAction.Jump then
        self:HandleJumpWaypoint(currentPos, targetPos, moveTime)
    else
        self:HandleWalkWaypoint(currentPos, targetPos, moveTime)
    end
end

-- 处理行走路径点
function PatrolState:HandleWalkWaypoint(currentPos, targetPos, moveTime)
    local HumanoidRootPart = self.AIManager.NPC.HumanoidRootPart
    
    -- 确保目标位置在地面上
    targetPos = self:GetGroundPosition(targetPos)
    
    -- 计算朝向
    local lookDirection = (targetPos - currentPos).Unit
    local targetCFrame = CFrame.lookAt(targetPos, targetPos + lookDirection)
    
    -- 创建移动动画
    self.isMoving = true
    local tweenInfo = TweenInfo.new(
        moveTime,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.InOut,
        0,
        false,
        0
    )
    
    self.moveTween = TweenService:Create(HumanoidRootPart, tweenInfo, {CFrame = targetCFrame})
    
    self.moveTween.Completed:Connect(function()
        self.isMoving = false
        self.currentWaypointIndex = self.currentWaypointIndex + 1
        self.moveTween = nil
    end)
    
    self.moveTween:Play()
end

-- 处理跳跃路径点
function PatrolState:HandleJumpWaypoint(currentPos, targetPos, moveTime)
    local HumanoidRootPart = self.AIManager.NPC.HumanoidRootPart
    
    -- 跳跃轨迹：抛物线运动
    local jumpHeight = 10 -- 跳跃高度
    local midPoint = currentPos:Lerp(targetPos, 0.5) + Vector3.new(0, jumpHeight, 0)
    
    -- 分两段进行跳跃：上升和下降
    self.isMoving = true
    
    -- 第一段：跳到最高点
    local lookDirection1 = (midPoint - currentPos).Unit
    local midCFrame = CFrame.lookAt(midPoint, midPoint + lookDirection1)
    
    local tweenInfo1 = TweenInfo.new(
        moveTime / 2,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out,
        0,
        false,
        0
    )
    
    self.moveTween = TweenService:Create(HumanoidRootPart, tweenInfo1, {CFrame = midCFrame})
    
    self.moveTween.Completed:Connect(function()
        -- 第二段：从最高点落到目标位置
        targetPos = self:GetGroundPosition(targetPos)
        local lookDirection2 = (targetPos - midPoint).Unit
        local targetCFrame = CFrame.lookAt(targetPos, targetPos + lookDirection2)
        
        local tweenInfo2 = TweenInfo.new(
            moveTime / 2,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.In,
            0,
            false,
            0
        )
        
        self.moveTween = TweenService:Create(HumanoidRootPart, tweenInfo2, {CFrame = targetCFrame})
        
        self.moveTween.Completed:Connect(function()
            self.isMoving = false
            self.currentWaypointIndex = self.currentWaypointIndex + 1
            self.moveTween = nil
        end)
        
        self.moveTween:Play()
    end)
    
    self.moveTween:Play()
end

return PatrolState