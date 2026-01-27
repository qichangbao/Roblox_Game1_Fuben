local TweenInterface = require(game.ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))
local GuiService = game:GetService("GuiService")

local UIEffects = {}

-- 将 GuiObject 的绝对位置转换为“物理屏幕坐标”（函数级注释）：
-- @param obj GuiObject 目标控件
-- @return Vector2 返回屏幕坐标（已统一考虑 IgnoreGuiInset）
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

-- 将屏幕坐标转换为容器局部坐标（函数级注释）：
-- @param container Instance ScreenGui 或 GuiObject
-- @param screenPos Vector2 屏幕坐标
-- @return Vector2 容器局部坐标
local function ScreenToContainer(container, screenPos)
    if container:IsA("ScreenGui") then
        local inset = GuiService:GetGuiInset()
        if container.IgnoreGuiInset then
            return screenPos
        else
            return Vector2.new(screenPos.X - inset.X, screenPos.Y - inset.Y)
        end
    elseif container:IsA("GuiObject") then
        local cScreen = GetScreenTopLeft(container)
        return Vector2.new(screenPos.X - cScreen.X, screenPos.Y - cScreen.Y)
    else
        return screenPos
    end
end

-- 播放 2D 伪粒子爆发（径向）效果（函数级注释）：
-- @param parent Instance 粒子容器，一般为 ScreenGui 或某个 Frame
-- @param center Vector2 爆发中心（相对 parent 的像素坐标）
-- @param params table 参数表：
--   image: string 颗粒贴图 rbxassetid，例如 "rbxassetid://16735005717"
--   count: number 粒子数量（默认 40）
--   radius: number 最大半径（像素，默认 120）
--   lifetime: number 单个粒子总时长（秒，默认 1.0）
--   sizeMin: number 最小尺寸（像素，默认 8）
--   sizeMax: number 最大尺寸（像素，默认 24）
--   fadeIn: number 淡入时长（秒，默认 0.1）
--   fadeOut: number 淡出时长（秒，默认 0.4）
--   easing: Enum.EasingStyle 补间曲线（默认 Enum.EasingStyle.Quad）
--   randomHue: boolean 是否随机色调（默认 false）
--   color: Color3 指定粒子颜色（默认 nil，不指定）
--   rotationRange: number 旋转范围（度，默认 90）
--   scaleJitter: number 尺寸抖动百分比（默认 0.2，表示±20%）
--   spinTurns: number 旋转圈数（默认 0，不旋转；如 1.5 表示旋转 540°）
--   spinRandom: boolean 旋转方向随机（默认 true）
-- @return nil
function UIEffects.PlayUIBurst(parent, center, params)
    if not parent or typeof(center) ~= "Vector2" then return end
    params = params or {}
    local image = params.image
    local count = math.clamp(params.count or 40, 1, 200)
    local radius = math.max(params.radius or 120, 1)
    local lifetime = math.max(params.lifetime or 1.0, 0.2)
    local sizeMin = math.max(params.sizeMin or 8, 1)
    local sizeMax = math.max(params.sizeMax or 24, sizeMin)
    local fadeIn = math.max(params.fadeIn or 0.1, 0)
    local fadeOut = math.max(params.fadeOut or 0.4, 0)
    local easing = params.easing or Enum.EasingStyle.Quad
    local randomHue = params.randomHue or false
    local color = params.color
    local rotRange = params.rotationRange or 90
    local scaleJitter = params.scaleJitter or 0.2
    local spinTurns = params.spinTurns or 0
    local spinRandom = params.spinRandom
    if spinRandom == nil then spinRandom = true end

    -- 调试：显示中心点，便于排查偏移（小白点，随粒子生命周期自动销毁）
    if params.debugCenter then
        local dot = Instance.new("Frame")
        dot.Name = "UIBurstCenterDebug"
        dot.BackgroundColor3 = Color3.new(1, 1, 1)
        dot.BorderSizePixel = 0
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Size = UDim2.fromOffset(3, 3)
        dot.Position = UDim2.fromOffset(center.X, center.Y)
        dot.ZIndex = 10
        dot.Parent = parent
        task.delay(lifetime, function()
            if dot then dot:Destroy() end
        end)
    end

    for i = 1, count do
        task.spawn(function()
            local p = Instance.new("ImageLabel")
            p.Name = "UIParticle"
            p.BackgroundTransparency = 1
            p.AnchorPoint = Vector2.new(0.5, 0.5)
            if image then p.Image = image end
            p.ImageTransparency = 1

            local sizePx = math.random(sizeMin, sizeMax)
            p.Size = UDim2.fromOffset(sizePx, sizePx)
            p.Position = UDim2.fromOffset(center.X, center.Y)

            if color then
                p.ImageColor3 = color
            elseif randomHue then
                p.ImageColor3 = Color3.fromHSV(math.random(), 0.75, 1)
            end

            local startRot = math.random(0, 360)
            p.Rotation = startRot

            local angle = math.rad(math.random(0, 359))
            local dist = math.random(math.floor(radius * 0.35), radius)
            local targetX = center.X + math.cos(angle) * dist
            local targetY = center.Y + math.sin(angle) * dist

            p.Parent = parent

            local flyTime = lifetime * 0.6

            if fadeIn > 0 then
                local inTween = TweenInterface.TweenNodeTransparencyImage(p, 0, fadeIn)
                inTween.Completed:Wait()
            else
                p.ImageTransparency = 0
            end

            local sizeScale = 1 + (math.random() * 2 - 1) * scaleJitter
            local flyInfo = TweenInfo.new(flyTime, easing, Enum.EasingDirection.Out)
            local spinDir = (spinRandom and (math.random(0,1) == 0 and -1 or 1) or 1)
            local endRot = startRot + math.random(-rotRange, rotRange) + (spinTurns * 360 * spinDir)
            local flyTween = TweenInterface.TweenNode(p, flyInfo, {
                Position = UDim2.fromOffset(targetX, targetY),
                Rotation = endRot,
                Size = UDim2.fromOffset(sizePx * sizeScale, sizePx * sizeScale),
            })
            flyTween.Completed:Wait()

            local fadeTween = TweenInterface.TweenNodeTransparencyImage(p, 1, fadeOut)
            fadeTween.Completed:Wait()

            p:Destroy()
        end)
    end
end

-- 在控件中心播放 2D 伪粒子爆发（函数级注释）：
-- @param target GuiObject 目标控件（用于取中心像素坐标）
-- @param params table 同 PlayUIBurst 的参数表；需包含 image 等必要参数
--   container: ScreenGui/GuiObject 指定粒子容器（可选，默认控件所在的 ScreenGui）
--   centerOffset: Vector2 额外像素偏移（可选，用于视觉校准，如 Vector2.new(0, 24)）
--   centerFromPivot: boolean 使用控件 Pivot(AnchorPoint) 作为中心（默认 false，使用几何中心）
-- @return nil
function UIEffects.PlayAtControlCenter(target, params)
    if not target then return end
    -- 计算物理屏幕坐标下的控件中心（支持几何中心或 Pivot 中心）
    local topLeft = GetScreenTopLeft(target)
    local size = target.AbsoluteSize
    local centerScreen
    params = params or {}
    if params.centerFromPivot then
        local a = target.AnchorPoint or Vector2.new(0, 0)
        centerScreen = Vector2.new(topLeft.X + size.X * a.X, topLeft.Y + size.Y * a.Y)
    else
        centerScreen = Vector2.new(topLeft.X + size.X * 0.5, topLeft.Y + size.Y * 0.5)
    end
    if params.centerOffset and typeof(params.centerOffset) == "Vector2" then
        centerScreen = centerScreen + params.centerOffset
    end

    -- 选择容器：优先使用传入 container，其次控件所属 ScreenGui
    local container = params.container or target:FindFirstAncestorOfClass("ScreenGui") or target.Parent
    if not container then return end

    -- 统一转换为容器局部坐标
    local finalCenter = ScreenToContainer(container, centerScreen)
    UIEffects.PlayUIBurst(container, finalCenter, params)
end

-- 在屏幕中心播放 2D 伪粒子爆发（函数级注释）：
-- @param screenGui ScreenGui 容器（用于取屏幕尺寸）
-- @param params table 同 PlayUIBurst 的参数表
-- @return nil
function UIEffects.PlayAtScreenCenter(screenGui, params)
    if not screenGui then return end
    local size = screenGui.AbsoluteSize
    local center = Vector2.new(size.X * 0.5, size.Y * 0.5)
    UIEffects.PlayUIBurst(screenGui, center, params)
end

return UIEffects
