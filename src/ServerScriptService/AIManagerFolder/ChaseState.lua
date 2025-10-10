local Players = game:GetService("Players")
local PathfindingMove = require(script.Parent:WaitForChild("PathfindingMoveModule"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local ChaseState = {}
ChaseState.__index = ChaseState

-- 追赶状态
function ChaseState.new(AIManager, animation)
    local self = setmetatable({}, ChaseState)
    self.AIManager = AIManager
    self.animation = animation
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
	end)

	-- 开始行走
	humanoid:MoveTo(targetPoint, targetPart)
end

function ChaseState:Enter()
    self:FindNearestModel()

    local Humanoid = self.AIManager.NPC:FindFirstChild('Humanoid')
    if not Humanoid then
        self.AIManager:SetState("Idle")
        return
    end

    if self.AIManager.target and self.AIManager.target.HumanoidRootPart then
        -- 目标在水里，则放弃追踪
        if Interface.isPointInTerrainWater(self.AIManager.target.HumanoidRootPart.Position) then
            self.AIManager.target = nil
            self.AIManager:SetState("Idle")
            return
        end

        local targetPos = self.AIManager.target.HumanoidRootPart.Position
        -- self.connection = PathfindingMove.MoveTo(self.AIManager.NPC, targetPos, function(reached)
        --     -- self.AIManager:SetState("Idle")
        --     -- return
        -- end)
        self:moveTo(Humanoid, targetPos, self.AIManager.target.HumanoidRootPart)
        self.AIManager:PlayAnimation(self.animation, true)

        if self.AIManager.monsterInfo.MonsterId == 30001 then
            local ui = game:GetService("SoundService"):WaitForChild("GAME")
            local sound = ui:WaitForChild("Langhuxi")
            sound:Play()
        end
        return
    else
        self.AIManager:SetState("Idle")
        return
    end
end

function ChaseState:Update(dt)
    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        self.AIManager:SetState("Idle")
        return
    end

    local Humanoid = self.AIManager.NPC:FindFirstChild('Humanoid')
    if not Humanoid then
        self.AIManager:SetState("Idle")
        return
    end

    local target = self.AIManager.target
    if not target then
        self.AIManager:SetState("Idle")
        return
    end
    
    local targetPosition = nil
    local targetHumanoidRootPart = target:FindFirstChild('HumanoidRootPart')
    if not targetHumanoidRootPart then
        self.AIManager.target = nil
        self.AIManager:SetState("Idle")
        return
    end

    local targetHumanoid = target:FindFirstChild('Humanoid')
    if not targetHumanoid then
        self.AIManager.target = nil
        self.AIManager:SetState("Idle")
        return
    end

    if targetHumanoid.Health <= 0 then
        self.AIManager.target = nil
        self.AIManager:SetState("Idle")
        return
    end

    -- 目标在水里，则放弃追踪
    if Interface.isPointInTerrainWater(targetHumanoidRootPart.Position) then
        self.AIManager.target = nil
        self.AIManager:SetState("Idle")
        return
    end

    targetPosition = targetHumanoidRootPart.CFrame.Position
    if not targetPosition then
        self.AIManager.target = nil
        self.AIManager:SetState("Idle")
        return
    end

    self:CheckDistance()
end

function ChaseState:FindNearestModel()
    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        return
    end
    local npcPos = HumanoidRootPart.CFrame.Position
    local visionRange = self.AIManager.monsterInfo.VisionRange
    local minDistance = math.huge

    for _, v in ipairs(Players:GetPlayers()) do
        local character = v.character
        if character
        and character.HumanoidRootPart
        and character.Humanoid
        and character.Humanoid.Health > 0 then
            if not Interface.isPointInTerrainWater(character.HumanoidRootPart.Position) then
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
end

function ChaseState:CheckDistance()
    local currentPos = self.AIManager.NPC.HumanoidRootPart.CFrame.Position
    local distanceToPlayer = 0
    local target = self.AIManager.target
    local targetHumanoidRootPart = target:FindFirstChild('HumanoidRootPart')
    local targetHumanoid = target:FindFirstChild('Humanoid')
    if targetHumanoidRootPart and targetHumanoid and targetHumanoid.Health > 0 then
        if not Interface.isPointInTerrainWater(targetHumanoidRootPart.Position) then
            distanceToPlayer = (targetHumanoidRootPart.CFrame.Position - currentPos).Magnitude
        end
    else
        self.AIManager.target = nil
        self.AIManager:SetState("Idle")
        return
    end
    
    local attackRange = self.AIManager.monsterInfo.AttackRange
    local visionRange = self.AIManager.monsterInfo.VisionRange
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
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end
end

return ChaseState
