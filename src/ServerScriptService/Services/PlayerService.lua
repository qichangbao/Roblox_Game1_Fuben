-- PlayerService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local AbilityConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("AbilityConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local PlayerService = Knit.CreateService {
	Name = "PlayerService",
	Client = {
	},

    AbilityData = {},
    AnimationTracks = {},
}
-- 配置参数
local FALL_HEIGHT_THRESHOLD = 17 -- 下落高度阈值（单位：stud）
local WATER_DAMAGE = 10 -- 水中每秒掉血量
local WATER_CHECK_INTERVAL = 1 -- 水中检测间隔（秒）

-- 数据存储
local _playerFallData = {}
local _playerWaterData = {} -- 存储玩家水中状态数据 {userId = lastDamageTime}

function PlayerService:KnitInit()
end

-- 服务启动时的初始化
-- @return void
function PlayerService:KnitStart()
    local function PlayerAdded(player)
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

                self.AnimationTracks[player.UserId] = {}
                local animator = humanoid:FindFirstChildOfClass("Animator")
                if animator then
                    -- 定义动画映射表
                    local animationMap = {
                        swing = {"rbxassetid://107273238071706", "rbxassetid://90203983110020"},
                        dig = {"rbxassetid://96906531402562", "rbxassetid://82370673878002"},
                    }
                    
                    -- 预加载所有动画
                    for animName, animInfo in pairs(animationMap) do
                        local animation = Instance.new("Animation")
                        if humanoid.RigType == Enum.HumanoidRigType.R6 then
                            animation.AnimationId = animInfo[1]
                        else
                            animation.AnimationId = animInfo[2]
                        end
                        
                        local success, track = pcall(function()
                            return animator:LoadAnimation(animation)
                        end)
                        
                        if success and track then
                            track.Priority = Enum.AnimationPriority.Action
                            track.Looped = false
                            self.AnimationTracks[player.UserId][animName] = track
                        end
                    end
                end

                local gameSound = Interface.safeWaitPart(game:GetService("SoundService"), "GAME")
                local music1 = Interface.safeWaitPart(gameSound, "Attack1"):Clone()
                music1.Name = "Attack1"
                music1.Parent = character

                local music2 = Interface.safeWaitPart(gameSound, "Attack2"):Clone()
                music2.Name = "Attack2"
                music2.Parent = character
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

            -- 在 CharacterAdded 事件中添加
            local forceField = Instance.new("ForceField")
            forceField.Parent = character

            -- 3秒后自动移除
            game:GetService("Debris"):AddItem(forceField, 3)
        end)
        
        player:LoadCharacter()
        player:SetAttribute("JoinTime", tick())
        player:SetAttribute("HumanoidType", GameConfig.HumanoidType.Player)

        -- 启动水中检测循环
        self:StartWaterDamageLoop(player)
    end

    local function PlayerRemoved(player)
        self.AnimationTracks[player.UserId] = nil
        self.AbilityData[player.UserId] = nil
        _playerFallData[player.UserId] = nil
        
        -- 停止水中检测循环并清理数据
        self:StopWaterDamageLoop(player)

        Knit.GetService("SettleService"):PlayerRemoved(player)
        Knit.GetService("InventoryService"):PlayerRemoved(player)
        Knit.GetService("DBService"):PlayerRemoved(player)
        Knit.GetService("MonsterService"):PlayerRemoved(player)
        Knit.GetService("LevelService"):PlayerRemoved(player)
        Knit.GetService("TaskService"):PlayerRemoved(player)
        Knit.GetService("ReviveService"):PlayerRemoved(player)
        Knit.GetService("GoldService"):PlayerRemoved(player)
        Knit.GetService("GMService"):PlayerRemoved(player)
    end

    for _, player in pairs(Players:GetPlayers()) do
        PlayerAdded(player)
    end
	
	-- 监听玩家加入事件
	Players.PlayerAdded:Connect(function(player)
        PlayerAdded(player)
	end)

	-- 监听玩家离开事件
	Players.PlayerRemoving:Connect(function(player)
        PlayerRemoved(player)
	end)

    -- 启动全局心跳检测
    self:StartHeartBeat()
end

function PlayerService:GetInitData(player)
    Knit.GetService("DBService"):PlayerAdded(player)
    Knit.GetService("SettleService"):PlayerAdded(player)
    Knit.GetService("MonsterService"):PlayerAdded(player)
    local duanWeiData = Knit.GetService("DBService"):Get(player.UserId, "DuanWeiData")
    Knit.GetService("LevelService"):PlayerAdded(player, duanWeiData)
    Knit.GetService("TaskService"):PlayerAdded(player)
    Knit.GetService("ReviveService"):PlayerAdded(player)
    Knit.GetService("GMService"):PlayerAdded(player)
        
    _playerFallData[player.UserId] = {
		lastYPosition = nil,
		fallStartY = nil,
		maxFallHeight = 0,
		isFalling = false,
		fallStartTime = nil,
		lastCheckTime = 0,
    }

    local islandName = nil
    local inventory = nil
    local tool = nil
    local ability = nil

    local hasEscapeTask = false
    local hasEscapeTime = false
    local difficulty = GameConfig.Difficulty.Easy
    local isFirstLoginFuben = nil
    local gold = nil
    -- 获取传送数据
    local joinData = player:GetJoinData()
    if joinData and joinData.TeleportData then
        local localTeleportData = joinData.TeleportData
        islandName = localTeleportData.IslandName
        if localTeleportData.PlayerData then
            local playerData = localTeleportData.PlayerData[tostring(player.UserId)]
            if playerData and playerData.InventoryData and playerData.ToolData then
                inventory = playerData.InventoryData
                tool = playerData.ToolData
                Knit.GetService("InventoryService"):PlayerAdded(player, inventory, tool)
            end
            ability = playerData.AbilityData
            isFirstLoginFuben = localTeleportData.PlayerData.IsFirstLoginFuben
            gold = localTeleportData.PlayerData.Gold
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

    if not islandName then
        islandName = GameConfig.LandName
    end
    Knit.GetService("IslandService"):SetIslandName(islandName)

    if not inventory and not tool then
        inventory = Knit.GetService("DBService"):Get(player.UserId, "PlayerInventory")
        tool = Knit.GetService("DBService"):Get(player.UserId, "PlayerToolData")
        Knit.GetService("InventoryService"):PlayerAdded(player, inventory, tool)
    end

    if not ability then
        ability = Knit.GetService("DBService"):Get(player.UserId, "AbilityData")
    end
    self.AbilityData[player.UserId] = ability
    self:InitPlayerAbility(player, ability)
    
    if not hasEscapeTask then
        Knit.GetService("TaskService"):InitEscapeTask(GameConfig.DefaultEscapeTask)
    end

    if not hasEscapeTime then
        Knit.GetService("TaskService"):InitEscapeTime(GameConfig.DefaultEscapeTime)
    end

    if not isFirstLoginFuben then
        isFirstLoginFuben = Knit.GetService("DBService"):Get(player.UserId, "IsFirstLoginFuben")
    end

    if not gold then
        gold = Knit.GetService("DBService"):Get(player.UserId, "Gold")
    end
    Knit.GetService("GoldService"):PlayerAdded(player, gold)

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
        IsFirstLoginFuben = isFirstLoginFuben,
        Gold = gold,
        IslandName = islandName,
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

function PlayerService:addHp(player, hp)
    if not player or not player.Character then
        return
    end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid then
        return
    end
    local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return
    end
    local maxHealth = humanoid.MaxHealth
    local health = humanoid.Health
    health = math.min(health + hp, maxHealth)
    humanoid.Health = health
    local EffectFolder = game:GetService("ServerStorage"):FindFirstChild("Effect")
    if not EffectFolder then
        return
    end
    local AddHPEffect = EffectFolder:FindFirstChild("AddHPEffect")
    if not AddHPEffect then
        return
    end
    local effect = AddHPEffect:Clone()
    effect.Parent = player.Character
    effect:PivotTo(CFrame.new(humanoidRootPart.Position.X, humanoidRootPart.Position.Y - humanoid.HipHeight, humanoidRootPart.Position.Z))
    -- 使用Debris服务在3秒后自动销毁特效
    game:GetService("Debris"):AddItem(effect, 3)
end

-- 播放挥舞动画
-- @param player Player 玩家对象
-- @param cd number 冷却时间，用于调整动画播放速度 (cd越小动画越快，cd越大动画越慢)
function PlayerService:PlaySwingAnimation(player, cd)
    if not self.AnimationTracks[player.UserId] or not self.AnimationTracks[player.UserId]["swing"] then
        return
    end
    
    local animationTrack = self.AnimationTracks[player.UserId]["swing"]
    animationTrack:Play()
    
    -- 获取动画的总时长
    local animationLength = animationTrack.Length
    
    -- 根据cd参数和动画时长计算播放速度
    -- 目标：让动画在cd秒内播放完成
    local playbackSpeed = cd / animationLength
    animationTrack:AdjustSpeed(playbackSpeed)
end

-- 播放挖掘动画函数（从下往上）
-- @param player Player 玩家对象
-- @param cd number 冷却时间，用于调整动画播放速度 (cd越小动画越快，cd越大动画越慢)
function PlayerService:PlayDigAnimation(player, cd)
    if not self.AnimationTracks[player.UserId] or not self.AnimationTracks[player.UserId]["dig"] then
        return
    end
    
    local animationTrack = self.AnimationTracks[player.UserId]["dig"]
    animationTrack:Play()
    
    -- 获取动画的总时长
    local animationLength = animationTrack.Length
    
    -- 根据cd参数和动画时长计算播放速度
    -- 目标：让动画在cd秒内播放完成
    local playbackSpeed = cd / animationLength
    animationTrack:AdjustSpeed(playbackSpeed)
end

function PlayerService:playAnimation(player, animationName, soundName, cd)
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if animationName == "dig" then
        self:PlayDigAnimation(player, cd)
    else
        self:PlaySwingAnimation(player, cd)
    end

    local music = character:FindFirstChild(soundName)
    if music then
        music:Play()
    end
end

-- 启动全局检测循环（水中伤害 + 下落检测）
function PlayerService:StartHeartBeat()
    RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        -- 遍历所有需要检测的玩家（水中伤害）
        for userId, lastDamageTime in pairs(_playerWaterData) do
            local player = Players:GetPlayerByUserId(userId)
            
            -- 检查玩家是否还在游戏中
            if not player or not player.Parent or not player.Character then
                _playerWaterData[userId] = nil
                continue
            end
            
            -- 检查是否需要进行伤害检测（每秒一次）
            if currentTime - lastDamageTime >= WATER_CHECK_INTERVAL then
                if Interface.IsPlayerInWater(player.Character) then
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        --humanoid:TakeDamage(WATER_DAMAGE)
                        print(player.Name .. " 在水中受到 " .. WATER_DAMAGE .. " 点伤害")
                    end
                end
                _playerWaterData[userId] = currentTime
            end
        end
        
        -- 遍历所有需要检测的玩家（下落检测）
        for userId, fallData in pairs(_playerFallData) do
            local player = Players:GetPlayerByUserId(userId)
            
            -- 检查玩家是否还在游戏中
            if not player or not player.Parent or not player.Character then
                _playerFallData[userId] = nil
                continue
            end
            
            local character = player.Character
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            
            if not humanoid or not humanoidRootPart then
                continue
            end
            
            local currentY = humanoidRootPart.Position.Y
            local humanoidState = humanoid:GetState()
            
            -- 检查是否开始下落
            if humanoidState == Enum.HumanoidStateType.Freefall then
                if not fallData.isFalling then
                    -- 开始下落
                    fallData.isFalling = true
                    fallData.fallStartY = currentY
                    fallData.fallStartTime = currentTime
                    fallData.maxFallHeight = currentY
                end
                -- 更新最大下落高度
                if currentY < fallData.maxFallHeight then
                    fallData.maxFallHeight = currentY
                end
            elseif fallData.isFalling and (humanoidState == Enum.HumanoidStateType.Landed or humanoidState == Enum.HumanoidStateType.Running) then
                -- 检查是否有无敌保护（ForceField）
                if not character:FindFirstChild("ForceField") then
                    local fallHeight = fallData.fallStartY - currentY
                    if fallHeight > FALL_HEIGHT_THRESHOLD then
                        local damage = 0
                        if fallHeight > FALL_HEIGHT_THRESHOLD + 15 then
                            damage = humanoid.MaxHealth
                        elseif fallHeight > FALL_HEIGHT_THRESHOLD + 10 then
                            damage = 60
                        elseif fallHeight > FALL_HEIGHT_THRESHOLD + 5 then
                            damage = 30
                        else
                            damage = 10
                        end
                        
                        humanoid:TakeDamage(damage)
                    end
                    print(player.Name .. " 下落 " .. math.floor(fallHeight))
                end
                
                -- 重置下落状态
                fallData.isFalling = false
                fallData.fallStartY = nil
                fallData.fallStartTime = nil
                fallData.maxFallHeight = 0
            end
            
            -- 更新最后位置
            fallData.lastYPosition = currentY
            fallData.lastCheckTime = currentTime
        end
    end)
end

-- 为玩家启动水中检测
function PlayerService:StartWaterDamageLoop(player)
    if not player then return end
    
    local userId = player.UserId
    _playerWaterData[userId] = 0 -- 初始化最后伤害时间
end

-- 为玩家停止水中检测
function PlayerService:StopWaterDamageLoop(player)
    if not player then return end
    
    local userId = player.UserId
    _playerWaterData[userId] = nil
end

return PlayerService