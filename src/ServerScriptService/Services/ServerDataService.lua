-- ServerDataService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local ServerDataService = Knit.CreateService {
	Name = "ServerDataService",
	Client = {
        SendInitData = Knit.CreateSignal(),
	},

    HasInitData = {},       -- 记录玩家是否初始化数据
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
        player:SetAttribute("JoinTime", tick())

        Knit.GetService("DBService"):PlayerAdded(player)
        Knit.GetService("GoldService"):playerAdd(player, 0)

        local hasPlayerToolData = false
        local hasEscapeTask = false
        -- 获取传送数据
        local joinData = player:GetJoinData()
        if joinData and joinData.TeleportData then
            local JobId = joinData.TeleportData.JobId
            Knit.GetService("TeleportService"):SetMainServerJobId(JobId)

            local localTeleportData = joinData.TeleportData
            if localTeleportData.PlayersToolData then
                -- 获取该玩家的工具数据
                local playerToolData = localTeleportData.PlayersToolData[tostring(player.UserId)]
                if playerToolData then
                    Knit.GetService("InventoryService"):playerAdd(player, playerToolData)
                    hasPlayerToolData = true
                end
            end

            if localTeleportData.EscapeTask then
                Knit.GetService("TaskService"):InitEscapeTask(0, localTeleportData.EscapeTask)
                hasEscapeTask = true
            end
        end

        if not hasPlayerToolData then
            local toolData = Knit.GetService("DBService"):Get(player.UserId, "PlayerToolData")
            Knit.GetService("InventoryService"):playerAdd(player, toolData)
        end
        
        if not hasEscapeTask then
            Knit.GetService("TaskService"):InitEscapeTask(0, 100)
        end
        print(string.format("玩家 %s 没有传送数据", player.Name))

        if not self.HasInitData[player.UserId] then
            self.Client.SendInitData:Fire(player, self:GetInitData(player))
        end
    end

    local function playerRemoved(player)
        Knit.GetService("InventoryService"):playerRemoved(player)
        Knit.GetService("GoldService"):playerRemoved(player)
        Knit.GetService("DBService"):PlayerRemoving(player)
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
    if self.HasInitData[player.UserId] then
        return
    end

    local gold = 0
    local toolData = Knit.GetService("InventoryService"):GetToolData(player)

    if gold and toolData then
        self.HasInitData[player.UserId] = true
    end

    return {
        Gold = gold,
        ToolData = toolData,
    }
end

-- 客户端远程方法：获取玩家数据
-- @param player Player 请求数据的玩家
-- @return table 玩家数据
function ServerDataService.Client:GetInitData(player)
    return self.Server:GetInitData(player)
end

return ServerDataService