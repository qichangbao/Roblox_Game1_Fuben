local PathfindingService = game:GetService("PathfindingService")

local PathfindingMove = {}

function PathfindingMove.StopMove(npc)
    local Humanoid = npc:FindFirstChild('Humanoid')
    if Humanoid and Humanoid.RootPart then
        Humanoid.WalkToPoint = Humanoid.RootPart.Position
        Humanoid.WalkToPart = nil
    end
end

-- npc: Model, targetPosition: Vector3, callback: function(reached)
function PathfindingMove.MoveTo(npc, targetPosition, callback)
    local rootPart = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("RootPart")
    if not rootPart then
        warn("NPC模型没有HumanoidRootPart或RootPart")
        return
    end
    local humanoid = npc:FindFirstChild("Humanoid")
    if not humanoid then
        warn("NPC模型没有Humanoid")
        return
    end
    local startPos = rootPart.Position
    -- 优化寻路参数，适应台阶环境
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 6,
        AgentCanJump = true,
        Cost = {
        },
    })
    path:ComputeAsync(startPos, targetPosition)
    local waypoints = path:GetWaypoints()
    if path.Status ~= Enum.PathStatus.Success then
        PathfindingMove.StopMove(npc)
        if callback then callback(false) end
        return
    end

    local tempWaypoints = {}
    for _, wp in ipairs(waypoints) do
        -- 检查路径点是否需要跳跃
        if wp.Label == "Water" then
            break
        end
        table.insert(tempWaypoints, wp)
    end

    local connection = nil
    local currentWaypoint = 2

    local function moveToNextWaypoint(jumpAttempts)
        jumpAttempts = jumpAttempts or 0
        if currentWaypoint > #tempWaypoints then
            PathfindingMove.StopMove(npc)
            if callback then callback(true) end
            return
        end
        local humanoidTemp = npc:FindFirstChild("Humanoid")
        if not humanoidTemp then
            warn("NPC模型没有Humanoid")
            return
        end
        local wp = tempWaypoints[currentWaypoint]

        -- 检查路径点是否需要跳跃
        if wp.Action == Enum.PathWaypointAction.Jump then
            humanoidTemp.Jump = true
            task.wait(0.05)
        end

        local targetPos = wp.Position
        humanoidTemp:MoveTo(targetPos)

        connection = humanoidTemp.MoveToFinished:Once(function(reached)
            if reached then
                currentWaypoint = currentWaypoint + 1
                moveToNextWaypoint()
            else
                PathfindingMove.StopMove(npc)
                if callback then callback(false) end
            end
        end)
    end

    moveToNextWaypoint()

    return connection
end

return PathfindingMove

