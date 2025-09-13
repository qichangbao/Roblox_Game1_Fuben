local Players = game:GetService("Players")

local ChaseState = {}
ChaseState.__index = ChaseState

-- 追赶状态
function ChaseState.new(AIManager, animation)
    local self = setmetatable({}, ChaseState)
    self.AIManager = AIManager
    self.animation = animation
    return self
end

function ChaseState:Enter()
    print("进入Chase状态")
    self.AIManager:PlayAnimation(self.animation, true)

    self:FindNearestModel()
end

function ChaseState:Update(dt)
    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        return
    end

    local target = self.AIManager.target
    if not target then
        self.AIManager:SetState("Idle")
        return
    end
    
    local targetPosition = nil
    local targetHumanoidRootPart = target:FindFirstChild('HumanoidRootPart')
    local targetHumanoid = target:FindFirstChild('Humanoid')
    if targetHumanoidRootPart and targetHumanoid and targetHumanoid.Health > 0 then
        targetPosition = targetHumanoidRootPart.CFrame.Position
    end

    if not targetPosition then
        self.AIManager.target = nil
        self.AIManager:SetState("Idle")
        return
    end
    -- 计算移动方向
    local currentPos = HumanoidRootPart.CFrame.Position
    local direction = (targetPosition - currentPos).Unit
    local speed = self.AIManager.NPC:GetAttribute("WalkSpeed") * dt
    local newPos = currentPos + direction * speed
    
    -- 使用射线检测前方地面，支持小台阶自动攀爬
    local rayOrigin = Vector3.new(newPos.X, currentPos.Y + 3, newPos.Z) -- 从目标位置上方5个单位处发射射线
    local rayDirection = Vector3.new(0, -8, 0) -- 向下发射10个单位长的射线
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {self.AIManager.NPC} -- 忽略怪物自身
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

    local finalPos = newPos
    local rootPartHeight = HumanoidRootPart.Size.Y
    local maxStepHeight = 3 -- 最大可攀爬台阶高度（单位）
    
    if raycastResult then
        local groundY = raycastResult.Position.Y + rootPartHeight / 2
        local currentY = currentPos.Y
        local heightDifference = groundY - currentY
        
        -- 如果高度差在可接受范围内，允许攀爬
        if math.abs(heightDifference) <= maxStepHeight then
            finalPos = Vector3.new(newPos.X, groundY, newPos.Z)
        else
            -- 如果台阶太高，保持当前高度继续移动
            finalPos = Vector3.new(newPos.X, currentY, newPos.Z)
        end
    else
        -- 如果没有检测到地面，保持当前高度
        finalPos = Vector3.new(newPos.X, currentPos.Y, newPos.Z)
        print("1111111111111")
    end
    
    if finalPos.Y > -1 then
        local ll = 0
    end
    print(finalPos)
    -- 更新位置和方向（确保怪物正面朝向目标）
    local lookDirection = (targetPosition - finalPos).Unit
    HumanoidRootPart.CFrame = CFrame.lookAt(finalPos, finalPos + Vector3.new(lookDirection.X, 0, lookDirection.Z))

    self:CheckDistance()
end

function ChaseState:FindNearestModel()
    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        return
    end
    local npcPos = HumanoidRootPart.CFrame.Position
    local visionRange = self.AIManager.NPC:GetAttribute("VisionRange")
    local minDistance = math.huge

    for _, v in ipairs(Players:GetPlayers()) do
        local character = v.character
        if character and character.HumanoidRootPart and character.Humanoid and character.Humanoid.Health > 0 then
            local dis = (character.HumanoidRootPart.Position - npcPos).Magnitude
            if dis <= visionRange then
                if not minDistance or dis < minDistance then
                    self.AIManager.target = character
                    minDistance = dis
                end
            end
        end
    end
end

function ChaseState:CheckDistance()
    local currentPos = self.AIManager.NPC.HumanoidRootPart.CFrame.Position
    local distanceToPlayer = 0
    local target = self.AIManager.target
    local targetHumanoidRootPart = target:FindFirstChild('HumanoidRootPart')
    local targetHumanoid = target:FindFirstChild('Humanoid')
    if targetHumanoidRootPart and targetHumanoid and targetHumanoid.Health > 0 then
        distanceToPlayer = (targetHumanoidRootPart.CFrame.Position - currentPos).Magnitude
    else
        self.AIManager.target = nil
        self.AIManager:SetState("Idle")
        return
    end
    
    local attackRange = self.AIManager.NPC:GetAttribute("AttackRange")
    local visionRange = self.AIManager.NPC:GetAttribute("VisionRange")
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = {target}
    local parts = workspace:GetPartBoundsInRadius(currentPos, attackRange, params) or {}
    if #parts > 0 then
        self.AIManager:SetState("Attack")
        return
    elseif distanceToPlayer > visionRange then
        self.AIManager.target = nil
        self.AIManager:SetState("Idle")
        return
    end
end

function ChaseState:Exit()
    print("退出ChaseState状态")
end

return ChaseState
