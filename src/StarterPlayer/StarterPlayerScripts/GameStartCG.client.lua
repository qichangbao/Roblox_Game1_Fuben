local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild('Packages'):WaitForChild('Knit'):waitForChild('Knit'))
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local DesignConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("DesignConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))

--[[
    展示开场CG：让船航行并跟随摄像机
    行为：
    - 禁用玩家移动与摄像机控制
    - 控制地图中 `Special/Boat` 沿自身前进方向航行 10 秒
    - 航行过程中摄像机脚本化跟随船体
    - 航行结束后恢复玩家与默认摄像机
    返回：void
]]
local function ShowGameStartCG(playerUserIds)
    local mapConfig = DesignConfig:GetByMapId(_G.ClientData.IslandId)
    if not mapConfig then return end
    local boat = workspace:FindFirstChild(GameConfig.TeleportPartNames)
    if not boat then return end

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
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        _G.CGPlaying = false
        return
    end

    Knit.GetController("UIController").ShowMainUI:Fire(false)

    local moveSpeed = 60
    local startCFrame = boat:GetAttribute("CGStartFrame")
    local endCFrame = boat:GetAttribute("CGEndFrame")
    local boatFrame = boat:GetPivot()
    local hrpOffsetCF = {}
    local players = {}
    for _, playerUserId in ipairs(playerUserIds) do
        local player = Players:GetPlayerByUserId(playerUserId)
        if not player then continue end
        table.insert(players, player)
        local playerCharacter = player.Character or player.CharacterAdded:Wait()
        local playerHumanoidRootPart = playerCharacter:FindFirstChild("HumanoidRootPart")
        if not playerHumanoidRootPart then continue end
        hrpOffsetCF[player.UserId] = boatFrame:ToObjectSpace(playerHumanoidRootPart.CFrame)
    end

    local function setPlayerFrame(current)
        for _, player in ipairs(players) do
            local playerCharacter = player.Character or player.CharacterAdded:Wait()
            local playerHumanoidRootPart = playerCharacter:FindFirstChild("HumanoidRootPart")
            if not playerHumanoidRootPart then continue end
            playerHumanoidRootPart.CFrame = current * hrpOffsetCF[player.UserId]
        end
    end

    boat:PivotTo(startCFrame)
    setPlayerFrame(startCFrame)

    local camera = workspace.CurrentCamera
    local originalCameraType = camera.CameraType
    local originalCameraSubject = camera.CameraSubject
    local originalCameraCFrame = camera.CFrame

    local playerModule = require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
    local controls = playerModule:GetControls()
    controls:Disable()
    local origAnchored = humanoidRootPart.Anchored
    local origPlatformStand = humanoid.PlatformStand
    humanoidRootPart.Anchored = true
    humanoid.PlatformStand = true

    camera.CameraType = Enum.CameraType.Scriptable

    local cameraOffset = boat:GetAttribute("CGCameraOffsetFrame")
    local curTime = 0
    local dbgTime = 0
    local isShowBlackUI = false
    local conn
    conn = RunService.RenderStepped:Connect(function(dt)
        local current = boat:GetPivot()
        local toEnd = endCFrame.Position - current.Position
        local dist = toEnd.Magnitude
        local step = moveSpeed * dt
        curTime = curTime + dt
        dbgTime = dbgTime + dt
        if curTime >= 2 and not isShowBlackUI then
            isShowBlackUI = true
            Knit.GetController("UIController").ShowBlackUI:Fire({Show = true,
            Text = string.format("Approaching %s", mapConfig.DesignName),
            CallfuncMiddle = function()
                Knit.GetService("BoatService"):Reset(endCFrame):andThen(function()
                    Knit.GetController("UIController").ResetBoat:Fire()
                end)
            end,
            CallfuncEnd = function()
                camera.CameraType = originalCameraType
                camera.CameraSubject = originalCameraSubject
                camera.CFrame = originalCameraCFrame
                
                controls:Enable()
                humanoidRootPart.Anchored = origAnchored
                humanoid.PlatformStand = origPlatformStand
                _G.CGPlaying = false

                if conn then
                    conn:Disconnect()
                    conn = nil
                end

                task.delay(0.3, function()
                    Knit.GetController("UIController").ShowMainUI:Fire(true)
                    Knit.GetController("UIController").ShowStartGameUI:Fire() -- 显示开始游戏UI
                end)
            end})
            return
        end

        local newPos
        if dist > 1e-4 then
            local dir = toEnd / dist
            newPos = current.Position + dir * step
            if (newPos - current.Position).Magnitude > dist then
                newPos = endCFrame.Position
            end
        else
            newPos = endCFrame.Position
        end
        local newCFrame = CFrame.new(newPos) * current.Rotation
        boat:PivotTo(newCFrame)
        setPlayerFrame(newCFrame)

        local camCFrame = newCFrame * cameraOffset
        camera.CFrame = CFrame.lookAt(camCFrame.Position, newCFrame.Position)
    end)
end

Knit.OnStart():andThen(function()
	Knit.GetController("UIController").ShowGameStartCG:Connect(function(playerUserIds)
        ShowGameStartCG(playerUserIds)
	end)
end)
