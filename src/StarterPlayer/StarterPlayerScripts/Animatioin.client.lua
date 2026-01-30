local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild('Packages'):WaitForChild('Knit'):waitForChild('Knit'))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local MonsterConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("MonsterConfig"))

local function PlayAnimation(animator, animationId, eventName)
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://" .. animationId

    local track = animator:LoadAnimation(animation)
    track.Looped = false
	track.Priority = Enum.AnimationPriority.Action4
    track:Play()

    track:GetMarkerReachedSignal(eventName):Connect(function()
        track:AdjustSpeed(0)
    end)
end

Knit.OnStart():andThen(function()
	Knit.GetController("UIController").OpenChest:Connect(function(chestItem)
        local humanoid = chestItem:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then return end
        local itemId = chestItem:GetAttribute("ItemId")
        if not itemId then return end
        local itemConfig = ItemConfig:GetByItemId(itemId)
        if not itemConfig then return end
        local animationId = itemConfig.Icon
        if not animationId or animationId == "" then return end
		PlayAnimation(animator, animationId, "Finish")
    end)
    Knit.GetController("UIController").PlayMonsterDead:Connect(function(npc)
        local humanoid = npc:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then return end
		local monsterId = npc:GetAttribute("MonsterId")
		if not monsterId then return end
		local monsterInfo = MonsterConfig:GetByMonsterId(monsterId)
		if not monsterInfo then return end
		local animationId = monsterInfo.AnimationDeath
		if not animationId or animationId == "" then return end
		PlayAnimation(animator, animationId, "Finish")
    end)
end)
