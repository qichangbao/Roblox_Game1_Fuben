local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local IdleState = {}
IdleState.__index = IdleState

-- 空闲状态
function IdleState.new(AIManager)
    local self = setmetatable({}, IdleState)
    self.AIManager = AIManager
    return self
end

function IdleState:Enter()
    self.AIManager:PlayAnimation("idle", true)
    self.AIManager:PlaySound("idle")

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
    local visionRange = self.AIManager.NPC:GetAttribute("VisionRange")
    for _, v in ipairs(Players:GetPlayers()) do
        local character = v.character
        if character then
            local targetHumanoidRootPart = character:FindFirstChild('HumanoidRootPart')
            local targetHumanoid = character:FindFirstChild('Humanoid')
            if targetHumanoidRootPart and targetHumanoid and targetHumanoid.Health > 0 then
                if not Interface.isPointInTerrainWater(targetHumanoidRootPart.Position) then
                    local dis = (targetHumanoidRootPart.CFrame.Position - npcPos).Magnitude
                    if dis <= visionRange then
                        self.AIManager:SetState("Chase")
                        return
                    end
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
end

return IdleState