-- TeleportService 服务
-- 使用Knit框架管理位置触发传送系统

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local TeleportServiceModule = Knit.CreateService {
    Name = "TeleportService",
    Client = {
        SendStartTeleport = Knit.CreateSignal(),
    },

    TeleportingPlayer = {},
}

-- ReserveServer配置
--local TARGET_PLACE_ID = 105534130650004  -- 目标传送场景ID（TestBoat）
local TARGET_PLACE_ID = 133323957345255

function TeleportServiceModule:KnitInit()
end

function TeleportServiceModule:KnitStart()
end

function TeleportServiceModule:isPlayerTeleport(player)
    return self.TeleportingPlayer[player.UserId]
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
function TeleportServiceModule:teleportToReserveServer(player, showUI)
    local SettleService = Knit.GetService("SettleService")
    local teleportData = SettleService:GetSettleData(player)
    if not teleportData then
        logMessage("ERROR", "玩家数据不存在", player)
        return false
    end

    -- 检查是否在Studio环境
    if isInStudio() then
        logMessage("INFO", "在实际游戏环境中，玩家将被传送到预留服务器副本", player)
        logMessage("INFO", "传送物品: " .. #teleportData.EscapeItems)
        logMessage("INFO", "物品总价值: " .. teleportData.TotalValue)
        logMessage("INFO", "物品总时间: " .. teleportData.TotalTime)
        logMessage("INFO", "是否成功: " .. tostring(teleportData.IsSuccess))
        return true
    end

    if showUI then
        self.Client.SendStartTeleport:Fire(player)
    end
    -- 记录玩家正在传送中
    self.TeleportingPlayer[player.UserId] = true
        
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
    self:teleportToReserveServer(player, false)
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
        local isInTrigger = Interface.isPlayerOnBoat(player)
        if isInTrigger then
            return self:teleportToReserveServer(player, true)
        end
    else
        return self:teleportToReserveServer(player, true)
    end
end

return TeleportServiceModule