--require(game:GetService('StarterPlayer'):WaitForChild("StarterPlayerScripts"):WaitForChild("ClientData"))

-- 禁用自动本地化功能，防止UI文本被自动翻译
local GuiService = game:GetService("GuiService")
pcall(function()
    GuiService.AutoLocalize = false
end)

-- -- 禁用滚轮缩放
-- local contextActionService = game:GetService('ContextActionService')
-- contextActionService:BindAction("BlockZoom",
--     function()
--         return Enum.ContextActionResult.Sink
--     end,
--     false,
--     Enum.UserInputType.MouseWheel
-- )

-- local camera = game.Workspace.CurrentCamera
-- local function onCharacterAdded(character)
--     local humanoid = character:WaitForChild("Humanoid")
--     -- 玩家坐下时，相机会拉远与玩家的距离，因此需要在玩家坐下时，将相机会拉远与玩家的距离恢复到初始值
--     humanoid.Seated:Connect(function(isSeated, seat)
--         camera.CameraSubject = humanoid
--     end)
-- end

-- local localPlayer = game.Players.LocalPlayer
-- if localPlayer.Character then
--     onCharacterAdded(localPlayer.Character)
-- else
--     localPlayer.CharacterAdded:Connect(function(character)
--         onCharacterAdded(character)
--     end)
-- end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
-- 初始化Knit框架
local Knit = require(ReplicatedStorage:WaitForChild('Packages'):WaitForChild('Knit'):waitForChild('Knit'))
Knit.AddControllers(script.Parent:WaitForChild('ControllersFolder'))
-- local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

-- local playerGui = Interface.safeWaitPart(game.Players.LocalPlayer, "PlayerGui")
-- local loadingUI = Interface.safeWaitPart(playerGui, "LoadingUI")
-- loadingUI.Enabled = true

_G.ClientData = require(game.Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("ClientData"))

-- 等待RemoteEvent创建
local isServerStartOverEvent = ReplicatedStorage:WaitForChild("IsServerStartOver")

-- 向服务器发送启动状态查询
-- @return void
local function checkServerStartStatus()
    print("向服务器发送启动状态查询...")
    isServerStartOverEvent:FireServer()
end

-- 处理服务器返回的启动状态
-- @param isStarted boolean 服务器是否已启动完成
isServerStartOverEvent.OnClientEvent:Connect(function(isStarted)
    if isStarted then
        print("服务器已启动完成！")
        
        -- 通知KnitInit服务器已启动完成
        local success, KnitInitClient = pcall(function()
            return require(script.Parent:WaitForChild("KnitInitClient"))
        end)
        
        if success and KnitInitClient then
            print("通知KnitInit执行监听器")
            KnitInitClient.executePendingListeners()
        else
            warn("KnitInitClient执行失败")
        end
    else
        print("服务器尚未启动完成，继续等待...")
        -- 等待1秒后重新查询
        task.wait(1)
        checkServerStartStatus()
    end
end)

Knit.Start():andThen(function()
    -- 开始检查服务器启动状态
    checkServerStartStatus()
end):catch(warn)

-- ========== 玩家位置显示系统 ==========

--[[
    创建并管理玩家位置显示UI
    实时显示玩家在世界中的坐标位置
]]
local function createPositionDisplay()
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- 创建ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PositionDisplay"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- 创建主框架
	local frame = Instance.new("Frame")
	frame.Name = "PositionFrame"
	frame.Size = UDim2.new(0, 250, 0, 100)
	frame.Position = UDim2.new(0, 10, 0, 10)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	-- 添加圆角
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

    local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
	-- 创建标题标签
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 25)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "玩家位置"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.FontFace = GameConfig.FontFace
	titleLabel.Parent = frame

	-- 创建位置标签
	local positionLabel = Instance.new("TextLabel")
	positionLabel.Name = "PositionLabel"
	positionLabel.Size = UDim2.new(1, -10, 1, -30)
	positionLabel.Position = UDim2.new(0, 5, 0, 25)
	positionLabel.BackgroundTransparency = 1
	positionLabel.Text = "X: 0\nY: 0\nZ: 0"
	positionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	positionLabel.TextScaled = true
	positionLabel.FontFace = GameConfig.FontFace
	positionLabel.TextXAlignment = Enum.TextXAlignment.Left
	positionLabel.TextYAlignment = Enum.TextYAlignment.Top
	positionLabel.Parent = frame

	return positionLabel
end

--[[
    更新玩家位置显示
    @param positionLabel TextLabel - 显示位置的标签
]]
local function updatePositionDisplay(positionLabel)
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer

	-- 位置更新连接
	local connection

	-- 角色重生处理
	local function onCharacterAdded(character)
		if connection then
			connection:Disconnect()
		end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChild("Humanoid")

		-- 创建位置更新循环
		connection = RunService.Heartbeat:Connect(function()
			if humanoidRootPart and humanoidRootPart.Parent and humanoid then
				local position = humanoidRootPart.Position
				positionLabel.Text = string.format(
					"X: %.2f\nY: %.2f\nZ: %.2f",
					position.X,
					position.Y - humanoid.HipHeight - humanoidRootPart.Size.Y / 2,
					position.Z
				)
			end
		end)
	end

	-- 监听角色重生
	player.CharacterAdded:Connect(onCharacterAdded)

	-- 如果角色已存在，立即开始更新
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

--[[
    初始化玩家位置显示系统
]]
local function initializePositionDisplay()
	-- 创建位置显示UI
	local positionLabel = createPositionDisplay()
	-- 开始更新位置
	updatePositionDisplay(positionLabel)

	print("[位置显示] 玩家位置显示系统已启动")
end

if RunService:IsStudio() then
	-- 启动位置显示系统
	initializePositionDisplay()
end

local StarterGui = game:GetService("StarterGui")
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)