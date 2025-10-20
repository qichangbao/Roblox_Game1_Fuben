local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local PlanConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("PlanConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))

local SpecialItemService = Knit.CreateService({
    Name = 'SpecialItemService',
    Client = {
    },
})

-- 打开土堆
function SpecialItemService:OpenMound(player, item)
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

-- 打开矿石
function SpecialItemService:OpenOre(player, item)
    if not player or not player.Parent then
        return false
    end
    
    local curItemId = item:GetAttribute("ItemId")
    if curItemId ~= 603 then
        return false
    end

    local itemInfo = ItemConfig:GetByIndex(curItemId)
    if not itemInfo then
        return false
    end

    local position = item:GetPivot().Position
    Knit.GetService("ItemService"):RemoveItem(item)
    
    local plan = PlanConfig:GetByCanisterId(itemInfo.Index)
    if not plan then
        return false
    end

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
    
    return true
end

function SpecialItemService:KnitInit()
end

function SpecialItemService:KnitStart()
end

return SpecialItemService
