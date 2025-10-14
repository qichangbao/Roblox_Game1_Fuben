--[[
	简化箭头导航使用示例
	展示如何使用SimpleArrowNavigation
	作者: AI Assistant
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 等待工具文件夹加载
local ToolFolder = ReplicatedStorage:WaitForChild("ToolFolder")

-- 导入简化导航接口
local SimpleArrowNavigation = require(ToolFolder:WaitForChild("SimpleArrowNavigation"))

local LocalPlayer = Players.LocalPlayer

--[[
	设置鼠标点击导航
]]
local function setupMouseNavigation()
	local mouse = LocalPlayer:GetMouse()
	
	mouse.Button1Down:Connect(function()
		-- 检查是否按住Ctrl键进行导航
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			if mouse.Hit then
				local targetPos = mouse.Hit.Position
				print("开始导航到:", targetPos)
				
				-- 显示箭头路径并启动自动清理和实时更新
				local success = SimpleArrowNavigation.NavigateTo(targetPos, nil, 5, true, 0.5)
				if success then
					print("箭头导航已创建（实时更新已启用）")
				else
					print("导航创建失败")
				end
			end
		end
	end)
end

--[[
	设置键盘快捷键
]]
local function setupKeyboardShortcuts()
	local realTimeUpdateEnabled = true -- 实时更新开关状态
	
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		local character = LocalPlayer.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then
			return
		end
		
		if input.KeyCode == Enum.KeyCode.G then
			-- G键: 导航到鼠标位置
			local mouse = LocalPlayer:GetMouse()
			if mouse.Hit then
				local targetPos = mouse.Hit.Position
				SimpleArrowNavigation.NavigateTo(targetPos, nil, 5, realTimeUpdateEnabled, 0.5)
				print("导航到鼠标位置:", targetPos, "实时更新:", realTimeUpdateEnabled and "开启" or "关闭")
			end
			
		elseif input.KeyCode == Enum.KeyCode.C then
			-- C键: 清理所有箭头
			SimpleArrowNavigation.ClearPath()
			print("已清理所有箭头")
			
		elseif input.KeyCode == Enum.KeyCode.T then
			-- T键: 测试导航（前方50格）
			local currentPos = character.HumanoidRootPart.Position
			local forwardDirection = character.HumanoidRootPart.CFrame.LookVector
			local testPos = currentPos + forwardDirection * 50
			
			SimpleArrowNavigation.NavigateTo(testPos, nil, 5, realTimeUpdateEnabled, 0.5)
			print("测试导航到前方50格，实时更新:", realTimeUpdateEnabled and "开启" or "关闭")
			
		elseif input.KeyCode == Enum.KeyCode.R then
			-- R键: 切换实时更新
			realTimeUpdateEnabled = not realTimeUpdateEnabled
			print("实时更新已", realTimeUpdateEnabled and "开启" or "关闭")
			
			-- 如果当前有导航，重新启动或停止实时更新
			if realTimeUpdateEnabled then
				print("提示: 下次导航将启用实时更新")
			else
				SimpleArrowNavigation.StopRealTimeUpdate()
				print("已停止当前实时更新")
			end
		end
	end)
end

--[[
	创建简单的UI界面
]]
local function createSimpleUI()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	
	-- 创建UI容器
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SimpleNavigationUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	
	-- 创建说明标签
	local instructionLabel = Instance.new("TextLabel")
	instructionLabel.Name = "InstructionLabel"
	instructionLabel.Size = UDim2.new(0, 350, 0, 120)
	instructionLabel.Position = UDim2.new(1, -370, 0, 20)
	instructionLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	instructionLabel.BackgroundTransparency = 0.3
	instructionLabel.BorderSizePixel = 0
	instructionLabel.Text = "箭头导航控制 (支持实时更新):\nCtrl+左键: 导航到点击位置\nG: 导航到鼠标位置\nC: 清理箭头\nT: 测试导航\nR: 切换实时更新"
	instructionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	instructionLabel.TextScaled = true
	instructionLabel.Font = Enum.Font.SourceSans
	instructionLabel.Parent = screenGui
	
	-- 添加圆角
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = instructionLabel
	
	-- 创建清理按钮
	local clearButton = Instance.new("TextButton")
	clearButton.Name = "ClearButton"
	clearButton.Size = UDim2.new(0, 100, 0, 40)
	clearButton.Position = UDim2.new(1, -120, 0, 140)
	clearButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	clearButton.Text = "清理箭头"
	clearButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	clearButton.TextScaled = true
	clearButton.Font = Enum.Font.SourceSansBold
	clearButton.Parent = screenGui
	
	local clearCorner = Instance.new("UICorner")
	clearCorner.CornerRadius = UDim.new(0, 5)
	clearCorner.Parent = clearButton
	
	-- 按钮事件
	clearButton.MouseButton1Click:Connect(function()
		SimpleArrowNavigation.ClearPath()
		print("手动清理箭头")
	end)
end

--[[
	主初始化函数
]]
local function main()
	-- 等待角色加载
	if not LocalPlayer.Character then
		LocalPlayer.CharacterAdded:Wait()
	end
	
	-- 设置鼠标导航
	setupMouseNavigation()
	
	-- 设置键盘快捷键
	setupKeyboardShortcuts()
	
	-- 创建简单UI
	createSimpleUI()
	
	-- 显示使用说明
	print("=== 简化箭头导航系统 (支持实时更新) ===")
	print("Ctrl+左键: 导航到点击位置（自动启用实时更新）")
	print("G: 导航到鼠标位置")
	print("C: 清理所有箭头")
	print("T: 测试导航（前方50格）")
	print("R: 切换实时更新开关")
	print("实时更新功能: 当玩家移动时自动重新计算箭头路径")
	print("=========================================")
	
	-- 暴露全局接口供调试使用
	_G.SimpleArrowNavigation = SimpleArrowNavigation
end

-- 启动系统
--main()