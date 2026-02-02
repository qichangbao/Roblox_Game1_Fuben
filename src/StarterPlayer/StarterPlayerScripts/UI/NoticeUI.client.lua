local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local TweenInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))

local _type = 0

local _screenGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("NoticeUI")
_screenGui.Enabled = false
local _frame = _screenGui:WaitForChild("Frame")
local _kuangFrame = _frame:WaitForChild("KuangFrame")
local _redFrame = _frame:WaitForChild("RedFrame")
local _blueFrame = _frame:WaitForChild("BlueFrame")

-- 创建UIGradient实现渐变效果
local gradient = Instance.new("UIGradient")
gradient.Name = "RedToYellowGradient"

-- 设置渐变方向（从上到下）
gradient.Rotation = 90 -- 90度表示垂直方向

-- 创建颜色序列点
local colorSequence = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),    -- 顶部红色 (位置0)
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 0)),   -- 底部黄色 (位置1)
})
gradient.Color = colorSequence

-- 将渐变应用到Frame
gradient.Parent = _kuangFrame

Knit.OnStart():andThen(function()
	Knit.GetController("UIController").ShowNoticeUI:Connect(function(data)
		if _screenGui.Enabled then return end
		_screenGui.Enabled = true
		Knit.GetController("UIController").ShakeCarame:Fire({ShakeIntensity = 0.3, ShakeSpeed = 20, ShakeDuration = 0.6})
		_type = data.Type
		_redFrame.Visible = false
		_blueFrame.Visible = false
		if data.Type == 1 then
			_redFrame.Visible = true
			_redFrame:FindFirstChild("NameLabel").Text = data.Title or ""
			_redFrame:FindFirstChild("DescriptionLabel").Text = data.Text or ""
			
			local GAME = Interface.safeWaitPart(game:GetService("SoundService"), "GAME")
			local sound = Interface.safeWaitPart(GAME, "Warn")
			sound.Looped = false
			sound:Play()
			
			for i = 1, 5 do
				local fadeIn = TweenInterface.TweenNodeTransparencyFrame(_kuangFrame, 0.7, 0.1)
				fadeIn.Completed:Wait()

				local fadeOut = TweenInterface.TweenNodeTransparencyFrame(_kuangFrame, 1, 0.5)
				fadeOut.Completed:Wait()
			end
		else
			_blueFrame.Visible = true
			_blueFrame:FindFirstChild("NameLabel").Text = data.Title or ""
			_blueFrame:FindFirstChild("DescriptionLabel").Text = data.Text or ""
		end
		
		task.delay(3, function()
			_screenGui.Enabled = false
		end)
	end)
end)