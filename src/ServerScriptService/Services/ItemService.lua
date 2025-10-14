-- ItemService 服务
-- 使用Knit框架管理物品生成和捡取系统

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local PosConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("PosConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local PlanConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("PlanConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local ItemFolder = ServerStorage:WaitForChild("Item")
if not ItemFolder then
    warn("Item folder not found")
    return
end

local ItemService = Knit.CreateService {
    Name = "ItemService",
    Client = {
    },

    ChestNum = 0,
    Items = {},
}

-- 创建炫彩宝箱特效
function ItemService:CreateXuanCaiChestEffect(position)
    local effect = ServerStorage:WaitForChild("Effect"):WaitForChild("XuanCaiChestEffect"):Clone()
    effect.Name = "XuanCaiChestEffect"
    effect.Parent = workspace
    effect:PivotTo(CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)))
end

-- 创建物品
function ItemService:CreateItem(itemId, position, attribute, isAnchored)
    if itemId == 0 then
        return
    end

    local itemInfo = ItemConfig:GetByIndex(itemId)
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
    item.Parent = workspace
    if item:IsA("BasePart") then
        item.Position = Vector3.new(position.X, position.Y + item.Size.Y / 2, position.Z)
    elseif item:IsA("Model") then
        item:PivotTo(CFrame.new(Vector3.new(position.X, position.Y + item.PrimaryPart.Size.Y / 2, position.Z)))
    end
    item:SetAttribute("ItemId", itemId)
    if attribute then
        attribute.IsEquipped = 0
    end
    GameConfig.SetItemAttribute(item, attribute)

    -- 创建外发光
    local highlight = Instance.new("Highlight")
    highlight.Parent = item
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0.85
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    
    -- 创建 ProximityPrompt 实例
    local proximityPrompt = Instance.new("ProximityPrompt")
    proximityPrompt.Parent = item

    -- 基本属性配置
    if itemInfo.Type == GameConfig.ItemType.Chest then
        proximityPrompt.ActionText = "Open"
    elseif itemInfo.Type == GameConfig.ItemType.Mound then
        proximityPrompt.ActionText = "Dig with a shovel"
    else
        proximityPrompt.ActionText = "Pick"
    end
    proximityPrompt.ObjectText = itemInfo.DisplayName
    proximityPrompt.KeyboardKeyCode = Enum.KeyCode.E -- 键盘按键
    proximityPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX -- 手柄按键
    proximityPrompt.MaxActivationDistance = 10 -- 最大激活距离
    proximityPrompt.HoldDuration = itemInfo.PickTime -- 按住时间（0表示点击即可）
    proximityPrompt.RequiresLineOfSight = true -- 是否需要视线可见

    -- 当玩家触发提示时
    proximityPrompt.Triggered:Connect(function(player)
        -- 执行物品捡取逻辑
        self:HandleItemPickup(player, item, itemInfo)
    end)

    -- 当玩家开始按住时（仅当 HoldDuration > 0 时有效）
    proximityPrompt.PromptButtonHoldBegan:Connect(function(player)
    end)

    -- 当玩家停止按住时
    proximityPrompt.PromptButtonHoldEnded:Connect(function(player)
    end)

    if isAnchored then
        task.delay(0.5, function()
            if item:IsA("BasePart") then
                -- 设置Part的锚固为false
                item.Anchored = true
            elseif item:IsA("Model") then
                -- 遍历Model中的所有Part，设置锚固为false
                for _, descendant in pairs(item:GetDescendants()) do
                    if descendant:IsA("BasePart") then
                        descendant.Anchored = true
                    end
                end
            end
        end)
    end

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
function ItemService:HandleItemPickup(player, item, itemInfo)
    if not player or not item then
        warn("HandleItemPickup: 参数不完整")
        return
    end
    
    -- 检查玩家是否死亡
    local character = player.Character
    if not character then
        return
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return
    end
    
    -- 检查物品是否还存在
    if not item.Parent then
        return
    end
    
    if itemInfo.Type == GameConfig.ItemType.Chest then
        -- 宝箱类物品，调用ChestService处理奖励
        Knit.GetService("ChestService"):OpenChest(player, item, itemInfo)
        return
    end

    --  mound 类物品不能拾取
    if itemInfo.Type == GameConfig.ItemType.Mound then
        return
    end

    -- 尝试将物品添加到玩家背包
    local success, errorMessage = Knit.GetService("InventoryService"):GiveToolToPlayer(player, item)
    if success then
        item:Destroy()
    else
        -- 添加失败，显示错误信息
        print(player.Name .. " 捡取失败: " .. (errorMessage or "未知错误"))
    end
end

-- 根据计划数据创建物品
-- @param planData: 计划数据
-- @param position: 物品位置
-- @param isAnchored: 是否固定物品
function ItemService:CreateItemByPlan(planData, position, isAnchored)
    if planData.CanisterId ~= 0 then    -- 宝箱类物品，调用ChestService处理奖励
        local random = math.random(1, 10000)
        if random <= planData.ChestProbability and self.ChestNum < GameConfig.ChestMaxNum then
            self.ChestNum += 1
            local item = self:CreateItem(planData.CanisterId, position, GameConfig.GetItemAttribute(), isAnchored)
            if planData.CanisterId == 503 then
                if type(planData.ItemId) == "table" then
                    for i, itemIdTemp in pairs(planData.ItemId) do
                        if itemIdTemp == 1035 then
                            self:CreateXuanCaiChestEffect(item:GetPivot().Position)
                            break
                        end
                    end
                else
                    if planData.ItemId == 1035 then
                        self:CreateXuanCaiChestEffect(item:GetPivot().Position)
                    end
                end
            end
            return item
        end
    else                                -- 普通物品
        if type(planData.ItemId) ~= "table" then
            local random = math.random(1, 10000)
            if random <= planData.Probability then
                return self:CreateItem(planData.ItemId, position, GameConfig.GetItemAttribute(), isAnchored)
            end
        else
            for index, itemId in pairs(planData.ItemId) do
                local random = math.random(1, 10000)
                if random <= planData.Probability[index] then
                    return self:CreateItem(itemId, position, GameConfig.GetItemAttribute(), isAnchored)
                end
            end
        end
    end
end

function ItemService:initItems()
    local posHasItem = {}
    local pos = PosConfig:GetAll()
    -- 随机打乱数组
    local posArray = Interface.randomTable(pos)
    for _, posData in pairs(posArray) do
        local posKey = Vector3.new(math.floor(posData.Position.X), math.floor(posData.Position.Y), math.floor(posData.Position.Z))
        if posHasItem[posKey] then
            print("位置已存在物品", posKey)
            continue
        end

        local planData = PlanConfig:GetByPlanId(posData.PlanId)
        if not planData then
            continue
        end

        local item = self:CreateItemByPlan(planData, posData.Position, false)
        if item then
            table.insert(self.Items, item)
            posHasItem[posKey] = true
        end
    end

    for _, item in pairs(self.Items) do
        if item:IsA("BasePart") then
            -- 设置Part的锚固为false
            item.Anchored = true
        elseif item:IsA("Model") then
            if item.PrimaryPart then
                item.PrimaryPart.Anchored = true
            end
        end
    end
end

function ItemService:KnitInit()
end

function ItemService:KnitStart()
    self:initItems()
    -- task.spawn(function()
    --     local itemTemp = self:CreateItem(1035, Vector3.new(353, -1.5, -250), GameConfig.GetItemAttribute(), false)
    --     if itemTemp then
    --         table.insert(self.Items, itemTemp)
    --     end

    --     task.delay(5, function()
    --         for _, item in pairs(self.Items) do
    --             if item:IsA("BasePart") then
    --                 -- 设置Part的锚固为false
    --                 item.Anchored = true
    --             elseif item:IsA("Model") then
    --                 if item.PrimaryPart then
    --                     item.PrimaryPart.Anchored = true
    --                 end
    --             end
    --         end
    --     end)
    -- end)
    -- self:CreateItem(1032, Vector3.new(353, -1.5, -160), GameConfig.GetItemAttribute(), false)
    -- self:CreateItem(1032, Vector3.new(353, -1.5, -170), GameConfig.GetItemAttribute(), false)
    -- self:CreateItem(1032, Vector3.new(353, -1.5, -180), GameConfig.GetItemAttribute(), false)
    -- self:CreateItem(1032, Vector3.new(353, -1.5, -190), GameConfig.GetItemAttribute(), false)
    -- self:CreateItem(1032, Vector3.new(353, -1.5, -200), GameConfig.GetItemAttribute(), false)
    -- self:CreateItem(1032, Vector3.new(353, -1.5, -210), GameConfig.GetItemAttribute(), false)
    -- self:CreateItem(1032, Vector3.new(353, -1.5, -220), GameConfig.GetItemAttribute(), false)
    -- self:CreateItem("额外的背包", Vector3.new(353, -1.5, -230), GameConfig.GetItemAttribute(), false)
    -- self:CreateItem("额外的背包", Vector3.new(353, -1.5, -240), GameConfig.GetItemAttribute(), false)
    -- self:CreateItem("额外的背包", Vector3.new(353, -1.5, -250), GameConfig.GetItemAttribute(), false)
end

return ItemService
