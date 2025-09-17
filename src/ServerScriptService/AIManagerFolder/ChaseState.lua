local Players = game:GetService("Players")
local PathfindingMove = require(script.Parent:WaitForChild("PathfindingMoveModule"))

local ChaseState = {}
ChaseState.__index = ChaseState

-- 追赶状态
function ChaseState.new(AIManager, animation)
    local self = setmetatable({}, ChaseState)
    self.AIManager = AIManager
    self.animation = animation
    self.connection = nil
    self.timer = 0
    return self
end

function ChaseState:Enter()
    print("进入Chase状态")
    --self.AIManager:PlayAnimation(self.animation, true)

    self:FindNearestModel()

    if self.AIManager.target and self.AIManager.target.HumanoidRootPart then
        local targetPos = self.AIManager.target.HumanoidRootPart.Position
        self.connection = PathfindingMove.MoveTo(self.AIManager.NPC, targetPos, function(reached)
            -- self.AIManager:SetState("Idle")
            -- return
        end)
    end
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

    self:CheckDistance()
    self.timer = self.timer + dt
    if self.timer >= 1 then
        self.timer = 0
        self:FindNearestModel()

        if self.connection then
            self.connection:Disconnect()
            self.connection = nil
        end
        if self.AIManager.target and self.AIManager.target.HumanoidRootPart then
            local targetPos = self.AIManager.target.HumanoidRootPart.Position
            self.connection = PathfindingMove.MoveTo(self.AIManager.NPC, targetPos, function(reached)
                -- self.AIManager:SetState("Idle")
                -- return
            end)
        end
    end
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
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end
end

return ChaseState
