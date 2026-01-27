local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local MonsterConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("MonsterConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local DeadState = {}
DeadState.__index = DeadState

-- 死亡状态
function DeadState.new(AIManager)
    local self = setmetatable({}, DeadState)
    self.AIManager = AIManager
    return self
end

function DeadState:Enter()
    -- 播放死亡动画并分析是否需要播放死亡音效
    local humanoid = self.AIManager.NPC:FindFirstChild("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Dead)
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.AutoRotate = false
    end
	 Knit.GetService("MonsterService"):PlayMonsterDead(self.AIManager.NPC)
	 self.AIManager:PlaySound("dead")

    local HumanoidRootPart = self.AIManager.NPC:FindFirstChild("HumanoidRootPart")
    if HumanoidRootPart then
        HumanoidRootPart.Anchored = true
    end

    -- 取消所有追逐
    Knit.GetService("MonsterService"):ChaseCannel(self.AIManager.NPC)

    task.delay(500, function()
        task.spawn(function()
            if self.AIManager then
                self.AIManager:Destroy()
                self.AIManager = nil
            end
        end)
    end)
end

function DeadState:Update(dt)
end

function DeadState:Exit()
end

return DeadState
