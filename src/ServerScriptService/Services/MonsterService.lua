-- MonsterService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local MonsterConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("MonsterConfig"))
local AIManager = require(script.Parent.Parent:WaitForChild("AIManagerFolder"):WaitForChild("AIManager"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local DesignMonsterConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("DesignMonsterConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local TweenInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))

local MonsterWorkspaceFolder = workspace:WaitForChild("Monster")
if not MonsterWorkspaceFolder then
    warn("MonsterWorkspaceFolder folder not found")
    return
end

local MonsterService = Knit.CreateService {
	Name = "MonsterService",
	Client = {
	    Chase = Knit.CreateSignal(),
	    DeadAnim = Knit.CreateSignal(),
	},

    Monsters = {},
    KillMonsters = {},
    ChaseMonsters = {},
    MonsterHealthBars = {}, -- 存储怪物血条的引用
    MonsterHealthBarState = {}, -- 存储血条动画状态（当前百分比/进行中的Tween）
}

-- 计算怪物血条的BillboardGui尺寸（根据怪物模型尺寸动态映射）
-- @param monster Model 怪物模型
-- @return UDim2 返回用于BillboardGui.Size的尺寸（Scale方式）
function MonsterService:_ComputeHealthBarBillboardSize(monster)
    -- 使用模型包围盒尺寸；若不可用则退化为HumanoidRootPart尺寸
    local size
    local success, result = pcall(function()
        return monster:GetExtentsSize()
    end)
    if success and result then
        size = result
    else
        local hrp = monster:FindFirstChild("HumanoidRootPart")
        if hrp then
            size = hrp.Size
        else
            size = Vector3.new(4, 6, 4) -- 兜底尺寸，防止nil
        end
    end

    -- 将包围盒尺寸映射为UI尺寸（Scale值），并限制上下界避免过大或过小
    -- 宽度基于模型X尺寸，高度基于模型Y尺寸，系数可按需要调整
    local widthScale = math.clamp(size.X / 4, 1, 4)
    local heightScale = math.clamp(size.Y / 20, 0.3, 1)

    return UDim2.new(widthScale, 0, heightScale, 0)
end

function MonsterService:PlayerAdded(player)
    self.KillMonsters[player.UserId] = {}
end

-- 通知客户端播放怪物死亡动画（函数级注释）：
-- @param npc Model 怪物模型
function MonsterService:PlayMonsterDead(npc)
    if not npc or not npc.Parent then
        return
    end
	    local monsterId = npc:GetAttribute("MonsterId")
	    print("[Server MonsterDead] PlayMonsterDead", npc, npc.Name, "MonsterId=", monsterId)
	    self.Client.DeadAnim:FireAll(npc)
end

-- 创建怪物血条UI
-- @param monster Model 怪物模型
-- @return BillboardGui 返回创建的血条UI
function MonsterService:CreateHealthBar(monster)
    local humanoid = monster:FindFirstChild("Humanoid")
    local HumanoidRootPart = monster:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not HumanoidRootPart then
        warn("Monster missing Humanoid or HumanoidRootPart: " .. monster.Name)
        return nil
    end
    
    -- 创建BillboardGui
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "HealthBar"
    -- 根据怪物尺寸动态设置血条容器大小与高度偏移
    billboardGui.Size = self:_ComputeHealthBarBillboardSize(monster)
    local offsetY = HumanoidRootPart.Size.Y / 2 + 1
    billboardGui.StudsOffset = Vector3.new(0, offsetY, 0)
    billboardGui.Parent = HumanoidRootPart
    
    -- 创建背景框架
    local backgroundFrame = Instance.new("Frame")
    backgroundFrame.Name = "Background"
    backgroundFrame.Size = UDim2.new(1, 0, 1, 0)
    backgroundFrame.Position = UDim2.new(0, 0, 0, 0)
    backgroundFrame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    backgroundFrame.BorderSizePixel = 0
    backgroundFrame.Parent = billboardGui
    
    -- 为背景框架添加圆角
    local backgroundCorner = Instance.new("UICorner")
    backgroundCorner.CornerRadius = UDim.new(0, 8)
    backgroundCorner.Parent = backgroundFrame
    
    -- 创建血条
    local healthBar = Instance.new("Frame")
    healthBar.Name = "HealthBar"
    healthBar.Size = UDim2.new(1, -4, 1, -4)
    healthBar.Position = UDim2.new(0, 2, 0, 2)
    healthBar.BackgroundColor3 = Color3.new(0, 1, 0) -- 绿色
    healthBar.BorderSizePixel = 0
    healthBar.Parent = backgroundFrame
    
    -- 为血条添加圆角
    local healthBarCorner = Instance.new("UICorner")
    healthBarCorner.CornerRadius = UDim.new(0, 4)
    healthBarCorner.Parent = healthBar
    
    -- 创建血量文本
    local healthText = Instance.new("TextLabel")
    healthText.Name = "HealthText"
    healthText.Size = UDim2.new(1, 0, 1, 0)
    healthText.Position = UDim2.new(0, 0, 0, 0)
    healthText.BackgroundTransparency = 1
    healthText.Text = string.format("%.0f/%.0f", humanoid.Health, humanoid.MaxHealth)
    healthText.TextColor3 = Color3.new(1, 1, 1)
    healthText.TextStrokeTransparency = 0
    healthText.TextStrokeColor3 = Color3.new(255, 0, 0)
    healthText.TextScaled = true
    healthText.FontFace = GameConfig.FontFace
    healthText.Parent = backgroundFrame
    
    return billboardGui
end

-- 更新血条显示（带减少动画）
-- @param monster Model 怪物模型
-- @return void
function MonsterService:UpdateHealthBar(monster)
    local humanoid = monster:FindFirstChild("Humanoid")
    if not humanoid  then return end
    local humanoidRootPart = monster:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    local billboardGui = humanoidRootPart:FindFirstChild("HealthBar")
    if not billboardGui then return end
    local backgroundFrame = billboardGui:FindFirstChild("Background")
    if not backgroundFrame then return end
    -- 动态调整血条容器尺寸（若怪物缩放变化）
    billboardGui.Size = self:_ComputeHealthBarBillboardSize(monster)
    local offsetY = humanoidRootPart.Size.Y / 2 + 1
    billboardGui.StudsOffset = Vector3.new(0, offsetY, 0)
    
    local healthBar = backgroundFrame:FindFirstChild("HealthBar")
    local healthText = backgroundFrame:FindFirstChild("HealthText")
    if healthBar and healthText then
        -- 计算血量百分比（限制在0~1）
        local healthPercent = humanoid.Health / humanoid.MaxHealth
        healthPercent = math.clamp(healthPercent, 0, 1)
        
        -- 当前显示的百分比（从UI尺寸读取）
        local currentPercent = healthBar.Size.X.Scale or 1

        -- 获取并维护该怪物的血条动画状态
        local state = self.MonsterHealthBarState[monster]
        if not state then
            state = { currentPercent = currentPercent, tween = nil }
            self.MonsterHealthBarState[monster] = state
        end

        -- 当血量减少时，使用Tween动画平滑缩短血条；增加或不变则直接更新
        if healthPercent < currentPercent then
            -- 取消之前可能存在的Tween，避免叠加
            if state.tween then
                pcall(function()
                    state.tween:Cancel()
                end)
                state.tween = nil
            end

            local targetSize = UDim2.new(healthPercent, -2, 1, -2)
            state.tween = TweenInterface.TweenNodeSize(healthBar, targetSize, 0.25, function()
                -- 动画结束后记录当前百分比
                if self.MonsterHealthBarState[monster] == state then
                    state.tween = nil
                    state.currentPercent = healthPercent
                end
            end)
        else
            -- 非减少：直接更新尺寸
            healthBar.Size = UDim2.new(healthPercent, -2, 1, -2)
            state.currentPercent = healthPercent
        end

        -- 更新血条颜色（绿色->黄色->红色）基于目标百分比
        if healthPercent > 0.6 then
            healthBar.BackgroundColor3 = Color3.new(0, 1, 0) -- 绿色
        elseif healthPercent > 0.3 then
            healthBar.BackgroundColor3 = Color3.new(1, 1, 0) -- 黄色
        else
            healthBar.BackgroundColor3 = Color3.new(1, 0, 0) -- 红色
        end
        
        -- 更新血量文本
        healthText.Text = string.format("%.0f/%.0f", humanoid.Health, humanoid.MaxHealth)
    end
end

function MonsterService:PlayerRemoved(player)
    self.KillMonsters[player.UserId] = nil
end

function MonsterService:KillMonster(player, monster)
    if not self.KillMonsters[player.UserId] then
        return
    end

    local monsterId = monster:GetAttribute("MonsterId")
    table.insert(self.KillMonsters[player.UserId], monsterId)

    local monsterInfo = MonsterConfig:GetByMonsterId(monsterId)
    if not monsterInfo then
        warn("Monster not found: " .. monsterId)
        return
    end
    Knit.GetService("QuestService"):OnNPCKilled(player, tostring(monsterId))
    
    -- 触发物品掉落
    local config = MonsterConfig:GetByMonsterId(monsterId)
    if config then
        -- 获取NPC当前位置
        local npcPosition = monster:GetPivot().Position
        
        -- 使用高级射线检测获取最佳地面位置
        local ignoreList = {monster} -- 忽略NPC本身
        local groundPosition = Interface.getGroundPosition(npcPosition, ignoreList)
        
        -- 在地面位置创建物品
        local itemArray = Interface.GetDropItems(config.DropPlanId)
        if itemArray then
	        local jobEffect = Interface.GetJobEffect(player)
            local doubleDropProbability = jobEffect and jobEffect.KillMonsterDoubleDrop or 0
            local isDoubleDrop = math.random(10000) <= doubleDropProbability
            for _, itemId in ipairs(itemArray) do
                if isDoubleDrop then
                    Knit.GetService("ItemService"):CreateItem(itemId, groundPosition, 0, Vector3.new(0, 0, 0), GameConfig.GetItemAttribute(), 0)
                end
                Knit.GetService("ItemService"):CreateItem(itemId, groundPosition, 0, Vector3.new(0, 0, 0), GameConfig.GetItemAttribute(), 0)
            end
        end
    end
end

function MonsterService:CreateMonster(data)
    if data.Refresh == 2 then
        if math.random(10000) > data.Probability then return end
    end

    if not data.MonsterId then return end

    local monsterInfo = MonsterConfig:GetByMonsterId(data.MonsterId)
    if not monsterInfo then
        warn("Monster not found: " .. data.MonsterId)
        return
    end

    local folder = game.ServerStorage:FindFirstChild("Monster")
    if not folder then
        warn("Monster type folder not found: Monster")
        return
    end
    
    local model = folder:FindFirstChild(monsterInfo.Model)
    if not model then
        warn("Monster model not found: " .. monsterInfo.Model)
        return
    end

    local monster = model:Clone()
    monster.Parent = MonsterWorkspaceFolder
    monster.Name = monsterInfo.Model .."_" .. tick()
    table.insert(self.Monsters, monster)
    monster:SetAttribute("HumanoidType", GameConfig.HumanoidType.Monster)

    -- 创建血条
    local healthBar = self:CreateHealthBar(monster)
    if healthBar then
        -- 存储血条引用
        self.MonsterHealthBars[monster] = healthBar
        
        -- 监听生命值变化
        local humanoid = monster:FindFirstChild("Humanoid")
        if humanoid then
            -- 存储连接引用的表
            local connections = {}
            
            -- 监听生命值变化
            connections.healthChanged = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
                self:UpdateHealthBar(monster)
            end)
            
            -- 监听死亡事件
            connections.died = humanoid.Died:Connect(function()
                -- 清理血条
                if self.MonsterHealthBars[monster] then
                    self.MonsterHealthBars[monster]:Destroy()
                    self.MonsterHealthBars[monster] = nil
                end
                -- 清理血条动画状态
                local state = self.MonsterHealthBarState[monster]
                if state and state.tween then
                    pcall(function()
                        state.tween:Cancel()
                    end)
                end
                self.MonsterHealthBarState[monster] = nil
                
                -- 断开所有连接
                for _, connection in pairs(connections) do
                    if connection then
                        connection:Disconnect()
                    end
                end
            end)
        end
    end

    AIManager.new(monster, data.Position, monsterInfo)
end

-- 移除怪物
function MonsterService:MonsterRemoved(monster)
    -- 清理血条
    if self.MonsterHealthBars[monster] then
        self.MonsterHealthBars[monster]:Destroy()
        self.MonsterHealthBars[monster] = nil
    end
    -- 清理血条动画状态
    local state = self.MonsterHealthBarState[monster]
    if state and state.tween then
        pcall(function()
            state.tween:Cancel()
        end)
    end
    self.MonsterHealthBarState[monster] = nil
    
    -- 从怪物列表中移除
    for i, v in ipairs(self.Monsters) do
        if v == monster then
            table.remove(self.Monsters, i)
            break
        end
    end
end

-- 改变所有怪物的属性
function MonsterService:ChangeAllMonsterAttribute(value)
    for _, monster in pairs(self.Monsters) do
        local humanoid = monster:FindFirstChild("Humanoid")
        if not humanoid then
            continue
        end

        local initVisionRange = monster:GetAttribute("InitVisionRange")
        local initAttackSpeed = monster:GetAttribute("InitAttackSpeed")
        local initAttack = monster:GetAttribute("InitAttack")
        local initWalkSpeed = monster:GetAttribute("InitWalkSpeed")
        local initMaxHealth = monster:GetAttribute("InitMaxHealth")
        if value then
            monster:SetAttribute("VisionRange", initVisionRange * (1 + value))
            monster:SetAttribute("InitAttack", initAttack * (1 + value))
            monster:SetAttribute("AttackSpeed", initAttackSpeed * (1 - value))
            humanoid.WalkSpeed = initWalkSpeed * (1 + value)
            humanoid.MaxHealth = humanoid.MaxHealth * (1 + value)
            humanoid.Health = humanoid.MaxHealth
        else
            monster:SetAttribute("VisionRange", initVisionRange)
            monster:SetAttribute("InitAttack", initAttack)
            monster:SetAttribute("AttackSpeed", initAttackSpeed)
            humanoid.WalkSpeed = initWalkSpeed
            humanoid.MaxHealth = initMaxHealth
            humanoid.Health = humanoid.MaxHealth
        end
    end
end

function MonsterService:GetKillMonsters(player)
    return self.KillMonsters[player.UserId]
end

-- 追逐玩家
function MonsterService:Chase(playerOrCharacter, npc)
    -- 兼容传入玩家或角色模型
    local player = playerOrCharacter
    if player and not player:IsA("Player") then
        player = Players:GetPlayerFromCharacter(playerOrCharacter)
    end
    if not player then
        return
    end

    if self.ChaseMonsters[npc.Name] and self.ChaseMonsters[npc.Name] ~= player.UserId then
        self:ChaseCannel(npc)
    end

    self.ChaseMonsters[npc.Name] = player.UserId
    -- 通知客户端显示/隐藏追逐标记
    self.Client.Chase:Fire(player, npc, true)
end

-- 取消所有追逐
function MonsterService:ChaseCannel(npc)
    if not self.ChaseMonsters[npc.Name] then return end
    local userId = self.ChaseMonsters[npc.Name]
    if not userId then return end
    local player = game.Players:GetPlayerByUserId(userId)
    if not player then return end
    
    self.Client.Chase:Fire(player, npc, false)
    self.ChaseMonsters[npc.Name] = nil
end

function MonsterService:DestroyAllMonsters()
    for _, monster in pairs(self.Monsters) do
        self:MonsterRemoved(monster)
    end
    self.Monsters = {}
end

function MonsterService:InitMonsters()
    if #self.Monsters > 0 then
        return
    end

    -- task.spawn(function()
    --     local islandId = Knit.GetService("IslandService"):GetIslandId()
    --     local monstersConfig = DesignMonsterConfig:GetAll()
    --     for _, config in ipairs(monstersConfig) do
    --         if config.MapId == islandId then
    --             self:CreateMonster(config)
    --         end
    --     end
    -- end)
    self:CreateMonster({Refresh = 1, MonsterId = 30001, Position = Vector3.new(159, 12.4, -22)})
    --self:CreateMonster({Refresh = 1, MonsterId = 30008, Position = Vector3.new(91, -1.4, -37)})
end

function MonsterService:KnitInit()
end

-- 服务启动时的初始化
-- @return void
function MonsterService:KnitStart()
end

return MonsterService
