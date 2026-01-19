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
    if not mapConfig then
        Knit.GetController("UIController").ResetCamareDir:Fire()
        return
    end

    if _G.CGPlaying then
        Knit.GetController("UIController").ResetCamareDir:Fire()
        return
    end
    _G.CGPlaying = true

    local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        Knit.GetController("UIController").ResetCamareDir:Fire()
        _G.CGPlaying = false
        return
    end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        Knit.GetController("UIController").ResetCamareDir:Fire()
        _G.CGPlaying = false
        return
    end

    local _boatOri = workspace:FindFirstChild(GameConfig.TeleportPartNames)
    if not _boatOri then
        Knit.GetController("UIController").ResetCamareDir:Fire()
        _G.CGPlaying = false
        return
    end
    local _boat = _boatOri:Clone()
    _boat.Name = "Boat_CG"
    _boat.Parent = workspace
    for _, part in ipairs(_boat:GetDescendants()) do
        if part:IsA("ProximityPrompt") then
            part:Destroy()
        end
    end

    Knit.GetController("UIController").ShowMainUI:Fire(false)

    local moveSpeed = 60
    local startCFrame = _boat:GetAttribute("CGStartFrame")
    local endCFrame = _boat:GetAttribute("CGEndFrame")
    local boatFrame = _boat:GetPivot()
    local hrpOffsetCF = {}
    local playerCharacters = {}
    for _, playerUserId in ipairs(playerUserIds) do
        local player = Players:GetPlayerByUserId(playerUserId)
        if not player then continue end
        local playerCharacter = player.Character or player.CharacterAdded:Wait()
        local playerHumanoidRootPart = playerCharacter:FindFirstChild("HumanoidRootPart")
        if not playerHumanoidRootPart then continue end
        local offset = boatFrame:ToObjectSpace(playerHumanoidRootPart.CFrame)
        -- 临时允许克隆
        local oldArchivable = playerCharacter.Archivable
        playerCharacter.Archivable = true
        local playerTemp = playerCharacter:Clone()
        playerCharacter.Archivable = oldArchivable
        playerTemp.Parent = workspace
        hrpOffsetCF[playerTemp] = offset
        table.insert(playerCharacters, playerTemp)
    end

    local function setPlayerFrame(current)
        for _, c in ipairs(playerCharacters) do
            local playerHumanoidRootPart = c:FindFirstChild("HumanoidRootPart")
            if not playerHumanoidRootPart then continue end
            local offset = hrpOffsetCF[c]
            if offset then
                playerHumanoidRootPart.CFrame = current * offset
            end
        end
    end

    local camera = workspace.CurrentCamera
    local originalCameraType = camera.CameraType
    local originalCameraSubject = camera.CameraSubject

    local playerModule = require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
    local controls = playerModule:GetControls()
    controls:Disable()

    camera.CameraType = Enum.CameraType.Scriptable

    _boat:PivotTo(startCFrame)
    setPlayerFrame(startCFrame)

    local cameraOffset = _boat:GetAttribute("CGCameraOffsetFrame")
    local curTime = 0
    local dbgTime = 0
    local conn
    task.delay(2, function()
        Knit.GetController("UIController").ShowBlackUI:Fire(
        {
            Show = true,
            Text = string.format("Approaching %s", mapConfig.DesignName),
            CallfuncMiddle = function()
                _G.CGPlaying = false
                _boat:Destroy()
                for _, c in ipairs(playerCharacters) do
                    c:Destroy()
                end

                if conn then
                    conn:Disconnect()
                    conn = nil
                end

                camera.CameraType = originalCameraType
                camera.CameraSubject = originalCameraSubject
                Knit.GetController("UIController").ResetCamareDir:Fire()
            end,
            CallfuncEnd = function()
                controls:Enable()
                task.delay(0.3, function()
                    Knit.GetController("UIController").ShowMainUI:Fire(true)
                    --Knit.GetController("UIController").ShowStartGameUI:Fire() -- 显示开始游戏UI
                end)
            end
        })
    end)
    
    conn = RunService.RenderStepped:Connect(function(dt)
        local current = _boat:GetPivot()
        local toEnd = endCFrame.Position - current.Position
        local dist = toEnd.Magnitude
        local step = moveSpeed * dt
        curTime = curTime + dt
        dbgTime = dbgTime + dt

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
        _boat:PivotTo(newCFrame)
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
