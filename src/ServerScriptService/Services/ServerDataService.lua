-- ServerDataService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))

local ServerDataService = Knit.CreateService {
	Name = "ServerDataService",
	Client = {
        SendInitData = Knit.CreateSignal(),
        ShowTip = Knit.CreateSignal(),
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
        Knit.GetService("SettleService"):PlayerAdded(player)
        Knit.GetService("MonsterService"):PlayerAdded(player)
        local duanWeiData = Knit.GetService("DBService"):Get(player.UserId, "DuanWeiData")
        Knit.GetService("LevelService"):playerAdd(player, duanWeiData)
        local inventory = Knit.GetService("DBService"):Get(player.UserId, "PlayerInventory")
        local toolData = Knit.GetService("DBService"):Get(player.UserId, "PlayerToolData")
        Knit.GetService("InventoryService"):playerAdd(player, inventory, toolData)

        local hasEscapeTask = false
        local hasEscapeTime = false
        -- 获取传送数据
        local joinData = player:GetJoinData()
        if joinData and joinData.TeleportData then
            local localTeleportData = joinData.TeleportData
            local TaskService = Knit.GetService("TaskService")
            if not TaskService:GetIsInit() then
                if localTeleportData.EscapeTask then
                    TaskService:InitEscapeTask(localTeleportData.EscapeTask)
                    hasEscapeTask = true
                end

                if localTeleportData.EscapeTime then
                    TaskService:InitEscapeTime(localTeleportData.EscapeTime)
                    hasEscapeTime = true
                end
            else
                hasEscapeTask = true
                hasEscapeTime = true
            end
        else
            print(string.format("玩家 %s 没有传送数据", player.Name))
        end
        
        if not hasEscapeTask then
            Knit.GetService("TaskService"):InitEscapeTask(GameConfig.DefaultEscapeTask)
        end

        if not hasEscapeTime then
            Knit.GetService("TaskService"):InitEscapeTime(GameConfig.DefaultEscapeTime)
        end

        if not self.HasInitData[player.UserId] then
            self.Client.SendInitData:Fire(player, self:GetInitData(player))
        end
    end

    local function playerRemoved(player)
        Knit.GetService("InventoryService"):playerRemoved(player)
        Knit.GetService("GoldService"):playerRemoved(player)
        Knit.GetService("SettleService"):PlayerRemoving(player)
        Knit.GetService("DBService"):PlayerRemoving(player)
        Knit.GetService("MonsterService"):playerRemoved(player)
        Knit.GetService("LevelService"):playerRemoved(player)
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

function ServerDataService:ShowTip(player, tip)
    self.Client.ShowTip:Fire(player, tip)
end

return ServerDataService