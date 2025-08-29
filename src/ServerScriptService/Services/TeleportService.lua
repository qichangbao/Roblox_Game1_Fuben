-- TeleportService 服务
-- 使用Knit框架管理位置触发传送系统

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))

local TeleportServiceModule = Knit.CreateService {
    Name = "TeleportService",
    Client = {},
}

-- 玩家位置检测数据
local playerPositionData = {}

-- 在Part上方多少单位触发传送
local TRIGGER_HEIGHT_OFFSET = 5

-- ReserveServer配置
local TARGET_PLACE_ID = 105534130650004  -- 目标传送场景ID（TestBoat）
local RESERVE_SERVER_COOLDOWN = 10 -- 预留服务器冷却时间（秒）

-- 创建的场景缓存
local createdPlaces = {}
-- 存储玩家的预留服务器使用记录
local playerReserveData = {}

-- 初始化玩家位置数据
-- @param player Player 玩家实例
-- @return void
local function initializePlayerPositionData(player)
    if not playerPositionData[player.UserId] then
        playerPositionData[player.UserId] = {
            lastTeleportTime = 0,
            hasTriggered = false
        }
    end
end

-- 检查玩家是否在任何触发Part的上方
-- @param player Player 要检查的玩家
-- @return boolean, BasePart 是否在触发范围内以及触发的Part
local function isPlayerInTriggerZone(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return false, nil
    end
    
    local playerPosition = player.Character.HumanoidRootPart.Position
    local land = workspace:FindFirstChild(GameConfig.LandName)
    if not land then
        error(string.format("未找到%s", GameConfig.LandName))
        return false, nil
    end
    -- 检查每个触发Part
    for _, partName in ipairs(GameConfig.TeleportPartNames) do
        local triggerPart = land:FindFirstChild(partName)
        if triggerPart and triggerPart:IsA("BasePart") then
            local partPosition = triggerPart.Position
            local partSize = triggerPart.Size
            
            -- 检查玩家是否在Part的X和Z范围内，且在Part上方指定高度内
            local xInRange = math.abs(playerPosition.X - partPosition.X) <= partSize.X / 2
            local zInRange = math.abs(playerPosition.Z - partPosition.Z) <= partSize.Z / 2
            local yAbovePart = playerPosition.Y >= partPosition.Y + partSize.Y / 2 and 
                              playerPosition.Y <= partPosition.Y + partSize.Y / 2 + TRIGGER_HEIGHT_OFFSET
            
            if xInRange and zInRange and yAbovePart then
                return true, triggerPart
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

-- 创建预留服务器副本
-- @param player Player 触发的玩家
-- @return string|nil 预留服务器访问码，失败时返回nil
local function createReserveServer(player)
    logMessage("INFO", "开始创建预留服务器副本", player)
    
    -- 检查冷却时间
    local currentTime = tick()
    local lastReserveTime = playerReserveData[player.UserId] or 0
    local cooldownRemaining = RESERVE_SERVER_COOLDOWN - (currentTime - lastReserveTime)
    
    if cooldownRemaining > 0 then
        logMessage("WARN", string.format("预留服务器冷却中，剩余时间: %.1f 秒", cooldownRemaining), player)
        return nil
    end
    
    -- 创建预留服务器
    local success, result = pcall(function()
        logMessage("INFO", "正在调用ReserveServer API...", player)
        logMessage("INFO", string.format("目标场景ID: %d", TARGET_PLACE_ID), player)
        
        -- 创建预留服务器访问码（使用目标场景ID）
        local accessCode = TeleportService:ReserveServer(TARGET_PLACE_ID)
        
        logMessage("INFO", string.format("预留服务器创建成功，访问码: %s", accessCode), player)
        return accessCode
    end)
    
    if success and result then
        playerReserveData[player.UserId] = currentTime
        logMessage("INFO", "预留服务器副本创建完成", player)
        return result
    else
        logMessage("ERROR", string.format("预留服务器创建失败: %s", tostring(result)), player)
        return nil
    end
end

-- 传送玩家到预留服务器副本
-- @param player Player 要传送的玩家
-- @return void
local function teleportToReserveServer(player)
    logMessage("INFO", "开始传送到预留服务器副本", player)
    
    -- 创建预留服务器
    local accessCode = createReserveServer(player)
    if not accessCode then
        logMessage("WARN", "无法创建预留服务器，使用备用场景", player)
        return
    end
    
    -- 准备传送数据
    local teleportData = {
        playerName = player.Name,
        userId = player.UserId,
        timestamp = os.time(),
        source = "dinosaur_island_trigger",
        serverType = "reserve_server",
        accessCode = accessCode
    }
    
    logMessage("INFO", "准备传送数据完成，开始传送", player)
    
    -- 执行传送到预留服务器
    local teleportSuccess, teleportError = pcall(function()
        logMessage("INFO", string.format("开始传送到目标场景: %d", TARGET_PLACE_ID), player)
        TeleportService:TeleportToPrivateServer(
            TARGET_PLACE_ID,
            accessCode,
            {player},
            nil, -- spawnName
            teleportData
        )
    end)
    
    if teleportSuccess then
        logMessage("INFO", "传送到预留服务器成功", player)
    else
        logMessage("WARN", string.format("传送到预留服务器失败: %s", tostring(teleportError)), player)
    end
end

-- 处理玩家传送到恐龙岛场景
-- @param player Player 要传送的玩家
-- @return void
local function teleportPlayerToDungeon(player)
    local currentTime = tick()
    local userId = player.UserId
    local playerData = playerPositionData[userId]
    
    logMessage("INFO", "到达触发位置，开始传送流程", player)
    
    -- 防止重复传送（10秒内只能传送一次）
    if currentTime - playerData.lastTeleportTime < 10 then
        logMessage("WARN", string.format("传送冷却中，剩余时间: %.1f秒", 10 - (currentTime - playerData.lastTeleportTime)), player)
        return
    end
    
    logMessage("INFO", "传送冷却检查通过", player)
    
    -- 更新传送时间
    playerData.lastTeleportTime = currentTime
    playerData.hasTriggered = true
    
    -- 检查是否在Studio环境
    if isInStudio() then
        logMessage("WARN", "Studio环境检测：模拟传送（实际传送已跳过）", player)
        logMessage("INFO", "在实际游戏环境中，玩家将被传送到预留服务器副本", player)
        return
    end
    
    logMessage("INFO", "使用ReserveServer方式传送", player)
    teleportToReserveServer(player)
end

-- 检查玩家位置并处理传送
-- @param player Player 要检查的玩家
-- @return void
local function checkPlayerPosition(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local userId = player.UserId
    
    -- 确保玩家数据已初始化
    initializePlayerPositionData(player)
    local playerData = playerPositionData[userId]
    
    -- 检查玩家是否在触发区域内
    local isInTrigger, triggerPart = isPlayerInTriggerZone(player)
    
    if isInTrigger then
        if not playerData.hasTriggered then
            -- 玩家首次进入触发区域
            logMessage("INFO", string.format("进入传送触发区域: %s", triggerPart.Name), player)
            teleportPlayerToDungeon(player)
        end
    else
        -- 玩家离开触发区域，重置触发状态
        if playerData.hasTriggered then
            playerData.hasTriggered = false
            logMessage("INFO", "离开传送触发区域", player)
        end
    end
end

-- 服务启动时的初始化
-- @return void
function TeleportServiceModule:KnitStart()
    -- 监听玩家加入事件
    Players.PlayerAdded:Connect(function(player)
        initializePlayerPositionData(player)
    end)
    
    -- 监听玩家离开事件
    Players.PlayerRemoving:Connect(function(player)
        if playerPositionData[player.UserId] then
            playerPositionData[player.UserId] = nil
        end
        
        -- 清理该玩家的场景创建记录
        if createdPlaces[player.UserId] then
            createdPlaces[player.UserId] = nil
        end
        
        -- 清理该玩家的预留服务器记录
        if playerReserveData[player.UserId] then
            playerReserveData[player.UserId] = nil
        end
    end)
    
    -- 启动位置检测循环
    RunService.Heartbeat:Connect(function()
        for _, player in pairs(Players:GetPlayers()) do
            checkPlayerPosition(player)
        end
    end)
end

return TeleportServiceModule