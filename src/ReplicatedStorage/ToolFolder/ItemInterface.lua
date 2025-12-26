local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("WeaponConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local DesignConfig = require(ReplicatedStorage:WaitForChild('ConfigFolder'):WaitForChild('DesignConfig'))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local ItemInterface = {}

-- 可视化检测区域（调试用）
-- @param cframe: 检测区域的CFrame
-- @param size: 检测区域的大小
local function _VisualizeDetectionArea(cframe, size)
	-- 创建可视化部件
	local visualPart = Instance.new("Part")
	visualPart.Name = "ToolDetectionArea"
	visualPart.Size = size
	visualPart.CFrame = cframe
	visualPart.Transparency = 0.7
	visualPart.Color = Color3.new(1, 0, 0) -- 红色
	visualPart.CanCollide = false
	visualPart.Anchored = true
	visualPart.Parent = workspace

	-- 0.2秒后移除可视化
	game:GetService("Debris"):AddItem(visualPart, 0.2)
end

-- 在攻击范围边缘展示命中特效（函数级注释）：
-- @param player Player 触发命中的玩家
-- 行为：获取玩家当前装备物品的攻击范围（WeaponConfig.Position.X），
--       将命中特效摆放在角色前方“攻击盒”的最远边缘中心点。
-- 计算：edgePos = HRP.Position + LookVector * detectionRange
-- 回退：若找不到装备或范围配置，退回到HRP位置播放特效。
local function _showHitEffect(player)
    local character = player and player.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- 查找当前装备的 Tool
    local equippedTool = nil
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then
            equippedTool = child
            break
        end
    end

    -- 计算攻击范围的最远边缘位置
    local pos = hrp.Position
    local forward = hrp.CFrame.LookVector
    local edgePos = pos

    if equippedTool then
        local itemId = equippedTool:GetAttribute("ItemId")
        if itemId then
            local weaponInfo = WeaponConfig:GetByItemId(itemId)
            if weaponInfo and weaponInfo.Position then
                local detectionRange = weaponInfo.Position.X
                if typeof(detectionRange) == "number" and detectionRange > 0 then
                    edgePos = pos + forward * detectionRange
                end
            end
        end
    end
    local effect = character:FindFirstChild("HitEffect")
    -- 朝向前方，便于某些发射型或方向性特效对齐
    effect.CFrame = CFrame.lookAt(edgePos, edgePos + forward)
    for _, particleEmitter in pairs(effect:GetDescendants()) do
        if particleEmitter:IsA("ParticleEmitter") then
            particleEmitter.Enabled = true
            particleEmitter:Emit(30)
        end
    end

    task.delay(1, function()
        for _, particleEmitter in pairs(effect:GetDescendants()) do
            if particleEmitter:IsA("ParticleEmitter") then
                particleEmitter.Enabled = false
            end
        end
    end)
end

-- 展示近战攻击的角色内置特效（函数级注释）：
-- @param player Player 触发攻击的玩家
-- 行为：在角色下查找 AttackEffect 模型/部件，
--       按角色的水平朝向将特效摆到“攻击盒”最远边缘中心点。
-- 细节：
-- 1) 使用水平前向（忽略Y）避免抬头/低头造成高度偏差；
-- 2) Model优先用 PivotTo，其次用 Ground2 或第一个 BasePart；
-- 3) AttackEffect 存在焊接/附件时可能覆盖位置，应确保用于展示的部件 Anchored。
function ItemInterface.showAttackEffect(player)
    local character = player and player.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- 计算攻击范围的最远边缘位置
    local pos = hrp.Position
    local forward = hrp.CFrame.LookVector

    -- 在角色下查找 AttackEffect（避免误查 Player 根节点）·
    local effect = character:FindFirstChild("AttackEffect")
    if not effect then return end
    -- 水平前向（忽略Y抬头/低头），更稳定的朝向
    local horizForward = Vector3.new(forward.X, 0, forward.Z)
    if horizForward.Magnitude > 0 then
        horizForward = horizForward.Unit
    else
        horizForward = forward
    end
    effect.CFrame = CFrame.lookAt(pos, pos + horizForward)

    for _, particleEmitter in pairs(effect:GetDescendants()) do
        if particleEmitter:IsA("ParticleEmitter") then
            particleEmitter.Enabled = true
            particleEmitter:Emit(30)
        end
    end

    task.delay(1, function()
        for _, particleEmitter in pairs(effect:GetDescendants()) do
            if particleEmitter:IsA("ParticleEmitter") then
                particleEmitter.Enabled = false
            end
        end
    end)
end

local function _takeDamage(player, hitCharacter, damage)
    if not player or not hitCharacter or not player.Character or hitCharacter == player.Character then return end
    local sourceHumanoid = player.Character:FindFirstChild("Humanoid")
	if not sourceHumanoid then return end
	local targetHumanoid = hitCharacter:FindFirstChild("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return false
	end

	local criticalProbability = Knit.GetService("PlayerService"):GetCriticalProbability(player)
	local attack = sourceHumanoid:GetAttribute("Attack")
	local humanoidType = hitCharacter:GetAttribute("HumanoidType")
	local normalDamage = attack + damage
	local isCrit = false
	local random = math.random(100)
	if random <= criticalProbability then			-- 暴击
		local criticalValue = Knit.GetService("PlayerService"):GetCriticalValue(player)
		normalDamage = normalDamage * criticalValue % 100
		isCrit = true
	end
	if humanoidType == GameConfig.HumanoidType.Monster then
		_showHitEffect(player)
		Interface.decHp(hitCharacter, normalDamage, isCrit)
		if targetHumanoid.Health <= 0 then
            Knit.GetService("MonsterService"):KillMonster(player, hitCharacter)
		end
		Knit.GetService("JobService"):TriggerJob(player, GameConfig.JobUnlockCondition.DamageNoWeapon, normalDamage)
		Knit.GetService("JobService"):TriggerJob(player, GameConfig.JobUnlockCondition.DamageNoWeaponNum, 1)
		Knit.GetService("JobService"):TriggerJob(player, GameConfig.JobUnlockCondition.DamageMonster, {monsterId = targetHumanoid:GetAttribute("MonsterId"), count = normalDamage})
		Knit.GetService("JobService"):TriggerJob(player, GameConfig.JobUnlockCondition.DamageMonsterNum, {monsterId = targetHumanoid:GetAttribute("MonsterId"), count = 1})
		return true
	elseif humanoidType == GameConfig.HumanoidType.Player then
		local islandId = Knit.GetService("IslandService"):GetIslandId()
		if not islandId then return end
		local mapConfig = DesignConfig:GetByMapId(islandId)
		if not mapConfig then return end
		local isOnBoat = Interface.isPlayerOnBoat(player)
		if isOnBoat then return end
		_showHitEffect(player)
		Interface.decHp(hitCharacter, normalDamage, isCrit)
    end
end

-- 执行区域检测
-- @param player: 使用工具的玩家
function ItemInterface.performAreaDetection(player, itemInfo, collisionCallback)
	local character = player.Character
	if not character then return false end
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	if not humanoidRootPart then return false end

	local curTool = nil
	for _, child in pairs(player.Character:GetChildren()) do
		if child:IsA("Tool") then
			curTool = child
			break
		end
	end
	
	if not curTool then
		return false
	end
	
	local handle = curTool:FindFirstChild("Handle")
	if not handle then
		warn("Tool没有Handle:", curTool.Name)
		return false
	end

	-- 计算检测区域（以角色为中心，向前方扩展）
	local centerPosition = humanoidRootPart.Position
	local lookDirection = humanoidRootPart.CFrame.LookVector

	local itemId = itemInfo.ItemId
	local weaponInfo = WeaponConfig:GetByItemId(itemId)
	-- 检测区域参数
	local detectionRange = weaponInfo.Position.X -- 检测距离
	local detectionWidth = weaponInfo.Position.Y -- 检测宽度
	local detectionHeight = weaponInfo.Position.Z -- 检测高度

	-- 计算检测区域的中心点（向前偏移）
	local detectionCenter = centerPosition + lookDirection * (detectionRange / 2)

	-- 创建检测区域的CFrame和大小
	local detectionCFrame = CFrame.lookAt(detectionCenter, detectionCenter + lookDirection)
	local detectionSize = Vector3.new(detectionWidth, detectionHeight, detectionRange)
	-- 可视化检测区域（调试用，可选）
	if game:GetService("RunService"):IsStudio() then
		_VisualizeDetectionArea(detectionCFrame, detectionSize)
	end

	-- 使用GetPartBoundsInBox进行区域检测
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = {character} -- 排除自己的角色

	local hitParts = workspace:GetPartBoundsInBox(detectionCFrame, detectionSize, overlapParams)
	if #hitParts == 0 then return false end

	local damage = weaponInfo.Damage
	local jobEffect = Interface.GetJobEffect(player)
	if jobEffect and jobEffect.DoubleDamage == itemId then
		damage *= 2
	end
	-- 处理检测到的所有部件
	local processedObjects = {} -- 防止重复处理同一个对象
	for _, hit in ipairs(hitParts) do
		local hitParent = hit.Parent

		-- 避免重复处理同一个对象
		if hitParent and not processedObjects[hitParent] then
			processedObjects[hitParent] = true

			-- 处理碰撞
            if not _takeDamage(player, hitParent, damage) then
                if collisionCallback then
                    collisionCallback(hit, weaponInfo)
                end
            end
		end
	end

	return true
end

return ItemInterface
