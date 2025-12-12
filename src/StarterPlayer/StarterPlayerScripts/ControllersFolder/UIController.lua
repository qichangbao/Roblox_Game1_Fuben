local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local Signal = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Signal"))

local UIController = Knit.CreateController {
    Name = "UIController",

    ShowTip = Signal.new(),
    ShowStoreUI = Signal.new(),
    ShowSellUI = Signal.new(),
    ShowTalentUI = Signal.new(),
    ShowMessageBoxUI = Signal.new(),
    HideMessageBoxUI = Signal.new(),
	ResetMessageBoxUI = Signal.new(),
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
    OpenSubmitUI = Signal.new(),
    OpenTaskUI = Signal.new(),
    ShowStartGameUI = Signal.new(),
    ShowNoticeUI = Signal.new(),
    ShowItemAttributeUI = Signal.new(),
    ShowDragonOrbLostUI = Signal.new(),
    ShowCG = Signal.new(),
    ShowFlyItemUI = Signal.new(),
    SuccEvacuation = Signal.new(),
    ShowMapFlag = Signal.new(),
    UpdateOverwhelmedUI = Signal.new(),
    ShowQuestUI = Signal.new(),
    UpdateQuestData = Signal.new(),
    ShakeCarame = Signal.new(),
    PickUpItem = Signal.new(),
    ShowGameStartCG = Signal.new(),
    ShowBlackUI = Signal.new(),
}

function UIController:KnitInit()
end

function UIController:KnitStart()
end

return UIController