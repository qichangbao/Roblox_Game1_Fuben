local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local TweenInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))

local _leftFrame = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainUI"):WaitForChild("left")

local _questFrame = _leftFrame:WaitForChild("QuestFrame")
local _questButton = _questFrame:WaitForChild("QuestButton")
_questButton.MouseButton1Click:Connect(function()
	Knit.GetController("UIController").ShowQuestUI:Fire(2)
end)

local _goldFrame = _leftFrame:WaitForChild("GoldFrame")
local _goldLabel = _goldFrame:WaitForChild("GoldLabel")
_goldLabel.Text = "0"

Knit.OnStart():andThen(function()
	_goldLabel.Text = _G.ClientData.Gold
	local UIController = Knit.GetController("UIController")
	UIController.ChangeGoldUI:Connect(function(gold)
		TweenInterface.AnimateNumberIncrease(_goldLabel, gold)
	end)
end)