local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local ChaseState = {}
ChaseState.__index = ChaseState

-- 追赶状态
function ChaseState.new(AIManager)
    local self = setmetatable({}, ChaseState)
    self.AIManager = AIManager
    self.connection = nil
    return self
end

function ChaseState:moveTo(humanoid, targetPoint, targetPart)
    -- 如果连接仍然连接，则断开连接
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end

	-- 监听 humanoid 达到目标
	self.connection = humanoid.MoveToFinished:Connect(function(reached)
		self.connection:Disconnect()
		self.connection = nil

	    print((reached and "目标已到达！") or "未能到达目标！")
        if not reached then
            local Humanoid = self.AIManager.NPC:FindFirstChild('Humanoid')
            if not Humanoid then
                self.AIManager:SetState("Idle")
                return
            end
            
            if self.AIManager.target and self.AIManager.target.HumanoidRootPart then
                local targetPos = self.AIManager.target.HumanoidRootPart.Position
                self:moveTo(Humanoid, targetPos, self.AIManager.target.HumanoidRootPart)
                return
            end

            self.AIManager:SetState("Idle")
            return
        end
	end)

	-- 开始行走
	humanoid:MoveTo(targetPoint, targetPart)
end

function ChaseState:Enter()
    self.AIManager.target = self.AIManager:FindVisionRangeNearestTarget()

    local Humanoid = self.AIManager.NPC:FindFirstChild('Humanoid')
    if not Humanoid then
        self.AIManager:SetState("Idle")
        Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)
        return
    end

    if self.AIManager.target and self.AIManager.target.HumanoidRootPart then
        -- 目标在水里，则放弃追踪
        if Interface.IsPlayerInWater(self.AIManager.target) then
            self.AIManager.target = nil
            self.AIManager:SetState("Idle")
            Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)
            return
        end

        local targetPos = self.AIManager.target.HumanoidRootPart.Position
        self:moveTo(Humanoid, targetPos, self.AIManager.target.HumanoidRootPart)
        self.AIManager:PlayAnimation("walk", true)
        self.AIManager:PlaySound("walk", true)
        Knit.GetService("MonsterService"):Chase(self.AIManager.target, self.AIManager.NPC)
        return
    else
        self.AIManager:SetState("Idle")
        Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)
        return
    end
end

function ChaseState:Update(dt)
    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        self.AIManager:SetState("Idle")
        Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)
        return
    end

    local Humanoid = self.AIManager.NPC:FindFirstChild('Humanoid')
    if not Humanoid then
        self.AIManager:SetState("Idle")
        Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)
        return
    end

    local target = self.AIManager.target
    if not target then
        self.AIManager:SetState("Idle")
        Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)
        return
    end
    
    local targetPosition = nil
    local targetHumanoidRootPart = target:FindFirstChild('HumanoidRootPart')
    if not targetHumanoidRootPart then
        self.AIManager.target = nil
        self.AIManager:SetState("Idle")
        Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)
        return
    end

    local targetHumanoid = target:FindFirstChild('Humanoid')
    if not targetHumanoid then
        self.AIManager.target = nil
        self.AIManager:SetState("Idle")
        Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)
        return
    end

    if targetHumanoid.Health <= 0 then
        self.AIManager.target = nil
        self.AIManager:SetState("Idle")
        Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)
        return
    end

    targetPosition = targetHumanoidRootPart.CFrame.Position
    if not targetPosition then
        self.AIManager.target = nil
        self.AIManager:SetState("Idle")
        Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)
        return
    end

    self:CheckDistance()
end

function ChaseState:CheckDistance()
    local currentPos = self.AIManager.NPC.HumanoidRootPart.CFrame.Position
    local distanceToPlayer = 0
    local target = self.AIManager.target
    local targetHumanoidRootPart = target:FindFirstChild('HumanoidRootPart')
    local targetHumanoid = target:FindFirstChild('Humanoid')
    if targetHumanoidRootPart and targetHumanoid and targetHumanoid.Health > 0 then
        if Interface.IsPlayerInWater(target) then
            self.AIManager.target = nil
            self.AIManager:SetState("Idle")
            Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)
            return
        end
        distanceToPlayer = (targetHumanoidRootPart.CFrame.Position - currentPos).Magnitude
    else
        self.AIManager.target = nil
        self.AIManager:SetState("Idle")
        Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)
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
        Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)
        return
    end
end

function ChaseState:Exit()
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end

    local Humanoid = self.AIManager.NPC:FindFirstChild('Humanoid')
    if Humanoid and Humanoid.RootPart then
        Humanoid.WalkToPoint = Humanoid.RootPart.Position
        Humanoid.WalkToPart = nil
    end
end

return ChaseState
