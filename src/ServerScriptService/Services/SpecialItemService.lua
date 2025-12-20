local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local SpecialItemService = Knit.CreateService({
    Name = 'SpecialItemService',
    Client = {
        ShakeCarame = Knit.CreateSignal(),
    },
})

function SpecialItemService:CreateDropItems(dropGroupId, position)
    local itemArray = Interface.GetDropItems(dropGroupId)
    if not itemArray then return false end

    for _, itemId in ipairs(itemArray) do
        Knit.GetService("ItemService"):CreateItem(itemId, position, 0, GameConfig.GetItemAttribute(), true)
    end
end

-- 打开土堆
function SpecialItemService:OpenMound(player, item)
    if not player or not player.Parent then return false end
    local curItemId = item:GetAttribute("ItemId")
    if curItemId ~= 601 then return false end
    local itemInfo = ItemConfig:GetByItemId(curItemId)
    if not itemInfo then return false end

    local position = item:GetPivot().Position
    self:CreateDropItems(item:GetAttribute("DropGroup"), position)

    Knit.GetService("ItemService"):RemoveItem(item)
    Knit.GetService("ItemService"):CreateItemNoProximityPrompt(602, position)
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
    self:CreateDropItems(item:GetAttribute("DropGroup"), position)

    Knit.GetService("ItemService"):RemoveItem(item)
    Knit.GetService("ItemService"):CreateItemNoProximityPrompt(602, position)
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
        
        -- 创建补间动画
        local tweenInfo = TweenInfo.new(
            jitterDuration,
            Enum.EasingStyle.Bounce,
            Enum.EasingDirection.Out
        )
        
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
                    -- 对于BasePart，使用Tween
                    local jitterTween = TweenService:Create(item, tweenInfo, {
                        CFrame = jitterCFrame
                    })
                    jitterTween:Play()
                    
                    -- 等待抖动完成后回到原位
                    jitterTween.Completed:Connect(function()
                        if item and item.Parent then
                            local returnTween = TweenService:Create(item, tweenInfo, {
                                CFrame = originalCFrame
                            })
                            returnTween:Play()
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

    local XuanCaiChestEffect = item:FindFirstChild("XuanCaiChestEffect")
    if XuanCaiChestEffect then
        XuanCaiChestEffect:Destroy()
    end

    local position = item:GetPivot().Position
    self:CreateDropItems(item:GetAttribute("DropGroup"), position)

    -- 播放开箱子动画
    self:PlayChestOpenAnimation(item)
    self:PlaySound(player, "OpenChest")

    self.Client.ShakeCarame:Fire(player, {ShakeIntensity = 0.3, ShakeSpeed = 20, ShakeDuration = 0.6})
    
    return true
end

-- 播放箱子打开动画（主函数）
function SpecialItemService:PlayChestOpenAnimation(chestItem)
    -- 先做“左右抬起-放下”的序列抖动，再执行开盖动画（函数级注释）：
    -- 行为：
    -- 1) 围绕 Z 轴（Roll）小幅旋转实现“左边/右边抬起”，每次抬起后立即放下；
    -- 2) 左抬起→放下→右抬起→放下为一轮，共进行 5 轮；
    -- 3) 完成抖动后复位到初始姿态，再根据 Top 类型执行开盖动画；
    -- 4) 最后禁用 ProximityPrompt，避免重复触发。
    -- @param chestItem Model 箱子模型（需有 Top/Bottom 子节点或已设置 Pivot）
    -- @return void
    if not chestItem or not chestItem:IsA("Model") then
        warn("PlayChestOpenAnimation: chestItem must be a Model")
        return
    end

    -- 左右抬起序列参数
    local basePivot = chestItem:GetPivot()
    local ROUNDS = 5
    local LIFT_ANGLE_DEG = 10      -- 抬起角度（度），过大可能显得夸张
    local HOLD_TIME = 0.03        -- 抬起后的停顿时间（秒）

    local leftAngle = math.rad(LIFT_ANGLE_DEG)   -- 左边抬起（Z轴正旋）
    local rightAngle = -math.rad(LIFT_ANGLE_DEG) -- 右边抬起（Z轴负旋）

    for _ = 1, ROUNDS do
        -- 左边抬起
        chestItem:PivotTo(basePivot * CFrame.Angles(0, 0, leftAngle))
        task.wait(HOLD_TIME)
        -- 放下复位
        chestItem:PivotTo(basePivot)
        task.wait(HOLD_TIME)

        -- 右边抬起
        chestItem:PivotTo(basePivot * CFrame.Angles(0, 0, rightAngle))
        task.wait(HOLD_TIME)
        -- 放下复位
        chestItem:PivotTo(basePivot)
        task.wait(HOLD_TIME)
    end

    -- 最终复位，准备开盖动画
    chestItem:PivotTo(basePivot)

    -- 查找箱子的Top部分
    local top = chestItem:FindFirstChild("Top")
    if not top then
        warn("Chest Top part not found")
        return
    end

    -- 根据Top的类型调用相应的动画函数
    if top:IsA("BasePart") then
        self:PlayPartAnimation(chestItem, top)
    elseif top:IsA("Model") then
        self:PlayModelAnimation(chestItem, top)
    else
        warn("Unsupported top type:", top.ClassName)
    end
    
    -- 禁用接近提示
    local proximityPrompt = chestItem:FindFirstChild("ProximityPrompt")
    if proximityPrompt then
        proximityPrompt.Enabled = false
    end
end

-- 播放BasePart类型的箱盖动画
function SpecialItemService:PlayPartAnimation(chestItem, top)
    local bottom = chestItem:FindFirstChild("Bottom")
    bottom.Anchored = true
    top.Anchored = true
    
    -- 旋转角度（向上打开）
    local rotationAngle = math.rad(90) -- 正90度，绕X轴向上打开
    local rotationCFrame = CFrame.Angles(rotationAngle, 0, 0)
    
    -- 保存原始CFrame用于动画
    local originalCFrame = top.CFrame
    
    -- 使用箱盖的枢轴（Pivot）进行旋转
    -- 枢轴位置已在Studio中设定好
    local pivotCFrame = top.PivotOffset
    local pivotPosition = originalCFrame:ToWorldSpace(pivotCFrame).Position
    
    -- 计算从枢轴到Top中心的相对位置
    local relativePosition = originalCFrame.Position - pivotPosition
    local relativeRotation = originalCFrame.Rotation
    
    -- 应用旋转变换
    local rotatedRelativePos = rotationCFrame:VectorToWorldSpace(relativePosition)
    local rotatedRotation = rotationCFrame * relativeRotation
    
    -- 计算最终的CFrame：枢轴 + 旋转后的相对位置 + 旋转
    local targetCFrame = CFrame.new(pivotPosition + rotatedRelativePos) * rotatedRotation
    
    -- 创建动画信息
    local tweenInfo = TweenInfo.new(
        1.5, -- 动画时长
        Enum.EasingStyle.Quad, -- 缓动样式
        Enum.EasingDirection.Out, -- 缓动方向
        0, -- 重复次数
        false, -- 是否反转
        0 -- 延迟
    )
    
    -- 创建并播放动画
    local tween = TweenService:Create(top, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
end

-- 播放Model类型的箱盖动画
function SpecialItemService:PlayModelAnimation(chestItem, top)
    -- 旋转角度（向上打开）
    local rotationAngle = math.rad(90) -- 正90度，绕X轴向上打开
    local rotationCFrame = CFrame.Angles(rotationAngle, 0, 0)
    
    local bottom = chestItem:FindFirstChild("Bottom")
    if bottom then
        if bottom:IsA("BasePart") then
            bottom.Anchored = true
        elseif bottom:IsA("Model") then
            -- 锚定Model中的所有BasePart
            for _, part in pairs(bottom:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = true
                end
            end
        end
    end
    
    -- 锚定Model中的所有BasePart
    for _, part in pairs(top:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
        end
    end
    
    -- 获取Model的原始PrimaryPart或第一个BasePart作为参考
    local referencePart = top.PrimaryPart
    if not referencePart then
        -- 如果没有PrimaryPart，找第一个BasePart
        for _, part in pairs(top:GetChildren()) do
            if part:IsA("BasePart") then
                referencePart = part
                break
            end
        end
    end
    
    if not referencePart then
        warn("Model top has no BasePart to use as reference")
        return
    end
    
    -- 保存原始CFrame用于动画
    local originalCFrame = referencePart.CFrame
    
    -- 定义动画信息
    local tweenInfo = TweenInfo.new(
        1.5, -- 动画时长
        Enum.EasingStyle.Quad, -- 缓动样式
        Enum.EasingDirection.Out, -- 缓动方向
        0, -- 重复次数
        false, -- 是否反转
        0 -- 延迟
    )

    -- 获取枢轴信息
    local pivotCFrame
    if top.PrimaryPart and top.PrimaryPart.PivotOffset then
        pivotCFrame = top.PrimaryPart.PivotOffset
    else
        pivotCFrame = referencePart.PivotOffset
    end
    local pivotPosition = originalCFrame:ToWorldSpace(pivotCFrame).Position
    local rotationTransform = CFrame.new(pivotPosition) * rotationCFrame * CFrame.new(-pivotPosition)
    
    -- 为Model中的每个BasePart创建补间动画
    local tweens = {}
    for _, part in pairs(top:GetDescendants()) do
        if part:IsA("BasePart") then
            local partTargetCFrame = rotationTransform * part.CFrame
            local partTween = TweenService:Create(part, tweenInfo, {CFrame = partTargetCFrame})
            table.insert(tweens, partTween)
        end
    end
    
    -- 同时播放所有动画
    for _, tween in pairs(tweens) do
        tween:Play()
    end
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
