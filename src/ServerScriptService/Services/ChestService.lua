local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local PlanConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("PlanConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local TweenService = game:GetService("TweenService")

local ChestService = Knit.CreateService({
    Name = 'ChestService',
    Client = {
    },
})

function ChestService:OpenChest(player, item, itemInfo)
    if not player or not player.Parent then
        return false
    end
    
    local plan = PlanConfig:GetByCanisterId(itemInfo.Index)
    if not plan then
        return false
    end

    local XuanCaiChestEffect = workspace:FindFirstChild("XuanCaiChestEffect")
    if XuanCaiChestEffect then
        XuanCaiChestEffect:Destroy()
    end

    -- 播放开箱子动画
    self:PlayChestOpenAnimation(item)

    local position = item:GetPivot().Position
    if type(plan.ItemId) == "table" then
        for i, itemId in pairs(plan.ItemId) do
            local random = math.random(1, 10000)
            if random <= plan.Probability[i] then
                Knit.GetService("ItemService"):CreateItem(itemId, position, GameConfig.GetItemAttribute(), true)
            end
        end
    else
        local random = math.random(1, 10000)
        if random <= plan.Probability then
            Knit.GetService("ItemService"):CreateItem(plan.ItemId, position, GameConfig.GetItemAttribute(), true)
        end
    end
    
    return true
end

-- 播放箱子打开动画（主函数）
function ChestService:PlayChestOpenAnimation(chestItem)
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
function ChestService:PlayPartAnimation(chestItem, top)
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
function ChestService:PlayModelAnimation(chestItem, top)
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

-- 播放开箱子音效
function ChestService:PlayChestOpenSound(chestItem)
    -- 检查箱子是否有声音部件
    local sound = chestItem:FindFirstChildOfClass("Sound")
    if not sound then
        -- 如果没有声音部件，创建一个
        sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://9117168362" -- 默认开箱子音效ID
        sound.Volume = 0.5
        sound.Parent = chestItem
    end
    
    -- 播放音效
    sound:Play()
end

function ChestService:KnitInit()
end

function ChestService:KnitStart()
end

return ChestService