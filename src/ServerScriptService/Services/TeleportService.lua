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

-- 使用向下射线检测玩家是否站在Model上面
-- @param player Player 要检查的玩家
-- @param triggerModel Model 要检测的Model
-- @return boolean, number 是否站在Model上面以及高度差
local function checkPlayerOnModel(player, triggerModel)
    local humanoidRootPart = player.Character.HumanoidRootPart
    local playerPosition = humanoidRootPart.Position
    
    -- 收集Model中所有的BasePart作为射线检测目标
    local modelParts = {}
    for _, descendant in pairs(triggerModel:GetDescendants()) do
        if descendant:IsA("BasePart") then
            table.insert(modelParts, descendant)
        end
    end
    
    if #modelParts == 0 then
        return false, math.huge
    end
    
    -- 创建射线参数
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
    raycastParams.FilterDescendantsInstances = modelParts
    
    -- 从玩家位置向下发射射线
    local rayOrigin = playerPosition
    local rayDirection = Vector3.new(0, -TRIGGER_HEIGHT_OFFSET - 2, 0)
    
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if raycastResult then
        local hitPart = raycastResult.Instance
        if hitPart and hitPart:IsDescendantOf(triggerModel) then
            local hitPosition = raycastResult.Position
            local heightDifference = playerPosition.Y - hitPosition.Y
            
            -- 检查高度差是否在合理范围内
            if heightDifference >= 0 and heightDifference <= TRIGGER_HEIGHT_OFFSET then
                return true, heightDifference
            end
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
        -- 获取物品配置服务
        
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
        for i, item in ipairs(itemsWithPrice) do
            if i <= 6 then
                logMessage("INFO", string.format("  选中: %s (价值: %d)", item.name, item.sellPrice), player)
            end
        end
    end
    
    -- 准备传送数据
    local teleportData = {
        EscapeItems = escapeItems,
    }
    
    -- 执行传送到预留服务器
    local teleportSuccess, teleportError = pcall(function()
        logMessage("INFO", string.format("开始传送到目标场景: %d", TARGET_PLACE_ID), player)
        TeleportService:TeleportToPlaceInstance(
            TARGET_PLACE_ID,
            _mainServerJobId,
            {player},
            nil, -- spawnName
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

-- 服务启动时的初始化
-- @return void
function TeleportServiceModule:KnitStart()
end

return TeleportServiceModule