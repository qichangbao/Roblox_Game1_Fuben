local AIManager = {}
AIManager.__index = AIManager

function AIManager.new(npc, position, monsterInfo)
    local self = setmetatable({}, AIManager)
    
    -- 保存原始NPC克隆体
    self.NPC = npc
    self.target = nil
    self.monsterInfo = monsterInfo
    
    self:InitializeAttributes(monsterInfo, position)

    self.CurrentState = nil
    self.States = {
        Idle = require(script.Parent:WaitForChild("IdleState")).new(self, monsterInfo.AnimationIdle),
        Patrol = require(script.Parent:WaitForChild("PatrolState")).new(self, monsterInfo.AnimationRun),
        Attack = require(script.Parent:WaitForChild("AttackState")).new(self, monsterInfo.AnimationAttack),
        Dead = require(script.Parent:WaitForChild("DeadState")).new(self, monsterInfo.AnimationDeath),
        Chase = require(script.Parent:WaitForChild("ChaseState")).new(self, monsterInfo.AnimationRun),
    }

    self.currentTrack = nil

    local Humanoid = self.NPC:FindFirstChildOfClass("Humanoid")
    if Humanoid then
        -- 监听死亡状态
        Humanoid.Died:Connect(function()
            self:SetState("Dead")
        end)
    end
    self.connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
        if self.CurrentState then
            self.CurrentState:Update(dt)
        end
    end)

    return self
end

function AIManager:InitializeAttributes(monsterInfo, position)
    if not monsterInfo then
        warn("InitializeAttributes: 参数不完整")
        return
    end

    self.NPC:SetAttribute("SpawnPosition", position)
    
    local humanoid = self.NPC:FindFirstChildOfClass("Humanoid")
    humanoid.WalkSpeed = monsterInfo.MoveSpeed
    humanoid.Health = monsterInfo.HP
    humanoid.MaxHealth = monsterInfo.HP
end

function AIManager:SetState(newState)
    if self.CurrentState then
        self.CurrentState:Exit()
    end
    
    self.CurrentState = self.States[newState]
    self.CurrentState:Enter()
end

function AIManager:Start()
    self:SetState('Idle')
end

function AIManager:Destroy()
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end
    -- 清理AI实例相关资源
    self:StopAnimation()
    self.States = nil
    if self.CurrentState then
        self.CurrentState:Exit()
        self.CurrentState = nil
    end
    self.NPC:Destroy()
end

function AIManager:StopAnimation()
	if self.currentTrack then
		self.currentTrack:Stop()
		self.currentTrack = nil
	end
end

-- 播放指定名称的动画
function AIManager:PlayAnimation(animId, isLoop)
	-- 停止当前动画
	self:StopAnimation()

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. animId
	-- 加载并播放新动画
	--local animationController = self.NPC:FindFirstChildOfClass("AnimationController")
	local animationController = self.NPC:FindFirstChildOfClass("Humanoid")
	local animator = animationController:FindFirstChildOfClass("Animator")
	local track = animator:LoadAnimation(animation)
	track:Play()
	track.Looped = isLoop
	self.currentTrack = track
end

return AIManager