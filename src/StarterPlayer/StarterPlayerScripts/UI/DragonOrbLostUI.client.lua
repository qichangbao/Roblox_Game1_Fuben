local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local TweenInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))

local _screenGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("DragonOrbLostUI")
_screenGui.Enabled = false
local _frame = _screenGui:WaitForChild("Frame")
local _kuangFrame = _frame:WaitForChild("KuangFrame")
local GAME = Interface.safeWaitPart(game:GetService("SoundService"), "GAME")

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
	Knit.GetController("UIController").ShowDragonOrbLostUI:Connect(function()
		if _screenGui.Enabled then return end
		Knit.GetController("UIController").ShakeCarame:Fire({ShakeIntensity = 0.3, ShakeSpeed = 20, ShakeDuration = 0.6})
		
		_screenGui.Enabled = true
		TweenInterface.AnimateUIShowScale(_frame)
		local sound = Interface.safeWaitPart(GAME, "Warn")
		sound.Looped = false
		sound:Play()
		sound.Ended:Connect(function()
			local BackMusic = Interface.safeWaitPart(GAME, "BackMusic1")
			BackMusic:Stop()
			BackMusic = Interface.safeWaitPart(GAME, "BackMusic2")
			BackMusic.Looped = true
			BackMusic:Play()
		end)
		
		for _ = 1, 5 do
			local fadeIn = TweenInterface.TweenNodeTransparencyFrame(_kuangFrame, 0.7, 0.1)
			fadeIn.Completed:Wait()

			local fadeOut = TweenInterface.TweenNodeTransparencyFrame(_kuangFrame, 1, 0.5)
			fadeOut.Completed:Wait()
		end
		_screenGui.Enabled = false
	end)
end)