local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local SoundService = game:GetService("SoundService")
local MonsterFolder = SoundService:WaitForChild("Monster")
local Players = game:GetService("Players")
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local AIManager = {}
AIManager.__index = AIManager

local _fovDegrees = 160     -- 怪物视角

function AIManager.new(npc, position, monsterInfo)
    local self = setmetatable({}, AIManager)
    
    -- 保存原始NPC克隆体
    self.NPC = npc
    self.target = nil
    self.monsterInfo = monsterInfo

    local Humanoid = self.NPC:FindFirstChildOfClass("Humanoid")
    if Humanoid then
        Humanoid:SetAttribute("MonsterId", monsterInfo.MonsterId)
        -- 监听死亡状态
        Humanoid.Died:Connect(function()
            self:SetState("Dead")

            -- 立即清理视野标记
            if self.VisionMarkers then
                self.VisionMarkers:Destroy()
                self.VisionMarkers = nil
                print("🧹 怪物死亡时已清理视野标记")
            end
            
            -- 清理视野标记相关引用
            self.InnerGuiPart = nil
            self.InnerSurfaceGui = nil
            self.InnerImage = nil
            self.SectorGuiPart = nil
            self.SectorSurfaceGui = nil
            self.SectorImage = nil
        end)

        local humanoidRootPart = self.NPC:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            humanoidRootPart.CollisionGroup = "Monster"
            
            position = Vector3.new(position.X, position.Y + Humanoid.HipHeight + humanoidRootPart.Size.Y / 2, position.Z)
        end
    end
    
    self:InitializeAttributes(monsterInfo, position)
    self.NPC:PivotTo(CFrame.new(position))

    local chaseFlag = self.NPC:FindFirstChild("ChaseFlag")
    if chaseFlag then
        for _, obj in ipairs(chaseFlag:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.Transparency = 1
            end
        end
    end

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
    -- 初始化特效
    self:InitAnimEffect(self.NPC)
    
    self.connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
        if self.CurrentState then
            self.CurrentState:Update(dt)
        end
        -- 更新视野标记（如果已创建）
        self:UpdateVisionMarkers()
    end)

    if self.NPC.PrimaryPart then
        local tiltAngle = math.rad(40)
        self.NPC.PrimaryPart.Orientation = Vector3.new(tiltAngle, 0, 0)
    end

    self:SetState('Idle')
    -- 创建视野可视化标记
    self:CreateVisionMarkers()

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
    self.NPC:SetAttribute("InitWalkSpeed", monsterInfo.MoveSpeed)
    self.NPC:SetAttribute("InitMaxHealth", monsterInfo.HP)
    
    local humanoid = self.NPC:FindFirstChildOfClass("Humanoid")
    humanoid.WalkSpeed = monsterInfo.MoveSpeed
    humanoid.Health = monsterInfo.HP
    humanoid.MaxHealth = monsterInfo.HP
end

function AIManager:SetState(newState)
    if self.CurrentState then
        self.CurrentState:Exit()
        self:StopSound()
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
            else
                warn(string.format("❌ 未找到预加载的动画: %s %s", animName, animInfo[1]))
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
-- 播放动画
-- @param animName string 动画名称
-- @param isLoop boolean 是否循环播放
-- @param playTimeScale number 播放速度倍数
-- @param maxTime number 最大动画时长限制（秒）
function AIManager:PlayAnimation(animName, isLoop, playTimeScale, maxTime)
    -- 停止当前动画
    self:StopAnimation()
    
    -- 获取预加载的动画轨道
    local track = self.animationTracks[animName]
    if not track then
        warn(string.format("❌ 未找到预加载的动画: %s", animName))
        return
    end
    
    -- 设置循环
    track.Looped = isLoop or false
    
    -- 播放动画
    track:Play()
    
    -- 在播放后设置速度（对外部动画更有效）
    local speedMultiplier = playTimeScale or 1
    if speedMultiplier ~= 1 then
        track:AdjustSpeed(speedMultiplier)
    end
    
    -- 如果设置了最大时长限制，检查调整速度后的动画时长
    if maxTime and maxTime > 0 then
        -- 获取动画的原始长度
        local originalLength = track.Length
        if originalLength > 0 then
            -- 计算调整速度后的实际动画时长
            local adjustedLength = originalLength / speedMultiplier
            
            -- 如果调整后的时长超过最大时长，进一步调整速度
            if adjustedLength > maxTime then
                local finalSpeedMultiplier = originalLength / maxTime
                track:AdjustSpeed(finalSpeedMultiplier)
            end
        end
    end
    
    self.currentTrack = track
end

-- 播放死亡动画并在最后一帧冻结（函数级注释）：
-- 行为：
-- 1. 使用预加载的 "dead" 动画轨道播放死亡动作；
-- 2. 优先监听动画事件标记 "Finish"，在关键帧处将速度设为0并停在最后一帧；
-- 3. 若没有事件标记，则在 Stopped 回调中二次播放并跳到 Length 处后将速度设为0。
function AIManager:PlayDeathAnimation()
    self:StopAnimation()

    local track = self.animationTracks and self.animationTracks["dead"]
    if not track then
        warn("未找到死亡动画轨道: dead")
        return
    end

    track.Looped = false
    track:Play()
    self.currentTrack = track

    local function freezeToLastFrame()
        local length = track.Length or 0
        if length <= 0 then
            local lenConn
            lenConn = track:GetPropertyChangedSignal("Length"):Connect(function()
                if track.Length and track.Length > 0 then
                    lenConn:Disconnect()
                    freezeToLastFrame()
                end
            end)
            return
        end

        track:Play(0, 1, 0)
        track.TimePosition = length
        track:AdjustSpeed(0)
    end

    local hasMarker = false
    local ok, _ = pcall(function()
        track:GetMarkerReachedSignal("Finish")
    end)
    if ok then
        hasMarker = true
    end

    if hasMarker then
        local markerConn
        markerConn = track:GetMarkerReachedSignal("Finish"):Connect(function()
            if markerConn then
                markerConn:Disconnect()
                markerConn = nil
            end
            freezeToLastFrame()
        end)
    else
        local stoppedConn
        stoppedConn = track.Stopped:Connect(function()
            if stoppedConn then
                stoppedConn:Disconnect()
                stoppedConn = nil
            end
            freezeToLastFrame()
        end)
    end
end

function AIManager:PlaySound(soundName, loop)
    self:StopSound()

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

function AIManager:StopSound()
    if self.currentSound then
        self.currentSound:Stop()
        self.currentSound = nil
    end
end

function AIManager:InitAnimEffect(monster)
    -- 生成并摆放命中特效到边缘中心
    local effect2 = Interface.GetEffect("PlayerHitEffect")
    effect2.Parent = monster
    effect2.Name = "PlayerHitEffect"
	for _, part in pairs(effect2:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Anchored = true
        elseif part:IsA("ParticleEmitter") then
            part.Enabled = false
        end
    end
end

--[[
    播放命中特效
    @param target 被命中的目标（玩家或怪物）
]]
function AIManager:PlayAnimHitEffect(target)
    local effect = self.NPC:FindFirstChild("PlayerHitEffect")
    if not effect then return end
	-- 朝向 NPC，自身位置仍然在目标身上
    Interface.PlayEffect(effect, CFrame.lookAt(target:GetPivot().Position, self.NPC:GetPivot().Position), 30, 1, false)
end

--[[
    创建视野可视化标记：
    - 红色内圈：visionRange/4
    - 红色外圈：visionRange
    - 两条红色边界线：±45°（前方90度视野）
]]
function AIManager:CreateVisionMarkers()
    if self.VisionMarkers then return end
    local hrp = self.NPC:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local folder = Instance.new("Folder")
    folder.Name = "VisionMarkers"
    folder.Parent = self.NPC
    self.VisionMarkers = folder

    local visionRange = self.NPC:GetAttribute("VisionRange") or 0
    -- 内圈（圆形）：改为 SurfaceGui + Image 实现
    self.InnerGuiPart = Instance.new("Part")
    self.InnerGuiPart.Name = "InnerGuiPart"
    self.InnerGuiPart.Anchored = true
    self.InnerGuiPart.CanCollide = false
    self.InnerGuiPart.CastShadow = false
    self.InnerGuiPart.Transparency = 1
    local innerDiameter = (visionRange / 3) * 2
    self.InnerGuiPart.Size = Vector3.new(innerDiameter, 0.05, innerDiameter)
    self.InnerGuiPart.Parent = folder

    local innerSurface = Instance.new("SurfaceGui")
    innerSurface.Name = "InnerSurfaceGui"
    innerSurface.Face = Enum.NormalId.Top
    innerSurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    innerSurface.PixelsPerStud = 50
    innerSurface.ClipsDescendants = true
    innerSurface.AlwaysOnTop = false
    innerSurface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    innerSurface.Parent = self.InnerGuiPart
    self.InnerSurfaceGui = innerSurface

    local innerImg = Instance.new("ImageLabel")
    innerImg.Name = "InnerImage"
    innerImg.BackgroundTransparency = 1
    innerImg.BorderSizePixel = 0
    innerImg.Image = "rbxassetid://97554656697230"
    innerImg.AnchorPoint = Vector2.new(0.5, 0.5)
    innerImg.Position = UDim2.fromScale(0.5, 0.5)
    innerImg.ImageTransparency = 0.6
    innerImg.Size = UDim2.fromOffset(self.InnerGuiPart.Size.X * innerSurface.PixelsPerStud, self.InnerGuiPart.Size.Z * innerSurface.PixelsPerStud)
    innerImg.Parent = innerSurface
    self.InnerImage = innerImg

    -- 扇形区域（填充）：使用 SurfaceGui + Image（单个部件，性能更好）
    self.SectorGuiPart = Instance.new("Part")
    self.SectorGuiPart.Name = "SectorGuiPart"
    self.SectorGuiPart.Anchored = true
    self.SectorGuiPart.CanCollide = false
    self.SectorGuiPart.CastShadow = false
    self.SectorGuiPart.Transparency = 1 -- 画布本体不可见
    -- 视野角度（度），用于按横向比例缩放画布；假设源图片为180度扇形
    local widthScale = _fovDegrees / 180
    self.SectorGuiPart.Size = Vector3.new(visionRange * 2 * widthScale, 0.05, visionRange)
    self.SectorGuiPart.Parent = folder

    local surface = Instance.new("SurfaceGui")
    surface.Name = "SectorSurfaceGui"
    surface.Face = Enum.NormalId.Top
    surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surface.PixelsPerStud = 50
    surface.ClipsDescendants = true
    surface.AlwaysOnTop = false
    surface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    surface.Parent = self.SectorGuiPart
    self.SectorSurfaceGui = surface

    local img = Instance.new("ImageLabel")
    img.Name = "SectorImage"
    img.BackgroundTransparency = 1
    img.BorderSizePixel = 0
    img.Image = "rbxassetid://82730477859737"
    -- 底中为扇形顶点；顶边中心对齐画布近边中心（怪物脚下）
    img.AnchorPoint = Vector2.new(0.5, 0.5)
    img.Position = UDim2.new(0.5, 0, 0.5, 0)
    img.ImageTransparency = 0.6
    img.Rotation = 90
    -- 手动让图片宽高与 Part 面板一致（X 对应宽度，Z 对应高度）
    img.Size = UDim2.fromOffset(self.SectorGuiPart.Size.X * surface.PixelsPerStud, self.SectorGuiPart.Size.Z * surface.PixelsPerStud)
    img.Parent = surface
    self.SectorImage = img
    -- 使用部件自身的Yaw偏移来校准整体方向，避免UI旋转导致顶点偏移
    self.SectorYawOffset = 0
end

-- 更新视野标记位置与朝向
function AIManager:UpdateVisionMarkers()
    if not self.VisionMarkers then return end
    local hrp = self.NPC:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local visionRange = self.NPC:GetAttribute("VisionRange") or 0
    -- 动态更新内圈大小（SurfaceGui + Image 方案）
    if self.InnerGuiPart then
        local innerDiameter = (visionRange/3) * 2
        self.InnerGuiPart.Size = Vector3.new(innerDiameter, 0.05, innerDiameter)
        if self.InnerImage and self.InnerSurfaceGui then
            local pxW = self.InnerGuiPart.Size.X * self.InnerSurfaceGui.PixelsPerStud
            local pxH = self.InnerGuiPart.Size.Z * self.InnerSurfaceGui.PixelsPerStud
            self.InnerImage.Size = UDim2.fromOffset(pxW, pxH)
        end
    end

    -- 射线检测地面高度，将标记贴地
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {self.NPC}
    local origin = hrp.Position
    local result = workspace:Raycast(origin, Vector3.new(0, -500, 0), rayParams)
    local groundY = (result and result.Position.Y) or (origin.Y - hrp.Size.Y/2)

    -- 让圆盘略高于地面：抬起厚度的一半再加微小偏移，避免被地面遮挡
    local innerT = (self.InnerGuiPart and self.InnerGuiPart.Size.Y) or 0.05
    local lift = innerT * 0.5 + 0.02
    local basePos = Vector3.new(origin.X, groundY + lift, origin.Z)
    -- 将内圈画布置于脚下中心（Top面向上）
    if self.InnerGuiPart then self.InnerGuiPart.CFrame = CFrame.new(basePos) end

    -- 计算前向与边界方向（水平分量）
    local forward = hrp.CFrame.LookVector
    local forwardXZ = Vector3.new(forward.X, 0, forward.Z).Unit

    -- 更新扇形画布Part：大小与朝向（局部Z轴指向怪物前方，Top面向上）
    if self.SectorGuiPart then
        local widthScale = _fovDegrees / 180
        self.SectorGuiPart.Size = Vector3.new(visionRange * 2 * widthScale, 0.05, visionRange)
        local baseCf = CFrame.lookAt(basePos, basePos + forwardXZ, Vector3.new(0, 1, 0))
        local yaw = CFrame.Angles(0, math.rad(self.SectorYawOffset or 0), 0)
        -- 让“图片底部中心”（扇形顶点）正好落在怪物脚下：
        -- 将画布中心沿前方移动半深度，使面板的近边中心位于怪物脚下
        local halfDepth = self.SectorGuiPart.Size.Z * 0.5
        self.SectorGuiPart.CFrame = (baseCf * yaw) + (forwardXZ * halfDepth)
        -- 手动同步图片尺寸，使其宽高与 Part 的 X/Z 一致
        if self.SectorImage and self.SectorSurfaceGui then
            local pxW = self.SectorGuiPart.Size.X * self.SectorSurfaceGui.PixelsPerStud
            local pxH = self.SectorGuiPart.Size.Z * self.SectorSurfaceGui.PixelsPerStud
            self.SectorImage.Size = UDim2.fromOffset(pxW, pxH)
            self.SectorImage.Position = UDim2.new(0.5, 0, 0.5, 0)
        end
    end
end

--[[
    查找在视野范围内最近的玩家目标
    @return Player 最近的玩家目标，若不存在则返回nil
]]
function AIManager:FindVisionRangeTarget()
    local HumanoidRootPart = self.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        print("HumanoidRootPart not found")
        return
    end
    
    local npcPos = HumanoidRootPart.CFrame.Position
    -- 前向向量（仅使用水平分量，忽略上下倾斜）
    local forward = HumanoidRootPart.CFrame.LookVector
    local forwardXZ = Vector3.new(forward.X, 0, forward.Z).Unit
    -- 视野阈值：使用 _fovDegrees（总角度），取半角用于点积比较
    local halfFovDeg = (_fovDegrees or 90) * 0.5
    local fovDotThreshold = math.cos(math.rad(halfFovDeg))
    local visionRange = self.NPC:GetAttribute("VisionRange")
    for _, v in ipairs(Players:GetPlayers()) do
        local character = v.Character
        if not character then continue end
        local targetHumanoidRootPart = character:FindFirstChild('HumanoidRootPart')
        local targetHumanoid = character:FindFirstChild('Humanoid')
        if not targetHumanoidRootPart then continue end
        if not targetHumanoid then continue end
        if targetHumanoid.Health <= 0 then continue end
        if Interface.IsPlayerInWater(character) then continue end
        if character:FindFirstChild("ForceField") then continue end

        local toTarget = targetHumanoidRootPart.Position - npcPos
        local dis = toTarget.Magnitude
        if dis <= visionRange then
            -- 仅使用水平分量判断是否在前方90度视野内
            local toTargetXZ = Vector3.new(toTarget.X, 0, toTarget.Z).Unit
            local dot = forwardXZ:Dot(toTargetXZ)
            if dot >= fovDotThreshold or dis <= visionRange / 3 then
                return v
            end
        end
    end
end

--[[
    查找在视野范围内最近的玩家目标
    @return Player 最近的玩家目标，若不存在则返回nil
]]
function AIManager:FindVisionRangeNearestTarget()
    local HumanoidRootPart = self.NPC:FindFirstChild('HumanoidRootPart')
    if not HumanoidRootPart then
        print("HumanoidRootPart not found")
        return
    end
    
    local npcPos = HumanoidRootPart.CFrame.Position
    -- 前向向量（仅使用水平分量，忽略上下倾斜）
    local forward = HumanoidRootPart.CFrame.LookVector
    local forwardXZ = Vector3.new(forward.X, 0, forward.Z).Unit
    -- 视野阈值：使用 _fovDegrees（总角度），取半角用于点积比较
    local halfFovDeg = (_fovDegrees or 90) * 0.5
    local fovDotThreshold = math.cos(math.rad(halfFovDeg))
    local visionRange = self.NPC:GetAttribute("VisionRange")
    local minDistance = math.huge
    local target = nil

    for _, v in ipairs(Players:GetPlayers()) do
        local character = v.Character
        if not character then continue end
        local targetHumanoidRootPart = character:FindFirstChild('HumanoidRootPart')
        local targetHumanoid = character:FindFirstChild('Humanoid')
        if not targetHumanoidRootPart then continue end
        if not targetHumanoid then continue end
        if targetHumanoid.Health <= 0 then continue end
        if Interface.IsPlayerInWater(character) then continue end
        if character:FindFirstChild("ForceField") then continue end
        
        local toTarget = targetHumanoidRootPart.Position - npcPos
        local dis = toTarget.Magnitude
        if dis <= visionRange then
            -- 仅使用水平分量判断是否在前方90度视野内
            local toTargetXZ = Vector3.new(toTarget.X, 0, toTarget.Z).Unit
            local dot = forwardXZ:Dot(toTargetXZ)
            if dot >= fovDotThreshold or dis <= visionRange / 3 then
                if dis < minDistance then
                    target = character
                    minDistance = dis
                end
            end
        end
    end
    return target
end

return AIManager
