local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local Signal = require(ReplicatedStorage.Packages.Knit.Signal)

local UIController = Knit.CreateController {
    Name = "UIController",

    ShowTip = Signal.new(),
	ChangeGoldUI = Signal.new(),
    ShowDragUI = Signal.new(),
    MoveDragUI = Signal.new(),
    HideDragUI = Signal.new(),
	UpdateToolUI = Signal.new(),
}

function UIController:KnitInit()
end

function UIController:KnitStart()
end

return UIController