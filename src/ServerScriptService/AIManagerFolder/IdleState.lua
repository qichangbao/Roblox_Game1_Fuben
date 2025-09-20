local Players = game:GetService("Players")

local IdleState = {}
IdleState.__index = IdleState

-- 空闲状态
function IdleState.new(AIManager, animation)
    local self = setmetatable({}, IdleState)
    self.AIManager = AIManager
    self.animation = animation
    return self
end

function IdleState:Enter()
    print("进入Idle状态")
    self.AIManager:PlayAnimation(self.animation, true)

    self.timer = math.random(5, 15)
end

function IdleState:Update(dt)
    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        print("HumanoidRootPart not found")
        return
    end

    self.timer = self.timer - dt

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
    
    if self.timer <= 0 then
        self.AIManager:SetState("Patrol")
        return
    end
end

function IdleState:Exit()
    print("退出Idle状态")
end

return IdleState