-- PlayerService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
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
    CurrentTweens = {},
    IsAnimating = {},
}

function PlayerService:KnitInit()
end

-- 服务启动时的初始化
-- @return void
function PlayerService:KnitStart()
    local function playerAdd(player)
        print("PlayerAdded    ", player.Name)

        if game:GetService("RunService"):IsStudio() then
            player.Chatted:Connect(function(message)
                local lowerMessage = string.lower(message)
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                
                -- 解析 "heal [amount]" 命令 - 加血
                local healMatch = string.match(lowerMessage, "^health (%d+)$")
                if healMatch then
                    local amount = tonumber(healMatch)
                    if amount and humanoid then
                        self:addHp(player, amount)
                        print(string.format("玩家 %s 恢复了 %d 点生命值，当前生命值: %d/%d", 
                            player.Name, amount, humanoid.Health, humanoid.MaxHealth))
                        return true
                    end
                end
                
                -- 解析 "heal" 命令 - 满血
                if lowerMessage == "health" then
                    if humanoid then
                        humanoid.Health = humanoid.MaxHealth
                        print(string.format("玩家 %s 生命值已恢复满血: %d/%d", 
                            player.Name, humanoid.Health, humanoid.MaxHealth))
                        return true
                    end
                end
                
                -- 解析 "damage [amount]" 命令 - 减血
                local damageMatch = string.match(lowerMessage, "^damage (%d+)$")
                if damageMatch then
                    local amount = tonumber(damageMatch)
                    if amount and humanoid then
                        humanoid:TakeDamage(amount)
                        print(string.format("玩家 %s 受到了 %d 点伤害，当前生命值: %d/%d", 
                            player.Name, amount, humanoid.Health, humanoid.MaxHealth))
                        return true
                    end
                end
                
                -- 解析 "speed [value]" 命令 - 设置移动速度
                local speedMatch = string.match(lowerMessage, "^speed (%d+)$")
                if speedMatch then
                    local speed = tonumber(speedMatch)
                    if speed and humanoid then
                        humanoid.WalkSpeed = speed
                        print(string.format("玩家 %s 移动速度设置为: %d", player.Name, speed))
                        return true
                    end
                end
                
                -- 解析 "speed reset" 命令 - 重置移动速度
                if lowerMessage == "speed reset" then
                    if humanoid then
                        local initSpeed = player:GetAttribute("InitWalkSpeed") or 16
                        humanoid.WalkSpeed = initSpeed
                        print(string.format("玩家 %s 移动速度已重置为: %d", player.Name, initSpeed))
                        return true
                    end
                end
                
                -- 解析 "jump [value]" 命令 - 设置跳跃力
                local jumpMatch = string.match(lowerMessage, "^jump (%d+)$")
                if jumpMatch then
                    local jumpPower = tonumber(jumpMatch)
                    if jumpPower and humanoid then
                        humanoid.JumpPower = jumpPower
                        print(string.format("玩家 %s 跳跃力设置为: %d", player.Name, jumpPower))
                        return true
                    end
                end
                
                -- 解析 "jump reset" 命令 - 重置跳跃力
                if lowerMessage == "jump reset" then
                    if humanoid then
                        local initJump = player:GetAttribute("InitJumpPower") or 50
                        humanoid.JumpPower = initJump
                        print(string.format("玩家 %s 跳跃力已重置为: %d", player.Name, initJump))
                        return true
                    end
                end
                
                -- 解析 "help" 命令 - 显示帮助信息
                if lowerMessage == "help" or lowerMessage == "debug help" then
                    print("=== 调试命令帮助 ===")
                    print("health [amount] - 恢复指定生命值")
                    print("health - 恢复满血")
                    print("damage [amount] - 造成指定伤害")
                    print("speed [value] - 设置移动速度")
                    print("speed reset - 重置移动速度")
                    print("jump [value] - 设置跳跃力")
                    print("jump reset - 重置跳跃力")
                    print("help - 显示此帮助信息")
                    return true
                end
            
                return false
            end)
        end
        
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
                self.CurrentTweens[player.UserId] = {}
                self.IsAnimating[player.UserId] = false
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
                local music1 = Interface.safeWaitPart(gameSound, "Attack1")
                music1.Name = "Attack1"
                if not music1.IsLoaded then
                    music1.Loaded:Wait()
                end
                music1.Parent = character

                local music2 = Interface.safeWaitPart(gameSound, "Attack2")
                music2.Name = "Attack2"
                if not music2.IsLoaded then
                    music2.Loaded:Wait()
                end
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
        end)
        
        player:LoadCharacter()
        player:SetAttribute("JoinTime", tick())
        player:SetAttribute("HumanoidType", GameConfig.HumanoidType.Player)
    end

    local function playerRemoved(player)
        self.AnimationTracks[player.UserId] = nil
        self.AbilityData[player.UserId] = nil
        self.CurrentTweens[player.UserId] = nil
        self.IsAnimating[player.UserId] = nil

        Knit.GetService("SettleService"):playerRemoved(player)
        Knit.GetService("InventoryService"):playerRemoved(player)
        Knit.GetService("DBService"):playerRemoved(player)
        Knit.GetService("MonsterService"):playerRemoved(player)
        Knit.GetService("LevelService"):playerRemoved(player)
        Knit.GetService("TaskService"):playerRemoved(player)
        Knit.GetService("ReviveService"):playerRemoved(player)
        Knit.GetService("GoldService"):playerRemoved(player)
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
    Knit.GetService("LevelService"):PlayerAdded(player, duanWeiData)
    Knit.GetService("TaskService"):PlayerAdded(player)
    Knit.GetService("ReviveService"):playerAdd(player)
        
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
        if localTeleportData.PlayerData then
            local playerData = localTeleportData.PlayerData[tostring(player.UserId)]
            if playerData and playerData.InventoryData and playerData.ToolData then
                inventory = playerData.InventoryData
                tool = playerData.ToolData
                Knit.GetService("InventoryService"):playerAdd(player, inventory, tool)
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

    if not inventory and not tool then
        inventory = Knit.GetService("DBService"):Get(player.UserId, "PlayerInventory")
        tool = Knit.GetService("DBService"):Get(player.UserId, "PlayerToolData")
        Knit.GetService("InventoryService"):playerAdd(player, inventory, tool)
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
    Knit.GetService("GoldService"):playerAdd(player, gold)

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
    effect:PivotTo(CFrame.new(humanoidRootPart.Position))
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
    
    -- 获取动画的总时长
    local animationLength = animationTrack.Length
    
    -- 根据cd参数和动画时长计算播放速度
    -- 目标：让动画在cd秒内播放完成
    local playbackSpeed = cd / animationLength
    animationTrack:AdjustSpeed(playbackSpeed)
    animationTrack:Play()
end

-- 播放挖掘动画函数（从下往上）
-- @param player Player 玩家对象
-- @param cd number 冷却时间，用于调整动画播放速度 (cd越小动画越快，cd越大动画越慢)
function PlayerService:PlayDigAnimation(player, cd)
    if not self.AnimationTracks[player.UserId] or not self.AnimationTracks[player.UserId]["dig"] then
        return
    end
    
    local animationTrack = self.AnimationTracks[player.UserId]["dig"]
    
    -- 获取动画的总时长
    local animationLength = animationTrack.Length
    
    -- 根据cd参数和动画时长计算播放速度
    -- 目标：让动画在cd秒内播放完成
    local playbackSpeed = cd / animationLength
    animationTrack:AdjustSpeed(playbackSpeed)
    animationTrack:Play()
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

return PlayerService