-- TeleportService 服务
-- 使用Knit框架管理位置触发传送系统

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))

local TeleportServiceModule = Knit.CreateService {
    Name = "TeleportService",
    Client = {},
}

-- 在Part上方多少单位触发传送（减小范围提高精度）
local TRIGGER_HEIGHT_OFFSET = 5
-- 射线检测的最大距离
local RAYCAST_DISTANCE = 10

-- ReserveServer配置
local TARGET_PLACE_ID = 105534130650004  -- 目标传送场景ID（TestBoat）

function TeleportServiceModule:KnitInit()
end

function TeleportServiceModule:KnitStart()
end

-- 使用射线检测玩家是否真正站在Model上
-- @param player Player 要检查的玩家
-- @param triggerModel Model 要检测的Model
-- @return boolean, number 是否在撤离区内以及高度差
local function checkPlayerOnModel(player, triggerModel)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return false, math.huge
    end
    
    local humanoidRootPart = player.Character.HumanoidRootPart
    local playerPosition = humanoidRootPart.Position
    
    -- 创建射线检测参数
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Include
    raycastParams.FilterDescendantsInstances = {triggerModel}
    
    -- 从玩家脚下向下发射射线
    local rayOrigin = playerPosition + Vector3.new(0, 1, 0) -- 稍微抬高起点
    local rayDirection = Vector3.new(0, -RAYCAST_DISTANCE, 0)
    
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if raycastResult then
        local hitPart = raycastResult.Instance
        local hitPosition = raycastResult.Position
        
        -- 检查射线是否击中了triggerModel中的Part
        if hitPart and hitPart:IsDescendantOf(triggerModel) then
            -- 计算玩家位置到击中点的距离（使用HumanoidRootPart位置更准确）
            local heightDifference = playerPosition.Y - hitPosition.Y
            
            -- 当玩家站在船上的物体上时，heightDifference可能是负数
            -- 我们需要检查玩家是否在合理的高度范围内（可以在船体上方或下方一定距离）
            if math.abs(heightDifference) <= TRIGGER_HEIGHT_OFFSET then
                return true
            end
        end
    end
    
    return false
end

-- 检查玩家是否站在Model上面（使用射线检测）
-- @param player Player 要检查的玩家
-- @return boolean, Model 是否站在Model上面以及触发的Model
local function isPlayerInTriggerZone(player)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end
    
    -- 检查每个触发Model
    for _, modelName in ipairs(GameConfig.TeleportPartNames) do
        local triggerModel = workspace:FindFirstChild(GameConfig.LandName):FindFirstChild("Special"):FindFirstChild(modelName)
        if triggerModel and triggerModel:IsA("Model") then
            return checkPlayerOnModel(player, triggerModel)
        end
    end
    
    return false
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
    local SettleService = Knit.GetService("SettleService")
    local teleportData = SettleService:GetSettleData(player)
    if not teleportData then
        logMessage("ERROR", "玩家数据不存在", player)
        return false
    end

    -- 检查是否在Studio环境
    if isInStudio() then
        logMessage("INFO", "在实际游戏环境中，玩家将被传送到预留服务器副本", player)
        logMessage("INFO", "传送物品: " .. table.concat(teleportData.EscapeItems, ", "))
        logMessage("INFO", "物品总价值: " .. teleportData.TotalValue)
        logMessage("INFO", "物品总时间: " .. teleportData.TotalTime)
        logMessage("INFO", "是否成功: " .. tostring(teleportData.IsSuccess))
        return true
    end
    
	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData(teleportData)
    -- 执行传送到预留服务器
    local teleportSuccess, teleportError = pcall(function()
        logMessage("INFO", string.format("开始传送到目标场景: %d", TARGET_PLACE_ID), player)
        TeleportService:TeleportAsync(
            TARGET_PLACE_ID,
            {player},
            teleportOptions
        )
    end)
    
    if teleportSuccess then
        return true
    end
    logMessage("WARN", string.format("传送到预留服务器失败: %s", tostring(teleportError)), player)
end

-- 传送
-- @param player Player 要检查的玩家
-- @return void
function TeleportServiceModule:Escape(player, needCheckPos)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    if needCheckPos then
        -- 检查玩家是否在触发区域内
        local isInTrigger = isPlayerInTriggerZone(player)
        if isInTrigger then
            return teleportToReserveServer(player)
        end
    else
        return teleportToReserveServer(player)
    end
end

return TeleportServiceModule