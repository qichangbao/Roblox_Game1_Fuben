local AttackState = {}
AttackState.__index = AttackState

-- 攻击状态
function AttackState.new(AIManager, animation)
    local self = setmetatable({}, AttackState)
    self.AIManager = AIManager
    self.animation = animation
    return self
end

function AttackState:ChangeDirection()
    if not self.AIManager.target then
        return
    end

    -- 更新位置和方向（确保怪物正面朝向目标）
    local targetPosition = nil
    local targetHumanoidRootPart = self.AIManager.target:FindFirstChild('HumanoidRootPart')
    local targetHumanoid = self.AIManager.target:FindFirstChild('Humanoid')
    if targetHumanoidRootPart and targetHumanoid and targetHumanoid.Health > 0 then
        targetPosition = targetHumanoidRootPart.CFrame.Position
    end
    if not targetPosition then
        return
    end

    local newPos = self.AIManager.NPC.HumanoidRootPart.Position
    local lookDirection = (targetPosition - newPos).Unit
    self.AIManager.NPC.HumanoidRootPart.CFrame = CFrame.lookAt(newPos, newPos + lookDirection)
end

function AttackState:Enter()
    print("进入Attack状态")

    self.timer = self.AIManager.NPC:GetAttribute("AttackSpeed")
    self.isFirst = true
    -- 更新位置和方向（确保怪物正面朝向目标）
    self:ChangeDirection()
    self.AIManager.NPC.HumanoidRootPart.Anchored = true
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

    print('正在攻击')
    self.isFirst = false
    self.timer = self.AIManager.NPC:GetAttribute("AttackSpeed")

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
    
    -- 更新位置和方向（确保怪物正面朝向目标）
    self:ChangeDirection()
    self.AIManager:PlayAnimation(self.animation, false)
    local damage = self.AIManager.NPC:GetAttribute("Damage")
    local humanoid = target:FindFirstChild("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid:TakeDamage(damage)
    end
end

function AttackState:Exit()
    print("退出Attack状态")
    self.AIManager.target = nil
    self.AIManager.NPC.HumanoidRootPart.Anchored = false
end

return AttackState