--[[]]
-- CombatText.client.lua（客户端）
-- 玩家加血/掉血冒泡数字显示
--
-- 需求点实现：
-- （一）数字叠加处理：同一目标在短时间内多次显示时，采用纵向堆叠，并附加±2~3像素的横向微偏移，避免完全重叠。
-- （二）透明度过渡：数字弹出时完全不透明（Alpha=1），在消失倒计时的最后0.2秒内渐隐至0。
-- 方向：加血数字向上移动，掉血数字向下移动（UI坐标系内的Y轴方向）。

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))

-- 配置
local TOTAL_DURATION = 0.8          -- 总持续时间（秒）
local CRIT_TOTAL_DURATION = 1.2     -- 暴击时总持续时间（秒）
local FADE_OUT_DURATION = 0.2       -- 渐隐持续时间（秒）
local STACK_WINDOW = 0.5            -- 多次触发叠加的时间窗口（秒）
local STACK_STEP_STUDS = 0.5        -- 垂直堆叠步进（单位：stud）
local HORIZONTAL_JITTER_MIN = 0.08  -- 横向抖动最小（单位：stud）
local HORIZONTAL_JITTER_MAX = 0.12  -- 横向抖动最大（单位：stud）
-- 注意：BillboardGui 使用世界坐标，Y 轴正方向为“向上”。
-- 因此：加血（向上）应为正数；掉血（向下）应为负数。
local UP_OFFSET = 1.5               -- 加血向上偏移（单位：stud，正）
local CRIT_UP_OFFSET = 2.0          -- 暴击时加血向上偏移（单位：stud，正）
local DOWN_OFFSET = -1.5            -- 掉血向下偏移（单位：stud，负）
local CRIT_DOWN_OFFSET = -2.0       -- 暴击时掉血向下偏移（单位：stud，负）
local ARC_MAX_HORIZONTAL = 0.6      -- 抛物线最大水平偏移（单位：stud）（在中点达到最大）
local CRIT_ARC_MAX_HORIZONTAL = 0.8 -- 暴击时抛物线最大水平偏移（单位：stud）（在中点达到最大）
local CRIT_SIZE_MULTIPLIER = 1.75   -- 暴击时整体字号与容器尺寸放大比例（适度放大，避免裁剪）

-- 关键阈值（可根据游戏数值平衡调整）
local CRIT_THRESHOLD = 60           -- 暴击阈值：数值达到或超过该值则视为暴击（仅用于客户端样式选择）

--[[]]
-- 样式配置表：不同类型的冒泡数字使用不同样式（颜色、字号、描边等）
-- 你可以根据项目美术规范修改这些参数，或在运行时覆写（见下方 StyleResolver）
local STYLE_CONFIG = {
    heal = {
        textColor = Color3.fromRGB(152, 251, 152),
        textSize = 40,
        strokeColor = Color3.fromRGB(60, 140, 60),
        strokeTransparency = 0.6,
        labelSize = {w = 90, h = 34},
        arcMaxHorizontalMultiplier = 1.0,
        moveDistanceMultiplier = 1.0,
    },
    damage = {
        textColor = Color3.fromRGB(255, 60, 60),
        textSize = 44,
        strokeColor = Color3.fromRGB(140, 20, 20),
        strokeTransparency = 0.6,
        labelSize = {w = 96, h = 36},
        arcMaxHorizontalMultiplier = 1.0,
        moveDistanceMultiplier = 1.0,
    },
    critHeal = {
        textColor = Color3.fromRGB(120, 255, 120),
        textSize = 52,
        strokeColor = Color3.fromRGB(40, 120, 40),
        strokeTransparency = 0.5,
        labelSize = {w = 110, h = 42},
        arcMaxHorizontalMultiplier = 1.2, -- 暴击时水平弧度更大
        moveDistanceMultiplier = 1.15,    -- 暴击时竖直位移稍大
    },
    critDamage = {
        textColor = Color3.fromRGB(255, 200, 40), -- 金色，突出暴击
        textSize = 56,
        strokeColor = Color3.fromRGB(160, 100, 0),
        strokeTransparency = 0.4,
        labelSize = {w = 120, h = 44},
        arcMaxHorizontalMultiplier = 1.25,
        moveDistanceMultiplier = 1.2,
    },
}

-- 可选：外部样式解析器（供其他系统在运行时指定样式）
-- 如果设置了 _G.CombatTextStyleResolver(worldPos, amount) 并返回有效样式key或样式表，则优先使用外部定义
-- 外部返回值可以是：
-- 1) 字符串样式key（例如 "heal"、"damage"、"critDamage"）；
-- 2) 样式表（包含 STYLE_CONFIG 相同字段），将与默认样式浅合并。
-- 注意：仅客户端生效，不影响其他玩家显示
local function resolveStyle(worldPos, amount)
    -- 默认样式选择：根据加血/掉血与阈值判定是否暴击
    local isHeal = amount >= 0
    local absAmount = math.abs(amount)
    local defaultKey
    if absAmount >= CRIT_THRESHOLD then
        defaultKey = isHeal and "critHeal" or "critDamage"
    else
        defaultKey = isHeal and "heal" or "damage"
    end
    local defaultStyle = STYLE_CONFIG[defaultKey]

    -- 外部解析器支持（可选）
    local resolver = rawget(_G, "CombatTextStyleResolver")
    if type(resolver) == "function" then
        local ok, res = pcall(resolver, worldPos, amount)
        if ok and res ~= nil then
            if type(res) == "string" and STYLE_CONFIG[res] then
                return STYLE_CONFIG[res]
            elseif type(res) == "table" then
                -- 浅合并：外部传入的字段覆盖默认字段
                local merged = {}
                for k, v in pairs(defaultStyle) do merged[k] = v end
                for k, v in pairs(res) do merged[k] = v end
                return merged
            end
        end
    end

    return defaultStyle
end

--============================
-- 基于世界坐标的屏幕投影显示（按现有Knit事件）
--============================

-- 针对世界坐标的堆叠记录（按位置散列）
local posStacks = {}

--[[]]
-- 将世界坐标量化为字符串Key，用于堆叠判断
-- @param worldPos Vector3 世界坐标
-- @return string 量化后的位置Key
local function stackKeyFromWorldPos(worldPos)
    local qx = math.floor(worldPos.X + 0.5)
    local qy = math.floor(worldPos.Y + 0.5)
    local qz = math.floor(worldPos.Z + 0.5)
    return string.format("%d|%d|%d", qx, qy, qz)
end

-- 屏幕容器
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- 活跃屏幕标签，渲染时驱动其位置与渐隐
local activeLabels = {}

--[[]]
-- 暴击动画：为文本标签添加弹跳缩放与旋转复位（函数级注释）
-- 目的：增强暴击的瞬时冲击感，同时保持与现有抛物线轨迹兼容
-- 实现：
-- 1) UIScale 从 1.25 回到 1.0（Back-Out），形成弹跳感；
-- 2) 文本先轻微倾斜（-6°），随后 0.18s 内平滑复位到 0°（Quint-Out）；
-- @param label TextLabel 要应用动画的标签
-- @return void
local function playCritAnimation(label)
    if not label then return end
    -- 缩放动画（弹跳）
    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 1.25
    uiScale.Parent = label
    local scaleTween = TweenService:Create(
        uiScale,
        TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    )
    scaleTween:Play()
    -- 旋转复位动画（动感）
    label.Rotation = -6
    local rotTween = TweenService:Create(
        label,
        TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Rotation = 0 }
    )
    rotTween:Play()
end

--[[]]
-- 世界坐标转换为屏幕坐标
-- @param worldPos Vector3 世界坐标
-- @return Vector2 屏幕坐标, boolean 是否在屏幕内
-- BillboardGui 绑定到世界中的部件，不再需要世界到屏幕坐标转换

--[[]]
-- 判断传入对象是否属于某个玩家的角色
-- @param inst Instance 可能是 BasePart、Model 或 Player
-- @return Player|nil 如果是玩家的角色，返回该玩家；否则返回nil
local function getPlayerFromInstance(inst)
    local PlayersService = Players
    if not inst then return nil end
    -- 若直接是 Player
    if inst:IsA("Player") then
        return inst
    end
    -- 向上查找角色模型
    local current = inst
    while current and not current:IsA("Model") do
        current = current.Parent
    end
    if current and current:IsA("Model") then
        local p = PlayersService:GetPlayerFromCharacter(current)
        if p then return p end
    end
    return nil
end

--[[]]
-- 生成并管理一个基于世界坐标的冒泡数字（屏幕投影）
-- 满足：叠加（同一位置短时间堆叠）、完全不透明弹出、末尾0.2s渐隐、加血向上/掉血向下
-- @param worldPos Vector3 世界坐标（来自服务器事件）
-- @param amount number 数值（正为加血，负为掉血）
--[[]]
-- 在世界坐标创建一个 BillboardGui 冒泡数字
-- 使用临时的本地不可见 Part 作为 Adornee，BillboardGui 绑定其上
-- 轨迹采用抛物线：
-- 垂直位移 y(t) = baseY + sign * distance * t^2
-- 水平位移 x(t) = jitter + arcX * (4*t*(1-t))
-- @param worldPos Vector3 世界坐标（来自服务器事件）
-- @param amount number 数值（正为加血，负为掉血）
--[[]]
-- 在世界坐标创建一个 BillboardGui 冒泡数字（函数级注释）：
-- 功能：
-- 1) 普通冒泡：保持现有加血/掉血样式与轨迹；
-- 2) 暴击冒泡：当 isCrit 为 true 时，强制使用暴击样式（颜色、字号、弧度与位移倍率更高），
--    并新增“弹跳放大”与“旋转复位”动画以增强视觉冲击；
-- 3) 玩家受击颜色覆盖：仅在非暴击时对玩家掉血改为近白色（240,240,240），暴击保留金色以突出效果；
-- 4) 叠加：同一位置短时间内堆叠，采用纵向位移与少量横向抖动；
-- 参数：
-- @param part Instance 目标部件或模型（用于确定世界位置、判断是否玩家）
-- @param amount number 数值（正为加血，负为掉血）
-- @param isCrit boolean 是否为暴击（true 则采用暴击样式与动画）
local function spawnBillboardLabelAtWorld(part, amount, isCrit)
    local isHeal = amount >= 0
    local textValue = ""
    if  isHeal then
        textValue = "+" .. tostring(math.abs(amount))
    else
        textValue = "-" .. tostring(math.abs(amount))
    end

    local worldPos = Vector3.new(part.Position.X, part.Position.Y + part.Size.Y / 2 + 1, part.Position.Z)
    -- 叠加处理（按世界坐标散列）
    local key = stackKeyFromWorldPos(worldPos)
    local stackRec = posStacks[key]
    local now = tick()
    if stackRec and (now - stackRec.lastTime <= STACK_WINDOW) then
        stackRec.index = stackRec.index + 1
        stackRec.lastTime = now
    else
        stackRec = { index = 0, lastTime = now }
        posStacks[key] = stackRec
    end

    -- 创建临时本地不可见的部件作为 Adornee
    local adPart = Instance.new("Part")
    adPart.Name = "CombatTextAdornee"
    adPart.Anchored = true
    adPart.CanCollide = false
    adPart.CanQuery = false
    adPart.Transparency = 1
    adPart.Size = Vector3.new(0.2, 0.2, 0.2)
    adPart.CFrame = CFrame.new(worldPos)
    adPart.Parent = workspace

    -- 解析样式（包含字号、颜色、描边、容器尺寸、弧度倍率等）
    local style = resolveStyle(worldPos, amount)
    -- 当 isCrit 为 true，强制采用暴击样式（覆盖默认解析结果）
    if isCrit then
        local critKey = isHeal and "critHeal" or "critDamage"
        local critStyle = STYLE_CONFIG[critKey]
        if critStyle then
            local merged = {}
            for k, v in pairs(style) do merged[k] = v end
            for k, v in pairs(critStyle) do merged[k] = v end
            style = merged
        end
    end
    -- 若目标为玩家且为掉血，且非暴击，则将文本颜色覆写为 240,240,240（不影响其他样式字段）
    local targetPlayer = getPlayerFromInstance(part)
    if (not isHeal) and targetPlayer ~= nil and not isCrit then
        local merged = {}
        for k, v in pairs(style) do merged[k] = v end
        merged.textColor = Color3.fromRGB(240, 240, 240)
        style = merged
    end

    -- BillboardGui 容器
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "CombatTextBillboard"
    billboard.Adornee = adPart
    -- 暴击时放大容器尺寸，防止文字溢出
    local sizeMul = (isCrit and CRIT_SIZE_MULTIPLIER) or 1.0
    local bwBase = (style.labelSize and style.labelSize.w) or 100
    local bhBase = (style.labelSize and style.labelSize.h) or 40
    local bw = math.floor(bwBase * sizeMul)
    local bh = math.floor(bhBase * sizeMul)
    billboard.Size = UDim2.fromOffset(bw, bh)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
    billboard.Parent = playerGui

    -- 文本标签
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Text = textValue
    label.FontFace = GameConfig.FontFace
    -- 暴击时文字更大：在原样式基础上额外乘以放大系数
    local textSizeBase = style.textSize or 48
    label.TextSize = math.floor(textSizeBase * sizeMul)
    label.TextStrokeTransparency = style.strokeTransparency or 0.6
    if style.strokeColor then label.TextStrokeColor3 = style.strokeColor end
    label.TextTransparency = 0 -- 完全不透明弹出
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Size = UDim2.fromOffset(bw, bh)
    label.ZIndex = isCrit and 11 or 10
    label.TextColor3 = style.textColor or Color3.fromRGB(255, 255, 255)
    -- 将文本居中到 BillboardGui 容器中心，避免出现“偏左/偏上”现象
    label.Position = UDim2.fromScale(0.5, 0.5)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = billboard
    -- 暴击：追加动画（弹跳缩放 + 旋转复位）
    if isCrit then
        playCritAnimation(label)
    end

    -- 横向微抖动（单位：stud）与纵向堆叠
    local jitter = HORIZONTAL_JITTER_MIN + math.random() * (HORIZONTAL_JITTER_MAX - HORIZONTAL_JITTER_MIN)
    jitter = (math.random(0, 1) == 0) and -jitter or jitter
    local baseY = stackRec.index * STACK_STEP_STUDS

    local createdAt = tick()
    local duration = isCrit and CRIT_TOTAL_DURATION or TOTAL_DURATION
    local fadeStart = duration - FADE_OUT_DURATION
    -- 轨迹参数：抛物线（世界偏移）
    local moveOffset = isHeal and (isCrit and CRIT_UP_OFFSET or UP_OFFSET) or (isCrit and CRIT_DOWN_OFFSET or DOWN_OFFSET)
    local moveDistance = math.abs(moveOffset) * (style.moveDistanceMultiplier or 1.0) -- 位移幅度（stud）
    local moveSign = (moveOffset < 0) and -1 or 1     -- 方向注释：上为+1，下为-1（世界坐标Y轴：上正下负）
    local arcX = (math.random(0,1) == 0 and -1 or 1) * (isCrit and CRIT_ARC_MAX_HORIZONTAL or ARC_MAX_HORIZONTAL) * (style.arcMaxHorizontalMultiplier or 1.0) -- 水平抛物线最大偏移（中点达到峰值，stud）

    -- 初始世界偏移（BillboardGui）
    billboard.StudsOffsetWorldSpace = Vector3.new(jitter, baseY, 0)

    -- 将该标签加入活跃列表，由渲染循环驱动其位置与渐隐
    table.insert(activeLabels, {
        label = label,
        billboard = billboard,
        adPart = adPart,
        jitter = jitter,
        baseY = baseY,
        createdAt = createdAt,
        duration = duration,
        fadeStart = fadeStart,
        moveDistance = moveDistance,
        moveSign = moveSign,
        arcX = arcX,
    })
end

--[[]]
-- 渲染循环：更新活跃标签的位置与透明度
-- 保证在最后0.2秒内渐隐，同时加血向上、掉血向下移动
local function updateActiveLabels()
    local now = tick()
    for i = #activeLabels, 1, -1 do
        local item = activeLabels[i]
        local elapsed = now - item.createdAt
        local progress = math.clamp(elapsed / item.duration, 0, 1)

        -- BillboardGui：抛物线轨迹（世界偏移）
        local curY = item.baseY + (item.moveSign * item.moveDistance * (progress * progress))
        local arcXOffset = item.arcX * (4 * progress * (1 - progress))
        item.billboard.StudsOffsetWorldSpace = Vector3.new(item.jitter + arcXOffset, curY, 0)

        -- 渐隐控制：最后0.2秒内线性至透明
        if elapsed >= item.fadeStart then
            local fadeProgress = math.clamp((elapsed - item.fadeStart) / FADE_OUT_DURATION, 0, 1)
            item.label.TextTransparency = fadeProgress
        end

        -- 生命周期结束：移除
        if elapsed >= item.duration then
            item.label:Destroy()
            if item.billboard then item.billboard:Destroy() end
            if item.adPart then item.adPart:Destroy() end
            table.remove(activeLabels, i)
        end
    end
end

RunService.RenderStepped:Connect(updateActiveLabels)

Knit.OnStart():andThen(function()
    Knit.GetService("ClientUIService").ChangeHp:Connect(function(part, amount, isCrit)
        spawnBillboardLabelAtWorld(part, amount, isCrit)
    end)
end)