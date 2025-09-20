local Players = game:GetService("Players")
local PathfindingMove = require(script.Parent:WaitForChild("PathfindingMoveModule"))

local PatrolState = {}
PatrolState.__index = PatrolState

-- 巡逻状态（使用智能移动，支持台阶爬升）
function PatrolState.new(AIManager, animation)
    local self = setmetatable({}, PatrolState)
    self.AIManager = AIManager
    self.animation = animation
    self.connection = nil
    self.patrolRadius = self.AIManager.monsterInfo.PatrolRadius
    self.maxDisForSpawn = self.AIManager.monsterInfo.MaxDisForSpawn
    self.spawnPosition = self.AIManager.NPC:GetAttribute("SpawnPosition")
    self.timer = 0

    return self
end

-- 进入巡逻状态
function PatrolState:Enter()
    print("进入PatrolState状态")
    self.timer = 0
    self.AIManager:PlayAnimation(self.animation, true)
    
    -- 设置固定测试目标点
    local npcPosition = self.AIManager.NPC.HumanoidRootPart.Position
    if (npcPosition - self.spawnPosition).Magnitude > self.maxDisForSpawn then
        self.targetPosition = self.spawnPosition
    else
        self.targetPosition = Vector3.new(npcPosition.X + 5 + math.random(-self.patrolRadius, self.patrolRadius),
        npcPosition.Y,
        npcPosition.Z + 10 + math.random(-self.patrolRadius, self.patrolRadius))
    end

    self.connection = PathfindingMove.MoveTo(self.AIManager.NPC, self.targetPosition, function(reached)
        if reached then
            print("到达目标点")
        else
            print("未到达目标点")
        end
        self.AIManager:SetState("Idle")
        return
    end)
end

-- 每帧更新
function PatrolState:Update(dt)
    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        print("HumanoidRootPart not found")
        return
    end

    -- 如果有玩家进入视野范围，切换到追逐状态
    local npcPos = HumanoidRootPart.CFrame.Position
    local visionRange = self.AIManager.monsterInfo.VisionRange
    for _, v in ipairs(Players:GetPlayers()) do
        local character = v.character
        if character then
            local targetHumanoidRootPart = character:FindFirstChild('HumanoidRootPart')
            local targetHumanoid = character:FindFirstChild('Humanoid')
            if targetHumanoidRootPart and targetHumanoid and targetHumanoid.Health > 0 then
                local dis = (targetHumanoidRootPart.CFrame.Position - npcPos).Magnitude
                if dis <= visionRange then
                    self.AIManager:SetState("Chase")
                    return
                end
            end
        end
    end

    -- 巡逻状态下，每15秒返回出生点
    self.timer = self.timer + dt
    if self.timer >= 15 then
        self.timer = 0
        self.AIManager.NPC:PivotTo(CFrame.new(self.spawnPosition))
        self.AIManager:SetState("Idle")
        return
    end
end

-- 退出巡逻状态
function PatrolState:Exit()
    print("退出PatrolState状态")
    if self.connection then
        self.connection:Disconnect()
    end
    self.connection = nil
end

return PatrolState