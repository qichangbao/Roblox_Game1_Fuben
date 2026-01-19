local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild('Packages'):WaitForChild('Knit'):waitForChild('Knit'))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
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
end)
