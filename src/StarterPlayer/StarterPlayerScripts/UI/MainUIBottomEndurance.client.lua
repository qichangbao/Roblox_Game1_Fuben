local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local TweenInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))
local PlayerAttribute = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("PlayerAttribute"))

local _frame = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainUI"):WaitForChild("bottom"):WaitForChild("EnduranceFrame")
_frame.Visible = false
local _maskFrame = _frame:WaitForChild("Frame")
local _oriSizeX = _maskFrame.Size.Width.Scale

-- 耐力配置
local _maxEndurance = GameConfig.PlayerInitAttribute.Endurance        -- 满耐力
local _minEnderance = 0       -- 空耐力
local _enduranceConsume = GameConfig.PlayerInitAttribute.EnduranceConsume
local _enduranceRecovery = GameConfig.PlayerInitAttribute.EnduranceRecovery

-- 当前耐力值（0~1）
local _staminaValue = _maxEndurance
-- 是否奔跑
local _isRun = false
-- 更新连接
local _staminaConn = nil
-- 记录 Y 轴 Size，保持不变
local _enduranceSizeY = _maskFrame.Size.Y

local function fadeIn()
	if _frame.Visible then
		return
	end
	
	_frame.Visible = true
	_frame.BackgroundTransparency = 1
	_maskFrame.BackgroundTransparency = 1
	TweenInterface.TweenNodeTransparencyFrame(_frame, 0, 0.5)
	TweenInterface.TweenNodeTransparencyFrame(_maskFrame, 0, 0.5)
end

local function fadeOut()
	if not _frame.Visible then
		return
	end
	
	TweenInterface.TweenNodeTransparencyFrame(_frame, 1, 0.5, function()
		_frame.Visible = false
	end)
	TweenInterface.TweenNodeTransparencyFrame(_maskFrame, 1, 0.5)
end

--[[
    设置耐力值并同步到耐力条 UI
    行为：
    - 将耐力值限制在 [0,1] 范围内
    - 更新 _enduranceFrame.Size.X.Scale
    返回：void
]]
local function SetStaminaValue(value)
	_staminaValue = math.clamp(value, _minEnderance, _maxEndurance)
	_maskFrame.Size = UDim2.new(_staminaValue / _maxEndurance * _oriSizeX, 0, _enduranceSizeY.Scale, _enduranceSizeY.Offset)
end

--[[
    启动耐力更新循环
    行为：
    - 使用 RenderStepped，根据 dt 线性消耗/恢复耐力
    - 按住 Shift：10 秒从 1 掉到 0
    - 松开 Shift：10 秒从 0 回到 1
    返回：void
]]
local function StartStaminaLoop()
	if _staminaConn then
		return
	end

	_staminaConn = RunService.RenderStepped:Connect(function(dt)
		if not localPlayer.Character then
			_frame.Visible = false
			return
		end
		local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		local moveDirection = humanoid.MoveDirection
		local rootPart = localPlayer.Character:FindFirstChild("HumanoidRootPart")
		local velocityMag = rootPart and rootPart.AssemblyLinearVelocity.Magnitude or 0
		local state = humanoid:GetState()
		local isSwimming = state == Enum.HumanoidStateType.Swimming
		local isActuallyMoving
		if isSwimming then
			isActuallyMoving = velocityMag > 0.5
		else
			isActuallyMoving = moveDirection.Magnitude > 0.1
		end
		if _isRun then
			fadeIn()
			if isActuallyMoving and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Swimming) then
				if _staminaValue > _minEnderance then
					local delta = dt * _enduranceConsume
					SetStaminaValue(_staminaValue - delta)
					return
				else
					_isRun = false
					Knit.GetService("PlayerService"):SwitchWalkOrRun(0)
				end
			end
		end
		
		if _staminaValue >= _maxEndurance then
			fadeOut()
			return
		end
		local delta = dt * _enduranceRecovery
		SetStaminaValue(_staminaValue + delta)
	end)
end

--[[
    初始化 Shift 键监听与耐力系统
    行为：
    - 监听 Shift 按下与松开
    - 按下时开始消耗耐力，松开时开始恢复
    - 启动耐力更新循环
    返回：void
]]
local function InitShiftAndEndurance()
	-- 初始耐力为满
	SetStaminaValue(_maxEndurance)
	-- 启动更新循环
	StartStaminaLoop()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			_isRun = true
			Knit.GetService("PlayerService"):SwitchWalkOrRun(1)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			_isRun = false
			Knit.GetService("PlayerService"):SwitchWalkOrRun(0)
		end
	end)
end

-- 在合适位置调用初始化（确保 _enduranceFrame 已经赋值）
InitShiftAndEndurance()

--[[
    监听本地玩家的Endurance 属性变化
    行为：
    - 绑定 Endurance 属性变化事件
    返回：void
]]
local function InitLocalEnduranceListener()
	local function onCharacter(character)
		-- 初始化一次
		_maxEndurance = PlayerAttribute.GetEndurance(localPlayer)
		_staminaValue = _maxEndurance
		_enduranceConsume = PlayerAttribute:GetEnduranceConsume(localPlayer)
		_enduranceRecovery = PlayerAttribute.GetEnduranceRecovery(localPlayer)
		_maskFrame.Size = UDim2.new(_oriSizeX, 0, _maskFrame.Size.Y.Scale, _maskFrame.Size.Y.Offset)
	end

	if localPlayer.Character then
		onCharacter(localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(onCharacter)
end

-- 初始化本地监听
InitLocalEnduranceListener()

Knit.OnStart():andThen(function()
	Knit.GetController("UIController").SwitchRun:Connect(function(isRun)
		if isRun then
			_isRun = true
			Knit.GetService("PlayerService"):SwitchWalkOrRun(1)
		else
			_isRun = false
			Knit.GetService("PlayerService"):SwitchWalkOrRun(0)
		end
	end)
end)
