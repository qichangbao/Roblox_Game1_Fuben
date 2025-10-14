local AttackState = {}
AttackState.__index = AttackState

-- 攻击状态
function AttackState.new(AIManager)
    local self = setmetatable({}, AttackState)
    self.AIManager = AIManager
    return self
end

function AttackState:Enter()
    self.timer = self.AIManager.NPC:GetAttribute("AttackSpeed")
    self.isFirst = true
    -- 更新位置和方向（确保怪物正面朝向目标）
    self:ChangeDirection()
end

function AttackState:ChangeDirection()
    if not self.AIManager.target then
        return
    end

    -- 更新方向（确保怪物正面朝向目标，但只在Y轴上转向）
    local targetPosition = nil
    local targetHumanoidRootPart = self.AIManager.target:FindFirstChild('HumanoidRootPart')
    local targetHumanoid = self.AIManager.target:FindFirstChild('Humanoid')
    if targetHumanoidRootPart and targetHumanoid and targetHumanoid.Health > 0 then
        targetPosition = targetHumanoidRootPart.CFrame.Position
    end
    if not targetPosition then
        return
    end

    local currentPos = self.AIManager.NPC.HumanoidRootPart.Position
    
    -- 只计算水平方向的向量（忽略Y轴差异）
    local horizontalDirection = Vector3.new(
        targetPosition.X - currentPos.X,
        0,  -- 保持Y轴为0，不上下倾斜
        targetPosition.Z - currentPos.Z
    ).Unit
    
    -- 使用当前的Y位置，只改变朝向
    local newCFrame = CFrame.lookAt(currentPos, currentPos + horizontalDirection)
    self.AIManager.NPC.HumanoidRootPart.CFrame = newCFrame
end

function AttackState:Update(dt)
    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        print("HumanoidRootPart not found")
        return
    end

    local target = self.AIManager.target
    if not target then
        self.AIManager:SetState("Idle")
        return
    end

    self.timer = self.timer - dt
    if not self.isFirst and self.timer > 0 then
        return
    end

    self.isFirst = false
    self.timer = self.AIManager.NPC:GetAttribute("AttackSpeed")
    
    -- 更新位置和方向（确保怪物正面朝向目标）
    self:ChangeDirection()
    self.AIManager:PlayAnimation("attack", false, Enum.AnimationPriority.Action)

    task.wait(1)

    self.AIManager:PlaySound("attack")

    local currentPos = HumanoidRootPart.CFrame.Position
    local attackRange = self.AIManager.NPC:GetAttribute("AttackRange")
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = {self.AIManager.target}
    local parts = workspace:GetPartBoundsInRadius(currentPos, attackRange, params) or {}
    if #parts == 0 then
        self.AIManager:SetState("Idle")
        return
    end

    if not target.HumanoidRootPart or not target.Humanoid or target.Humanoid.Health <= 0 then
        self.AIManager:SetState("Idle")
        return
    end
    
    local attack = self.AIManager.NPC:GetAttribute("Attack")
    local humanoid = target:FindFirstChild("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid:TakeDamage(attack)
    end
end

function AttackState:Exit()
    self.AIManager.target = nil
end

return AttackState