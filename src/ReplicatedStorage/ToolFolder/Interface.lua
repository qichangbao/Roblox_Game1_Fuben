local Interface = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local UserInputService = game:GetService("UserInputService")
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local DropPoolConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("DropPoolConfig"))
local DropTableConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("DropTableConfig"))
local HeroConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("HeroConfig"))
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
    local rayDirection = Vector3.new(0, -30, 0)
    
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
function Interface.isPlayerOnBoat(player)
    if not player or not player.Character then return false end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local boat = workspace:FindFirstChild(GameConfig.TeleportPartNames)
    if not boat then return false end

    local origin = hrp.Position + Vector3.new(0, 1, 0)
    local direction = Vector3.new(0, -50, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = {boat}

    local result = workspace:Raycast(origin, direction, params)
    if not result or not result.Instance then return false end

    local hitPart = result.Instance
    if hitPart:IsDescendantOf(boat) then
        return true
    end

    return false
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
    Knit.GetService("ClientUIService"):BroadcastHpChange(part, hp)
end

function Interface.decHp(character, damage, isCrit)
    if not character or not character.Parent then return end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	humanoid:TakeDamage(damage)
	
	local part = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	Knit.GetService("ClientUIService"):BroadcastHpChange(part, -damage, isCrit)
end

-- 获取掉落物品
function Interface.GetDropItems(dropId, resType)
    local dropConfig = DropPoolConfig:GetById(dropId)
    if not dropConfig then return end

    local dropTables = {}
    if dropConfig.DropType == 1 then        -- 1为唯一掉落（多个里面按权重必定抽1个）
        local totalProbability = 0
        for _, weight in ipairs(dropConfig.Weight) do
            totalProbability = totalProbability + weight[2]
        end
        local randomNum = math.random(totalProbability)
        local currentProbability = 0
        for _, weight in ipairs(dropConfig.Weight) do
            currentProbability = currentProbability + weight[2]
            if randomNum <= currentProbability and weight[1] > 0 then
                table.insert(dropTables, weight[1])
                break
            end
        end
    elseif dropConfig.DropType == 2 then    -- 2为独立掉落（每一个为独立概率掉落互不影响）
        for _, weight in ipairs(dropConfig.Weight) do
            if math.random(10000) <= weight[2] and weight[1] > 0 then
                table.insert(dropTables, weight[1])
            end
        end
    end

    if #dropTables == 0 then return end

    local itemArray = {}
    for _, dropTableId in ipairs(dropTables) do
        local dropTable = DropTableConfig:GetById(dropTableId)
        if not dropTable then continue end

        -- 把掉落数据存在表中
        local dropArray = {}
        for _, info in ipairs(dropTable.DropInfo) do
            local itemId = info[1]
            local num = info[2]
            local probability = info[3]
            for _ = 1, num do
                table.insert(dropArray, {itemId, probability})
            end
        end

        local curNum = 0
        local dropNum = math.random(dropTable.MinDrop or 0, dropTable.MaxDrop or 0)
        while curNum < dropNum do
            if #dropArray == 0 then
                break
            end
            for i = #dropArray, 1, -1 do
                local info = dropArray[i]
                if dropTable.Type == 2 then
                    table.remove(dropArray, i)
                end
                local itemId = info[1]
                local probability = info[2]
                if math.random(1, 10000) <= probability then
                    table.insert(itemArray, itemId)
                    curNum += 1
                    if curNum >= dropNum then
                        break
                    end
                end
            end
        end
    end

    return itemArray
end

-- 获取金币模型名称
function Interface.GetGoldModelId(gold)
    if gold >= 100 then
        return 1041
    elseif gold >= 10 then
        return 1040
    else
        return 1039
    end
end

-- 是否为金币
function Interface.IsGold(itemId)
    return itemId == 1039 or itemId == 1040 or itemId == 1041
end

-- 字符串分割
-- @param str 要分割的字符串
-- @param delim 分隔符
-- @return 分割后的字符串数组
function Interface.Split(str, delim)
	local result = {}
	local pattern = string.format("([^%s]+)", delim)
	for part in string.gmatch(str, pattern) do
		table.insert(result, part)
	end
	return result
end

-- 获取职业效果
-- @param player 玩家
-- @return 职业效果表
function Interface.GetJobEffect(player)
    local jobId = Knit.GetService("JobService"):GetCurJobId(player)
    local jobData = Knit.GetService("JobService"):GetJobData(player)
    local data = jobData[jobId]
    if not data then return end
    local config = HeroConfig:GetById(tonumber(jobId))
    if not config then return end

    local effects = {
        Attribute = {},
        FreeReviveCount = 0,
        DoubleDamage = 0,
        KillMonsterDoubleDrop = 0,
    }
    local function addEffect(effect)
        local effectAction = Interface.Split(effect, "_")
        local effectType = tonumber(effectAction[1])
        if effectType == GameConfig.JobAttributeType.Attribute then
            table.insert(effects.Attribute, {AttributeId = tonumber(effectAction[2]), Value = tonumber(effectAction[3])})
        elseif effectType == GameConfig.JobAttributeType.FreeRelive then
            effects.FreeReviveCount = tonumber(effectAction[2])
        elseif effectType == GameConfig.JobAttributeType.DoubleDamage then
            effects.DoubleDamage = tonumber(effectAction[2])
        elseif effectType == GameConfig.JobAttributeType.KillMonsterDoubleDrop then
            effects.KillMonsterDoubleDrop = tonumber(effectAction[2])
        end
    end
    if data.IsFinished then
        for _, effect in ipairs(config.EffectAction) do
            addEffect(effect)
        end
    else
        for level = 1, data.Level - 1 do
            local effect = config.EffectAction[level]
            addEffect(effect)
        end
    end

    return effects
end

function Interface.GetEffect(effectName)
    local effectFolder = ReplicatedStorage:FindFirstChild("Effect")
    if not effectFolder then return end
    local effect = effectFolder:FindFirstChild(effectName)
    if not effect then return end
    return effect:Clone()
end

function Interface.PlayEffect(effect, effectCFrame,emitCount, liveTime, isDestroy, callFunc)
    if not effect then return end
    if effect:IsA("Model") then
        effect:PivotTo(effectCFrame)
    elseif effect:IsA("BasePart") then
        effect.CFrame = effectCFrame
    end
    for _, particleEmitter in pairs(effect:GetDescendants()) do
        if particleEmitter:IsA("ParticleEmitter") then
            particleEmitter.Enabled = true
            particleEmitter:Emit(emitCount)
        elseif particleEmitter:IsA("BasePart") then
            particleEmitter.CanCollide = false
            particleEmitter.Anchored = true
        end
    end
    if liveTime and liveTime > 0 then
        task.delay(liveTime, function()
            for _, particleEmitter in pairs(effect:GetDescendants()) do
                if particleEmitter:IsA("ParticleEmitter") then
                    particleEmitter.Enabled = false
                end
            end
            if callFunc then
                callFunc(effect)
            end
            if isDestroy then
                effect:Destroy()
            end
        end)
    end
end

-- 播放特效
-- @param effectName 特效名称
-- @param effectCFrame 特效位置
-- @param liveTime 特效生命周期
-- @param callFunc 特效销毁后回调函数
function Interface.PlayEffectByName(effectName, effectCFrame, emitCount, liveTime, callFunc)
    local effect = Interface.GetEffect(effectName)
    if not effect then return end
    local parent = workspace:FindFirstChild("Effect")
    if not parent then return end
    effect.Parent = parent

    Interface.PlayEffect(effect, effectCFrame, emitCount, liveTime, true, callFunc)
    return effect
end

-- 格式化重量显示，最多保留两位小数，去掉多余的零
function Interface.formatValue(value)
	if not value then
		return ""
	end

	local roundedValue = math.floor(value * 100 + 0.5) / 100

	if roundedValue % 1 == 0 then
		return string.format("%d", roundedValue)
	elseif (roundedValue * 10) % 1 == 0 then
		return string.format("%.1f", roundedValue)
	else
		return string.format("%.2f", roundedValue)
	end
end

return Interface
