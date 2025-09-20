-- MonsterService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local MonsterConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("MonsterConfig"))
local AIManager = require(script.Parent.Parent:WaitForChild("AIManagerFolder"):WaitForChild("AIManager"))

local MonsterService = Knit.CreateService {
	Name = "MonsterService",
	Client = {
	},
}

local function CreateMonster(monsterId, position)
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

function MonsterService:KnitInit()
    CreateMonster(30001, Vector3.new(353, -1.5, -240))
    --CreateMonster(30002, Vector3.new(353, -1.5, -250))
end

-- 服务启动时的初始化
-- @return void
function MonsterService:KnitStart()
end

return MonsterService