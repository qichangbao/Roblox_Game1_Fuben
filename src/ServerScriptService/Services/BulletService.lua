local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local TweenInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))

local BulletService = Knit.CreateService({
    Name = "BulletService",
    Client = {
        BulletFired = Knit.CreateSignal(),
    },
})

-- 函数注释：Knit 初始化阶段调用，用于服务级初始化
function BulletService:KnitInit()
end

-- 函数注释：Knit 启动阶段调用，用于服务启动后的逻辑
function BulletService:KnitStart()
end

-- 函数注释：处理客户端发来的开火请求
-- @param player Player 触发开火的玩家
-- @param fireData table 射击参数（Origin, Direction, MaxDistance, Damage, IgnoreList）
function BulletService.Client:FireBullet(player, fireData)
    return self.Server:FireBullet(player, fireData)
end

-- 函数注释：在服务器端执行射线检测，驱动子弹模型飞行并在命中后结算伤害
-- @param player Player 触发开火的玩家
-- @param fireData table 射击参数（Origin, Direction, MaxDistance, Damage, BulletTemplate, Speed, IgnoreList, IsCrit）
function BulletService:FireBullet(player, fireData)
    if not player or not player.Character or not fireData then
        return
    end

    local origin = fireData.Origin
    local direction = fireData.Direction
    local maxDistance = fireData.MaxDistance or 500
    local damage = fireData.Damage or 10
    local bulletTemplate = fireData.BulletTemplate
    local speed = fireData.Speed or 200

    if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
        return
    end

    if direction.Magnitude < 1e-3 then
        return
    end

    local character = player.Character

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local ignoreList = { character }
    if typeof(fireData.IgnoreList) == "table" then
        for _, inst in ipairs(fireData.IgnoreList) do
            if typeof(inst) == "Instance" then
                table.insert(ignoreList, inst)
            end
        end
    end
    rayParams.FilterDescendantsInstances = ignoreList

    local unitDir = direction.Unit
    local result = Workspace:Raycast(origin, unitDir * maxDistance, rayParams)

    local hitPosition = origin + unitDir * maxDistance
    local hitInstance = nil
    local hitModel = nil

    if result then
        hitPosition = result.Position
        hitInstance = result.Instance
        hitModel = hitInstance:FindFirstAncestorOfClass("Model")
    end

    local distance = (hitPosition - origin).Magnitude
    local travelTime = distance / math.max(speed, 1)

    local bulletClone = nil
    local bulletRoot = nil

    if bulletTemplate and typeof(bulletTemplate) == "Instance" then
        bulletClone = bulletTemplate:Clone()
        bulletClone.Parent = Workspace

        if bulletClone:IsA("Model") then
            bulletRoot = bulletClone.PrimaryPart or bulletClone:FindFirstChildWhichIsA("BasePart")
        elseif bulletClone:IsA("BasePart") then
            bulletRoot = bulletClone
        end
    end

    if bulletRoot then
        bulletRoot.CFrame = CFrame.lookAt(origin, hitPosition)

        TweenInterface.TweenNodeMoveFrame(bulletRoot, CFrame.lookAt(hitPosition, hitPosition + unitDir), travelTime, function()
            if hitModel then
                Interface.decHp(hitModel, damage, fireData.IsCrit or false)
            end
            if bulletClone and bulletClone.Parent then
                bulletClone:Destroy()
            end
        end)

        Debris:AddItem(bulletClone, travelTime + 2)
    else
        if hitModel then
            Interface.decHp(hitModel, damage, fireData.IsCrit or false)
        end
    end

    self.Client.BulletFired:FireAll(player, {
        Origin = origin,
        Direction = unitDir,
        HitPosition = hitPosition,
        HitInstance = hitInstance,
    })
end

return BulletService
