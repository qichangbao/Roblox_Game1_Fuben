local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local TweenInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))

local _type = 0
local _callfunc1 = nil
local _callfunc2 = nil
local _buttonText1 = "Confirm"
local _buttonText2 = "Cancel"
local _button1Time = 0
local _button2Time = 0
local _connect1 = nil
local _connect2 = nil
local _isPause = false
local _screenGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MessageBoxUI")
_screenGui.Enabled = false
local _frame = _screenGui:WaitForChild("Frame")
local _textLabel = _frame:WaitForChild("TextLabel")
local _button1 = _frame:WaitForChild("Button1")
local _button2 = _frame:WaitForChild("Button2")

local function close()
	_callfunc1 = nil
	_callfunc2 = nil
	_isPause = false

	if _connect1 then
		_connect1:Disconnect()
		_connect1 = nil
	end
	if _connect2 then
		_connect2:Disconnect()
		_connect2 = nil
	end
	_screenGui.Enabled = false
end

local function Button1()
	if _type == 1 then
		Knit.GetService("ReviveService"):RevivePlayer():andThen(function(succ)
			if succ == 2 then
				close()
			elseif succ == 1 then
				_isPause = true
			end
		end)
	elseif _type == 2 then
		Knit.GetService("SettleService"):Settle(false):andThen(function(succ)
			if succ then
				close()
			end
		end)
	else
		if _callfunc1 then
			_callfunc1()
		end
		close()
	end
end

_button1.MouseButton1Click:Connect(function()
	Button1()
end)

local function Button2()
	if _type == 1 or _type == 2 then
		Knit.GetService("SettleService"):Settle(false):andThen(function(succ)
			if succ then
				close()
			end
		end)
	else
		if _callfunc2 then
			_callfunc2()
		end
		close()
	end
end

_button2.MouseButton1Click:Connect(function()
	Button2()
end)

Knit.OnStart():andThen(function()
	Knit.GetController("UIController").ShowMessageBoxUI:Connect(function(params)
		if _screenGui.Enabled then return end
		_screenGui.Enabled = true
		TweenInterface.AnimateUIShowScale(_frame)
		_type = params.Type or 0
		_callfunc1 = params.Button1Callfunc
		_callfunc2 = params.Button2Callfunc
		_textLabel.Text = params.Content or ""
		local text1 = params.ButtonText1 or _buttonText1
		_button1.Text = text1
		local text2 = params.ButtonText2 or _buttonText2
		_button2.Text = text2
		_button1Time = params.Button1Time or 0
		_button2Time = params.Button2Time or 0
		_isPause = false
		if _connect1 then
			_connect1:Disconnect()
			_connect1 = nil
		end
		if _connect2 then
			_connect2:Disconnect()
			_connect2 = nil
		end
		if _button1Time > 0 then
			_button1.Text = string.format("%s(%d)", text1, math.floor(_button1Time))
			_connect1 = game:GetService("RunService").Heartbeat:Connect(function(dt)
				if _isPause then return end
				_button1Time -= dt
				_button1.Text = string.format("%s(%d)", text1, math.floor(_button1Time))
				if _button1Time <= 0 then
					Button1()
				end
			end)
		end
		if _button2Time > 0 then
			_button2.Text = string.format("%s(%d)", text2, math.floor(_button2Time))
			_connect2 = game:GetService("RunService").Heartbeat:Connect(function(dt)
				if _isPause then return end
				_button2Time -= dt
				_button2.Text = string.format("%s(%d)", text2, math.floor(_button2Time))
				if _button2Time <= 0 then
					Button2()
				end
			end)
		end
	end)
	Knit.GetController("UIController").HideMessageBoxUI:Connect(function(params)
		close()
	end)
	Knit.GetController("UIController").ResetMessageBoxUI:Connect(function(params)
		_isPause = false
	end)
end)