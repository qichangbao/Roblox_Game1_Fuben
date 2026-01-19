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
        local upInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local downInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

        local upTween = TweenService:Create(target, upInfo, {
            Position = startPosition + Vector3.new(0, 1, 0),
        })

        local downTween = TweenService:Create(target, downInfo, {
            Position = Vector3.new(startPosition.X, floorY + target.Size.Y / 2, startPosition.Z),
        })

        upTween.Completed:Connect(function()
            if target.Parent then
                downTween:Play()
            end
        end)

        upTween:Play()
    end
    for _, itemId in ipairs(itemArray) do
        local itemTemp = Knit.GetService("ItemService"):CreateItem(itemId, position, 0, GameConfig.GetItemAttribute(), true)
        if itemTemp then
            playAction(itemTemp)
        end
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
    self:CreateDropItems(item, position)

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
    self:CreateDropItems(item, position)

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
    -- 播放开箱子动画
    self:PlayChestOpenAnimation(item, function()
        self:CreateDropItems(item, position)
    end)
    self:PlaySound(player, "OpenChest")

    self.Client.OpenChest:FireAll(player.Character:GetPivot(), item)
    self.Client.ShakeCarame:Fire(player, {ShakeIntensity = 0.3, ShakeSpeed = 20, ShakeDuration = 0.6})
    
    return true
end

function SpecialItemService:PlayChestOpenAnimation(chestItem, finishedCallback)
    local proximityPrompt = chestItem:FindFirstChild("ProximityPrompt")
    if proximityPrompt then
        proximityPrompt.Enabled = false
    end
    task.delay(1.33, function()
        if finishedCallback then
            finishedCallback()
        end
    end)
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
