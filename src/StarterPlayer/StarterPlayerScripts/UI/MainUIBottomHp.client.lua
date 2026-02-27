local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local TweenInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local _frame = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainUI"):WaitForChild("bottom"):WaitForChild("HpFrame")
_frame.Visible = false
local _maskFrame = _frame:WaitForChild("Frame")
local _whiteFrame = _frame:WaitForChild("WhiteFrame")
local _oriSizeX = _maskFrame.Size.X.Scale
local _whiteTween = nil
local _maskTween = nil

local function fadeIn()
	if _frame.Visible then
		return
	end

	_frame.Visible = true
	_frame.BackgroundTransparency = 1
	_maskFrame.BackgroundTransparency = 1
	_whiteFrame.BackgroundTransparency = 1
	TweenInterface.TweenNodeTransparencyFrame(_frame, 0, 0.5)
	TweenInterface.TweenNodeTransparencyFrame(_whiteFrame, 0, 0.5)
	TweenInterface.TweenNodeTransparencyFrame(_maskFrame, 0, 0.5)
end

local function fadeOut()
	if not _frame.Visible then
		return
	end

	_whiteFrame.Visible = false
	TweenInterface.TweenNodeTransparencyFrame(_frame, 1, 0.5, function()
		_frame.Visible = false
	end)
	TweenInterface.TweenNodeTransparencyFrame(_maskFrame, 1, 0.5)
end

--[[
    监听本地玩家 Humanoid 的 Endurance 属性变化
    行为：
    - 角色生成时找到 Humanoid
    - 属性变化时更新耐力条 UI
    返回：void
]]
local function InitLocalEnduranceListener()
	local function onCharacter(character)
		_whiteFrame.Size = UDim2.new(_oriSizeX, 0, _whiteFrame.Size.Y.Scale, _whiteFrame.Size.Y.Offset)
		_maskFrame.Size = UDim2.new(_oriSizeX, 0, _maskFrame.Size.Y.Scale, _maskFrame.Size.Y.Offset)
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
		if humanoid then
			-- 初始化一次
			humanoid.HealthChanged:Connect(function(newHealth)
				if newHealth ~= humanoid.MaxHealth then
					fadeIn()
				else
					task.delay(1, function()
						if humanoid.Health >= humanoid.MaxHealth then
							fadeOut()
						end
					end)
				end
				_whiteFrame.Visible = true
				local newScale = newHealth / humanoid.MaxHealth * _oriSizeX
				if _whiteTween then
					_whiteTween:Cancel()
					_whiteTween = nil
				end
				_whiteTween = TweenInterface.TweenProgressBarSize(_whiteFrame, newScale, 1)
				if _maskTween then
					_maskTween:Cancel()
					_maskTween = nil
				end
				_maskTween = TweenInterface.TweenProgressBarSize(_maskFrame, newScale, 0.35)
			end)
		end
	end

	if localPlayer.Character then
		onCharacter(localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(onCharacter)
end

-- 初始化本地监听
InitLocalEnduranceListener()