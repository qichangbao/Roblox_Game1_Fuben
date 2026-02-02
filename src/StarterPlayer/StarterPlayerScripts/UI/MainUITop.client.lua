local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local DesignConfig = require(ReplicatedStorage:WaitForChild('ConfigFolder'):WaitForChild('DesignConfig'))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local TweenInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))

local _topFrame = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainUI"):WaitForChild("top")
local _taskTipLabel = _topFrame:WaitForChild("TaskTipLabel")
_taskTipLabel.RichText = true
_taskTipLabel.Text = ""

local _taskGoldFrame = _topFrame:WaitForChild("TaskGoldFrame")
local _taskGoldLabelFrame = _taskGoldFrame:WaitForChild("TaskGoldLabelFrame")
local _taskCurGoldLabel = _taskGoldLabelFrame:WaitForChild("TaskCurGoldLabel")
_taskCurGoldLabel.Text = ""
local _taskTargetGoldLabel = _taskGoldLabelFrame:WaitForChild("TaskTargetGoldLabel")
_taskTargetGoldLabel.Text = ""
local _taskTargetGoldProgress = _taskGoldFrame:WaitForChild("TaskTargetGoldProgress")
_taskTargetGoldProgress.Size = UDim2.new(0, 0, 1, 0)

local _textLabel = _taskGoldFrame:WaitForChild("TextLabel")
_textLabel.Visible = false
local _oriX = _textLabel.Position.X.Scale
local _oriY = _textLabel.Position.Y.Scale

local _mapConfig = DesignConfig:GetByMapId(_G.ClientData.IslandId)
-- 游戏时间视角下的撤离时间（秒，用于UI展示）
local _escapeTime = _mapConfig.EvacuateTime
local _curEscapeTask = 0

local function updateTaskLabel(curEscapeTask, escapeTask)
	if escapeTask == 0 then return end
	local isTaskDone = curEscapeTask >= escapeTask
	if isTaskDone then
		_taskCurGoldLabel.TextColor3 = Color3.new(0, 255, 0)
	else
		_taskCurGoldLabel.TextColor3 = Color3.new(255, 0, 0)
	end

	local curGold = tonumber(_taskCurGoldLabel.Text)
	if curGold and curGold < curEscapeTask then
		TweenInterface.AnimateNumberIncrease(_taskCurGoldLabel, curEscapeTask)
	else
		_taskCurGoldLabel.Text = curEscapeTask
	end
	_taskTargetGoldLabel.Text = string.format("/%s", escapeTask)
	TweenInterface.TweenProgressBarSize(_taskTargetGoldProgress, curEscapeTask / escapeTask, 0.4)
	if curEscapeTask >= escapeTask then
		-- 目标达成时启动颜色脉冲循环：1秒到黑色，再1秒回原色，持续循环（函数级注释）
		TweenInterface.StartPulseGuiColorLoop(_taskTargetGoldProgress, Color3.new(0, 0, 0), 1.0, 1.0)
	else
		-- 未达成或回退时停止颜色脉冲循环
		TweenInterface.StopPulseGuiColorLoop(_taskTargetGoldProgress)
	end
	local space = curEscapeTask - _curEscapeTask
	_curEscapeTask = curEscapeTask
	_textLabel.Visible = true
	_textLabel.Text = "+" .. space
	_textLabel.TextTransparency = 1
	_textLabel.Position = UDim2.new(_oriX, 0, _oriY - 0.5, 0)
	TweenInterface.TweenNodeTransparencyText(_textLabel, 0, 0.2, function()
		task.wait(1)
		TweenInterface.TweenNodeTransparencyText(_textLabel, 1, 0.2, function()
			_textLabel.Visible = false
		end)
		
	end)
	TweenInterface.TweenNodeMovePosition(_textLabel, UDim2.new(_oriX, 0, _oriY, 0), 0.2)
end

game:GetService("RunService").Heartbeat:Connect(function(dt)
	_escapeTime -= dt
	if _escapeTime <= 30 then
		_taskTipLabel.TextColor3 = Color3.new(0.858823, 0.184313, 0.184313)
	end
	_taskTipLabel.Text = Interface.formatTimeMMSS(_escapeTime)
end)

Knit.OnStart():andThen(function()
	local UIController = Knit.GetController("UIController")
	UIController.UpdateEscapeTime:Connect(function(escapeTime)
		_escapeTime = escapeTime
	end)
	UIController.UpdateEscapeTask:Connect(function(curEscapeTask, escapeTask)
		updateTaskLabel(curEscapeTask, escapeTask)
	end)
	updateTaskLabel(_G.ClientData.CurEscapeTask, _G.ClientData.EscapeTask)
end)