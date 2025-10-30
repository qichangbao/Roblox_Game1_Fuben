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

local MonsterService = Knit.CreateService {
	Name = "MonsterService",
	Client = {
        Chase = Knit.CreateSignal(),
	},

    Monsters = {},
    KillMonsters = {},
    ChaseMonsters = {},
}

function MonsterService:PlayerAdded(player)
    self.KillMonsters[player.UserId] = {}
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
    monster.Parent = workspace
    monster.Name = monsterInfo.Model .."_" .. tick()
    table.insert(self.Monsters, monster)
    monster:SetAttribute("HumanoidType", GameConfig.HumanoidType.Monster)

    AIManager.new(monster, position, monsterInfo)
end

-- 移除怪物
function MonsterService:MonsterRemoved(monster)
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
    -- self:CreateMonster(30001, Vector3.new(353, -0.7, -240))
    -- self:CreateMonster(30002, Vector3.new(353, -1.5, -220))
    -- self:CreateMonster(30003, Vector3.new(353, -1.5, -220))
end

-- 服务启动时的初始化
-- @return void
function MonsterService:KnitStart()
end

return MonsterService