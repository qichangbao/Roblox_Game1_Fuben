-- MonsterService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
	},

    Monsters = {},
    KillMonsters = {},
}

function MonsterService:PlayerAdded(player)
    self.KillMonsters[player.userId] = {}
end

function MonsterService:playerRemoved(player)
    self.KillMonsters[player.userId] = nil
end

function MonsterService:KillMonster(player, monster)
    if not self.KillMonsters[player.userId] then
        return
    end

    local monsterId = monster:GetAttribute("MonsterId")
    table.insert(self.KillMonsters[player.userId], monsterId)
end

function MonsterService:CreateMonster(monsterId, position)
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
function MonsterService:ChangeAllMonsterAttribute(attribute, value)
    for _, monster in pairs(self.Monsters) do
        local initValue = monster:GetAttribute("Init" .. attribute)
        if value then
            monster:SetAttribute(attribute, initValue + value)
        else
            monster:SetAttribute(attribute, initValue)
        end
    end
end

function MonsterService:GetKillMonsters(player)
    return self.KillMonsters[player.userId]
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
    --self:CreateMonster(30002, Vector3.new(353, -1.5, -220))
    --self:CreateMonster(30003, Vector3.new(353, -1.5, -220))
end

-- 服务启动时的初始化
-- @return void
function MonsterService:KnitStart()
end

return MonsterService