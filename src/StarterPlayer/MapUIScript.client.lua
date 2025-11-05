local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

-- 小地图配置参数
local MINIMAP_CONFIG = {
	-- 世界坐标范围 (根据实际地图大小调整)
	WORLD_SIZE = {
		["恐龙岛"] = {
			MIN_X = -660,
			MAX_X = 660,
			MIN_Z = -335,
			MAX_Z = 835,
		},
	},
	SMALL_SIZE = UDim2.new(0, 12, 0, 12),   -- 小地图图标大小
	BIG_SIZE = UDim2.new(0, 30, 0, 30),     -- 大地图图标大小
	ANCHOR_POINT = Vector2.new(0.5, 0.5),    -- 中心锚点

	-- 玩家图标配置
	PLAYER_ICON = {
		ME_IMAGE_ID = "rbxassetid://90941656719008",
		OTHER_IMAGE_ID = "rbxassetid://139656289934655",
		DEAD_IMAGE_ID = "rbxassetid://81155562919187",
		EVACUATION_IMAGE_ID = "rbxassetid://123301081984157",
	},
	-- npc图标配置
	NPC_ICON = {
		IMAGE_ID = "rbxassetid://132589050439123",
	},
	-- 地图标记配置
	MAP_FLAG_ICON = {
		JH_IMAGE_ID = "rbxassetid://90530174201898",
		WX_IMAGE_ID = "rbxassetid://103232461341010",
		WZ_IMAGE_ID = "rbxassetid://119128646137875",
	},
}

local _touchPos = Vector2.new(0, 0)
-- 玩家图标存储
local playerIcons = {}
local npcIcons = {}
-- circleImage: 光圈图片资源ID（建议使用白色圆环PNG，或自定义）
local circleImage = "rbxassetid://3926307971" -- 可替换为你的圆环图片ID

local _screenGui = script.Parent
_screenGui.Enabled = true
local _frame = _screenGui:WaitForChild("Frame")
local _bigMap = _frame:WaitForChild("BigMap")
local _titleImage = _bigMap:WaitForChild("TitleImage")
local _closeButton = _titleImage:WaitForChild("CloseButton")
_closeButton.MouseButton1Click:Connect(function()
	_bigMap.Visible = false
	_touchPos = Vector2.new(0, 0)
end)
local _map = _bigMap:WaitForChild("map")
local _bigImageLabel = _map:WaitForChild("ImageLabel")
local _buttonFrame = _bigImageLabel:WaitForChild("ButtonFrame")
_buttonFrame.Visible = false

local _smallMap = _frame:WaitForChild("SmallMap")
local _mapButton = _smallMap:WaitForChild("MapButton")
_mapButton.MouseButton1Down:Connect(function(x, y)
	_bigMap.Visible = true
	_buttonFrame.Visible = false
	_touchPos = Vector2.new(0, 0)
end)
local _smallImageLabel = _smallMap:WaitForChild("ImageLabel")
-- 开启剪裁，确保图片平移时视窗只显示可见区域
_smallMap.ClipsDescendants = true

-- 将屏幕点击坐标转换为ImageLabel图像的UV坐标，并在对应位置显示操作面板
-- @param x number 鼠标点击的屏幕X坐标（像素）
-- @param y number 鼠标点击的屏幕Y坐标（像素）
-- 说明：
--   1) 将屏幕坐标转换为相对于 _bigImageLabel 的本地坐标；
--   2) 归一化为UV(0~1)，保存到 _touchPos（便于网络同步/跨设备一致）；
--   3) 将 _buttonFrame 定位到该UV位置（父级改为 _imageLabel）。
local function placeMarkerOnImageFromScreenXY(x, y)
	local absPos = _bigImageLabel.AbsolutePosition
	local absSize = _bigImageLabel.AbsoluteSize

	-- 屏幕坐标 -> 考虑顶栏GuiInset后的视口坐标
	-- 优先使用 UserInputService:GetMouseLocation()，更稳定
	local mousePos = Vector2.new(x, y)
	if UserInputService then
		mousePos = UserInputService:GetMouseLocation()
	end
	local inset = GuiService:GetGuiInset()
	local viewportX = mousePos.X - inset.X
	local viewportY = mousePos.Y - inset.Y

	-- 视口坐标 -> 相对 _bigImageLabel 的本地像素坐标
	local localX = viewportX - absPos.X
	local localY = viewportY - absPos.Y

	-- 防止点击在图片外部，进行范围裁剪
	localX = math.clamp(localX, 0, absSize.X)
	localY = math.clamp(localY, 0, absSize.Y)

	-- 归一化为UV坐标（0~1）
	local uvX = absSize.X > 0 and (localX / absSize.X) or 0
	local uvY = absSize.Y > 0 and (localY / absSize.Y) or 0

	-- 保存为归一化坐标，便于其他客户端复用同一点
	_touchPos = Vector2.new(uvX, uvY)

	_buttonFrame.Position = UDim2.fromScale(uvX, uvY)
	_buttonFrame.Visible = true
end

local _textButton = _bigMap:WaitForChild("TextButton")
_textButton.MouseButton1Down:Connect(function(x, y)
	-- 将屏幕点击坐标转换为图片UV坐标，并在图片对应位置显示操作面板
	placeMarkerOnImageFromScreenXY(x, y)
end)

local jhBtn = _buttonFrame:WaitForChild("JHButton")
local wxBtn = _buttonFrame:WaitForChild("WXButton")
local wzBtn = _buttonFrame:WaitForChild("WZButton")
jhBtn.MouseButton1Down:Connect(function(x, y)
	_buttonFrame.Visible = false
	Knit.GetService("MapService"):ShowFlag(1, _touchPos):andThen(function()

	end)
end)
wxBtn.MouseButton1Down:Connect(function(x, y)
	_buttonFrame.Visible = false
	Knit.GetService("MapService"):ShowFlag(2, _touchPos):andThen(function()

	end)
end)
wzBtn.MouseButton1Down:Connect(function(x, y)
	_buttonFrame.Visible = false
	Knit.GetService("MapService"):ShowFlag(3, _touchPos):andThen(function()

	end)
end)

-- 在icon上添加光圈特效，播放3次
local function playCircleEffect(icon)
	local circle = Instance.new("ImageLabel")
	circle.Name = "CircleEffect"
	circle.Image = circleImage
	circle.BackgroundTransparency = 1
	circle.AnchorPoint = icon.AnchorPoint
	circle.Position = icon.Position
	circle.Size = UDim2.new(0, icon.Size.X.Offset * 10, 0, icon.Size.Y.Offset * 10)
	circle.ZIndex = icon.ZIndex + 1
	circle.ImageTransparency = 0
	circle.Parent = icon.Parent

	for i = 1, 3 do
		circle.Size = UDim2.new(0, icon.Size.X.Offset * 10, 0, icon.Size.Y.Offset * 10)
		-- 动画目标：缩小到icon大小，逐渐透明
		local tween = TweenService:Create(circle, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = icon.Size,
			ImageTransparency = 0
		})

		tween:Play()
		tween.Completed:Wait()
		task.wait(0.05)
	end
	circle:Destroy()
end

-- 世界坐标到小地图坐标转换函数
-- @param worldPosition Vector3 世界坐标位置
-- @return UDim2 小地图上的UI坐标
local function worldToMapPosition(worldPosition)
	local worldSize = MINIMAP_CONFIG.WORLD_SIZE[_G.ClientData.IslandName]

	-- 计算相对位置 (0-1范围)
	local relativeX = (worldPosition.X - worldSize.MIN_X) / (worldSize.MAX_X - worldSize.MIN_X)
	local relativeZ = (worldPosition.Z - worldSize.MIN_Z) / (worldSize.MAX_Z - worldSize.MIN_Z)

	-- 限制在0-1范围内
	relativeX = math.clamp(relativeX, 0, 1)
	relativeZ = math.clamp(relativeZ, 0, 1)

	-- 转换为UI坐标 (Z轴对应Y轴，需要翻转)
	return UDim2.new(relativeX, 0, 1 - relativeZ, 0)
end

-- 将小地图图片居中到给定世界坐标（以本地玩家为中心）
-- @param worldPosition Vector3 世界坐标位置
-- 说明：
--   - 计算玩家在整张地图图片中的相对位置（0~1）
--   - 将 _smallImageLabel 以像素偏移移动，使该位置位于 _smallMap 的中心
--   - 支持缩放系数 SMALL_MAP_ZOOM，并进行边界夹紧，避免空白溢出
--   - X轴按小地图贴图方向进行翻转，保证左右与贴图一致
local function centerSmallMapOnWorldPosition(worldPosition)
	local worldSize = MINIMAP_CONFIG.WORLD_SIZE[_G.ClientData.IslandName]
	local relativeX = (worldPosition.X - worldSize.MIN_X) / (worldSize.MAX_X - worldSize.MIN_X)
	local relativeZ = (worldPosition.Z - worldSize.MIN_Z) / (worldSize.MAX_Z - worldSize.MIN_Z)

	-- 限制在0-1范围内
	relativeX = math.clamp(relativeX, 0, 1)
	relativeZ = math.clamp(relativeZ, 0, 1)

	-- 计算图片与视窗的像素尺寸
	local viewportSize = _smallMap.AbsoluteSize
	local zoom = MINIMAP_CONFIG.SMALL_MAP_ZOOM or 2.0
	local imageWidth = viewportSize.X * zoom
	local imageHeight = viewportSize.Y * zoom

	-- 确认小地图图片尺寸与锚点，用于像素偏移
	_smallImageLabel.AnchorPoint = Vector2.new(0, 0)
	_smallImageLabel.Size = UDim2.fromOffset(imageWidth, imageHeight)

	-- 玩家在图片中的像素坐标（Y轴翻转；X轴翻转修正）
	local playerPX = (1 - relativeX) * imageWidth
	local playerPY = (1 - relativeZ) * imageHeight

	-- 使玩家位于视窗中心：左上角偏移 = 视窗中心 - 玩家像素位置
	local desiredOffsetX = viewportSize.X * 0.5 - playerPX
	local desiredOffsetY = viewportSize.Y * 0.5 - playerPY

	-- 边界夹紧：图片必须覆盖整个视窗
	local minOffsetX = viewportSize.X - imageWidth
	local minOffsetY = viewportSize.Y - imageHeight
	local offsetX = math.clamp(desiredOffsetX, minOffsetX, 0)
	local offsetY = math.clamp(desiredOffsetY, minOffsetY, 0)

	_smallImageLabel.Position = UDim2.fromOffset(offsetX, offsetY)
end

-- 创建玩家图标
-- @param player Player 玩家对象
-- @param mapFrame Frame 小地图框架
-- @return ImageLabel 创建的图标
local function createPlayerIcon(player, mapFrame)
	local icon = Instance.new("ImageLabel")
	icon.Name = "PlayerIcon_" .. player.Name
	icon.Image = player == Players.LocalPlayer and MINIMAP_CONFIG.PLAYER_ICON.ME_IMAGE_ID or MINIMAP_CONFIG.PLAYER_ICON.OTHER_IMAGE_ID
	local isSmall = (mapFrame == _smallImageLabel) or (mapFrame == _smallMap)
	icon.Size = isSmall and MINIMAP_CONFIG.SMALL_SIZE or MINIMAP_CONFIG.BIG_SIZE
	icon.AnchorPoint = MINIMAP_CONFIG.ANCHOR_POINT
	icon.BackgroundTransparency = 1
	icon.Parent = mapFrame

	return icon
end

-- 创建玩家图标
-- @param player Player 玩家对象
-- @param mapFrame Frame 小地图框架
-- @return ImageLabel 创建的图标
local function createNPCIcon(npc, mapFrame)
	local icon = Instance.new("ImageLabel")
	icon.Name = "NPCIcon_" .. npc.Name
	icon.Image = MINIMAP_CONFIG.NPC_ICON.IMAGE_ID
	icon.Size = (mapFrame == _smallImageLabel) and MINIMAP_CONFIG.SMALL_SIZE or MINIMAP_CONFIG.BIG_SIZE
	icon.AnchorPoint = MINIMAP_CONFIG.ANCHOR_POINT
	icon.BackgroundTransparency = 1
	icon.Parent = mapFrame

	return icon
end

-- 在地图上创建标记图标（大图与小图）
-- @param type number 地图标记类型（集合/危险/物资）
-- @param position Vector2 标记的UV坐标（0~1，基于ImageLabel图像）
local function createMapFlag(type, position)
	local iconBig = Instance.new("ImageLabel")
	iconBig.Name = type
	iconBig.Size = MINIMAP_CONFIG.BIG_SIZE
	iconBig.AnchorPoint = MINIMAP_CONFIG.ANCHOR_POINT
	iconBig.BackgroundTransparency = 1
	iconBig.Parent = _bigImageLabel
	local image = nil
	if type == GameConfig.MapFlagType.JiHe then
		image = MINIMAP_CONFIG.MAP_FLAG_ICON.JH_IMAGE_ID
	elseif type == GameConfig.MapFlagType.WeiXian then
		image = MINIMAP_CONFIG.MAP_FLAG_ICON.WX_IMAGE_ID
	elseif type == GameConfig.MapFlagType.WuZi then
		image = MINIMAP_CONFIG.MAP_FLAG_ICON.WZ_IMAGE_ID
	end
	iconBig.Image = image

	-- 使用传入的UV坐标（若未传入则回退到当前_touchPos）
	local uv = position or _touchPos
	iconBig.Position = UDim2.fromScale(uv.X, uv.Y)

	playCircleEffect(iconBig)

	local iconSmall = Instance.new("ImageLabel")
	iconSmall.Name = type
	iconSmall.Size = MINIMAP_CONFIG.SMALL_SIZE
	iconSmall.AnchorPoint = MINIMAP_CONFIG.ANCHOR_POINT
	iconSmall.BackgroundTransparency = 1
	iconSmall.Parent = _smallImageLabel
	iconSmall.Image = image
	-- 小地图上根据同一UV定位
	iconSmall.Position = UDim2.fromScale(uv.X, uv.Y)

	playCircleEffect(iconSmall)
end

-- 更新玩家图标位置和朝向
-- @param player Player 玩家对象
-- @param icon ImageLabel 玩家图标
-- @param mapFrame Frame 小地图框架
-- 说明：
--   - 小地图模式下，X轴按贴图方向翻转，修正左右反向问题
local function updatePlayerIcon(player, icon, mapFrame)
	local character = player.Character
	if not character then
		icon.Visible = false
		return
	end
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		icon.Visible = false
		return
	end

	icon.Visible = true

	-- 更新位置
	local worldPosition = humanoidRootPart.Position
	if mapFrame == _smallMap then
		-- 小地图：根据世界坐标平移图片，并将箭头放在真实视窗位置（边缘不强制居中）
		centerSmallMapOnWorldPosition(worldPosition)

		-- 计算玩家在整张图片中的像素位置
		local worldSize = MINIMAP_CONFIG.WORLD_SIZE[_G.ClientData.IslandName]
		local relativeX = (worldPosition.X - worldSize.MIN_X) / (worldSize.MAX_X - worldSize.MIN_X)
		local relativeZ = (worldPosition.Z - worldSize.MIN_Z) / (worldSize.MAX_Z - worldSize.MIN_Z)
		relativeX = math.clamp(relativeX, 0, 1)
		relativeZ = math.clamp(relativeZ, 0, 1)

		local viewportSize = _smallMap.AbsoluteSize
		local imageSize = _smallImageLabel.AbsoluteSize
		local offsetX = _smallImageLabel.Position.X.Offset
		local offsetY = _smallImageLabel.Position.Y.Offset

		local playerPX = (1 - relativeX) * imageSize.X
		local playerPY = (1 - relativeZ) * imageSize.Y

		-- 转为视窗中的归一化坐标（0~1），并裁剪到范围内
		local ux = (offsetX + playerPX) / viewportSize.X
		local uy = (offsetY + playerPY) / viewportSize.Y
		ux = math.clamp(ux, 0, 1)
		uy = math.clamp(uy, 0, 1)

		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.new(ux, 0, uy, 0)
	else
		-- 大地图或挂在图片上的图标：使用世界坐标映射
		icon.Position = worldToMapPosition(worldPosition)
	end

	-- 更新朝向 (将3D朝向转换为2D旋转角度)
	local lookDirection = humanoidRootPart.CFrame.LookVector
	local rotationAngle = math.atan2(-lookDirection.X, lookDirection.Z)
	icon.Rotation = math.deg(rotationAngle)
end

-- 更新NPC图标位置和朝向
-- @param npc Model NPC对象
-- @param icon ImageLabel NPC图标
-- @param mapFrame Frame 小地图框架
local function updateNPCIcon(npc, icon, mapFrame)
	if not npc then
		icon.Visible = false
		return
	end

	icon.Visible = true

	-- 更新位置
	local worldPosition = npc:getPivot().Position
	icon.Position = worldToMapPosition(worldPosition)
end

Knit.OnStart():andThen(function()
	local island = Interface.safeWaitPart(workspace, _G.ClientData.IslandName)
	local Special = Interface.safeWaitPart(island, "Special")
	local NPC = Interface.safeWaitPart(Special, "NPC")
	for _, npc in pairs(NPC:GetChildren()) do
		if not npcIcons[npc] then
			npcIcons[npc] = {}
			npcIcons[npc].small = createNPCIcon(npc, _smallImageLabel)
			npcIcons[npc].big = createNPCIcon(npc, _bigImageLabel)
		end
	end

	Knit.GetController("UIController").SuccEvacuation:Connect(function(userId)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local image = MINIMAP_CONFIG.PLAYER_ICON.EVACUATION_IMAGE_ID
			playerIcons[player].small.Image = image
			playerIcons[player].big.Image = image
		end
	end)

	Knit.GetController("UIController").ShowMapFlag:Connect(function(data)
		createMapFlag(data.Type, data.Position)
	end)

	-- 主更新循环
	RunService.Heartbeat:Connect(function(dt)
		for i, player in pairs(Players:GetPlayers()) do
			-- 确保玩家有图标
			if not playerIcons[player] then
				continue
			end

			-- 更新图标位置和朝向
			local smallFrame = (player == Players.LocalPlayer) and _smallMap or _smallImageLabel
			updatePlayerIcon(player, playerIcons[player].small, smallFrame)
			updatePlayerIcon(player, playerIcons[player].big, _bigImageLabel)
		end
	end)

	local function playerAdded(player)
		-- 确保玩家有图标
		if not playerIcons[player] then
			playerIcons[player] = {}
			playerIcons[player].small = createPlayerIcon(player, (player == Players.LocalPlayer) and _smallMap or _smallImageLabel)
			playerIcons[player].big = createPlayerIcon(player, _bigImageLabel)
		end

		local function characterAdded(character)
			local image = player == Players.LocalPlayer and MINIMAP_CONFIG.PLAYER_ICON.ME_IMAGE_ID or MINIMAP_CONFIG.PLAYER_ICON.OTHER_IMAGE_ID
			playerIcons[player].small.Image = image
			playerIcons[player].big.Image = image

			local Humanoid = character:FindFirstChildOfClass("Humanoid")
			if Humanoid then
				Humanoid.Died:Connect(function()
					local image = MINIMAP_CONFIG.PLAYER_ICON.DEAD_IMAGE_ID
					playerIcons[player].small.Image = image
					playerIcons[player].big.Image = image
				end)
			end
		end

		if player.Character then
			characterAdded(player.Character)
		end

		player.CharacterAdded:Connect(function(character)
			characterAdded(character)
		end)
	end

	for i, player in pairs(Players:GetPlayers()) do
		playerAdded(player)
	end

	Players.PlayerAdded:Connect(function(player)
		playerAdded(player)
	end)

	-- 处理玩家离开时的清理
	Players.PlayerRemoving:Connect(function(player)
		if playerIcons[player] then
			playerIcons[player].small:Destroy()
			playerIcons[player].big:Destroy()
			playerIcons[player] = nil
		end
	end)
end)