local Interface = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local UserInputService = game:GetService("UserInputService")
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

--[[
    深拷贝函数 - 递归复制表结构
    @param original table 原始表
    @return table 深拷贝后的新表
]]
function Interface.clone(original)
    if type(original) ~= "table" then
        return original
    end
    
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = Interface.clone(value)
    end
    
    return copy
end

-- 预加载并设置 ImageLabel 的图片（函数级注释）：
-- @param img ImageLabel 目标图像控件
-- @param source Instance|string Texture/Decal实例，或asset id字符串（支持纯数字或rbxassetid://前缀）
-- @param timeout number 可选，最大等待时长（秒），默认2.0；超过也不报错，仅结束等待
-- @return boolean 是否成功触发并完成预加载（true表示已完成，false表示超时或失败）
function Interface.PreloadImageForLabel(img, source, timeout)
    timeout = timeout or 2.0
    if not img or not img:IsA("ImageLabel") then
        return false
    end

    -- 转换为内容ID字符串
    local function toContentId(src)
        if typeof(src) == "string" then
            if src:match("^rbxassetid://") or src:match("^https?://") then
                return src
            elseif src:match("^%d+$/?") or src:match("^%d+$") then
                -- 兼容可能带斜杠的数字字符串
                local id = src:gsub("/", "")
                return "rbxassetid://" .. id
            end
        elseif typeof(src) == "Instance" then
            if src:IsA("Texture") or src:IsA("Decal") then
                return src.Texture
            end
        end
        return nil
    end

    local cid = toContentId(source)
    if not cid then
        return false
    end

    -- 先设置 Image，再进行预加载（对ImageLabel生效）
    img.Image = cid

    local ok, err = pcall(function()
        -- ContentProvider:PreloadAsync 会在资源加载完成后返回
        local finished = false
        local done = false
        task.spawn(function()
            ContentProvider:PreloadAsync({ img })
            finished = true
        end)
        local start = os.clock()
        while not finished do
            if os.clock() - start >= timeout then
                done = false
                break
            end
            task.wait(0.03)
        end
        if finished then
            done = true
        end
        return done
    end)

    if not ok then
        warn("PreloadImageForLabel failed:", err)
        return false
    end
    return true
end

-- 随机打乱一个数组
function Interface.randomTable(t)
    -- 数组随机打乱
    local array = {}
    for _, posData in pairs(t) do
        table.insert(array, posData)
    end
    
    -- Fisher-Yates洗牌算法随机打乱数组
    for i = #array, 2, -1 do
        local j = math.random(i)
        array[i], array[j] = array[j], array[i]
    end
    return array
end

function Interface.formatTimeMMSS(seconds)
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", minutes, secs)
end

-- 使用多层射线检测获取真正的地面位置
-- @param startPosition Vector3 起始位置
-- @param ignoreList table 忽略的实例列表
-- @return Vector3 地面位置，如果没有检测到则返回原位置
function Interface.getGroundPosition(startPosition, ignoreList)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = ignoreList or {}
    
    local currentPosition = startPosition
    local totalHeightDrop = 0
    local maxLayers = 5 -- 最多检测5层
    local minHeightDrop = 3 -- 最小高度差要求
    
    for layer = 1, maxLayers do
        -- 从当前位置向下发射射线
        local rayDirection = Vector3.new(0, -100, 0)
        local raycastResult = workspace:Raycast(currentPosition, rayDirection, raycastParams)
        
        if raycastResult then
            local hitPosition = raycastResult.Position
            local layerHeightDrop = currentPosition.Y - hitPosition.Y
            totalHeightDrop = totalHeightDrop + layerHeightDrop
            
            -- 检查是否是足够厚的地面
            if layerHeightDrop >= minHeightDrop and totalHeightDrop >= minHeightDrop then
                local groundPosition = hitPosition + Vector3.new(0, 0.1, 0)
                return groundPosition
            elseif layerHeightDrop < 0.5 then
                -- 击中了很薄的结构，继续向下检测
                currentPosition = hitPosition - Vector3.new(0, 0.1, 0) -- 稍微向下偏移继续检测
                
                -- 将击中的物体加入忽略列表，避免重复击中
                if raycastResult.Instance then
                    table.insert(raycastParams.FilterDescendantsInstances, raycastResult.Instance)
                end
            else
                -- 找到了有一定厚度的地面
                if totalHeightDrop >= minHeightDrop then
                    local groundPosition = hitPosition + Vector3.new(0, 0.1, 0)
                    return groundPosition
                else
                    -- 高度差不够，继续检测
                    currentPosition = hitPosition - Vector3.new(0, 0.1, 0)
                end
            end
        else
            -- 没有击中任何物体
            print("第", layer, "层未击中任何物体")
            break
        end
    end
    
    -- 所有检测都失败，返回一个安全的地面位置
    local safeGroundPosition = Vector3.new(startPosition.X, startPosition.Y - 10, startPosition.Z)
    return safeGroundPosition
end

--[[
    更精确的手机检测（推荐使用）
    结合多种因素判断，包括屏幕尺寸、安全区域、输入方式等
    @return boolean 如果是手机设备返回true，否则返回false
]]
function Interface.isMobile()
    -- 必须有触摸屏
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and
           not UserInputService.MouseEnabled then
        return true
    end
    return false
end

--[[
    安全等待子对象出现
    @param parent Instance 父对象
    @param child string 子对象名称
    @param time number 超时时间（秒），默认1秒
    @return Instance 子对象，如果超时返回nil
]]
function Interface.safeWaitPart(parent, childName, time)
    time = time or 1
    local child = parent:FindFirstChild(childName)
    while not child do
        task.wait(time)
        child = parent:FindFirstChild(childName)
    end
    return child
end

function Interface.GetDuanWeiIcon(duanweiData)
    if not duanweiData then
        return
    end
    local duanwei = tonumber(duanweiData.duanWei)
    if not duanwei then
        return
    end
    local level = tonumber(duanweiData.level)
    if not level then
        return
    end
    local duanweiConfig = GameConfig.DuanWeiType[duanwei]
    if not duanweiConfig then
        return
    end
    return duanweiConfig.icons[level]
end

--[[
    计算 DuanWei 升级
    @param duanWeiData table DuanWei 数据
    @param escapeSucc boolean 是否成功逃脱
    @return table 更新后的 DuanWei 数据
]]
function Interface.calculateDuanWei(duanWeiData, escapeSucc)
    local tempData = Interface.clone(duanWeiData)
    local DuanWeiType = GameConfig.DuanWeiType
    if escapeSucc then
        tempData.star += 1
        -- 到达当前升级星数
        if tempData.star > DuanWeiType[tempData.duanWei].levelStarNum
        and DuanWeiType[tempData.duanWei].levelStarNum ~= -1 then
            tempData.level += 1
            tempData.star = 1
        end

        -- 到达当前升段位标准
        if tempData.level > DuanWeiType[tempData.duanWei].levelNum
        and DuanWeiType[tempData.duanWei].levelNum ~= -1 then
            tempData.duanWei = math.min(tempData.duanWei + 1, #DuanWeiType)
            tempData.level = 1
            tempData.star = 1
        end
    else
        if DuanWeiType[tempData.duanWei].allowDeduction then
            tempData.star = tempData.star - 1
            if tempData.star <= 0 then
                tempData.level = tempData.level - 1
                if tempData.level <= 0 then
                    if tempData.duanWei > 1 then
                        tempData.duanWei = tempData.duanWei - 1
                        tempData.level = DuanWeiType[tempData.duanWei].levelNum
                        tempData.star = DuanWeiType[tempData.duanWei].levelStarNum
                    else
                        tempData.duanWei = 1
                        tempData.level = 1
                        tempData.star = 0
                    end
                else
                    tempData.star = DuanWeiType[tempData.duanWei].levelStarNum
                end
            end
        end
    end

    return tempData
end

--[[
    判断一个点是否在地形水体内
    @param point Vector3 要判断的点
    @return boolean 如果在水体内返回true，否则返回false
]]
-- 判断一个点是否在地形水体内（函数级注释）：
-- 说明：
-- - 使用 Terrain:ReadVoxels 读取该点所在的体素材质；
-- - 注意 Region3:ExpandToGrid 会对齐到体素网格，返回的 materials 索引 [1][1][1]
--   并不保证是“点所在体素”，若点靠近体素边界，可能命中相邻体素（例如岩石 Slate）。
-- - 为避免误判，需计算“点所在体素”与“区域最小体素”的差，得到正确的索引后读取材质。
-- @param point Vector3 要判断的世界坐标点
-- @return boolean 若该点所在体素材质为 Water 返回 true，否则返回 false
function Interface.isPointInTerrainWater(point)
    local Terrain = workspace:FindFirstChildOfClass("Terrain")
    if not Terrain then return false end

    local voxelResolution = 4  -- Roblox Terrain 的体素分辨率为 4
    -- 以 point 为中心构造一个体素大小的 Region3，并对齐到网格
    local region = Region3.new(
        point - Vector3.new(voxelResolution/2, voxelResolution/2, voxelResolution/2),
        point + Vector3.new(voxelResolution/2, voxelResolution/2, voxelResolution/2)
    ):ExpandToGrid(voxelResolution)

    local materials, _ = Terrain:ReadVoxels(region, voxelResolution)

    -- 计算区域世界坐标最小点（对齐后的），并转换为体素坐标
    local regionCenter = region.CFrame.Position
    local regionSize = region.Size
    local regionMin = regionCenter - (regionSize * 0.5)
    local minCell = Terrain:WorldToCell(regionMin)
    local pointCell = Terrain:WorldToCell(point)

    -- 计算点所在体素相对于区域起始体素的索引（Lua 索引从 1 开始）
    local ix = math.max(1, (pointCell.X - minCell.X) + 1)
    local iy = math.max(1, (pointCell.Y - minCell.Y) + 1)
    local iz = math.max(1, (pointCell.Z - minCell.Z) + 1)

    -- 边界保护：若区域尺寸为 1x1x1，则索引最多为 1
    local maxX = #materials
    local maxY = #materials[1]
    local maxZ = #materials[1][1]
    ix = math.min(ix, maxX)
    iy = math.min(iy, maxY)
    iz = math.min(iz, maxZ)

    local mat = materials[ix][iy][iz]
    return mat == Enum.Material.Water
end

-- 检测玩家是否在游泳
-- 判断玩家是否在水中（函数级注释）：
-- 行为：
-- 1) Swimming 状态下直接返回 true；
-- 2) 水面跳跃：若 HRP 下方 3 studs 内是 Terrain 的 Water，也返回 true；
-- 3) 体素检测：脚下采样点在 Water 体素内返回 true；
-- 4) ForceField 存在时返回 false（无敌不受水影响）。
-- @param character Model 玩家角色模型
-- @return boolean 是否判定为在水中
function Interface.IsPlayerInWater(character)
    if not character then return false end

    if character:FindFirstChild("ForceField") then
        return false  -- 有无敌时不受水中伤害
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    if humanoid:GetState() == Enum.HumanoidStateType.Swimming then return true end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end

    -- 水面邻近检测：从 HRP 向下少量距离仅检测 Terrain 的 Water
    local SURFACE_CHECK_DEPTH = 3
    local Terrain = workspace:FindFirstChildOfClass("Terrain")
    if Terrain then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { Terrain }
        local res = workspace:Raycast(humanoidRootPart.Position, Vector3.new(0, -SURFACE_CHECK_DEPTH, 0), params)
        if res and res.Instance == Terrain and res.Material == Enum.Material.Water then
            return true
        end
    end

    -- 体素检测：脚下采样点在水体内
    local position = humanoidRootPart.Position
    local point = Vector3.new(position.X, position.Y - humanoid.HipHeight - humanoidRootPart.Size.Y / 2, position.Z)
    return Interface.isPointInTerrainWater(point)
end

-- 使用射线检测玩家是否真正站在Model上
-- @param player Player 要检查的玩家
-- @param triggerModel Model 要检测的Model
-- @return boolean, number 是否在撤离区内以及高度差
function Interface.checkPlayerOnModel(player, triggerModel)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local humanoidRootPart = player.Character.HumanoidRootPart
    local playerPosition = humanoidRootPart.Position
    
    -- 创建射线检测参数
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Include
    raycastParams.FilterDescendantsInstances = {triggerModel}
    
    -- 从玩家脚下向下发射射线
    local rayOrigin = playerPosition + Vector3.new(0, 1, 0) -- 稍微抬高起点
    local rayDirection = Vector3.new(0, -10, 0)
    
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if raycastResult then
        local hitPart = raycastResult.Instance
        local hitPosition = raycastResult.Position
        
        -- 检查射线是否击中了triggerModel中的Part
        if hitPart and hitPart:IsDescendantOf(triggerModel) then
            -- 计算玩家位置到击中点的距离（使用HumanoidRootPart位置更准确）
            local heightDifference = playerPosition.Y - hitPosition.Y
            
            -- 当玩家站在船上的物体上时，heightDifference可能是负数
            -- 我们需要检查玩家是否在合理的高度范围内（可以在船体上方或下方一定距离）
            if math.abs(heightDifference) <= 5 then
                return true
            end
        end
    end
    
    return false
end

-- 检查玩家是否站在船上面
-- @param player Player 要检查的玩家
-- @return boolean 是否站在船上面
function Interface.isPlayerOnBoat(player, islandName)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    local land = Interface.safeWaitPart(workspace, islandName)
    local special = Interface.safeWaitPart(land, "Special")
    -- 检查每个触发Model
    for _, modelName in ipairs(GameConfig.TeleportPartNames) do
        local triggerModel = Interface.safeWaitPart(special, modelName)
        if triggerModel and triggerModel:IsA("Model") then
            return Interface.checkPlayerOnModel(player, triggerModel)
        end
    end
    
    return false
end

-- 存储每个TextLabel的动画状态，避免重复动画冲突
local animationStates = {}

--[[
    数字递增动画接口
    @param labelOrFrom TextLabel|number 如果是TextLabel则自动更新文本，如果是数字则作为起始值
    @param to number 目标值
    @return NumberValue 可监听Changed事件的数值容器
    @return Tween 动画对象（可用于控制暂停/取消）
]]
function Interface.AnimateNumberIncrease(labelOrFrom, to)
    local label = nil
    local from = 0
    local target = 0

    if typeof(labelOrFrom) == "Instance" and labelOrFrom:IsA("TextLabel") then
        label = labelOrFrom
        from = tonumber(label.Text) or 0
        target = tonumber(to) or from
        
        -- 如果该TextLabel已有动画在运行，先取消旧动画
        if animationStates[label] then
            local oldState = animationStates[label]
            if oldState.tween then
                oldState.tween:Cancel()
            end
            if oldState.num then
                oldState.num:Destroy()
            end
            -- 从当前动画值开始新动画，保持连贯性
            from = oldState.num and oldState.num.Value or from
        end
    else
        from = tonumber(labelOrFrom) or 0
        target = tonumber(to) or from
    end

    -- 使用NumberValue承载动画数值，便于外部监听数值变化
    local num = Instance.new("NumberValue")
    num.Name = "Interface_AnimateNumber"
    num.Value = from

    -- 根据数值差计算时长：保持统一速度，限定上下限
    local delta = math.abs(target - from)
    local duration = math.clamp(delta / 100, 0.3, 1)

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(num, tweenInfo, { Value = target })

    -- 如果传入了TextLabel，则自动更新文本显示（取整）
    if label then
        -- 记录当前动画状态
        animationStates[label] = {
            num = num,
            tween = tween
        }
        
        num.Changed:Connect(function(v)
            label.Text = tostring(math.floor(v))
        end)
    end

    tween:Play()
    
    -- 动画完成时的清理工作
    tween.Completed:Connect(function()
        num.Value = target
        if label then
            label.Text = tostring(math.floor(target))
            -- 清理动画状态记录
            animationStates[label] = nil
        end
        -- 清理NumberValue对象
        num:Destroy()
    end)
    
    return num, tween
end

-- 将进度条通过补间动画平滑更新（函数级注释）：
-- @param bar GuiObject 进度条UI对象（通常为 Frame 或 ImageLabel）
-- @param targetRatio number 目标比例（0-1），会被 clamp 到 [0,1]
-- @param duration number 动画时长（秒），可选，默认 0.35 秒
-- @return void
function Interface.TweenProgressBarSize(bar, targetRatio, duration)
    duration = duration or 0.35
    if not bar or not bar:IsA("GuiObject") then
        return
    end
    targetRatio = math.clamp(targetRatio or 0, 0, 1)
    local currentSize = bar.Size
    local goal = {
        Size = UDim2.new(targetRatio, 0, currentSize.Y.Scale, currentSize.Y.Offset),
    }
    local info = TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local tween = TweenService:Create(bar, info, goal)
    tween:Play()
end

-- 启动Gui颜色黑色脉冲循环（函数级注释）：
-- @param gui GuiObject 需要循环变色的UI对象（Frame/ImageLabel/TextLabel等）
-- @param toBlackDuration number 变为黑色的时长（秒），默认1.0
-- @param backDuration number 从黑色恢复到原色的时长（秒），默认1.0
-- 行为：持续“到黑→回原”循环，直到调用 StopPulseGuiColorLoop 或对象销毁
function Interface.StartPulseGuiColorLoop(gui, toColor, toBlackDuration, backDuration)
    if not gui or not gui:IsA("GuiObject") then
        return
    end
    -- 已在循环中则跳过
    if gui:GetAttribute("Interface_ColorPulseLoopRunning") then
        return
    end
    gui:SetAttribute("Interface_ColorPulseLoopRunning", true)

    toBlackDuration = toBlackDuration or 1.0
    backDuration = backDuration or 1.0

    local function getColorPropName(instance)
        if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
            return "ImageColor3"
        elseif instance:IsA("TextLabel") or instance:IsA("TextButton") then
            return "TextColor3"
        else
            return "BackgroundColor3"
        end
    end

    local propName = getColorPropName(gui)
    -- 读取当前颜色（允许外部改变原色时能跟随）
    local ok1, initColor = pcall(function()
        return gui[propName]
    end)
    task.spawn(function()
        while gui.Parent and gui:GetAttribute("Interface_ColorPulseLoopRunning") do
            -- 读取当前颜色（允许外部改变原色时能跟随）
            local ok2, currentColor = pcall(function()
                return gui[propName]
            end)
            if not ok2 or typeof(currentColor) ~= "Color3" then
                break
            end

            local tweenToBlack = TweenService:Create(gui, TweenInfo.new(toBlackDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { [propName] = toColor })
            tweenToBlack:Play()
            tweenToBlack.Completed:Wait()

            -- 循环可能在到黑期间被停止
            if not gui.Parent or not gui:GetAttribute("Interface_ColorPulseLoopRunning") then
                break
            end

            local tweenBack = TweenService:Create(gui, TweenInfo.new(backDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { [propName] = currentColor })
            tweenBack:Play()
            tweenBack.Completed:Wait()
        end

        pcall(function()
            gui[propName] = initColor
        end)
        gui:SetAttribute("Interface_ColorPulseLoopRunning", false)
    end)
end

-- 停止Gui颜色黑色脉冲循环（函数级注释）：
-- @param gui GuiObject 待停止的UI对象
-- 行为：将运行标记置为false，正在进行的当前补间完成后退出循环
function Interface.StopPulseGuiColorLoop(gui)
    if not gui or not gui:IsA("GuiObject") then
        return
    end
    if gui:GetAttribute("Interface_ColorPulseLoopRunning") then
        gui:SetAttribute("Interface_ColorPulseLoopRunning", false)
    end
end

function Interface.addHp(character, hp)
    if not character or not character.Parent then
        return
    end
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then
        return
    end
    local maxHealth = humanoid.MaxHealth
    local health = humanoid.Health
    humanoid.Health = math.min(health + hp, maxHealth)

    -- local EffectFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Effect")
    -- if not EffectFolder then
    --     return
    -- end
    -- local AddHPEffect = EffectFolder:FindFirstChild("AddHPEffect")
    -- if not AddHPEffect then
    --     return
    -- end
    -- local effect = AddHPEffect:Clone()
    -- effect.Parent = character
    -- effect:PivotTo(CFrame.new(humanoidRootPart.Position.X, humanoidRootPart.Position.Y - humanoid.HipHeight, humanoidRootPart.Position.Z))
    -- -- 使用Debris服务在3秒后自动销毁特效
    -- game:GetService("Debris"):AddItem(effect, 3)

    local part = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    Knit.GetService("ClientUIService"):ChangeHp(part, hp)
end

function Interface.decHp(character, damage, isCrit)
    if not character or not character.Parent then
        return
    end
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then
        return
    end
    humanoid:TakeDamage(damage)
    
    local part = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    Knit.GetService("ClientUIService"):ChangeHp(part, -damage, isCrit)
end

-- 存储每个GuiObject的缩放动画状态，避免重复动画冲突
local uiScaleStates = {}

--[[
    UI显示动画：使用 UIScale 将尺寸从 0 缩放到 1
    @param guiObject GuiObject|ScreenGui 目标UI元素（Frame、ImageLabel、TextLabel等）或屏幕容器
    @param opts table? 可选配置
        - duration number 动画时长（秒），默认 0.1
        - easingStyle Enum.EasingStyle 缓动类型，默认 Quad
        - easingDirection Enum.EasingDirection 缓动方向，默认 Out
        - setVisible boolean 是否在播放前设置为可见：
            GuiObject 使用 Visible=true，ScreenGui/SurfaceGui/BillboardGui 使用 Enabled=true，默认 true
        - center boolean 是否将 AnchorPoint 设为居中 (0.5,0.5)，仅 GuiObject 生效，默认 false
    @return UIScale, Tween 返回 UIScale 与 Tween 对象（便于外部控制/监听）
    说明：
    - 优先使用 UIScale 缩放，不会破坏原始 Size/Position 布局
    - 若目标下不存在 UIScale，会自动创建一个
]]
function Interface.AnimateUIShowScale(guiObject, opts)
    if typeof(guiObject) ~= "Instance" or not guiObject:IsA("GuiBase2d") then
        warn("AnimateUIShowScale: 需要传入 GuiObject 或 ScreenGui（GuiBase2d）")
        return nil, nil
    end

    opts = opts or {}
    local duration = typeof(opts.duration) == "number" and opts.duration or 0.1
    local easingStyle = opts.easingStyle or Enum.EasingStyle.Quad
    local easingDirection = opts.easingDirection or Enum.EasingDirection.Out
    local setVisible = (opts.setVisible == nil) and true or opts.setVisible
    local center = opts.center == true
    local isGuiObject = guiObject:IsA("GuiObject")

    if center and isGuiObject then
        guiObject.AnchorPoint = Vector2.new(0.5, 0.5)
    end
    if setVisible then
        if isGuiObject then
            guiObject.Visible = true
        else
            if guiObject:IsA("ScreenGui") or guiObject:IsA("SurfaceGui") or guiObject:IsA("BillboardGui") then
                guiObject.Enabled = true
            end
        end
    end

    local scale = guiObject:FindFirstChildOfClass("UIScale")
    if not scale then
        scale = Instance.new("UIScale")
        scale.Scale = 0
        scale.Parent = guiObject
    else
        -- 从 0 开始，保证有缩放过渡
        scale.Scale = 0
    end

    -- 如果该 GuiObject 有动画在运行，先取消旧动画
    if uiScaleStates[guiObject] then
        local old = uiScaleStates[guiObject]
        if old.tween then old.tween:Cancel() end
    end

    local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
    local tween = TweenService:Create(scale, tweenInfo, { Scale = 1 })

    -- 记录当前动画状态
    uiScaleStates[guiObject] = {
        scale = scale,
        tween = tween,
    }

    tween:Play()
    tween.Completed:Connect(function()
        -- 动画完成后清理状态记录
        uiScaleStates[guiObject] = nil
    end)

    return scale, tween
end

return Interface
