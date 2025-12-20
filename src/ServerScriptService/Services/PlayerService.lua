-- PlayerService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local TalentTreeConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("TalentTreeConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local ConstantConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ConstantConfig"))
local DesignConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("DesignConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local ItemInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("ItemInterface"))

local _initHealth = ConstantConfig:GetByIndex(5).Effect1
local _initWalkSpeed = ConstantConfig:GetByIndex(6).Effect1
local _initRunSpeed = ConstantConfig:GetByIndex(7).Effect1

local PlayerService = Knit.CreateService {
	Name = "PlayerService",
	Client = {
        UpdateOverwhelmed = Knit.CreateSignal(),-- 更新负重信号
	},

    PlayerCount = 0,   -- 玩家人数
    TalentData = {},   -- 玩家能力数据
    AnimationTracks = {},-- 玩家动画轨道
    FallData = {},      -- 存储玩家下落数据
    WaterData = {},     -- 存储玩家水中状态数据
    AttributeData = {}, -- 存储玩家属性数据
    AnimationMarkerConns = {},  -- 动画标记事件连接
}
-- 配置参数
local FALL_HEIGHT_THRESHOLD = 17 -- 下落高度阈值（单位：stud）
local WATER_DAMAGE = 10 -- 水中每秒掉血量
local WATER_CHECK_INTERVAL = 2 -- 水中检测间隔（秒）

function PlayerService:KnitInit()
end

-- 服务启动时的初始化
-- @return void
function PlayerService:KnitStart()
    local function PlayerAdded(player)
        print("PlayerAdded    ", player.Name)
        player.CharacterAdded:Connect(function(character)
            local humanoid = character:WaitForChild("Humanoid")
            humanoid.AutoJumpEnabled = false
            humanoid.UseJumpPower = true
            humanoid.Health = _initHealth
            humanoid.MaxHealth = _initHealth
            humanoid.WalkSpeed = _initWalkSpeed
            humanoid:SetAttribute("InitHealth", humanoid.Health)
            humanoid:SetAttribute("InitWalkSpeed", humanoid.WalkSpeed)
            humanoid:SetAttribute("InitJumpPower", humanoid.JumpPower)
            humanoid:SetAttribute("InitMaxHealth", humanoid.MaxHealth)
            
            self:InitPlayerTalent(player, self.TalentData[player.UserId])
            self:InitAnimEffect(player)

            -- 如果之前已有标记连接，先清理（例如角色重生）
            self:RemoveAnimationMarker(player)
            self.AnimationTracks[player.UserId] = {}
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if animator then
                -- 预加载所有动画
                for animName, animIds in pairs(GameConfig.AnimationMap) do
                    self.AnimationTracks[player.UserId][animName] = {}
                    for _, animId in ipairs(animIds) do
                        local animation = Instance.new("Animation")
                        animation.AnimationId = animId
                        
                        local success, track = pcall(function()
                            return animator:LoadAnimation(animation)
                        end)
                        
                        if success and track then
                            track.Priority = Enum.AnimationPriority.Action3
                            track.Looped = false
                            table.insert(self.AnimationTracks[player.UserId][animName], track)

                            -- 为动画标记添加监听（支持 "Hit" 或 "hit" 名称）
                            -- 结构：AnimationMarkerConns[userId][animName][markerName] = { RBXScriptConnection, ... }
                            self.AnimationMarkerConns[player.UserId] = self.AnimationMarkerConns[player.UserId] or {}
                            self.AnimationMarkerConns[player.UserId][animName] = self.AnimationMarkerConns[player.UserId][animName] or {}

                            local function bindMarker(markerName)
                                local ok, signal = pcall(function()
                                    return track:GetMarkerReachedSignal(markerName)
                                end)
                                if ok and signal then
                                    local conn = signal:Connect(function(param)
                                        self:OnAnimationMarker(player, animName, markerName, param, track)
                                    end)
                                    -- 为每条轨道分别保存连接，避免被覆盖
                                    local container = self.AnimationMarkerConns[player.UserId][animName]
                                    container[markerName] = container[markerName] or {}
                                    table.insert(container[markerName], conn)
                                end
                            end

                            bindMarker("Hit")
                        end
                    end
                end

                local gameSound = Interface.safeWaitPart(game:GetService("SoundService"), "GAME")
                local music1 = Interface.safeWaitPart(gameSound, "Attack1"):Clone()
                music1.Name = "Attack1"
                music1.Parent = character:FindFirstChild("HumanoidRootPart") or character

                local music2 = Interface.safeWaitPart(gameSound, "Attack2"):Clone()
                music2.Name = "Attack2"
                music2.Parent = character:FindFirstChild("HumanoidRootPart") or character
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
        -- 断开动画标记事件连接，避免内存泄漏
        self:RemoveAnimationMarker(player)

        self.AnimationTracks[player.UserId] = nil
        self.TalentData[player.UserId] = nil
        self.FallData[player.UserId] = nil
        self.WaterData[player.UserId] = nil
        self.AttributeData[player.UserId] = nil
        
        -- 停止水中检测循环并清理数据
        self:StopWaterDamageLoop(player)

        Knit.GetService("GoldService"):PlayerRemoved(player)
        Knit.GetService("InventoryService"):PlayerRemoved(player)
        Knit.GetService("LevelService"):PlayerRemoved(player)
        Knit.GetService("TalentService"):PlayerRemoved(player)
        Knit.GetService("GMService"):PlayerRemoved(player)
        Knit.GetService("QuestService"):PlayerRemoved(player)
        Knit.GetService("SettleService"):PlayerRemoved(player)
        Knit.GetService("MonsterService"):PlayerRemoved(player)
        Knit.GetService("ReviveService"):PlayerRemoved(player)
        Knit.GetService("TaskService"):PlayerRemoved(player)
        Knit.GetService("EquipmentService"):PlayerRemoved(player)

        Knit.GetService("DBService"):PlayerRemoved(player)
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

    Knit.GetService("EquipmentService"):PlayerAdded(player)
    Knit.GetService("GoldService"):PlayerAdded(player)
    Knit.GetService("InventoryService"):PlayerAdded(player)
    Knit.GetService("LevelService"):PlayerAdded(player)
    Knit.GetService("TalentService"):PlayerAdded(player)
    Knit.GetService("GMService"):PlayerAdded(player)
    Knit.GetService("QuestService"):PlayerAdded(player)
    Knit.GetService("SettleService"):PlayerAdded(player)
    Knit.GetService("MonsterService"):PlayerAdded(player)
    Knit.GetService("ReviveService"):PlayerAdded(player)
    Knit.GetService("TaskService"):PlayerAdded(player)
        
    self.FallData[player.UserId] = {
		lastYPosition = nil,
		fallStartY = nil,
		maxFallHeight = 0,
		isFalling = false,
		fallStartTime = nil,
		lastCheckTime = 0,
    }

    self.AttributeData[player.UserId] = {
        Overwhelmed = 0,                                            -- 负重
        InitMaxOverwhelmed = GameConfig.Overwhelmed,                -- 初始负重
        Luck = GameConfig.Luck,                                    -- 幸运值
        InitLuck = GameConfig.Luck,                                 -- 初始幸运值
        Attack = GameConfig.Attack,                                 -- 攻击力
        InitAttack = GameConfig.Attack,                             -- 初始攻击力
        CriticalProbability = GameConfig.CriticalProbability,       -- 暴击几率
        InitCriticalProbability = GameConfig.CriticalProbability,   -- 初始暴击几率
    }

    local islandId = GameConfig.IsLandId
    self.PlayerCount = #Players:GetPlayers()
    -- 获取传送数据
    local joinData = player:GetJoinData()
    if joinData and joinData.TeleportData then
        local localTeleportData = joinData.TeleportData
        islandId = localTeleportData.IslandId or islandId
        self.PlayerCount = localTeleportData.PlayerCount or self.PlayerCount
    else
        print(string.format("玩家 %s 没有传送数据", player.Name))
    end

    Knit.GetService("IslandService"):SetIslandId(islandId)
    
    local mapConfig = DesignConfig:GetByMapId(islandId)
    local effect1 = ConstantConfig:GetByID(1).Effect1
    local escapeTask = mapConfig.DesignTarget * effect1[self.PlayerCount][2] / 10000
    Knit.GetService("TaskService"):InitEscapeTask(escapeTask)
    Knit.GetService("TaskService"):SetEscapeTime(mapConfig.EvacuateTime)

    local gold = Knit.GetService("GoldService"):GetGoldData(player)
    local inventoryData = Knit.GetService("InventoryService"):GetInventoryData(player)
    local tool = Knit.GetService("InventoryService"):GetToolData(player)
    self.AttributeData[player.UserId].Overwhelmed = 0
    for _, toolData in ipairs(tool) do
        local itemId = toolData.ItemId
        local itemInfo = ItemConfig:GetByItemId(itemId)
        if itemInfo then
            self.AttributeData[player.UserId].Overwhelmed += itemInfo.Weight
        end
    end
    local talentData = Knit.GetService("TalentService"):GetTalentData(player)
    self.TalentData[player.UserId] = talentData
    self:InitPlayerTalent(player, talentData)
    self.AttributeData[player.UserId].InitMaxOverwhelmed = GameConfig.Overwhelmed
    self:UpdateOverwhelmed(player)

    Knit.GetService("MonsterService"):InitMonsters(player)
    Knit.GetService("ItemService"):InitItems(player)

    return {
        IslandId = islandId,
        PlayerCount = self.PlayerCount,
        Gold = gold,
        Inventory = inventoryData,
        ToolData = tool,
        EquipmentData = Knit.GetService("EquipmentService"):GetEquipmentData(player),
        IsFirstLoginFuben = Knit.GetService("DBService"):Get(player.UserId, "IsFirstLoginFuben"),
        QuestData = Knit.GetService("QuestService"):GetPlayerQuests(player),
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
-- @param talent table 能力数据
function PlayerService:InitPlayerTalent(player, talent)
    if not talent then return end
    local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    if not humanoid then return end

    for talentId, talentData in pairs(talent) do
        local talentInfo = TalentTreeConfig:GetByTalentTreeId(tonumber(talentId))
        if talentInfo then
            if talentInfo.Type == GameConfig.TalentType.WalkSpeed then
                local initWalkSpeed = player:GetAttribute("InitWalkSpeed")
                if initWalkSpeed then
                    local value = 0
                    if talentInfo.ChildType == 1 then
                        value = humanoid:GetAttribute("InitWalkSpeed") *  (1 + talentInfo.Value / 100)
                    else
                        value = humanoid:GetAttribute("InitWalkSpeed") +  talentInfo.Value
                    end
                    humanoid:SetAttribute("InitWalkSpeed", value)
                end
            elseif talentInfo.Type == GameConfig.TalentType.MaxHealth then
                local initMaxHealth = humanoid:GetAttribute("InitMaxHealth")
                if initMaxHealth then
                    local value = 0
                    if talentInfo.ChildType == 1 then
                        value = humanoid:GetAttribute("InitMaxHealth") *  (1 + talentInfo.Value / 100)
                    else
                        value = humanoid:GetAttribute("InitMaxHealth") +  talentInfo.Value
                    end
                    humanoid:SetAttribute("InitMaxHealth", value)
                end
            elseif talentInfo.Type == GameConfig.TalentType.Jump then
                local initJumpPower = player:GetAttribute("InitJumpPower")
                if initJumpPower then
                    local value = 0
                    if talentInfo.ChildType == 1 then
                        value = humanoid:GetAttribute("InitJumpPower") *  (1 + talentInfo.Value / 100)
                    else
                        value = humanoid:GetAttribute("InitJumpPower") +  talentInfo.Value
                    end
                    humanoid:SetAttribute("InitJumpPower", value)
                end
            elseif talentInfo.Type == GameConfig.TalentType.Overwhelmed then
                local value = self.AttributeData[player.UserId].InitMaxOverwhelmed
                if talentInfo.ChildType == 1 then
                    value = value *  (1 + talentInfo.Value / 100)
                else
                    value = value +  talentInfo.Value
                end
                self.AttributeData[player.UserId].InitMaxOverwhelmed = value
            elseif talentInfo.Type == GameConfig.TalentType.CriticalProbability then
                local value = self.AttributeData[player.UserId].InitCriticalProbability
                if talentInfo.ChildType == 1 then
                    value = value *  (1 + talentInfo.Value / 100)
                else
                    value = value +  talentInfo.Value
                end
                self.AttributeData[player.UserId].InitCriticalProbability = value
            elseif talentInfo.Type == GameConfig.TalentType.Luck then
                local value = self.AttributeData[player.UserId].InitLuck
                if talentInfo.ChildType == 1 then
                    value = value *  (1 + talentInfo.Value / 100)
                else
                    value = value +  talentInfo.Value
                end
                self.AttributeData[player.UserId].InitLuck = value
            end
        end
    end
    self:ChangePlayerAttribute("WalkSpeed")
    self:ChangePlayerAttribute("MaxHealth")
    self:ChangePlayerAttribute("Health")
    self:ChangePlayerAttribute("JumpPower")
    self:ChangePlayerAttribute("Overwhelmed")
    self:ChangePlayerAttribute("Luck")
    self:ChangePlayerAttribute("CriticalProbability")
end

-- 计算玩家步行速度
-- @param player Player 玩家对象
-- @param value number 乘法因子，用于计算新的步行速度
-- @return number 新的步行速度
function PlayerService:CalculateWalkSpeed(player, value)
    local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    if not humanoid then return 0 end
    value = value or 1
    local initWalkSpeed = humanoid:GetAttribute("InitWalkSpeed")
    local overwhelmed = self.AttributeData[player.UserId].Overwhelmed
    local scale = 1
    if overwhelmed <= GameConfig.OverwhelmedWeight.Normal then
        scale = 1
    elseif overwhelmed <= GameConfig.OverwhelmedWeight.Overweight then
        scale = 0.7
    else
        scale = 0.3
    end
    local newWalkSpeed = initWalkSpeed * scale * value
    return newWalkSpeed
end

-- 计算玩家跳跃力
-- @param player Player 玩家对象
-- @param value number 乘法因子，用于计算新的步行速度
-- @return number 新的跳跃力
function PlayerService:CalculateJumpPower(player, value)
    local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    if not humanoid then return 0 end
    value = value or 1
    local initJumpPower = humanoid:GetAttribute("InitJumpPower")
    local overwhelmed = self.AttributeData[player.UserId].Overwhelmed
    local scale = 1
    if overwhelmed <= GameConfig.OverwhelmedWeight.Normal then
        scale = 1
    elseif overwhelmed <= GameConfig.OverwhelmedWeight.Overweight then
        scale = 0.7
    else
        scale = 0.3
    end
    local newJumpPower = initJumpPower * scale * value
    return newJumpPower
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
            humanoid.WalkSpeed = self:CalculateWalkSpeed(player, attributeValue)
        elseif attributeName == "MaxHealth" then
            humanoid.MaxHealth = attributeValue
        elseif attributeName == "JumpPower" then
            humanoid.JumpPower = self:CalculateJumpPower(player, attributeValue)
        elseif attributeName == "Overwhelmed" then
            self.AttributeData[player.UserId].Overwhelmed = attributeValue
        elseif attributeName == "Luck" then
            self.AttributeData[player.UserId].Luck = attributeValue
        elseif attributeName == "Attack" then
            self.AttributeData[player.UserId].Attack = attributeValue
        elseif attributeName == "CriticalProbability" then
            self.AttributeData[player.UserId].CriticalProbability = attributeValue
        end
    else
        if attributeName == "Health" then
            humanoid.Health = humanoid:GetAttribute("InitHealth")
        elseif attributeName == "WalkSpeed" then
            humanoid.WalkSpeed = self:CalculateWalkSpeed(player)
        elseif attributeName == "MaxHealth" then
            humanoid.MaxHealth = humanoid:GetAttribute("InitMaxHealth")
        elseif attributeName == "JumpPower" then
            humanoid.JumpPower = self:CalculateJumpPower(player)
        elseif attributeName == "Overwhelmed" then
            self.AttributeData[player.UserId].Overwhelmed = self.AttributeData[player.UserId].InitMaxOverwhelmed
        elseif attributeName == "Luck" then
            self.AttributeData[player.UserId].Luck = self.AttributeData[player.UserId].InitLuck
        elseif attributeName == "Attack" then
            self.AttributeData[player.UserId].Attack = self.AttributeData[player.UserId].InitAttack
        elseif attributeName == "CriticalProbability" then
            self.AttributeData[player.UserId].CriticalProbability = self.AttributeData[player.UserId].InitCriticalProbability
        end
    end
end

function PlayerService:InitAnimEffect(player)
    -- 生成并摆放命中特效到边缘中心
    local effectTemplateFolder = ReplicatedStorage:FindFirstChild("Effect")
    if not effectTemplateFolder then return end
    local template1 = effectTemplateFolder:FindFirstChild("AttackEffect")
    if not template1 then return end

    local effect1 = template1:Clone()
    effect1.Parent = player.Character
    effect1.Name = "AttackEffect"
    effect1.CanCollide = false
    effect1.Anchored = true
    for _, particleEmitter in pairs(effect1:GetDescendants()) do
        if particleEmitter:IsA("ParticleEmitter") then
            particleEmitter.Enabled = false
        end
    end

    local template2 = effectTemplateFolder:FindFirstChild("HitEffect")
    if not template2 then return end

    local effect2 = template2:Clone()
    effect2.Parent = player.Character
    effect2.Name = "HitEffect"
    effect2.CanCollide = false
    effect2.Anchored = true
    for _, particleEmitter in pairs(effect2:GetDescendants()) do
        if particleEmitter:IsA("ParticleEmitter") then
            particleEmitter.Enabled = false
        end
    end
end

-- 播放挥舞动画（函数级注释）：
-- 行为：从同名动画列表中随机选一条进行播放；
--       根据期望冷却时间 cd 调整播放速度，使动画在 cd 秒内完成。
-- 公式：播放速度 = 动画时长 / cd（cd越小越快，越大越慢）；
-- 注意：需要预加载 GameConfig.AnimationMap["swing"] 为多个 AnimationTrack。
function PlayerService:PlaySwingAnimation(player, cd)
    if not self.AnimationTracks[player.UserId] or not self.AnimationTracks[player.UserId]["swing"] then
        return
    end

    local tracks = self.AnimationTracks[player.UserId]["swing"]
    if typeof(tracks) ~= "table" or #tracks == 0 then
        return
    end

    local animationTrack = tracks[math.random(1, #tracks)]
    animationTrack:Play()

    -- 获取动画的总时长
    local animationLength = animationTrack.Length

    -- 根据cd参数和动画时长计算播放速度
    -- 目标：让动画在cd秒内播放完成
    local playbackSpeed
    if typeof(cd) == "number" and cd > 0 then
        playbackSpeed = animationLength / cd
    else
        playbackSpeed = 1
    end
    animationTrack:AdjustSpeed(playbackSpeed)

    ItemInterface.showAttackEffect(player)
end

-- 播放挖掘动画函数（从下往上）
-- @param player Player 玩家对象
-- @param cd number 冷却时间，用于调整动画播放速度 (cd越小动画越快，cd越大动画越慢)
-- 播放挖掘动画（函数级注释）：
-- 行为：从同名动画列表中随机选一条进行播放；
--       根据期望冷却时间 cd 调整播放速度，使动画在 cd 秒内完成。
-- 公式：播放速度 = 动画时长 / cd（cd越小越快，越大越慢）。
function PlayerService:PlayDigAnimation(player, cd)
    if not self.AnimationTracks[player.UserId] or not self.AnimationTracks[player.UserId]["dig"] then
        return
    end

    local tracks = self.AnimationTracks[player.UserId]["dig"]
    if typeof(tracks) ~= "table" or #tracks == 0 then
        return
    end

    local animationTrack = tracks[math.random(1, #tracks)]
    animationTrack:Play()

    -- 获取动画的总时长
    local animationLength = animationTrack.Length

    -- 根据cd参数和动画时长计算播放速度
    -- 目标：让动画在cd秒内播放完成
    local playbackSpeed
    if typeof(cd) == "number" and cd > 0 then
        playbackSpeed = animationLength / cd
    else
        playbackSpeed = 1
    end
    animationTrack:AdjustSpeed(playbackSpeed)
end

-- 按动画名随机播放（函数级注释）：
-- @param player Player 玩家对象
-- @param animationName string 动画名（需在 GameConfig.AnimationMap 中存在）
-- @param cd number 期望动画完成时长（秒），用于计算播放速度；
-- 行为：从该动画名下预加载的多个 AnimationTrack 中随机选择一条播放，
--       并按公式 speed = Length / cd 调整播放速度使其在 cd 秒内完成。
function PlayerService:PlayAnimationByNameRandom(player, animationName, cd)
    local userId = player and player.UserId
    if not userId or not self.AnimationTracks[userId] then return end
    local tracks = self.AnimationTracks[userId][animationName]
    if typeof(tracks) ~= "table" or #tracks == 0 then return end

    local track = tracks[math.random(1, #tracks)]
    track:Play()

    local length = track.Length
    local speed
    if typeof(cd) == "number" and cd > 0 then
        speed = length / cd
    else
        speed = 1
    end
    track:AdjustSpeed(speed)
end

-- 播放动画统一入口（函数级注释）：
-- @param player Player 玩家
-- @param animationName string 动画名（支持同名下多动画随机播放）
-- @param soundName string 声音资源名（角色下预置的音效）
-- @param cd number 冷却时长，控制动画播放速度（动画在 cd 秒内完成）
-- 行为：调用 PlayAnimationByNameRandom 实现按名随机播放；
--       非 "dig" 动画保持原有调用 ItemInterface.showAttackEffect(player)。
function PlayerService:playAnimation(player, animationName, soundName, cd)
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- 按名随机播放（支持同名多轨）
    self:PlayAnimationByNameRandom(player, animationName, cd)

    -- 非挖掘动作保留命中特效触发
    if animationName ~= "dig" then
        ItemInterface.showAttackEffect(player)
    end

    local music = character:FindFirstChild(soundName)
    if music then
        music:Play()
    end
end

-- 断开并清理动画标记事件连接（函数级注释）：
-- @param player Player 玩家
-- 行为：遍历 AnimationMarkerConns[userId][animName][markerName] 的连接数组，逐个断开；
-- 结构兼容：既兼容旧版单连接字典，也支持新版每轨道多连接列表。
function  PlayerService:RemoveAnimationMarker(player)
    local userConns = self.AnimationMarkerConns[player.UserId]
    if userConns then
        for _, markers in pairs(userConns) do
            for _, connOrList in pairs(markers) do
                if typeof(connOrList) == "RBXScriptConnection" then
                    connOrList:Disconnect()
                elseif typeof(connOrList) == "table" then
                    for _, conn in ipairs(connOrList) do
                        if typeof(conn) == "RBXScriptConnection" then
                            conn:Disconnect()
                        end
                    end
                end
            end
        end
        self.AnimationMarkerConns[player.UserId] = nil
    end
end

-- 动画标记统一回调（服务端）
-- @function OnAnimationMarker
-- @param player Player 触发标记的玩家
-- @param animationName string 动画名称（如 "swing"、"dig"）
-- @param markerName string 标记名称（如 "Hit"）
-- @param param any 标记参数（来自动画编辑器中该标记的参数）
-- @param track AnimationTrack 触发的动画轨道
-- @return void
function PlayerService:OnAnimationMarker(player, animationName, markerName, param, track)
    -- 在这里编写你的命中逻辑。例如：处理武器命中、采集判定等。
    
    -- 获取玩家当前装备的工具（函数级注释）：
    -- 行为：从玩家角色下查找处于装备状态的 Tool（Tool 被装备时 Parent 会在 Character 下）
    -- 返回：local equippedTool Tool|nil
    local equippedTool = self:GetEquippedTool(player)
    if not equippedTool then return end
    local itemId = equippedTool:GetAttribute("ItemId")
    local itemInfo = ItemConfig:GetByItemId(itemId)
    if not itemInfo then return end

    ItemInterface.performAreaDetection(player, itemInfo, function(hit, weaponInfo)
        local script = equippedTool:FindFirstChild("ModuleScript")
        if script then
            local module = require(script)
            if module and module.HandleToolCollision then
                module:HandleToolCollision(player, hit, weaponInfo)
            end
        end
    end)
end

-- 获取玩家当前装备的工具（函数级注释）：
-- @param player Player 玩家
-- @return Tool|nil 返回玩家当前装备的 Tool；若未装备则返回 nil
function PlayerService:GetEquippedTool(player)
    if not player or not player.Character then
        return nil
    end
    for _, child in ipairs(player.Character:GetChildren()) do
        if child:IsA("Tool") then
            return child
        end
    end
    return nil
end

-- 启动全局检测循环（水中伤害 + 下落检测）
function PlayerService:StartHeartBeat()
    RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        -- 遍历所有需要检测的玩家（水中伤害）
        for userId, lastDamageTime in pairs(self.WaterData) do
            local player = Players:GetPlayerByUserId(userId)
            
            -- 检查玩家是否还在游戏中
            if not player or not player.Parent or not player.Character then
                self.WaterData[userId] = nil
                continue
            end
            
            -- 检查是否需要进行伤害检测（每秒一次）
            if currentTime - lastDamageTime >= WATER_CHECK_INTERVAL then
                if Interface.IsPlayerInWater(player.Character) then
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        Interface.decHp(player.Character, WATER_DAMAGE)
                        print(player.Name .. " 在水中受到 " .. WATER_DAMAGE .. " 点伤害")
                    end
                end
                self.WaterData[userId] = currentTime
            end
        end
        
        -- 遍历所有需要检测的玩家（下落检测）
        for userId, fallData in pairs(self.FallData) do
            local player = Players:GetPlayerByUserId(userId)
            
            -- 检查玩家是否还在游戏中
            if not player or not player.Parent or not player.Character then
                self.FallData[userId] = nil
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
                        
                        Interface.decHp(player.Character, damage)
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
    self.WaterData[userId] = 0 -- 初始化最后伤害时间
end

-- 为玩家停止水中检测
function PlayerService:StopWaterDamageLoop(player)
    if not player then return end
    
    local userId = player.UserId
    self.WaterData[userId] = nil
end

function PlayerService:UpdateOverwhelmed(player)
    if not player then return end
    
    local userId = player.UserId
    self.AttributeData[userId].Overwhelmed = 0
    local overwhelmed = 0
    local tool = Knit.GetService("InventoryService"):GetToolData(player)
    for _, toolData in ipairs(tool) do
        local itemId = toolData.ItemId
        local itemInfo = ItemConfig:GetByItemId(itemId)
        if itemInfo then
            overwhelmed += itemInfo.Weight
        end
    end
    local bag = Knit.GetService("InventoryService"):GetBagData(player)
    for _, bagData in ipairs(bag) do
        local itemId = bagData.ItemId
        local itemInfo = ItemConfig:GetByItemId(itemId)
        if itemInfo then
            overwhelmed += itemInfo.Weight
        end
    end

    self.AttributeData[player.UserId].Overwhelmed = overwhelmed
    self.Client.UpdateOverwhelmed:Fire(player, self.AttributeData[userId].Overwhelmed, self.AttributeData[userId].InitMaxOverwhelmed)
    self:ChangePlayerAttribute(player, "WalkSpeed", player:getAttribute("WalkSpeed"))
    self:ChangePlayerAttribute(player, "JumpPower", player:getAttribute("JumpPower"))
    if player.Character and player.Character.Humanoid then
        print(player.Name .. " 负重 " .. self.AttributeData[player.UserId].Overwhelmed .. " 速度 " .. player.Character.Humanoid.WalkSpeed)
        print(player.Name .. " 负重 " .. self.AttributeData[player.UserId].Overwhelmed .. " 跳跃力 " .. player.Character.Humanoid.JumpPower)
    end
end

function PlayerService:GetPlayerAttribute(player, attributeName)
    if not player or not attributeName or not self.AttributeData[player.UserId][attributeName] then return nil end
    return self.AttributeData[player.UserId][attributeName]
end

function PlayerService:GetPlayerCount()
    return self.PlayerCount
end

return PlayerService
