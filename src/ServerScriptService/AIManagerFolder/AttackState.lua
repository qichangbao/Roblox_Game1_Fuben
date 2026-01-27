local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local AttackState = {}
AttackState.__index = AttackState

-- 攻击状态构造函数
-- @param AIManager AIManager AI管理器实例
-- @return AttackState 攻击状态实例
function AttackState.new(AIManager)
    local self = setmetatable({}, AttackState)
    self.AIManager = AIManager
    self.damageTimer = 0 -- 用于计算伤害延时的计时器
    self.shouldCalculateDamage = false -- 标记是否需要计算伤害
    return self
end

function AttackState:Enter()
    self.timer = self.AIManager.NPC:GetAttribute("AttackSpeed")
    self.isFirst = true
    self.damageTimer = 0 -- 重置伤害计时器
    self.shouldCalculateDamage = false -- 重置伤害计算标记
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

function AttackState:CalculateDamage()
    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        print("HumanoidRootPart not found")
        return
    end

    local target = self.AIManager.target
    if not target then
        self.AIManager:SetState("Chase")
        return
    end

    self.AIManager:PlaySound("attack")
    local currentPos = HumanoidRootPart.CFrame.Position
    local attackRange = self.AIManager.NPC:GetAttribute("AttackRange")
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = {self.AIManager.target}
    local parts = workspace:GetPartBoundsInRadius(currentPos, attackRange, params) or {}
    if #parts == 0 then
        self.AIManager:SetState("Chase")
        return
    end

    if not target.HumanoidRootPart or not target.Humanoid or target.Humanoid.Health <= 0 then
        self.AIManager:SetState("Chase")
        return
    end

    -- 检查是否有无敌保护（ForceField）
    if target:FindFirstChild("ForceField") then
        self.AIManager:SetState("Chase")
        return
    end
    
    local attack = self.AIManager.NPC:GetAttribute("Attack")
    local humanoid = target:FindFirstChild("Humanoid")
    if humanoid and humanoid.Health > 0 then
        Interface.decHp(target, attack)
        -- 播放命中特效
        self.AIManager:PlayAnimHitEffect(target)
        if humanoid.Health <= 0 then
            self.AIManager:SetState("Chase")
            return
        end
    end
end

function AttackState:Update(dt)
    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        print("HumanoidRootPart not found")
        return
    end

    local target = self.AIManager.target
    if not target then
        self.AIManager:SetState("Chase")
        return
    end

    -- 处理伤害计算延时
    if self.shouldCalculateDamage then
        self.damageTimer = self.damageTimer + dt
        local damageDelay = self.AIManager.NPC:GetAttribute("AttackSpeed") / 3
        if self.damageTimer >= damageDelay then
            self:CalculateDamage()
            self.shouldCalculateDamage = false
            self.damageTimer = 0
        end
    end

    self.timer = self.timer - dt
    if not self.isFirst and self.timer > 0 then
        return
    end

    self.isFirst = false
    self.timer = self.AIManager.NPC:GetAttribute("AttackSpeed")
    local initAttackSpeed = self.AIManager.NPC:GetAttribute("InitAttackSpeed")
    
    -- 更新位置和方向（确保怪物正面朝向目标）
    self:ChangeDirection()
    self.AIManager:PlayAnimation("attack", false, initAttackSpeed / self.timer, self.timer)

    -- 开始伤害计算延时
    self.shouldCalculateDamage = true
    self.damageTimer = 0
end

-- 退出攻击状态
-- 清理目标引用和重置伤害计算状态
function AttackState:Exit()
    self.AIManager.target = nil
    self.shouldCalculateDamage = false -- 停止伤害计算
    self.damageTimer = 0 -- 重置伤害计时器
end

return AttackState