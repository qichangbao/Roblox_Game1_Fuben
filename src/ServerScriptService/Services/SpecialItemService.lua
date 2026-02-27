local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local TweenInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))

local SpecialItemService = Knit.CreateService({
    Name = 'SpecialItemService',
    Client = {
        ShakeCarame = Knit.CreateSignal(),
        OpenChest = Knit.CreateSignal(),
    },
})

function SpecialItemService:CreateDropItems(item, position)
    local dropGroupId = item:GetAttribute("DropGroup")
    local itemArray = Interface.GetDropItems(dropGroupId)
    if not itemArray then return false end

    local function playAction(itemTemp)
        local target = itemTemp.PrimaryPart
        if not target then return end
        local height = item.PrimaryPart.Size.Y / 2
        local floorY = position.Y - height + 0.5
        local startPosition = target.Position
        TweenInterface.TweenNodeMovePosition(target, startPosition + Vector3.new(0, 1, 0), 0.5, function()
            if target.Parent then
                TweenInterface.TweenNodeMovePosition(target, Vector3.new(startPosition.X, floorY + target.Size.Y / 2, startPosition.Z), 0.2)
            end
        end)
    end
    for _, itemId in ipairs(itemArray) do
        local itemTemp = Knit.GetService("ItemService"):CreateItem(itemId, position, 0, Vector3.new(0, 0, 0), GameConfig.GetItemAttribute(), 0)
        if itemTemp then
            playAction(itemTemp)
        end
    end
end

-- 播放木桶被推倒动画（函数级注释）：
-- @param player Player 推倒木桶的玩家
-- @param barrelItem Instance 木桶对应的物品实例（Model 或 BasePart）
-- 行为：根据玩家相对木桶的左右位置决定倾倒方向，将木桶从直立姿势缓慢旋转到一侧倒地。
function SpecialItemService:PlayBarrelKnockOverAnimation(player, barrelItem, callFunc)
	if not player or not barrelItem or not barrelItem.Parent then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not root then
		return
	end

	local targetNode = nil
	if barrelItem:IsA("Model") then
		targetNode = barrelItem.PrimaryPart
	else
		targetNode = barrelItem
	end

	if not targetNode then
		return
	end

	local originalCFrame = targetNode.CFrame
	local pivotPos = originalCFrame.Position
	local toPlayer = root.Position - pivotPos
	toPlayer = Vector3.new(toPlayer.X, 0, toPlayer.Z)
	if toPlayer.Magnitude == 0 then
		return
	end
	toPlayer = toPlayer.Unit

	local awayDir = -toPlayer
	local up = Vector3.new(0, 1, 0)
	local axis = up:Cross(awayDir)
	if axis.Magnitude == 0 then
		return
	end
	axis = axis.Unit

	local tiltAngle = math.rad(90)
	local rotateCf = CFrame.fromAxisAngle(axis, tiltAngle)
	local targetCFrame = CFrame.new(pivotPos) * rotateCf * CFrame.new(-pivotPos) * originalCFrame

	TweenInterface.TweenNodeMoveFrame(targetNode, targetCFrame, 0.4, callFunc)
end

-- 打开土堆
function SpecialItemService:OpenMound(player, item)
    if not player or not player.Parent then return false end
    local curItemId = item:GetAttribute("ItemId")
    if curItemId ~= 601 then return false end
    local itemInfo = ItemConfig:GetByItemId(curItemId)
    if not itemInfo then return false end

    local position = item:GetPivot().Position
    self:CreateDropItems(item, position)

    Knit.GetService("ItemService"):RemoveItem(item)
    Knit.GetService("ItemService"):CreateItemNoProximityPrompt(602, position, 0, Vector3.new(0, 0, 0), GameConfig.GetItemAttribute(), 0)
    self:PlaySound(player, "OpenMound")
    
    self.Client.ShakeCarame:Fire(player, {ShakeIntensity = 0.3, ShakeSpeed = 20, ShakeDuration = 0.6})

    return true
end

-- 打开矿石
function SpecialItemService:OpenOre(player, item)
    if not player or not player.Parent then
        return false
    end
    
    local curItemId = item:GetAttribute("ItemId")
    if curItemId ~= 603 then
        return false
    end

    local itemInfo = ItemConfig:GetByItemId(curItemId)
    if not itemInfo then
        return false
    end

    local position = item:GetPivot().Position
    self:CreateDropItems(item, position)

    Knit.GetService("ItemService"):RemoveItem(item)
    Knit.GetService("ItemService"):CreateItemNoProximityPrompt(602, position, 0, Vector3.new(0, 0, 0), GameConfig.GetItemAttribute(), 0)
    self:PlaySound(player, "OpenOre")
    
    self.Client.ShakeCarame:Fire(player, {ShakeIntensity = 0.3, ShakeSpeed = 20, ShakeDuration = 0.6})
end

--[[
    让物品抖动几下
    @param player Player 玩家对象
    @param item Model 物品模型
]]
function SpecialItemService:JitterOre(player, item)
    if not item or not item.Parent then
        return false
    end
    
    -- 获取物品的原始位置
    local originalCFrame = item:GetPivot()
    
    -- 抖动参数
    local jitterCount = 2 -- 抖动次数
    local jitterIntensity = 0.5 -- 抖动强度
    local jitterDuration = 0.1 -- 每次抖动持续时间
    
    -- 创建抖动序列
    for i = 1, jitterCount do
        -- 生成随机偏移
        local randomOffset = Vector3.new(
            (math.random() - 0.5) * jitterIntensity,
            (math.random() - 0.5) * jitterIntensity,
            (math.random() - 0.5) * jitterIntensity
        )
        
        -- 计算抖动后的位置
        local jitterCFrame = originalCFrame + randomOffset
        
        -- 延迟执行每次抖动
        task.spawn(function()
            task.wait((i - 1) * jitterDuration)
            
            -- 检查物品是否仍然存在
            if item and item.Parent then
                -- 抖动到随机位置
                if item:IsA("Model") then
                    -- 对于Model，直接使用PivotTo
                    item:PivotTo(jitterCFrame)
                    
                    -- 延迟后回到原位
                    task.wait(jitterDuration)
                    if item and item.Parent then
                        item:PivotTo(originalCFrame)
                    end
                else
                    TweenInterface.TweenNodeMoveFrame(item, jitterCFrame, jitterDuration, function()
                        if item and item.Parent then
                            TweenInterface.TweenNodeMoveFrame(item, originalCFrame, jitterDuration)
                        end
                    end)
                end
            end
        end)
    end
    self.Client.ShakeCarame:Fire(player, {ShakeIntensity = 0.5, ShakeSpeed = 10, ShakeDuration = 0.2})
    
    return true
end

function SpecialItemService:OpenChest(player, item)
    if not player or not player.Parent then
        return false
    end
    local itemId = item:GetAttribute("ItemId")
    local itemInfo = ItemConfig:GetByItemId(itemId)
    if not itemInfo then
        return false
    end

    local XuanCaiChestEffect = item:FindFirstChild("XuanCaiChestEffect")
    if XuanCaiChestEffect then
        XuanCaiChestEffect:Destroy()
    end

    local proximityPrompt = item:FindFirstChild("ProximityPrompt")
    if proximityPrompt then
        proximityPrompt.Enabled = false
    end
    local position = item:GetPivot().Position

    -- Icon在箱子类型里代表的是动画ID，如果有就播动画，如果没有就执行自己代码写的推翻的动画
    if not itemInfo.Icon then
		self:PlayBarrelKnockOverAnimation(player, item, function()
            local dropPointPart = item:FindFirstChild("DropPointPart")
            if dropPointPart then
                self:CreateDropItems(item, dropPointPart.Position)
            else
                self:CreateDropItems(item, position)
            end
        end)
    else
        -- 等待客户端播完箱子动画
        task.delay(1.33, function()
            self:CreateDropItems(item, position)
        end)
        self:PlaySound(player, "OpenChest")
        self.Client.OpenChest:FireAll(item)
        self.Client.ShakeCarame:Fire(player, {ShakeIntensity = 0.3, ShakeSpeed = 20, ShakeDuration = 0.6})
    end

    return true
end

-- 播放音效
function SpecialItemService:PlaySound(player, soundName)
    local Sound = Interface.safeWaitPart(game:GetService("SoundService"), "GAME")
    local music = Interface.safeWaitPart(Sound, soundName):Clone()
    music.Parent = player.Character
    music:Play()

    game:GetService("Debris"):AddItem(music, 3)
end

function SpecialItemService:KnitInit()
end

function SpecialItemService:KnitStart()
end

return SpecialItemService
