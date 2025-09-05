-- ServerDataService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local ServerDataService = Knit.CreateService {
	Name = "ServerDataService",
	Client = {
	},
}

function ServerDataService:KnitInit()
end

-- 服务启动时的初始化
-- @return void
function ServerDataService:KnitStart()
    local function playerAdd(player)
        print("PlayerAdded    ", player.Name)
        
        player.CharacterAdded:Connect(function(character)
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.AutoJumpEnabled = false
            end
        end)
        
        player:LoadCharacter()

        Knit.GetService("DBService"):PlayerAdded(player)
        Knit.GetService("GoldService"):playerAdd(player, 0)
        -- 获取传送数据
        local joinData = player:GetJoinData()
        if not joinData or not joinData.TeleportData then
            local toolData = Knit.GetService("DBService"):Get(player.UserId, "PlayerToolData")
            Knit.GetService("InventoryService"):playerAdd(player, toolData)
            Knit.GetService("TaskService"):playerAdd(player, {{Type = 1, Target = 10000}})
            print(string.format("玩家 %s 没有传送数据", player.Name))
            return
        end
        
        local localTeleportData = joinData.TeleportData
        if localTeleportData.PlayersToolData then
            -- 获取该玩家的工具数据
            local playerToolData = localTeleportData.PlayersToolData[tostring(player.UserId)]
            if playerToolData then
                Knit.GetService("InventoryService"):playerAdd(player, playerToolData)
            else
                local toolData = Knit.GetService("DBService"):Get(player.UserId, "PlayerToolData")
                Knit.GetService("InventoryService"):playerAdd(player, toolData)
                print(string.format("玩家 %s 在传送数据中没有找到对应的工具数据", player.Name))
            end
        else
            local toolData = Knit.GetService("DBService"):Get(player.UserId, "PlayerToolData")
            Knit.GetService("InventoryService"):playerAdd(player, toolData)
            print(string.format("玩家 %s 的传送数据中没有工具数据", player.Name))
        end
    

        if localTeleportData.TaskGold then
            Knit.GetService("TaskService"):playerAdd(player, {{Type = 1, Target = localTeleportData.TaskGold}})
        else
            Knit.GetService("TaskService"):playerAdd(player, {{Type = 1, Target = 10000}})
        end
    end

    local function playerRemoved(player)
        Knit.GetService("InventoryService"):playerRemoved(player)
        Knit.GetService("GoldService"):playerRemoved(player)
        Knit.GetService("DBService"):PlayerRemoving(player)
        Knit.GetService("TaskService"):playerRemoved(player)
    end

    for _, player in pairs(Players:GetPlayers()) do
        playerAdd(player)
    end
	
	-- 监听玩家加入事件
	Players.PlayerAdded:Connect(function(player)
        playerAdd(player)
	end)

	-- 监听玩家离开事件
	Players.PlayerRemoving:Connect(function(player)
        playerRemoved(player)
	end)
end

function ServerDataService:GetInitData(player)
    local gold = 0
    local toolData = Knit.GetService("InventoryService"):GetToolData(player)
    local taskData = Knit.GetService("TaskService"):GetTaskData(player)

    return {
        Gold = gold,
        ToolData = toolData,
        TaskData = taskData,
    }
end

-- 客户端远程方法：获取玩家数据
-- @param player Player 请求数据的玩家
-- @return table 玩家数据
function ServerDataService.Client:GetInitData(player)
    return self.Server:GetInitData(player)
end

return ServerDataService