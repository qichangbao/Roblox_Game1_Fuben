-- ItemService 服务
-- 使用Knit框架管理物品生成和捡取系统

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local DesignResConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("DesignResConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local DesignConfig = require(ReplicatedStorage:WaitForChild('ConfigFolder'):WaitForChild('DesignConfig'))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local ItemWorkspaceFolder = workspace:WaitForChild("Item")
if not ItemWorkspaceFolder then
    warn("ItemWorkspaceFolder folder not found")
    return
end
local EffectWorkspaceFolder = workspace:WaitForChild("Effect")
if not EffectWorkspaceFolder then
    warn("EffectWorkspaceFolder folder not found")
    return
end
local ItemFolder = ReplicatedStorage:WaitForChild("Item")
if not ItemFolder then
    warn("Item folder not found")
    return
end

local ItemService = Knit.CreateService {
    Name = "ItemService",
    Client = {
    },

    Items = {},
}

-- 创建炫彩宝箱特效
function ItemService:CreateXuanCaiChestEffect(item)
    local position = item:GetPivot().Position
    local effect = ReplicatedStorage:WaitForChild("Effect"):WaitForChild("XuanCaiChestEffect"):Clone()
    effect.Name = "XuanCaiChestEffect"
    effect.Parent = item
    effect:PivotTo(CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)))
end

function ItemService:CreateItemNoProximityPrompt(itemId, position, dropGroup, attribute, isAnchored)
    if not itemId or itemId == 0 then
        return
    end

    local itemInfo = ItemConfig:GetByItemId(itemId)
    if not itemInfo then
        warn("Item not found: " .. itemId)
        return
    end

    local folder = ItemFolder:FindFirstChild(GameConfig.ItemTypeFolder[itemInfo.Type])
    if not folder then
        warn("Item type folder not found: " .. GameConfig.ItemTypeFolder[itemInfo.Type])
        return
    end

    local part = folder:FindFirstChild(itemInfo.Model)
    if not part then
        warn("Item model not found: " .. itemInfo.Model)
        return
    end
    local item = part:Clone()
    item.Name = itemInfo.Item .. tick()
    item.Parent = ItemWorkspaceFolder
    if item:IsA("BasePart") then
        item.Position = Vector3.new(position.X, position.Y + item.Size.Y / 2, position.Z)
    elseif item:IsA("Model") then
        item:PivotTo(CFrame.new(Vector3.new(position.X, position.Y + item.PrimaryPart.Size.Y / 2, position.Z)))
    end
    item:SetAttribute("ItemId", itemId)
    if dropGroup and dropGroup > 0 then
        item:SetAttribute("DropGroup", dropGroup)
    end
    if attribute then
        attribute.IsEquipped = 0
    end
    GameConfig.SetItemAttribute(item, attribute)
    for _, descendant in pairs(item:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Anchored = false
            descendant.CanCollide = true
            descendant.CollisionGroup = "Item"
        end
    end

    if isAnchored then
        item.PrimaryPart.Anchored = true
    end

    return item, itemInfo
end

-- 创建物品
function ItemService:CreateItem(itemId, position, dropGroup, attribute, isAnchored)
    local item, itemInfo = self:CreateItemNoProximityPrompt(itemId, position, dropGroup, attribute, isAnchored)
    if not item or not itemInfo then
        return
    end

    -- 创建外发光
    local highlight = Instance.new("Highlight")
    highlight.Parent = item
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded

    -- 创建 ProximityPrompt 实例
    local proximityPrompt = Instance.new("ProximityPrompt")
    proximityPrompt.Parent = item

    -- 基本属性配置
    if itemInfo.Type == GameConfig.ItemType.Chest then
        proximityPrompt.ActionText = "Open"
    elseif itemInfo.Type == GameConfig.ItemType.Mound then
        if itemInfo.ItemId == 601 then
            proximityPrompt.ActionText = "Dig with a shovel"
        else
            proximityPrompt.ActionText = "Mining with a Ore"
        end
    elseif itemInfo.Type == GameConfig.ItemType.Buff then
        proximityPrompt.ActionText = "Eat"
    else
        proximityPrompt.ActionText = "Pick"
    end
    proximityPrompt.ObjectText = itemInfo.DisplayName
    proximityPrompt.KeyboardKeyCode = Enum.KeyCode.E -- 键盘按键
    proximityPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX -- 手柄按键
    proximityPrompt.MaxActivationDistance = 10 -- 最大激活距离
    proximityPrompt.HoldDuration = itemInfo.PickTime -- 按住时间（0表示点击即可）
    proximityPrompt.RequiresLineOfSight = false -- 是否需要视线可见

    -- 当玩家触发提示时
    proximityPrompt.Triggered:Connect(function(player)
        if itemInfo.Type == GameConfig.ItemType.Chest then
            -- 宝箱类物品，调用SpecialItemService处理奖励
            Knit.GetService("SpecialItemService"):OpenChest(player, item)
            return
        elseif itemInfo.Type == GameConfig.ItemType.Mound then
            --  mound 类物品不能拾取
            return
        elseif itemInfo.Type == GameConfig.ItemType.Buff then
            --  Buff 类物品不能拾取
            local script = item:FindFirstChild("ModuleScript")
            if script then
                local module = require(script)
                if module and module.Triggered then
                    module:Triggered(player, itemInfo)
                end
            end
            item:Destroy()
            return
        end

        -- 执行物品捡取逻辑
        self:HandleItemPickup(player, item)
    end)

    -- 当玩家开始按住时（仅当 HoldDuration > 0 时有效）
    proximityPrompt.PromptButtonHoldBegan:Connect(function(player)
    end)

    -- 当玩家停止按住时
    proximityPrompt.PromptButtonHoldEnded:Connect(function(player)
    end)

    table.insert(self.Items, item)
    return item
end

function ItemService:RemoveItem(item)
    if item then
        item:Destroy()
    end
end

-- 处理玩家拾取物品的逻辑
-- @param player: 拾取物品的玩家
-- @param item: 要拾取的物品实例
-- @param itemInfo: 物品配置信息
function ItemService:HandleItemPickup(player, item)
    if not player or not item then return end
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    if not item.Parent then return end

    local isGold = Interface.IsGold(item:GetAttribute("ItemId"))
    if isGold then
        local gold = item:GetAttribute("Gold")
        Knit.GetService("TaskService"):UpdateEscapeTask(gold)
        self.Items[item] = nil
        item:Destroy()
        return
    end
    -- 尝试将物品添加到玩家背包
    local success, errorMessage = Knit.GetService("InventoryService"):GiveToolToPlayer(player, item)
    if success then
        local itemId = item:GetAttribute("ItemId")
        if itemId and itemId ~= 0 then
            Knit.GetService("QuestService"):OnItemPicked(player, itemId, character:GetPivot().Position)
        end

        self.Items[item] = nil
        item:Destroy()
    else
        -- 添加失败，显示错误信息
        print(player.Name .. " 捡取失败: " .. (errorMessage or "未知错误"))
    end
end

-- 查找最近的物品
-- @param player: 玩家
-- @return item: 最近的物品
function ItemService:FindNearestItem(player)
    if not player or not player.Character then
        return nil
    end
    
    local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return nil
    end
    
    local playerPosition = humanoidRootPart.Position
    local nearestItem = nil
    local nearestDistance = math.huge
    
    -- 遍历所有物品，找到最近的一个
    for _, item in pairs(self.Items) do
        if item and item.Parent then -- 确保物品仍然存在
            local itemId = item:GetAttribute("ItemId")
            if not itemId then
                continue
            end
            
            local itemInfo = ItemConfig:GetByItemId(itemId)
            if not itemInfo or itemInfo.Type ~= GameConfig.ItemType.Collect then
                continue
            end
            
            local itemPosition = nil
            
            -- 获取物品位置
            if item:IsA("BasePart") then
                itemPosition = item.Position
            elseif item:IsA("Model") then
                itemPosition = item:GetPivot().Position
            end
            
            -- 计算距离
            if itemPosition then
                local distance = (playerPosition - itemPosition).Magnitude
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestItem = item
                end
            end
        end
    end
    
    return nearestItem
end

-- 查找最近的物品
-- @param player: 玩家
-- @return item: 最近的物品
function ItemService.Client:FindNearestItem(player)
    return self.Server:FindNearestItem(player)
end

function ItemService:GetItems()
    return self.Items
end

function ItemService.Client:GetItems()
    return self.Server:GetItems()
end

function ItemService:DestroyAllItems()
    for _, item in pairs(self.Items) do
        self:RemoveItem(item)
    end
    self.Items = {}
end

function ItemService:InitItems()
    if #self.Items > 0 then
        return
    end
    
    task.spawn(function()
        local islandId = Knit.GetService("IslandService"):GetIslandId()
        local designConfig = DesignConfig:GetByMapId(islandId)
        if not designConfig then return end

        local resArray = {}
        local resConfig = DesignResConfig:GetAll()
        for _, config in ipairs(resConfig) do
            if config.MapId == islandId then
                if not resArray[config.Resource] then
                    resArray[config.Resource] = {}
                end
                if not resArray[config.Resource][config.Refresh] then
                    resArray[config.Resource][config.Refresh] = {}
                end
                table.insert(resArray[config.Resource][config.Refresh], config)
            end
        end

        local resourceNum = designConfig.ResourceNum
        for _, data in pairs(resourceNum) do
            local resType = data[1]
            local num = data[2]
            if not resArray[resType] then continue end
            if resArray[resType][1] then
                for _, config in ipairs(resArray[resType][1]) do
                    local modelId = config.CanisterId
                    local gold
                    if config.Resource == 1 then
                        gold = math.random(config.GoldRange[1], config.GoldRange[2])
                        modelId = Interface.GetGoldModelId(gold)
                    end
                    local item = self:CreateItem(modelId, config.Position, config.DropGroup, GameConfig.GetItemAttribute(), true)
                    if gold and item then
                        item:SetAttribute("Gold", gold)
                    end
                    num -= 1
                    if num <= 0 then
                        break
                    end
                end
            end
            if resArray[resType][2] then
                Interface.randomTable(resArray[resType][2])
                for _, config in ipairs(resArray[resType][2]) do
                    local modelId = config.CanisterId
                    local gold
                    if config.Resource == 1 then
                        gold = math.random(config.GoldRange[1], config.GoldRange[2])
                        modelId = Interface.GetGoldModelId(gold)
                    end
                    local item = self:CreateItem(modelId, config.Position, config.DropGroup, GameConfig.GetItemAttribute(), true)
                    if gold and item then
                        item:SetAttribute("Gold", gold)
                    end
                    num -= 1
                    if num <= 0 then
                        break
                    end
                end
            end
        end

        -- task.spawn(function()
        --     self:CreateItem(507, Vector3.new(185, 11.6, -7.8), 1, GameConfig.GetItemAttribute(), true)
        -- end)
    end)
end

function ItemService:KnitInit()
end

function ItemService:KnitStart()
end

return ItemService
