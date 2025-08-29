--require(game:GetService('StarterPlayer'):WaitForChild("StarterPlayerScripts"):WaitForChild("ClientData"))

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

local loadingUI = require(game.StarterGui:WaitForChild("LoadingUI"))

-- 显示加载界面（不自动隐藏）
loadingUI.Show()
loadingUI.UpdateText("Waiting for server startup...")

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
        loadingUI.UpdateText("Server startup completed")
        -- 等待0.5秒后隐藏加载界面
        task.wait(0.5)
        loadingUI.Hide()
    else
        print("服务器尚未启动完成，继续等待...")
        loadingUI.UpdateText("Server startup in progress...")
        -- 等待1秒后重新查询
        task.wait(1)
        checkServerStartStatus()
    end
end)

-- 开始检查服务器启动状态
checkServerStartStatus()

-- ========== Workspace组件加载检测 ==========

local IsClientWorkspaceLoadedOver = false
-- 检测workspace中所有组件是否加载完成
-- @return void
local function checkWorkspaceLoaded()
    local workspace = game:GetService("Workspace")
    
    -- 等待基本组件加载
    local function waitForBasicComponents()
        -- 等待地形加载
        local terrain = workspace:WaitForChild("Terrain")
        if not terrain then
            warn("地形加载超时")
            return false
        end
        
        -- 等待相机加载
        local camera = workspace:WaitForChild("Camera")
        if not camera then
            warn("相机加载超时")
            return false
        end
        
        print("基本workspace组件已加载")
        return true
    end
    
    -- 检查所有子对象是否完全加载
    -- @param parent Instance 要检查的父对象
    -- @param depth number 递归深度（防止无限递归）
    -- @return boolean 是否所有子对象都已加载
    local function checkAllChildrenLoaded(parent, depth)
        depth = depth or 0
        if depth > 10 then -- 限制递归深度
            return true
        end
        
        for _, child in pairs(parent:GetChildren()) do
            -- 检查子对象是否为模型或文件夹类型
            if child:IsA("Model") or child:IsA("Folder") then
                -- 递归检查子对象
                if not checkAllChildrenLoaded(child, depth + 1) then
                    return false
                end
            end
            
            -- 检查是否有正在加载的内容
            if child:IsA("MeshPart") or child:IsA("Part") then
                -- 等待网格和纹理加载
                if child:IsA("MeshPart") and child.MeshId ~= "" then
                    -- 检查网格是否加载完成
                    local contentProvider = game:GetService("ContentProvider")
                    local success, errorMessage = pcall(function()
                        contentProvider:PreloadAsync({child})
                    end)
                    if not success then
                        warn(string.format("预加载失败 %s: %s", child.Name, tostring(errorMessage)))
                        -- 不返回false，继续检查其他组件
                    end
                end
            end
        end
        
        return true
    end
    
    -- 等待workspace完全加载的主函数
    -- @return void
    local function waitForWorkspaceComplete()
        print("开始检测workspace组件加载状态...")
        
        -- 等待基本组件
        local basicComponentsLoaded = waitForBasicComponents()
        if not basicComponentsLoaded then
            warn("基本组件加载失败，跳过详细检测")
            IsClientWorkspaceLoadedOver = true
            return
        end
        
        -- 等待所有子对象加载完成
        local maxAttempts = 30 -- 最大尝试次数
        local attempts = 0
        
        while attempts < maxAttempts do
            attempts = attempts + 1
            
            if checkAllChildrenLoaded(workspace) then
                print("Workspace所有组件已加载完成！")
                break
            else
                print(string.format("Workspace组件加载中... (尝试 %d/%d)", attempts, maxAttempts))
                task.wait(0.5) -- 等待0.5秒后重新检查
            end
        end
        
        if attempts >= maxAttempts then
            warn("Workspace组件加载检测超时，但继续执行游戏")
        end
        
        IsClientWorkspaceLoadedOver = true
        print("Workspace加载检测完成，游戏可以正常进行")
    end
    
    -- 在新线程中执行检测，避免阻塞主线程
    task.spawn(waitForWorkspaceComplete)
end

-- 启动workspace组件加载检测
checkWorkspaceLoaded()



-- ========== 玩家位置显示系统 ==========

--[[
    创建并管理玩家位置显示UI
    实时显示玩家在世界中的坐标位置
]]
local function createPositionDisplay()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
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
	local RunService = game:GetService("RunService")
	local player = Players.LocalPlayer

	-- 等待角色加载
	local function waitForCharacter()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
		return humanoidRootPart
	end

	-- 位置更新连接
	local connection

	-- 角色重生处理
	local function onCharacterAdded(character)
		if connection then
			connection:Disconnect()
		end

		local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

		-- 创建位置更新循环
		connection = RunService.Heartbeat:Connect(function()
			if humanoidRootPart and humanoidRootPart.Parent then
				local position = humanoidRootPart.Position
				positionLabel.Text = string.format(
					"X: %.1f\nY: %.1f\nZ: %.1f",
					position.X,
					position.Y - 3,
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
	-- 等待PlayerGui加载
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- 创建位置显示UI
	local positionLabel = createPositionDisplay()

	-- 开始更新位置
	updatePositionDisplay(positionLabel)

	print("[位置显示] 玩家位置显示系统已启动")
end

-- 启动位置显示系统
initializePositionDisplay()

local StarterGui = game:GetService("StarterGui")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)