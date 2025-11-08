-- MonsterService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local MonsterConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("MonsterConfig"))
local AIManager = require(script.Parent.Parent:WaitForChild("AIManagerFolder"):WaitForChild("AIManager"))
local MonsterPosConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("MonsterPosConfig"))
local MonsterPlanConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("MonsterPlanConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local TweenService = game:GetService("TweenService")

local MonsterWorkspaceFolder = workspace:WaitForChild("Monster")
if not MonsterWorkspaceFolder then
    warn("MonsterWorkspaceFolder folder not found")
    return
end

local MonsterService = Knit.CreateService {
	Name = "MonsterService",
	Client = {
        Chase = Knit.CreateSignal(),
	},

    Monsters = {},
    KillMonsters = {},
    ChaseMonsters = {},
    MonsterHealthBars = {}, -- 存储怪物血条的引用
    MonsterHealthBarState = {}, -- 存储血条动画状态（当前百分比/进行中的Tween）
}

function MonsterService:PlayerAdded(player)
    self.KillMonsters[player.UserId] = {}
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
    billboardGui.Size = UDim2.new(4, 0, 0.5, 0)
    billboardGui.StudsOffset = Vector3.new(0, HumanoidRootPart.Size.Y / 2 + 1, 0)
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
    
    local billboardGui = humanoidRootPart:FindFirstChild("HealthBar")
    if not billboardGui then
        return
    end
    
    local backgroundFrame = billboardGui:FindFirstChild("Background")
    if not backgroundFrame then
        return
    end
    
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
            local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local tween = TweenService:Create(healthBar, tweenInfo, { Size = targetSize })
            state.tween = tween
            tween:Play()
            tween.Completed:Connect(function()
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
    Knit.GetService("ClientUIService"):ShowTipAll(string.format("%s Killed the monster %s", player.Name, monsterInfo.DisplayName))
end

--local index = 0
function MonsterService:CreateMonster(monsterId, position)
    -- if monsterId ~= 30002 then
    --     return
    -- end
    -- if index >= 1 then
    --     return
    -- end
    -- index += 1
    local monsterInfo = MonsterConfig:GetByMonsterId(monsterId)
    if not monsterInfo then
        warn("Monster not found: " .. monsterId)
        return
    end

    local folder = game.ServerStorage:FindFirstChild("Monster")
    if not folder then
        warn("Monster type folder not found: Monster")
        return
    end
    
    local part = folder:FindFirstChild(monsterInfo.Model)
    if not part then
        warn("Monster model not found: " .. monsterInfo.Model)
        return
    end

    local monster = part:Clone()
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

    AIManager.new(monster, position, monsterInfo)
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
    if not self.ChaseMonsters[npc.Name] then
        return
    end

    local userId = self.ChaseMonsters[npc.Name]
    if not userId then
        return
    end
    local player = game.Players:GetPlayerByUserId(userId)
    if not player then
        return
    end
    self.Client.Chase:Fire(player, npc, false)
    self.ChaseMonsters[npc.Name] = nil
end

function MonsterService:CreateMonsterByPlan(planData, position)
    if type(planData.MonsterId) ~= "table" then
        local random = math.random(1, 10000)
        if random <= planData.Probability then
            self:CreateMonster(planData.MonsterId, position)
        end
    else
        for index, monsterId in pairs(planData.MonsterId) do
            local random = math.random(1, 10000)
            if random <= planData.Probability[index] then
                self:CreateMonster(monsterId, position)
            end
        end
    end
end

function MonsterService:initMonsters()
    task.spawn(function()
        local pos = MonsterPosConfig:GetAll()
        -- 随机打乱数组
        local posArray = Interface.randomTable(pos)
        for _, posData in pairs(posArray) do
            local planData = MonsterPlanConfig:GetByMonsterPlanId(posData.MonsterPlanId)
            if not planData then
                continue
            end

            self:CreateMonsterByPlan(planData, posData.Position)
        end
    end)
end

function MonsterService:KnitInit()
    self:initMonsters()
    --self:CreateMonster(30001, Vector3.new(353, -0.7, -240))
    --self:CreateMonster(30002, Vector3.new(353, -0.7, -220))
    --self:CreateMonster(30003, Vector3.new(353, -0.7, -200))
end

-- 服务启动时的初始化
-- @return void
function MonsterService:KnitStart()
end

return MonsterService