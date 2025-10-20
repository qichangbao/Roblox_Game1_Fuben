-- PlayerService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local AbilityConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("AbilityConfig"))

local PlayerService = Knit.CreateService {
	Name = "PlayerService",
	Client = {
	},

    AbilityData = {},
}

function PlayerService:KnitInit()
end

-- 服务启动时的初始化
-- @return void
function PlayerService:KnitStart()
    local function playerAdd(player)
        print("PlayerAdded    ", player.Name)
        
        player.CharacterAdded:Connect(function(character)
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.AutoJumpEnabled = false
                humanoid.UseJumpPower = true
                player:SetAttribute("InitHealth", humanoid.Health)
                player:SetAttribute("InitWalkSpeed", humanoid.WalkSpeed)
                player:SetAttribute("InitJumpPower", humanoid.JumpPower)
                player:SetAttribute("InitMaxHealth", humanoid.MaxHealth)
                player:SetAttribute("InitAttack", 1)
                
                self:InitPlayerAbility(player, self.AbilityData[player.UserId])
            end
            
            -- 递归遍历角色下的所有Part并设置CollisionGroup
            local function setCollisionGroupForAllParts(parent)
                for _, child in ipairs(parent:GetChildren()) do
                    if child:IsA("BasePart") then
                        child.CollisionGroup = "Player"
                    end
                    -- 递归处理子对象
                    setCollisionGroupForAllParts(child)
                end
            end
            
            -- 为角色下的所有Part设置CollisionGroup
            setCollisionGroupForAllParts(character)
            
            -- 监听新添加的Part（如装备、配件等）
            character.ChildAdded:Connect(function(child)
                if child:IsA("BasePart") then
                    child.CollisionGroup = "Player"
                elseif child:IsA("Model") or child:IsA("Folder") then
                    -- 如果是模型或文件夹，递归设置其中的Part
                    setCollisionGroupForAllParts(child)
                end
            end)
        end)
        
        player:LoadCharacter()
        player:SetAttribute("JoinTime", tick())
        player:SetAttribute("HumanoidType", GameConfig.HumanoidType.Player)
    end

    local function playerRemoved(player)
        Knit.GetService("SettleService"):PlayerRemoving(player)
        Knit.GetService("InventoryService"):playerRemoved(player)
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

function PlayerService:GetInitData(player)
    Knit.GetService("DBService"):PlayerAdded(player)
    Knit.GetService("SettleService"):PlayerAdded(player)
    Knit.GetService("MonsterService"):PlayerAdded(player)
    local duanWeiData = Knit.GetService("DBService"):Get(player.UserId, "DuanWeiData")
    Knit.GetService("LevelService"):playerAdd(player, duanWeiData)
    local inventory = nil
    local tool = nil
    local ability = nil

    local hasEscapeTask = false
    local hasEscapeTime = false
    local difficulty = GameConfig.Difficulty.Easy
    -- 获取传送数据
    local joinData = player:GetJoinData()
    if joinData and joinData.TeleportData then
        local localTeleportData = joinData.TeleportData
        if localTeleportData.PlayerData then
            local playerData = localTeleportData.PlayerData[tostring(player.UserId)]
            if playerData and playerData.InventoryData and playerData.ToolData then
                inventory = playerData.InventoryData
                tool = playerData.ToolData
                Knit.GetService("InventoryService"):playerAdd(player, inventory, tool)
            end
            ability = playerData.AbilityData
        end

        difficulty = localTeleportData.Difficulty or GameConfig.Difficulty.Easy
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

    if not inventory and not tool then
        inventory = Knit.GetService("DBService"):Get(player.UserId, "PlayerInventory")
        tool = Knit.GetService("DBService"):Get(player.UserId, "PlayerToolData")
        Knit.GetService("InventoryService"):playerAdd(player, inventory, tool)
    end

    if ability then
        self.AbilityData[player.UserId] = ability
        self:InitPlayerAbility(player, ability)
    end
    
    if not hasEscapeTask then
        Knit.GetService("TaskService"):InitEscapeTask(GameConfig.DefaultEscapeTask)
    end

    if not hasEscapeTime then
        Knit.GetService("TaskService"):InitEscapeTime(GameConfig.DefaultEscapeTime)
    end

    local inventoryData = Knit.GetService("InventoryService"):GetInventoryData(player)
    local toolData = Knit.GetService("InventoryService"):GetToolData(player)
    local escapeTask = Knit.GetService("TaskService"):GetEscapeTask()
    local escapeTime = Knit.GetService("TaskService"):GetEscapeTime()

    return {
        Inventory = inventoryData,
        ToolData = toolData,
        EscapeTask = escapeTask,
        EscapeTime = escapeTime,
        Difficulty = difficulty,
    }
end

-- 客户端远程方法：获取玩家数据
-- @param player Player 请求数据的玩家
-- @return table 玩家数据
function PlayerService.Client:GetInitData(player)
    return self.Server:GetInitData(player)
end

-- 初始化玩家能力
-- @param player Player 玩家
-- @param ability table 能力数据
function PlayerService:InitPlayerAbility(player, ability)
    if not ability then
        return
    end
    for abilityId, abilityData in pairs(ability) do
        local level = abilityData.Level
        if not level or level <= 0 then
            continue
        end
        local abilityInfo = AbilityConfig:GetByAbilityId(abilityId)
        if abilityInfo then
            local value = 1
            if type(abilityInfo.Value) == "table" then
                value = (1 + abilityInfo.Value[level] / 100)
            else
                value = abilityInfo.Value
            end
            if abilityInfo.Type == 1 then
                local initWalkSpeed = player:GetAttribute("InitWalkSpeed")
                if initWalkSpeed then
                    self:ChangePlayerAttribute(player, "WalkSpeed", initWalkSpeed * value)
                end
            elseif abilityInfo.Type == 2 then
                local initMaxHealth = player:GetAttribute("InitMaxHealth")
                if initMaxHealth then
                    self:ChangePlayerAttribute(player, "MaxHealth", initMaxHealth * value)
                    self:ChangePlayerAttribute(player, "Health", initMaxHealth * value)
                end
            elseif abilityInfo.Type == 3 then
                local initJumpPower = player:GetAttribute("InitJumpPower")
                if initJumpPower then
                    self:ChangePlayerAttribute(player, "JumpPower", initJumpPower * value)
                end
            elseif abilityInfo.Type == GameConfig.AbilityType.Attack then
                local initAttack = player:GetAttribute("InitAttack")
                if initAttack then
                    self:ChangePlayerAttribute(player, "Attack", initAttack * value)
                end
            end
        end
    end
end

function PlayerService:ChangePlayerAttribute(player, attributeName, attributeValue)
    if not player or not player.Character then
        return
    end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    if attributeValue then
        if attributeName == "Health" then
            humanoid.Health = attributeValue
        elseif attributeName == "WalkSpeed" then
            humanoid.WalkSpeed = attributeValue
        elseif attributeName == "MaxHealth" then
            humanoid.MaxHealth = attributeValue
        elseif attributeName == "JumpPower" then
            humanoid.JumpPower = attributeValue
        end
    else
        if attributeName == "Health" then
            humanoid.Health = player:GetAttribute("InitHealth")
        elseif attributeName == "WalkSpeed" then
            humanoid.WalkSpeed = player:GetAttribute("InitWalkSpeed")
        elseif attributeName == "MaxHealth" then
            humanoid.MaxHealth = player:GetAttribute("InitMaxHealth")
        elseif attributeName == "JumpPower" then
            humanoid.JumpPower = player:GetAttribute("InitJumpPower")
        elseif attributeName == "Attack" then
            humanoid:SetAttribute("Attack", player:GetAttribute("InitAttack"))
        end
    end
end

return PlayerService