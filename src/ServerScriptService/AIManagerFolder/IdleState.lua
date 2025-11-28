
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

    local target = self.AIManager:FindVisionRangeTarget()
    if target then
        self.AIManager:SetState("Chase")
        return
    end
    
    if self.timer <= 0 then
        -- 怪物类型为2时，不巡逻
        if self.AIManager.monsterInfo.Type == 2 then return end
        self.AIManager:SetState("Patrol")
        return
    end
end

function IdleState:Exit()
end

return IdleState