local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local SoundService = game:GetService("SoundService")
local MonsterFolder = SoundService:WaitForChild("Monster")

local AIManager = {}
AIManager.__index = AIManager

function AIManager.new(npc, position, monsterInfo)
    local self = setmetatable({}, AIManager)
    
    -- 保存原始NPC克隆体
    self.NPC = npc
    self.target = nil
    self.monsterInfo = monsterInfo

    local Humanoid = self.NPC:FindFirstChildOfClass("Humanoid")
    if Humanoid then
        -- 监听死亡状态
        Humanoid.Died:Connect(function()
            self:SetState("Dead")
        end)

        local humanoidRootPart = self.NPC:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            humanoidRootPart.CollisionGroup = "Monster"
            
            position = Vector3.new(position.X, position.Y + Humanoid.HipHeight + humanoidRootPart.Size.Y / 2, position.Z)
        end
    end
    
    self:InitializeAttributes(monsterInfo, position)
    self.NPC:PivotTo(CFrame.new(position))

    self.CurrentState = nil
    self.States = {
        Idle = require(script.Parent:WaitForChild("IdleState")).new(self),
        Patrol = require(script.Parent:WaitForChild("PatrolState")).new(self),
        Attack = require(script.Parent:WaitForChild("AttackState")).new(self),
        Dead = require(script.Parent:WaitForChild("DeadState")).new(self),
        Chase = require(script.Parent:WaitForChild("ChaseState")).new(self),
    }

    -- 预加载所有动画
    self.currentTrack = nil
    self.animationTracks = {}
    self:PreloadAnimations(monsterInfo)
    -- 预加载所有音效
    self.currentSound = nil
    self.sounds = {}
    self:PreloadSound()
    
    self.connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
        if self.CurrentState then
            self.CurrentState:Update(dt)
        end
    end)

    if self.NPC.PrimaryPart then
        local tiltAngle = math.rad(40)
        self.NPC.PrimaryPart.Orientation = Vector3.new(tiltAngle, 0, 0)
    end

    self:SetState('Idle')

    return self
end

function AIManager:InitializeAttributes(monsterInfo, position)
    if not monsterInfo then
        warn("InitializeAttributes: 参数不完整")
        return
    end

    self.NPC:SetAttribute("MonsterId", monsterInfo.MonsterId)
    self.NPC:SetAttribute("SpawnPosition", position)
    self.NPC:SetAttribute("InitVisionRange", monsterInfo.VisionRange)
    self.NPC:SetAttribute("VisionRange", monsterInfo.VisionRange)
    self.NPC:SetAttribute("InitAttackRange", monsterInfo.AttackRange)
    self.NPC:SetAttribute("AttackRange", monsterInfo.AttackRange)
    self.NPC:SetAttribute("InitAttackSpeed", monsterInfo.AttackSpeed)
    self.NPC:SetAttribute("AttackSpeed", monsterInfo.AttackSpeed)
    self.NPC:SetAttribute("InitAttack", monsterInfo.Attack)
    self.NPC:SetAttribute("Attack", monsterInfo.Attack)
    
    local humanoid = self.NPC:FindFirstChildOfClass("Humanoid")
    humanoid.WalkSpeed = monsterInfo.MoveSpeed
    humanoid.Health = monsterInfo.HP
    humanoid.MaxHealth = monsterInfo.HP
end

function AIManager:SetState(newState)
    if self.CurrentState then
        self.CurrentState:Exit()
    end

    if not self.States or type(self.States) ~= "table" then
        return
    end
    
    self.CurrentState = self.States[newState]
    if self.CurrentState then
        self.CurrentState:Enter()
    end
end

function AIManager:Destroy()
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end
    -- 清理AI实例相关资源
    self:StopAnimation()
    
    -- 清理预加载的动画轨道
    if self.animationTracks then
        for animName, track in pairs(self.animationTracks) do
            if track then
                track:Stop()
                track:Destroy()
            end
        end
        self.animationTracks = nil
        print("🧹 已清理预加载的动画轨道")
    end
    
    self.States = nil
    if self.CurrentState then
        self.CurrentState:Exit()
        self.CurrentState = nil
    end
    Knit.GetService("MonsterService"):MonsterRemoved(self.NPC)
    self.NPC:Destroy()
end

--[[
    预加载所有动画
    @param monsterInfo table 怪物信息，包含各种动画ID
]]
function AIManager:PreloadAnimations(monsterInfo)
    local Humanoid = self.NPC:FindFirstChildOfClass("Humanoid")
    if not Humanoid then
        warn("未找到Humanoid，无法预加载动画")
        return
    end
    
    local animator = Humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        warn("未找到Animator，无法预加载动画")
        return
    end
    
    -- 定义动画映射表
    local animationMap = {
        idle = {monsterInfo.AnimationIdle, Enum.AnimationPriority.Idle},
        walk = {monsterInfo.AnimationRun, Enum.AnimationPriority.Movement},
        attack = {monsterInfo.AnimationAttack, Enum.AnimationPriority.Action},
        dead = {monsterInfo.AnimationDeath, Enum.AnimationPriority.Action2},
    }
    
    -- 预加载所有动画
    for animName, animInfo in pairs(animationMap) do
        if animInfo[1] and animInfo[1] ~= "" then
            local animation = Instance.new("Animation")
            animation.AnimationId = "rbxassetid://" .. animInfo[1]
            
            local success, track = pcall(function()
                return animator:LoadAnimation(animation)
            end)
            
            if success and track then
                track.Priority = animInfo[2]
                self.animationTracks[animName] = track
            end
        end
    end
end

function AIManager:PreloadSound()
    local monsterId = self.monsterInfo.MonsterId
    local idFolder = MonsterFolder:FindFirstChild(monsterId)
    if not idFolder then
        return
    end

    local humanoidRootPart = self.NPC:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return
    end

    local soundMap = {
        "idle",
        "walk",
        "attack",
        "dead",
    }
    for i, v in ipairs(soundMap) do
        local soundTemp = idFolder:FindFirstChild(v)
        if soundTemp then
            local sound = soundTemp:Clone()
            sound.Parent = self.NPC.PrimaryPart
            self.sounds[v] = sound
        end
    end
end

function AIManager:StopAnimation()
	if self.currentTrack then
		self.currentTrack:Stop()
		self.currentTrack = nil
	end
end

--[[
    播放指定名称的动画（使用预加载的动画轨道）
    @param animName string 动画名称 (idle, run, attack, death等)
    @param isLoop boolean 是否循环播放
]]
function AIManager:PlayAnimation(animName, isLoop, priority)
    -- 停止当前动画
    self:StopAnimation()
    
    -- 获取预加载的动画轨道
    local track = self.animationTracks[animName]
    if not track then
        warn(string.format("❌ 未找到预加载的动画: %s", animName))
        return
    end
    
    -- 播放动画
    track:Play()
    track.Looped = isLoop or false
    self.currentTrack = track
end

function AIManager:PlaySound(soundName, loop)
    if self.currentSound then
        self.currentSound:Stop()
        self.currentSound = nil
    end

    if not self.sounds[soundName] then
        return
    end

    local sound = self.sounds[soundName]
    if loop then
        sound.Looped = true
    else
        sound.Looped = false
    end
    sound:Play()
    self.currentSound = sound
end

return AIManager