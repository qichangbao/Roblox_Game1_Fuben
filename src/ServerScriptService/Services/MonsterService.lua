-- MonsterService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local MonsterConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("MonsterConfig"))
local AIManager = require(script.Parent.Parent:WaitForChild("AIManagerFolder"):WaitForChild("AIManager"))
local MonsterPosConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("MonsterPosConfig"))
local MonsterPlanConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("MonsterPlanConfig"))

local MonsterService = Knit.CreateService {
	Name = "MonsterService",
	Client = {
	},
}

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
    monster:PivotTo(CFrame.new(position, monster.HumanoidRootPart.CFrame.LookVector))

    local aiManager = AIManager.new(monster, position, monsterInfo)
    aiManager:Start()
end

function MonsterService:CreateMonsterByPlan(planData, position)
    if type(planData.MonsterId) ~= "table" then
        local random = math.random(1, 10000)
        if random <= planData.Probability then
            print("创建怪物:", planData.MonsterId, "概率:", planData.Probability)
            self:CreateMonster(planData.MonsterId, position)
        end
    else
        for index, monsterId in pairs(planData.MonsterId) do
            local random = math.random(1, 10000)
            if random <= planData.Probability[index] then
                print("创建怪物:", monsterId, "概率:", planData.Probability[index])
                self:CreateMonster(monsterId, position)
            end
        end
    end
end

function MonsterService:initMonsters()
    task.spawn(function()
        local pos = MonsterPosConfig:GetAll()
        for _, posData in pairs(pos) do
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
    --self:CreateMonster(30001, Vector3.new(353, -1.5, -240))
    --self:CreateMonster(30002, Vector3.new(353, -1.5, -250))
end

-- 服务启动时的初始化
-- @return void
function MonsterService:KnitStart()
end

return MonsterService