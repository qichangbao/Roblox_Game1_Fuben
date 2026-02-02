local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local screenGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("DragItemUI")
screenGui.Enabled = false

local frame = screenGui:WaitForChild("Frame")
local dragImage = frame:WaitForChild("DragImage")
local discardLabel = frame:WaitForChild("DiscardLabel")

Knit.OnStart():andThen(function()
	local UIController = Knit.GetController("UIController")
	UIController.ShowDragUI:Connect(function(icon, pos, discardLabelShow)
		screenGui.Enabled = true
		dragImage.Image = icon
		discardLabel.Visible = discardLabelShow

		local absoluteSize = dragImage.AbsoluteSize
		frame.Position = UDim2.new(0, pos.X - absoluteSize.X / 2, 0, pos.Y - absoluteSize.Y)
	end)
	UIController.MoveDragUI:Connect(function(pos)
		local absoluteSize = dragImage.AbsoluteSize
		frame.Position = UDim2.new(0, pos.X - absoluteSize.X / 2, 0, pos.Y - absoluteSize.Y)
	end)
	UIController.HideDragUI:Connect(function()
		screenGui.Enabled = false
	end)
end)