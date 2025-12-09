local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local _itemImageLabel = script.Parent
local _itemImageFadeTween = nil
local _itemImageFadeConn = nil
local _itemImageFadeDelayThread = nil
local _itemImageFadeSeqId = 0
local _itemParticleOffThread = nil

local PARTICLE_PART = ReplicatedStorage:WaitForChild("Effect"):WaitForChild("PickUpStars"):Clone()
PARTICLE_PART.Anchored = true
PARTICLE_PART.CanCollide = false
PARTICLE_PART.Parent = workspace:WaitForChild("Effect")
local PARTICLE_EMITTER = PARTICLE_PART:WaitForChild("Attachment"):WaitForChild("ParticleEmitter")
PARTICLE_EMITTER.Enabled = false

-- 播放拾取物品图标淡入/停留/淡出动画（函数级注释）：
-- @param imageLabel ImageLabel 要播放动画的图像标签
-- @param fadeIn number 淡入时长（秒），从不可见到完全可见
-- @param hold number 停留时长（秒），保持完全可见
-- @param fadeOut number 淡出时长（秒），从完全可见到不可见
local function PlayItemImageFade(imageLabel, fadeIn, hold, fadeOut)
    -- 非阻塞版淡入/停留/淡出动画（函数级注释）：
    -- 目标：移除 Completed:Wait 与 task.wait，避免连续拾取时阻塞导致图标不显示。
    -- 机制：新调用会取消旧补间/延时，通过序列ID确保旧回调不越权执行。

    -- 取消上一轮状态
    if _itemImageFadeTween then _itemImageFadeTween:Cancel() end
    if _itemImageFadeConn then _itemImageFadeConn:Disconnect() end
    if _itemImageFadeDelayThread then task.cancel(_itemImageFadeDelayThread) end
    if _itemParticleOffThread then task.cancel(_itemParticleOffThread) end
    _itemImageFadeTween = nil
    _itemImageFadeConn = nil
    _itemImageFadeDelayThread = nil
    _itemParticleOffThread = nil

    -- 新序列ID
    _itemImageFadeSeqId = _itemImageFadeSeqId + 1
    local seqId = _itemImageFadeSeqId

    -- 初始显示
    imageLabel.Visible = true
    imageLabel.ImageTransparency = 1

    -- 淡入
    local inInfo = TweenInfo.new(fadeIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local inTween = TweenService:Create(imageLabel, inInfo, { ImageTransparency = 0 })
    _itemImageFadeTween = inTween
    _itemImageFadeConn = inTween.Completed:Connect(function()
        if _itemImageFadeSeqId ~= seqId then return end
        _itemImageFadeConn = nil
        -- 停留 -> 淡出（使用 task.delay）
        _itemImageFadeDelayThread = task.delay(hold, function()
            if _itemImageFadeSeqId ~= seqId then return end
            local outInfo = TweenInfo.new(fadeOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            local outTween = TweenService:Create(imageLabel, outInfo, { ImageTransparency = 1 })
            _itemImageFadeTween = outTween
            _itemImageFadeConn = outTween.Completed:Connect(function()
                if _itemImageFadeSeqId ~= seqId then return end
                _itemImageFadeConn = nil
                _itemImageFadeTween = nil
                imageLabel.Visible = false
                -- 淡出完成后 0.5s 关闭拾取粒子
                _itemParticleOffThread = task.delay(0.5, function()
                    if _itemImageFadeSeqId ~= seqId then return end
                    PARTICLE_EMITTER.Enabled = false
                end)
            end)
            outTween:Play()
        end)
    end)
    inTween:Play()
end

-- 计算控件左上角的“物理屏幕坐标”（函数级注释）：
-- @param obj GuiObject 目标控件
-- @return Vector2 屏幕坐标（考虑 IgnoreGuiInset）
local function GetScreenTopLeft(obj)
	local p = obj.AbsolutePosition
	local root = obj:FindFirstAncestorOfClass("ScreenGui")
	if root then
		local inset = GuiService:GetGuiInset()
		if root.IgnoreGuiInset then
			p = Vector2.new(p.X + inset.X, p.Y + inset.Y)
		end
	end
	return p
end

-- 将 3D 粒子放置到 UI 中心的屏幕位置（函数级注释）：
-- @param icon GuiObject 目标 UI 控件
-- @param depth number 与摄像机的距离（单位：studs），推荐 8~20
local function UpdateWorldParticleToUICenter(icon, depth)
	local camera = workspace.CurrentCamera
	if not camera or not icon or not PARTICLE_PART then return end
	depth = depth or 12

	local topLeft = GetScreenTopLeft(icon)
	local size = icon.AbsoluteSize
	local centerX = topLeft.X + size.X * 0.5
	local centerY = topLeft.Y + size.Y * 0.5

	-- 使用像素坐标生成从摄像机出发的射线，并沿射线前进到指定距离
	local ray = camera:ViewportPointToRay(centerX, centerY)
	local worldPos = ray.Origin + ray.Direction * depth

	-- 保证粒子朝向摄像机，获得更稳定的视觉效果
	PARTICLE_PART.CFrame = CFrame.lookAt(worldPos, worldPos + camera.CFrame.LookVector)
end

-- 每帧更新：让 3D 粒子贴紧 UI 中心（函数级注释）
RunService.RenderStepped:Connect(function()
	if not PARTICLE_EMITTER.Enabled then return end
	UpdateWorldParticleToUICenter(_itemImageLabel, 12)
end)

Knit.OnStart():andThen(function()
	Knit.GetController("UIController").PickUpItem:Connect(function(itemInfo)
		if not itemInfo then return end

		PARTICLE_EMITTER.Enabled = true -- 播放粒子

		_itemImageLabel.Visible = false
		_itemImageLabel.ImageTransparency = 1
		_itemImageLabel.Image = itemInfo.Icon
		PlayItemImageFade(_itemImageLabel, 0.5, 2.0, 0.5)
	end)
end)
