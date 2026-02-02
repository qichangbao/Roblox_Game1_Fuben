local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local TweenInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))

local _screenGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("BlackUI")
_screenGui.Enabled = true
local _frame = _screenGui:WaitForChild("Frame")
local _textLabel = _frame:WaitForChild("TextLabel")
_frame.BackgroundTransparency = 0
_textLabel.TextTransparency = 0

local function show(data)
	if data.CallfuncStart then
		data.CallfuncStart()
	end
	_textLabel.Text = data.Text
	_frame.BackgroundTransparency = 1
	_textLabel.TextTransparency = 1

	local fadeTime = 1 -- 动画时长（秒）
	TweenInterface.TweenNodeTransparencyFrame(_frame, 0, fadeTime, function()
		if data.CallfuncMiddle then
			data.CallfuncMiddle()
		end
	end)
	TweenInterface.TweenNodeTransparencyText(_textLabel, 0, fadeTime)
	task.wait(fadeTime + 1)
	TweenInterface.TweenNodeTransparencyFrame(_frame, 1, fadeTime, function()
		_screenGui.Enabled = false
		if data.CallfuncEnd then
			data.CallfuncEnd()
		end
	end)
	TweenInterface.TweenNodeTransparencyText(_textLabel, 1, fadeTime)
end

Knit.OnStart():andThen(function()
	Knit.GetController("UIController").ShowBlackUI:Connect(function(data)
		if data.Show then
			_screenGui.Enabled = true
			show(data)
		else
			_screenGui.Enabled = false
		end
	end)
end)

