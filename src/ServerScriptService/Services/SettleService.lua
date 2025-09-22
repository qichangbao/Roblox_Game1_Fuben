local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))

local SettleService = Knit.CreateService({
    Name = 'SettleService',
    Client = {
        SendShowUI = Knit.CreateSignal(),
    },

    SettleData = {},
})

function SettleService:KnitInit()
end

function SettleService:KnitStart()
end

function SettleService:PlayerAdded(player)
    self.SettleData[player.UserId] = {}
end

function SettleService:PlayerRemoving(player)
    self.SettleData[player.UserId] = nil
end

function SettleService:GetSettleData(player)
    return self.SettleData[player.UserId]
end

function SettleService:Settle(player, needCheckPos)
    local InventoryService = Knit.GetService("InventoryService")
    local escapeItems = InventoryService:GetEscapeItems(player)
    if #escapeItems > 6 then
        -- 创建包含价格信息的物品数组
        local itemsWithPrice = {}
        for _, itemId in ipairs(escapeItems) do
            local itemInfo = ItemConfig:GetByIndex(itemId)
            if itemInfo and itemInfo.SellPrice then
                table.insert(itemsWithPrice, {
                    itemId = itemId,
                    sellPrice = itemInfo.SellPrice,
                    name = itemInfo.Item or "未知物品"
                })
            end
        end
        
        -- 按价格降序排序
        table.sort(itemsWithPrice, function(a, b)
            return a.sellPrice > b.sellPrice
        end)
        
        -- 取前6个最高价值的物品
        local topSixItems = {}
        for i = 1, math.min(6, #itemsWithPrice) do
            table.insert(topSixItems, itemsWithPrice[i].itemId)
        end
        
        -- 更新escapeItems为最高价值的6件物品
        escapeItems = topSixItems
    end

    local totalValue = 0
    for _, itemId in ipairs(escapeItems) do
        local itemInfo = ItemConfig:GetByIndex(itemId)
        if itemInfo and itemInfo.SellPrice then
            totalValue += itemInfo.SellPrice
        end
    end

    -- 工具栏4-6格和背包的探索，辅助，进攻类物品可以带回出生岛
    local toolData = InventoryService:GetToolData(player)
    for i = 4, #toolData do
        local data = toolData[i]
        if data.ItemId ~= 0 then
            local itemInfo = ItemConfig:GetByIndex(data.ItemId)
            if itemInfo and itemInfo.Type >= GameConfig.ItemType.Explore and itemInfo.Type <= GameConfig.ItemType.Assistance then
                table.insert(escapeItems, data.ItemId)
            end
        end
        toolData[i] = nil
    end
    local bagData = InventoryService:GetBagData(player)
    for i = 1, #bagData do
        local data = bagData[i]
        if data.ItemId ~= 0 then
            local itemInfo = ItemConfig:GetByIndex(data.ItemId)
            if itemInfo and itemInfo.Type >= GameConfig.ItemType.Explore and itemInfo.Type <= GameConfig.ItemType.Assistance then
                table.insert(escapeItems, data.ItemId)
            end
        end
        bagData[i] = nil
    end
    InventoryService:ToolDataToDB(player)

    local totalTime = tick() - player:GetAttribute("JoinTime")
    
    -- 准备传送数据
    self.SettleData[player.UserId] = {
        EscapeItems = escapeItems,
        TotalValue = totalValue,
        TotalTime = totalTime,
        IsSuccess = Knit.GetService("TaskService"):IsSuccess(),
        needCheckPos = needCheckPos,
    }

    self.Client.SendShowUI:Fire(player, self.SettleData[player.UserId])
end

function SettleService.Client:Settle(player, needCheckPos)
    self.Server:Settle(player, needCheckPos)
end

function SettleService:Escape(player, needCheckPos)
    return Knit.GetService("TeleportService"):Escape(player, needCheckPos)
end

function SettleService.Client:Escape(player, needCheckPos)
    return self.Server:Escape(player, needCheckPos)
end

return SettleService