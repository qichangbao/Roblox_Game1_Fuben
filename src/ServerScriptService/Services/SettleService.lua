local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local DesignConfig = require(ReplicatedStorage:WaitForChild('ConfigFolder'):WaitForChild('DesignConfig'))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local SettleService = Knit.CreateService({
    Name = 'SettleService',
    Client = {
        SendShowUI = Knit.CreateSignal(),
        SuccEvacuation = Knit.CreateSignal(),
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

function SettleService:PlayerRemoved(player)
    self.SettleData[player.UserId] = nil
    -- 如果玩家不是正常退出，则判定为撤离失败，掉落身上所有物品
    if not Knit.GetService("TeleportService"):isPlayerTeleport(player) and not game:GetService("RunService"):IsStudio() then
        self:Settle(player, true)
    end
end

function SettleService:GetSettleData(player)
    return self.SettleData[player.UserId]
end

local function succ(player)
    local InventoryService = Knit.GetService("InventoryService")
    local toolData = InventoryService:GetToolData(player)
    local bagData = InventoryService:GetBagData(player)
    local totalValue = 0
    local totalTime = tick() - player:GetAttribute("JoinTime")
    local escapeItems = InventoryService:GetEscapeItems(player)
    if #escapeItems > 6 then
        -- 创建包含价格信息的物品数组
        local itemsWithPrice = {}
        for _, itemData in ipairs(escapeItems) do
            local itemInfo = ItemConfig:GetByItemId(itemData.ItemId)
            if itemInfo then
                table.insert(itemsWithPrice, {
                    ItemId = itemData.ItemId,
                    Attribute = itemData.Attribute,
                    SellPrice = itemData.Attribute.Gold,
                })
            end
        end
        
        -- 按价格降序排序
        table.sort(itemsWithPrice, function(a, b)
            return a.SellPrice > b.SellPrice
        end)
        
        -- 取前6个最高价值的物品
        local topSixItems = {}
        for i = 1, math.min(6, #itemsWithPrice) do
            table.insert(topSixItems, {
                ItemId = itemsWithPrice[i].ItemId,
                Attribute = itemsWithPrice[i].Attribute,
            })
        end
        
        -- 更新escapeItems为最高价值的6件物品
        escapeItems = topSixItems
    end

    for _, itemData in ipairs(escapeItems) do
        totalValue += itemData.Attribute.Gold
    end

    -- 获取玩家当前位置
    local playerPosition = player.Character:GetPivot().Position
    -- 使用高级射线检测获取最佳地面位置
    local ignoreList = {player.Character} -- 忽略玩家本身
    local groundPosition = Interface.getGroundPosition(playerPosition, ignoreList)
    -- 工具栏4-6格和背包的探索，辅助，进攻类物品可以带回出生岛
    for i = 1, #toolData do
        local data = toolData[i]
        if data.ItemId == 0 then continue end
        local itemInfo = ItemConfig:GetByItemId(data.ItemId)
        if not itemInfo then continue end
        if itemInfo.Type == GameConfig.ItemType.Collect then
            task.spawn(function()
                Knit.GetService("ItemService"):CreateItem(data.ItemId, groundPosition, 0, Vector3.new(0, 0, 0), data.Attribute, 0)
                task.wait(0.3)
            end)
        else if itemInfo.Type == GameConfig.ItemType.Explore
            or itemInfo.Type == GameConfig.ItemType.Weapon
            or itemInfo.Type == GameConfig.ItemType.Assistance
            or itemInfo.Type == GameConfig.ItemType.Treatment then
                table.insert(escapeItems, {
                    ItemId = data.ItemId,
                    Attribute = Interface.clone(data.Attribute),
                })
            end
        end
        toolData[i] = {ItemId = 0, Attribute = GameConfig.GetItemAttribute()}
    end

    InventoryService:UpdateToolData(player, toolData)
    for i = 1, #bagData do
        local data = bagData[i]
        if data.ItemId == 0 then continue end
        local itemInfo = ItemConfig:GetByItemId(data.ItemId)
        if not itemInfo then continue end
        if itemInfo.Type == GameConfig.ItemType.Collect then
            task.spawn(function()
                Knit.GetService("ItemService"):CreateItem(data.ItemId, groundPosition, 0, Vector3.new(0, 0, 0), data.Attribute, 0)
                task.wait(0.3)
            end)
        else if itemInfo.Type == GameConfig.ItemType.Explore
            or itemInfo.Type == GameConfig.ItemType.Weapon
            or itemInfo.Type == GameConfig.ItemType.Assistance
            or itemInfo.Type == GameConfig.ItemType.Treatment then
                table.insert(escapeItems, {
                    ItemId = data.ItemId,
                    Attribute = Interface.clone(data.Attribute),
                })
            end
        end
        bagData[i] = nil
    end

    return escapeItems, totalValue, totalTime
end

local function faild(player)
    local InventoryService = Knit.GetService("InventoryService")
    local toolData = InventoryService:GetToolData(player)
    local bagData = InventoryService:GetBagData(player)
    
    -- 添加 nil 值检查，防止 ipairs 接收到 nil
    if not toolData then
        toolData = {}
    end
    if not bagData then
        bagData = {}
    end
    
    -- 撤离失败，清空工具栏和背包
    local allItems = {}
    for _, itemData in ipairs(toolData) do
        if itemData.ItemId ~= 0 then
            table.insert(allItems, itemData)
        end
    end
    for _, itemData in ipairs(bagData) do
        if itemData.ItemId ~= 0 then
            table.insert(allItems, itemData)
        end
    end

    -- 清空工具栏和背包数据
    InventoryService:UpdateToolData(player)
    InventoryService:UpdateBagData(player)

    -- 获取玩家当前位置
    if player.Character then
        local playerPosition = player.Character:GetPivot().Position
        -- 使用高级射线检测获取最佳地面位置
        local ignoreList = {player.Character} -- 忽略玩家本身
        local groundPosition = Interface.getGroundPosition(playerPosition, ignoreList)
        for _, itemData in ipairs(allItems) do
            task.spawn(function()
                -- 触发物品丢弃条件
                _G.TriggerManager:DropItem(player, itemData.ItemId)
                Knit.GetService("ItemService"):CreateItem(itemData.ItemId, groundPosition, 0, Vector3.new(0, 0, 0), itemData.Attribute, 0)
                task.wait(0.3)
            end)
        end

        local humanoid = player.Character:FindFirstChild("Humanoid")
        if humanoid then
            Interface.decHp(player.Character, humanoid.MaxHealth)
        end
    end
end

-- 结算玩家
-- @param player Player 玩家对象
-- @param isForceLose boolean 是否强制失败
function SettleService:Settle(player, isForceLose)
    local InventoryService = Knit.GetService("InventoryService")
    local isSuccess = false
    local escapeItems = {}
    local totalValue = 0
    local totalTime = 0
    local killMonsters = Knit.GetService("MonsterService"):GetKillMonsters(player)
    if not isForceLose then
		local isOnBoat = Interface.isPlayerOnBoat(player)
        if isOnBoat then
            escapeItems, totalValue, totalTime = succ(player)
            isSuccess = true
        else
            faild(player)
        end
    else
        faild(player)
    end

    -- 清空背包数据
    InventoryService:UpdateBagData(player)
    InventoryService:ToolDataToDB(player)
    for _, v in pairs(escapeItems) do
        InventoryService:AddItem(player, v)
        Knit.GetService("JobService"):TriggerJob(player, GameConfig.JobUnlockCondition.CollectItemNum, {itemId = v.ItemId, count = 1})
    end
    InventoryService:InventoryToDB(player)

    local levelData = Knit.GetService("LevelService"):GetLevelData(player)
    -- 准备传送数据
    self.SettleData[player.UserId] = {
        LevelData = levelData,
        EscapeItems = escapeItems,
        KillMonsterNum = #killMonsters,
        TotalValue = totalValue,
        TotalTime = totalTime,
        IsSuccess = isSuccess,
    }

    self.Client.SendShowUI:Fire(player, self.SettleData[player.UserId])
    if isSuccess then
        self.Client.SuccEvacuation:FireAll(player.UserId)
    end
    return true
end

function SettleService.Client:Settle(player, isForceLose)
    return self.Server:Settle(player, isForceLose)
end

function SettleService:Escape(player)
    return Knit.GetService("TeleportService"):Escape(player)
end

function SettleService.Client:Escape(player)
    return self.Server:Escape(player)
end

return SettleService