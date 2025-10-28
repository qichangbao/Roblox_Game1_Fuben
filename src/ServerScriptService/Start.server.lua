local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

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

_G.TriggerManager = require(ServerScriptService:WaitForChild("TriggerFolder"):WaitForChild("TriggerManager")).new()

-- 全局禁用自动重生
game.Players.CharacterAutoLoads = false

print("服务器JobID：", game.JobId)
print("服务器GameID：", game.GameId)
print("服务器PlaceID：", game.PlaceId)
print("服务器名称：", game.Name)
print("服务器PrivateServerId：", game.PrivateServerId)

-- 禁用自动本地化功能
local GuiService = game:GetService("GuiService")
pcall(function()
    GuiService.AutoLocalize = false
    print("已禁用自动本地化功能")
end)

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

local PhysicsService = game:GetService("PhysicsService")
PhysicsService:RegisterCollisionGroup("Player")
PhysicsService:RegisterCollisionGroup("Monster")
PhysicsService:CollisionGroupSetCollidable("Player", "Monster", false)