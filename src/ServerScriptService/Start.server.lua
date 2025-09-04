local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

math.randomseed(os.time())

-- 初始化Knit框架
local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"):WaitForChild("Knit"))
Knit.AddServices(ServerScriptService:WaitForChild("Services"))

-- 服务器启动状态标志
local isServerStarted = false

Knit.Start():andThen(function()
    -- Knit启动完成，标记服务器已启动
    isServerStarted = true
    print("服务器启动完成！")
end):catch(warn)

-- 时间系统配置
local _gameTime = 12 -- 游戏时间（小时，0-24）
local _lastUpdateTime = tick() -- 上次更新的真实时间
local Real_To_Game_Second = 288-- 现实1秒 = 游戏288秒

-- 时间系统更新函数
-- @param deltaTime number 距离上次更新的真实时间间隔（秒）
local function updateGameTime(deltaTime)
    -- 计算游戏时间增量（小时）
    local gameTimeIncrement = (deltaTime * Real_To_Game_Second) / 3600
    
    -- 更新游戏时间
    _gameTime = _gameTime + gameTimeIncrement
    
    -- 确保时间在0-24小时范围内循环
    if _gameTime >= 24 then
        _gameTime = _gameTime - 24
    elseif _gameTime < 0 then
        _gameTime = _gameTime + 24
    end
    
    -- 更新Lighting的ClockTime
    Lighting.ClockTime = _gameTime
end

-- -- 连接到Heartbeat事件进行实时更新
-- game:GetService("RunService").Heartbeat:Connect(function(dt)
--     local currentTime = tick()
--     local deltaTime = currentTime - _lastUpdateTime
    
--     -- 更新游戏时间
--     updateGameTime(deltaTime)
    
--     -- 记录当前时间用于下次计算
--     _lastUpdateTime = currentTime
-- end)

-- local TriggerManager = require(ServerScriptService:WaitForChild("TriggerFolder"):WaitForChild("TriggerManager"))
-- TriggerManager.new()

-- 全局禁用自动重生
game.Players.CharacterAutoLoads = false

print("服务器JobID：", game.JobId)
print("服务器GameID：", game.GameId)
print("服务器PlaceID：", game.PlaceId)
print("服务器名称：", game.Name)

-- 服务器启动状态检查事件
local serverStartCheckEvent = Instance.new("RemoteEvent")
serverStartCheckEvent.Name = "IsServerStartOver"
serverStartCheckEvent.Parent = ReplicatedStorage

-- 处理客户端的服务器启动状态查询
-- @param player Player 发送请求的玩家
serverStartCheckEvent.OnServerEvent:Connect(function(player)
    print("收到来自玩家 " .. player.Name .. " 的服务器启动状态查询")
    -- 向客户端发送服务器启动状态
    serverStartCheckEvent:FireClient(player, isServerStarted)
end)


local function playerAdded(player)
	print("PlayerAdded    ", player.Name)
	
	player.CharacterAdded:Connect(function(character)
	end)
	
	player:LoadCharacter()
    
	-- 获取传送数据
	local joinData = player:GetJoinData()
	if not joinData or not joinData.TeleportData then
        local data = {1,1,4}
		print(string.format("玩家 %s 没有传送数据", player.Name))
		return
	end
	
	local localTeleportData = joinData.TeleportData
	if not localTeleportData.PlayersToolData then
		print(string.format("玩家 %s 的传送数据中没有工具数据", player.Name))
		return
	end
	
	-- 获取该玩家的工具数据
	local playerToolData = localTeleportData.PlayersToolData[tostring(player.UserId)]
	if not playerToolData then
		print(string.format("玩家 %s 在传送数据中没有找到对应的工具数据", player.Name))
		return
	end
	print(playerToolData)
    for i, v in pairs(playerToolData) do
        print(i, v)
    end
end

local function playerRemoving(player)
	print("playerRemoving    ", player.Name)
end

for _, player in Players:GetPlayers() do
	task.spawn(playerAdded, player)
end

Players.PlayerAdded:Connect(function(player)
	playerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	playerRemoving(player)
end)