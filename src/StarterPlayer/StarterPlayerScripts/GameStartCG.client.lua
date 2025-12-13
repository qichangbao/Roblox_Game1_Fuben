local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild('Packages'):WaitForChild('Knit'):waitForChild('Knit'))
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local DesignConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("DesignConfig"))

--[[
    展示开场CG：让船航行并跟随摄像机
    行为：
    - 禁用玩家移动与摄像机控制
    - 控制地图中 `Special/Boat` 沿自身前进方向航行 10 秒
    - 航行过程中摄像机脚本化跟随船体
    - 航行结束后恢复玩家与默认摄像机
    返回：void
]]
local function ShowGameStartCG()
    local mapConfig = DesignConfig:GetByMapId(_G.ClientData.IslandId)
    if not mapConfig then return end
    local land = workspace:FindFirstChild(mapConfig.MapName)
    if not land then return end
    local Special = land:FindFirstChild("Special")
    if not Special then return end
    local Boat = Special:FindFirstChild("Boat")
    if not Boat then return end

    if _G.CGPlaying then
        return
    end
    _G.CGPlaying = true

    local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        _G.CGPlaying = false
        return
    end

    character.Parent = Boat

    local camera = workspace.CurrentCamera
    local originalCameraType = camera.CameraType
    local originalCameraSubject = camera.CameraSubject
    local originalWalkSpeed = humanoid.WalkSpeed
    local originalJumpPower = humanoid.JumpPower

    local playerModule = require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
    local controls = playerModule:GetControls()
    controls:Disable()
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0

    camera.CameraType = Enum.CameraType.Scriptable

    local moveSpeed = 60
    local startCFrame = Boat:GetAttribute("CGStartFrame")
    local endCFrame = Boat:GetAttribute("CGEndFrame")

    Boat:PivotTo(startCFrame)

    local cameraOffset = Boat:GetAttribute("CGCameraOffsetFrame")
    local curTime = 0
    local isShowBlackUI = false
    local conn
    conn = RunService.RenderStepped:Connect(function(dt)
        local current = Boat:GetPivot()
        local toEnd = endCFrame.Position - current.Position
        local step = moveSpeed * dt
        curTime = curTime + dt
        if curTime >= 2 and not isShowBlackUI then
            isShowBlackUI = true
            Knit.GetController("UIController").ShowBlackUI:Fire({Show = true,
            Text = string.format("Approaching %s", mapConfig.DesignName),
            CallfuncMiddle = function()
                Boat:PivotTo(endCFrame)
                character.Parent = workspace
                camera.CameraType = originalCameraType
                camera.CameraSubject = originalCameraSubject or humanoid
            end,
            CallfuncEnd = function()
                controls:Enable()
                humanoid.WalkSpeed = originalWalkSpeed
                humanoid.JumpPower = originalJumpPower
                _G.CGPlaying = false

                if conn then
                    conn:Disconnect()
                    conn = nil
                end

                task.delay(0.3, function()
                    Knit.GetController("UIController").ShowStartGameUI:Fire() -- 显示开始游戏UI
                end)
            end})
            return
        end

        local newPos = current.Position + toEnd.Unit * step
        local newCFrame = CFrame.new(newPos) * current.Rotation
        Boat:PivotTo(newCFrame)

        local camCFrame = newCFrame * cameraOffset
        camera.CFrame = CFrame.lookAt(camCFrame.Position, newCFrame.Position)
    end)
end

Knit.OnStart():andThen(function()
	Knit.GetController("UIController").ShowGameStartCG:Connect(function()
        ShowGameStartCG()
	end)
end)
