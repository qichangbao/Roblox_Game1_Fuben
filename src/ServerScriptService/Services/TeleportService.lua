-- TeleportService 服务
-- 使用Knit框架管理位置触发传送系统

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))

local TeleportServiceModule = Knit.CreateService {
    Name = "TeleportService",
    Client = {},
}

-- 在Part上方多少单位触发传送
local TRIGGER_HEIGHT_OFFSET = 5

-- ReserveServer配置
local TARGET_PLACE_ID = 105534130650004  -- 目标传送场景ID（TestBoat）
local _mainServerJobId = nil

-- 使用包围盒检测玩家是否在撤离区内
-- @param player Player 要检查的玩家
-- @param triggerModel Model 要检测的Model
-- @return boolean, number 是否在撤离区内以及高度差
local function checkPlayerOnModel(player, triggerModel)
    local humanoidRootPart = player.Character.HumanoidRootPart
    local playerPosition = humanoidRootPart.Position
    
    -- 获取Model的包围盒
    local modelCFrame, modelSize = triggerModel:GetBoundingBox()
    
    -- 将玩家位置转换到Model的本地坐标系
    local localPlayerPosition = modelCFrame:PointToObjectSpace(playerPosition)
    
    -- 计算包围盒的半尺寸
    local halfSize = modelSize / 2
    
    -- 检查玩家是否在包围盒的X和Z范围内
    local isInXRange = math.abs(localPlayerPosition.X) <= halfSize.X
    local isInZRange = math.abs(localPlayerPosition.Z) <= halfSize.Z
    
    if isInXRange and isInZRange then
        -- 计算玩家与Model顶部的高度差
        local modelTop = modelCFrame.Position.Y + halfSize.Y
        local modelBottom = modelCFrame.Position.Y - halfSize.Y
        local heightDifference = playerPosition.Y - modelTop
        
        -- 检查玩家是否在Model上方的合理高度范围内
        if heightDifference >= 0 and heightDifference <= TRIGGER_HEIGHT_OFFSET then
            return true, heightDifference
        end
        
        -- 如果在XZ范围内但高度不合适，检查是否在Model内部
        if playerPosition.Y >= modelBottom and playerPosition.Y <= modelTop then
            -- 玩家在Model内部，也算作触发
            local heightDifferenceFromBottom = playerPosition.Y - modelBottom
            return true, heightDifferenceFromBottom
        end
    end
    
    return false, math.huge
end

-- 检查玩家是否站在Model上面（使用射线检测）
-- @param player Player 要检查的玩家
-- @return boolean, Model 是否站在Model上面以及触发的Model
local function isPlayerInTriggerZone(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return false, nil
    end
    
    -- 检查每个触发Model
    for _, modelName in ipairs(GameConfig.TeleportPartNames) do
        local triggerModel = workspace:FindFirstChild(modelName)
        if triggerModel and triggerModel:IsA("Model") then
            local isOnModel, heightDifference = checkPlayerOnModel(player, triggerModel)
            
            if isOnModel then
                return true, triggerModel
            end
        end
    end
    
    return false, nil
end

-- 检查是否在Studio环境中
-- @return boolean 是否在Studio环境
local function isInStudio()
    return RunService:IsStudio()
end

-- 记录详细日志的函数
-- @param level string 日志级别 (INFO, WARN, ERROR)
-- @param message string 日志消息
-- @param player Player 相关玩家（可选）
local function logMessage(level, message, player)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local playerInfo = player and string.format(" [玩家:%s]", player.Name) or ""
    local logText = string.format("[%s] [%s]%s %s", timestamp, level, playerInfo, message)
    
    if level == "ERROR" then
        error(logText)
    elseif level == "WARN" then
        warn(logText)
    else
        print(logText)
    end
end

-- 传送玩家到预留服务器副本
-- @param player Player 要传送的玩家
-- @return void
local function teleportToReserveServer(player)
    local escapeItems = Knit.GetService("InventoryService"):GetEscapeItems(player)
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
    for i, itemId in ipairs(escapeItems) do
        local itemInfo = ItemConfig:GetByIndex(itemId)
        if itemInfo and itemInfo.SellPrice then
            totalValue += itemInfo.SellPrice
        end
    end
    local totalTime = tick() - player:GetAttribute("JoinTime")
    
    -- 准备传送数据
    local teleportData = {
        EscapeItems = escapeItems,
        TotalValue = totalValue,
        TotalTime = totalTime,
        IsSuccess = Knit.GetService("TaskService"):IsSuccess(),
    }
    
    -- 执行传送到预留服务器
    local teleportSuccess, teleportError = pcall(function()
        logMessage("INFO", string.format("开始传送到目标场景: %d", TARGET_PLACE_ID), player)
        TeleportService:Teleport(
            TARGET_PLACE_ID,
            player,
            teleportData
        )
    end)
    
    if teleportSuccess then
        return true
    end

    logMessage("WARN", string.format("传送到预留服务器失败: %s", tostring(teleportError)), player)
    return
end

-- 处理玩家传送到恐龙岛场景
-- @param player Player 要传送的玩家
-- @return void
local function teleportPlayerToDungeon(player)
    -- 检查是否在Studio环境
    if isInStudio() then
        logMessage("WARN", "Studio环境检测：模拟传送（实际传送已跳过）", player)
        logMessage("INFO", "在实际游戏环境中，玩家将被传送到预留服务器副本", player)
        return true
    end
    
    return teleportToReserveServer(player)
end

-- 检查玩家位置并处理传送
-- @param player Player 要检查的玩家
-- @return void
local function checkPlayerPosition(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    -- 检查玩家是否在触发区域内
    local isInTrigger, triggerPart = isPlayerInTriggerZone(player)
    if isInTrigger then
        return teleportPlayerToDungeon(player)
    end
end

function TeleportServiceModule.Client:Escape(player)
    return checkPlayerPosition(player)
end

function TeleportServiceModule:SetMainServerJobId(jobId)
    _mainServerJobId = jobId
end

function TeleportServiceModule:KnitStart()
end

return TeleportServiceModule