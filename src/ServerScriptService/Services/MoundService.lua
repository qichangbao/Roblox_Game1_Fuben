local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local PlanConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("PlanConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))

local MoundService = Knit.CreateService({
    Name = 'MoundService',
    Client = {
    },
})

function MoundService:OpenMound(player, item)
    if not player or not player.Parent then
        return false
    end
    
    local curItemId = item:GetAttribute("ItemId")
    if curItemId ~= 601 then
        return false
    end

    local itemInfo = ItemConfig:GetByIndex(curItemId)
    if not itemInfo then
        return false
    end

    local position = item:GetPivot().Position
    Knit.GetService("ItemService"):RemoveItem(item)
    Knit.GetService("ItemService"):CreateItemNoProximityPrompt(602, position)

    local plan = PlanConfig:GetByCanisterId(itemInfo.Index)
    if not plan then
        return false
    end

    for i, itemId in pairs(plan.ItemId) do
        local random = math.random(1, 10000)
        if random <= plan.Probability[i] then
            Knit.GetService("ItemService"):CreateItem(itemId, position, GameConfig.GetItemAttribute(), true)
        end
    end
    
    return true
end

-- 播放箱子打开动画（主函数）
function MoundService:PlayChestOpenAnimation(chestItem)
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

function MoundService:KnitInit()
end

function MoundService:KnitStart()
end

return MoundService
