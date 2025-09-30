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
	local targetReached = false

    -- 如果连接仍然连接，则断开连接
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end

	-- 监听 humanoid 达到目标
	self.connection = humanoid.MoveToFinished:Connect(function(reached)
		targetReached = true
		self.connection:Disconnect()
		self.connection = nil
	    print((reached and "目标已到达！") or "未能到达目标！")
	end)

	-- 开始行走
	humanoid:MoveTo(targetPoint, targetPart)

	-- 在新线程中执行，以免使函数阻塞
	task.spawn(function()
		while not targetReached do
			-- humanoid 仍然存在吗？
			if not (humanoid and humanoid.Parent) then
				break
			end
			-- 目标是否发生了变化？
			if humanoid.WalkToPoint ~= targetPoint then
				break
			end
			-- 刷新超时
			humanoid:MoveTo(targetPoint)
			task.wait(6)
		end

		-- 如果连接仍然连接，则断开连接
		if self.connection then
			self.connection:Disconnect()
			self.connection = nil
		end
	end)
end

function ChaseState:Enter()
    self:FindNearestModel()

    local Humanoid = self.AIManager.NPC:FindFirstChild('Humanoid')
    if not Humanoid then
        self.AIManager:SetState("Idle")
        return
    end

    if self.AIManager.target and self.AIManager.target.HumanoidRootPart then
        local targetPos = self.AIManager.target.HumanoidRootPart.Position
        -- self.connection = PathfindingMove.MoveTo(self.AIManager.NPC, targetPos, function(reached)
        --     -- self.AIManager:SetState("Idle")
        --     -- return
        -- end)
        self:moveTo(Humanoid, targetPos, self.AIManager.target.HumanoidRootPart)
    end
    self.AIManager:PlayAnimation(self.animation, true)
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
    local Humanoid = self.AIManager.NPC:FindFirstChild('Humanoid')
    if Humanoid and Humanoid.RootPart then
        Humanoid.WalkToPoint = Humanoid.RootPart.Position
        Humanoid.WalkToPart = nil
    end
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end
end

return ChaseState
