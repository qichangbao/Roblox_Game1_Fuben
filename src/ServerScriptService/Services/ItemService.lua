-- ItemService 服务
-- 使用Knit框架管理物品生成和捡取系统

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local PosConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("PosConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))

local ItemService = Knit.CreateService {
    Name = "ItemService",
    Client = {},
}

function ItemService:CreateItem(itemName, position)
    local itemInfo = ItemConfig:GetByItem(itemName)
    if not itemInfo then
        warn("Item not found: " .. itemName)
        return
    end

    local part = game.ServerStorage:FindFirstChild(itemInfo.Model)
    if not part then
        warn("Item model not found: " .. itemInfo.Model)
        return
    end
    local item = part:Clone()
    item.Name = itemName
    item.Parent = workspace
    if item:IsA("BasePart") then
        item.Position = position
    elseif item:IsA("Model") then
        item:PivotTo(CFrame.new(position))
    end
    item:SetAttribute("CD", itemInfo.CD)
    item:SetAttribute("Duration", itemInfo.Duration)
    
    -- 创建 ProximityPrompt 实例
    local proximityPrompt = Instance.new("ProximityPrompt")
    proximityPrompt.Parent = item

    -- 基本属性配置
    proximityPrompt.ActionText = "Pick"
    proximityPrompt.ObjectText = itemInfo.DisplayName
    proximityPrompt.KeyboardKeyCode = Enum.KeyCode.E -- 键盘按键
    proximityPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX -- 手柄按键
    proximityPrompt.MaxActivationDistance = 10 -- 最大激活距离
    proximityPrompt.HoldDuration = itemInfo.PickTime -- 按住时间（0表示点击即可）
    proximityPrompt.RequiresLineOfSight = true -- 是否需要视线可见

    -- 当玩家触发提示时
    proximityPrompt.Triggered:Connect(function(player)
        print(player.Name .. " 触发了提示")
        -- 执行物品捡取逻辑
        self:HandleItemPickup(player, item)
    end)

    -- 当玩家开始按住时（仅当 HoldDuration > 0 时有效）
    proximityPrompt.PromptButtonHoldBegan:Connect(function(player)
        print(player.Name .. " 开始按住按钮")
    end)

    -- 当玩家停止按住时
    proximityPrompt.PromptButtonHoldEnded:Connect(function(player)
        print(player.Name .. " 停止按住按钮")
    end)
end

--[[
    处理物品捡取逻辑
    @param player 玩家对象
    @param item 物品实例
    @param itemName 物品名称
    @param itemInfo 物品配置信息
]]
function ItemService:HandleItemPickup(player, item)
    if not player or not item then
        warn("HandleItemPickup: 参数不完整")
        return
    end
    
    -- 检查物品是否还存在
    if not item.Parent then
        return
    end
    
    -- 尝试将物品添加到玩家背包
    local success, errorMessage = Knit.GetService("BackpackService"):GiveToolToPlayer(player, item)
    if success then
        -- 成功添加到背包，销毁世界中的物品
        item:Destroy()
        print(player.Name .. " 成功捡取了 " .. item.Name)
    else
        -- 添加失败，显示错误信息
        warn(player.Name .. " 捡取失败: " .. (errorMessage or "未知错误"))
    end
end

function ItemService:initItems()
    task.spawn(function()
        local items = {}
        for i = 1, GameConfig.ItemType.Max - 1 do
            local itemList = ItemConfig:GetAllByType(i)
            table.insert(items, itemList)
        end
        local coordinates = PosConfig:GetAll()
        -- 打乱coordinates数组并取前50个数据
        local shuffledCoordinates = {}
        for i, coord in pairs(coordinates) do
            table.insert(shuffledCoordinates, coord)
        end
        -- 使用Fisher-Yates洗牌算法打乱数组
        for i = #shuffledCoordinates, 2, -1 do
            local j = math.random(i)
            shuffledCoordinates[i], shuffledCoordinates[j] = shuffledCoordinates[j], shuffledCoordinates[i]
        end
        -- 取前50个数据
        local finalCoordinates = {}
        for i = 1, math.min(GameConfig.InitItemNums, #shuffledCoordinates) do
            table.insert(finalCoordinates, shuffledCoordinates[i])
        end
        coordinates = finalCoordinates
        for _, coord in pairs(coordinates) do
            if type(coord.Type) == "number" then
                if items[coord.Type] then
                    local item = items[coord.Type][math.random(1, #items[coord.Type])]
                    self:CreateItem(item.Item, coord.Position)
                end
            elseif type(coord.Type) == "string" then
                local typeList = string.split(coord.Type, ",")
                local type = typeList[math.random(1, #typeList)]
                if items[tonumber(type)] then
                    local item = items[tonumber(type)][math.random(1, #items[tonumber(type)])]
                    self:CreateItem(item.Item, coord.Position)
                end
            end
        end
    end)
end

function ItemService:KnitInit()
end

function ItemService:KnitStart()
    --self:initItems()
    self:CreateItem("传送装置", Vector3.new(353, -1.5, -160))
    -- self:CreateItem("额外的背包", Vector3.new(353, -1.5, -170))
    -- self:CreateItem("额外的背包", Vector3.new(353, -1.5, -180))
    -- self:CreateItem("额外的背包", Vector3.new(353, -1.5, -190))
    -- self:CreateItem("额外的背包", Vector3.new(353, -1.5, -200))
    -- self:CreateItem("额外的背包", Vector3.new(353, -1.5, -210))
    -- self:CreateItem("额外的背包", Vector3.new(353, -1.5, -220))
    -- self:CreateItem("额外的背包", Vector3.new(353, -1.5, -230))
    -- self:CreateItem("额外的背包", Vector3.new(353, -1.5, -240))
    -- self:CreateItem("额外的背包", Vector3.new(353, -1.5, -250))
end

return ItemService
