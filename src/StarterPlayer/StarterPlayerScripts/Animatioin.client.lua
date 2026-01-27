local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild('Packages'):WaitForChild('Knit'):waitForChild('Knit'))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local MonsterConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("MonsterConfig"))
local TweenService = game:GetService("TweenService")

local function PlayChestOpenByAnimation(animator, animationId)
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://" .. animationId

    local track = animator:LoadAnimation(animation)
    track.Looped = false
    track:Play()

    track:GetMarkerReachedSignal("Finish"):Connect(function()
        track:AdjustSpeed(0)
    end)
end

local function PlayChestOpenByTween(chestItem, cframe)
    local primaryPart = chestItem.PrimaryPart or chestItem:FindFirstChild("HumanoidRootPart")
    if not primaryPart then return end

    local pivot = chestItem:GetPivot()
    local tiltAngle = math.rad(75)
    local forward = cframe.LookVector
    local right = cframe.RightVector
    local axis = forward:Cross(Vector3.new(0, 1, 0))
    if axis.Magnitude < 1e-4 then
        axis = right
    end
    axis = axis.Unit
    local tiltCFrame = CFrame.fromAxisAngle(axis, -tiltAngle)
    local targetPivot = CFrame.new(pivot.Position) * tiltCFrame
    local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for _, part in ipairs(chestItem:GetDescendants()) do
        if part:IsA("BasePart") then
            local offset = pivot:ToObjectSpace(part.CFrame)
            local targetCFrame = targetPivot * offset
            TweenService:Create(part, tweenInfo, { CFrame = targetCFrame }):Play()
        end
    end
end

-- 在客户端播放怪物死亡动画并输出调试日志（函数级注释）：
-- @param npc Model 怪物模型
-- 行为：
-- 1. 通过 MonsterId 从 MonsterConfig 取 AnimationDeath；
-- 2. 本地 LoadAnimation 并播放；
-- 3. 在 Stopped 事件中，将动画跳到最后一帧并速度设为0；
-- 4. 打印当前正在播放的动画轨道，帮助排查“站起来”的原因。
local function playMonsterDeathClient(npc)
	if not npc or not npc.Parent then
		print("[Client MonsterDead] npc 无效或已被销毁", npc)
		return
	end

	print("[Client MonsterDead] 开始处理", npc, npc.Name)

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		print("[Client MonsterDead] 未找到 Humanoid", npc.Name)
		return
	end

	local monsterId = npc:GetAttribute("MonsterId")
	print("[Client MonsterDead] MonsterId=", monsterId)
	if not monsterId then
		return
	end

	local monsterInfo = MonsterConfig:GetByMonsterId(monsterId)
	if not monsterInfo then
		print("[Client MonsterDead] 未找到 MonsterConfig", monsterId)
		return
	end

	local deathId = monsterInfo.AnimationDeath
	print("[Client MonsterDead] AnimationDeath=", deathId)
	if not deathId or deathId == "" then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animateScript = npc:FindFirstChild("Animate", true)
	if animateScript then
		print("[Client MonsterDead] 发现 Animate 脚本:", animateScript:GetFullName())
	end

	local playingBefore = animator:GetPlayingAnimationTracks()
	print("[Client MonsterDead] 清理旧动画轨道, 数量=", #playingBefore)
	for _, t in ipairs(playingBefore) do
		local anim = t.Animation
		local animId = anim and anim.AnimationId or "<nil>"
		print("[Client MonsterDead] 停止旧轨道", t, "AnimId=", animId, "Priority=", t.Priority)
		t:Stop(0)
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. tostring(deathId)
	local track = animator:LoadAnimation(animation)
	if not track then
		print("[Client MonsterDead] LoadAnimation 失败")
		return
	end

	local finishedByMarker = false

	local function freezeAtCurrent()
		print("[Client MonsterDead] freezeAtCurrent, TimePosition=", track.TimePosition)
		track:AdjustSpeed(0)
		local hrp = npc:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = true
			print("[Client MonsterDead] 已在客户端锚定 HumanoidRootPart", hrp)
		end
	end

	local guardConn
	guardConn = animator.AnimationPlayed:Connect(function(newTrack)
		local anim = newTrack.Animation
		local animId = anim and anim.AnimationId or "<nil>"
		if newTrack ~= track and animId ~= animation.AnimationId then
			print("[Client MonsterDead] 拦截新轨道", newTrack, "AnimId=", animId, "Priority=", newTrack.Priority)
			newTrack:Stop(0)
		end
	end)

	local finishConn = track:GetMarkerReachedSignal("Finish"):Connect(function()
		print("[Client MonsterDead] Finish 标记触发, TimePosition=", track.TimePosition)
		finishedByMarker = true
		freezeAtCurrent()
	end)

	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action4
	track:Play()
	print("[Client MonsterDead] 已播放死亡动画 track=", track)

	local function dumpPlayingTracks(tag)
		local list = animator:GetPlayingAnimationTracks()
		print("[Client MonsterDead]", tag, "当前播放中的轨道数量=", #list)
		for _, t in ipairs(list) do
			local anim = t.Animation
			local animId = anim and anim.AnimationId or "<nil>"
			print("[Client MonsterDead] 轨道", t, "AnimId=", animId, "Priority=", t.Priority, "Speed=", t.Speed)
		end
	end

	dumpPlayingTracks("播放开始")

	local function freezeToLastFrame()
		local length = track.Length or 0
		print("[Client MonsterDead] freezeToLastFrame, Length=", length)
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
		local hrp = npc:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = true
			print("[Client MonsterDead] 已在客户端锚定 HumanoidRootPart", hrp)
		end
		dumpPlayingTracks("冻结后")
	end

	local stoppedConn
	stoppedConn = track.Stopped:Connect(function()
		print("[Client MonsterDead] track.Stopped 触发", npc.Name)
		if stoppedConn then
			stoppedConn:Disconnect()
			stoppedConn = nil
		end
		if finishConn then
			finishConn:Disconnect()
			finishConn = nil
		end
		if not finishedByMarker then
			freezeToLastFrame()
		end
		if guardConn then
			guardConn:Disconnect()
			guardConn = nil
		end
	end)
end

--[[
	打开宝箱：优先播放配置动画；若无动画，则根据参数 cframe 方向
	让宝箱整体向 cframe 的前方“倒下”
]]
Knit.OnStart():andThen(function()
	Knit.GetController("UIController").OpenChest:Connect(function(cframe, chestItem)
        local humanoid = chestItem:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            PlayChestOpenByTween(chestItem, cframe)
            return
        end
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            PlayChestOpenByTween(chestItem, cframe)
            return
        end
        
        local itemId = chestItem:GetAttribute("ItemId")
        if not itemId then
            PlayChestOpenByTween(chestItem, cframe)
            return
        end
        local itemConfig = ItemConfig:GetByItemId(itemId)
        if not itemConfig then
            PlayChestOpenByTween(chestItem, cframe)
            return
        end
        local animationId = itemConfig.Icon
        if animationId then
            PlayChestOpenByAnimation(animator, animationId)
		else
            PlayChestOpenByTween(chestItem, cframe)
		end
    end)
    Knit.GetController("UIController").PlayMonsterDead:Connect(function(npc)
        playMonsterDeathClient(npc)
    end)
end)
