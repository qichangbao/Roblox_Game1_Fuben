local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild('Packages'):WaitForChild('Knit'):waitForChild('Knit'))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local TweenService = game:GetService("TweenService")

local _boat = workspace:WaitForChild(GameConfig.TeleportPartNames)
local _chuantai = _boat:WaitForChild("船台")
local _Controls = _chuantai:WaitForChild("Controls")
local _DiallingModule = _Controls:WaitForChild("Dialling Module")
local _partEscape = _DiallingModule:WaitForChild("ActivatorEscape")
local _partNextIsland = _DiallingModule:WaitForChild("ActivatorNextIsland")
local _partEscapePosY = _partEscape.Position.Y
local _partNextIslandPosY = _partNextIsland.Position.Y

local function ShowAnim(part, targetPos)
    local duration = 0.1
    local tween = TweenService:Create(
        part,
        TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { Position = targetPos }
    )
    tween:Play()
end

local function ChooseEscape()
    local pos = _partEscape.Position
    ShowAnim(_partEscape, Vector3.new(pos.X, _partEscapePosY - 0.5, pos.Z))
end

local function ChooseNextIsland()
    local pos = _partNextIsland.Position
    ShowAnim(_partNextIsland, Vector3.new(pos.X, _partNextIslandPosY - 0.5, pos.Z))
end

local function Reset()
    _partEscape.Position = Vector3.new(_partEscape.Position.X, _partEscapePosY, _partEscape.Position.Z)
    _partNextIsland.Position = Vector3.new(_partNextIsland.Position.X, _partNextIslandPosY, _partNextIsland.Position.Z)
end

Knit.OnStart():andThen(function()
    Knit.GetController("UIController").ChooseEscape:Connect(function()
        ChooseEscape()
    end)
    Knit.GetController("UIController").ChooseNextIsland:Connect(function()
        ChooseNextIsland()
    end)
    Knit.GetController("UIController").ResetBoat:Connect(function()
        Reset()
    end)
end)
