local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local Signal = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Signal"))

local UIController = Knit.CreateController {
    Name = "UIController",

    ShowTip = Signal.new(),
    ShowMessageBoxUI = Signal.new(),
	ChangeGoldUI = Signal.new(),
    ShowDragUI = Signal.new(),
    MoveDragUI = Signal.new(),
    HideDragUI = Signal.new(),
	UpdateToolUI = Signal.new(),
    UpdateBagUI = Signal.new(),
    InitTaskUI = Signal.new(),
    UpdateTaskUI = Signal.new(),
    UpdateEscapeTask = Signal.new(),
    ShowAdditionalBackpackUI = Signal.new(),
    ShowSettleUI = Signal.new(),
    OpenTaskUI = Signal.new(),
}

function UIController:KnitInit()
end

function UIController:KnitStart()
end

return UIController