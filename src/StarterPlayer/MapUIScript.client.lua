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
	-- 贴图方向配置：用于适配不同地图贴图的左右/上下方向
	-- FLIP_X=true 表示贴图X轴方向与世界X相反（需要取 1-rx）
	-- FLIP_Z=true 表示贴图Y(对应世界Z)方向与世界Z相反（需要取 1-rz）
	ORIENTATION = {
		-- 支持 FLIP_X/FLIP_Z 与 ROTATE_DEG(0/90/180/270)
		-- 校准：X轴翻转（世界X右→贴图内容左），Z轴翻转，旋转0°
		["恐龙岛"] = { FLIP_X = true, FLIP_Z = true, ROTATE_DEG = 0 },
	},
	SMALL_SIZE = UDim2.new(0, 12, 0, 12),   -- 小地图图标大小
	BIG_SIZE = UDim2.new(0, 30, 0, 30),     -- 大地图图标大小
	ANCHOR_POINT = Vector2.new(0.5, 0.5),    -- 中心锚点

	-- 大地图原始图片像素尺寸（用于按原图大小显示与缩放）
	-- 若与实际贴图不一致，请按图片像素宽高调整
	BIGMAP_IMAGE_SIZE = Vector2.new(1610, 1445),

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
	-- 光圈图标配置
	CIRCLE_ICON = "rbxassetid://122980088024715",

	-- 调试输出配置
	DEBUG_LOG = true,                 -- 是否开启调试打印
	DEBUG_THROTTLE_SEC = 1,         -- 玩家位置打印的节流间隔（秒）
	-- 小地图行为配置
	SMALL_CENTERED = false,        -- 小地图是否始终让玩家居中（false 为贴边夹紧显示）
	SMALL_MAP_ZOOM = 12.0,          -- 小地图缩放倍数（默认2.0），此处放大一倍为4.0
}

-- 最近一次点击对应的世界坐标（用于创建地图标记等）
local _touchWorldPos = nil
-- 玩家图标存储
local playerIcons = {}
local npcIcons = {}

local _screenGui = script.Parent
_screenGui.Enabled = true
local _frame = _screenGui:WaitForChild("Frame")
local _bigMap = _frame:WaitForChild("BigMap")
local _titleImage = _bigMap:WaitForChild("TitleImage")
local _closeButton = _titleImage:WaitForChild("CloseButton")
_closeButton.MouseButton1Click:Connect(function()
	_bigMap.Visible = false
end)
local _map = _bigMap:WaitForChild("map")
local _bigImageLabel = _map:WaitForChild("ImageLabel")
local _buttonFrame = _bigImageLabel:WaitForChild("ButtonFrame")
_buttonFrame.Visible = false

-- 方向变换：将世界归一坐标(rx,rz)映射到贴图内容归一坐标(cx,cy)
-- @param rx number 世界X相对坐标(0~1)
-- @param rz number 世界Z相对坐标(0~1)
-- @param orient table {FLIP_X, FLIP_Z, ROTATE_DEG}
local function applyOrientationToUV(rx, rz, orient)
	local cx = orient.FLIP_X and (1 - rx) or rx
	local cy = orient.FLIP_Z and (1 - rz) or rz
	local rot = orient.ROTATE_DEG or 0
	if rot == 90 then
		-- 顺时针90度：x'=y, y'=1-x
		local nx = cy
		local ny = 1 - cx
		cx, cy = nx, ny
	elseif rot == 180 then
		-- 180度：x'=1-x, y'=1-y
		cx = 1 - cx
		cy = 1 - cy
	elseif rot == 270 then
		-- 顺时针270度：x'=1-y, y'=x
		local nx = 1 - cy
		local ny = cx
		cx, cy = nx, ny
	end
	return cx, cy
end

-- 方向逆变换：将贴图内容归一坐标(cx,cy)还原为世界归一坐标(rx,rz)
-- @param cx number 内容X相对坐标(0~1)
-- @param cy number 内容Y相对坐标(0~1)
-- @param orient table {FLIP_X, FLIP_Z, ROTATE_DEG}
local function invertOrientationFromUV(cx, cy, orient)
	local rx, rz
	local rot = orient.ROTATE_DEG or 0
	if rot == 90 then
		-- 逆旋转90：x=y', y=1-x'
		local ux = cy
		local uy = 1 - cx
		cx, cy = ux, uy
	elseif rot == 180 then
		cx = 1 - cx
		cy = 1 - cy
	elseif rot == 270 then
		-- 逆旋转270：x=1-y', y=x'
		local ux = 1 - cy
		local uy = cx
		cx, cy = ux, uy
	end
	rx = orient.FLIP_X and (1 - cx) or cx
	rz = orient.FLIP_Z and (1 - cy) or cy
	return rx, rz
end

-- 初始化标记操作面板样式（固定像素尺寸，避免随父级缩放）
-- 作用：
--   - ButtonFrame 默认可能使用 Scale 尺寸，父级 _bigImageLabel 在缩放时会导致其变大
--   - 通过固定像素尺寸（Offset）与居中锚点，确保面板在任何缩放下大小一致
local function initMarkerPanelStyle()
	_buttonFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	if MINIMAP_CONFIG and MINIMAP_CONFIG.MARKER_PANEL_SIZE then
		_buttonFrame.Size = MINIMAP_CONFIG.MARKER_PANEL_SIZE
	else
		_buttonFrame.Size = UDim2.fromOffset(120, 120)
	end
	-- 提高层级，确保覆盖在地图之上
	_buttonFrame.ZIndex = (_bigImageLabel.ZIndex or 1) + 10
end

initMarkerPanelStyle()

-- 大地图视窗开启剪裁与初始锚点
_map.ClipsDescendants = true
_bigImageLabel.AnchorPoint = Vector2.new(0, 0)
-- 保持原始比例并完整显示到label尺寸，避免内部裁剪
_bigImageLabel.ScaleType = Enum.ScaleType.Fit
-- 设定初始尺寸为原图像素尺寸（乘以当前缩放），保证映射一致
do
	local base = MINIMAP_CONFIG.BIGMAP_IMAGE_SIZE
	-- 修正：bigMapZoom 在后面才初始化，这里使用默认值回退
	local zoom = 1.0
	_bigImageLabel.Size = UDim2.fromOffset(base.X * zoom, base.Y * zoom)
end

-- 大地图缩放与拖拽状态
-- 最小缩放动态计算：保证可以缩到“全图完全可见”
-- 注意：当视窗较大时，最小缩放不超过 1.0（不强制放大）
local BIGMAP_ZOOM_MIN = 1.0
local BIGMAP_ZOOM_MAX = 4.0
local bigMapZoom = 1.0
local isDraggingBig = false
local dragStartMouse = nil
local dragStartOffset = nil
local dragTotalDist = 0

-- 触摸缩放/拖拽状态（移动端）
-- 两指捏合时，围绕两指中点缩放；单指拖拽时平移
local touchPoints = {}
local pinchActive = false
local pinchStartDist = 0
local pinchStartZoom = 1.0

-- 计算 ImageLabel 内图片的实际显示尺寸与相对偏移
-- @param imageLabel ImageLabel 目标控件
-- @param baseSize Vector2 原始图片像素尺寸
-- @return Vector2 contentSize 缩放后的内容尺寸
-- @return Vector2 contentOffset 内容在label中的偏移：
--   Fit 模式为正的留白偏移 (labelSize - contentSize)/2；
--   Crop 模式为负的裁剪偏移 -(contentSize - labelSize)/2；
--   Stretch 模式偏移为(0,0)。
local function computeImageContent(imageLabel, baseSize)
	local labelSize = imageLabel.AbsoluteSize
	local W, H = baseSize.X, baseSize.Y
	local st = imageLabel.ScaleType
	if st == Enum.ScaleType.Stretch then
		return labelSize, Vector2.new(0, 0)
	end
	local sx = labelSize.X / math.max(W, 1)
	local sy = labelSize.Y / math.max(H, 1)
	local s
	if st == Enum.ScaleType.Crop then
		s = math.max(sx, sy)
	elseif st == Enum.ScaleType.Fit then
		s = math.min(sx, sy)
	else
		return labelSize, Vector2.new(0, 0)
	end
	local contentW = W * s
	local contentH = H * s
	local contentSize = Vector2.new(contentW, contentH)
	local dx = (labelSize.X - contentW) * 0.5
	local dy = (labelSize.Y - contentH) * 0.5
	local contentOffset = Vector2.new(dx, dy)
	return contentSize, contentOffset
end

-- 世界坐标映射到指定 ImageLabel 的可视区域坐标（UDim2）
-- 考虑 ScaleType(Crop/Fit/Stretch) 的缩放与裁剪，确保图标与底图一致
-- 参数：worldPos(Vector3)、imageLabel(ImageLabel)
-- 返回：UDim2（相对控件的归一化坐标）
-- 将世界坐标映射到 ImageLabel 的归一化坐标
-- @param worldPos Vector3 世界坐标
-- @param imageLabel ImageLabel 目标标签（小图或大图）
-- @return UDim2 归一化坐标（相对目标标签）
local function worldToImageLabelPosition(worldPos, imageLabel)
	local worldSize = MINIMAP_CONFIG.WORLD_SIZE[_G.ClientData.IslandName]
	local orient = MINIMAP_CONFIG.ORIENTATION[_G.ClientData.IslandName] or { FLIP_X = false, FLIP_Z = true, ROTATE_DEG = 0 }
	local rx = (worldPos.X - worldSize.MIN_X) / (worldSize.MAX_X - worldSize.MIN_X)
	local rz = (worldPos.Z - worldSize.MIN_Z) / (worldSize.MAX_Z - worldSize.MIN_Z)
	rx = math.clamp(rx, 0, 1)
	rz = math.clamp(rz, 0, 1)

	local baseSize = MINIMAP_CONFIG.BIGMAP_IMAGE_SIZE
	local contentSize, contentOffset = computeImageContent(imageLabel, baseSize)
	local labelSize = imageLabel.AbsoluteSize

	-- 根据贴图方向与旋转，变换为内容UV
	local ux, uy = applyOrientationToUV(rx, rz, orient)
	local px = ux * contentSize.X + contentOffset.X
	local py = uy * contentSize.Y + contentOffset.Y
	-- 夹紧到图片内容边界（而非整个label边界），确保图标能贴到图片边缘
	local contentLeft = contentOffset.X
	local contentTop = contentOffset.Y
	local contentRight = contentOffset.X + contentSize.X
	local contentBottom = contentOffset.Y + contentSize.Y
	px = math.clamp(px, contentLeft, contentRight)
	py = math.clamp(py, contentTop, contentBottom)

	local ux = labelSize.X > 0 and (px / labelSize.X) or 0
	local uy = labelSize.Y > 0 and (py / labelSize.Y) or 0
	return UDim2.new(ux, 0, uy, 0)
end

-- 夹紧偏移到可视区域范围
-- @param offsetX number 图像左上角X偏移（像素）
-- @param offsetY number 图像左上角Y偏移（像素）
-- @param imageSize Vector2 图像尺寸（像素）
-- @param viewportSize Vector2 视窗尺寸（像素）
-- @return number, number 夹紧后的X、Y偏移
-- 偏移夹紧：
-- 当图像大于视窗时，限制在 [视窗-图像, 0]；
-- 当图像不大于视窗时，自动居中显示（而非固定到左上角）。
local function clampBigMapOffset(offsetX, offsetY, imageSize, viewportSize)
	local clampedX = offsetX
	local clampedY = offsetY

	if imageSize.X <= viewportSize.X then
		clampedX = (viewportSize.X - imageSize.X) * 0.5
	else
		local minOffsetX = viewportSize.X - imageSize.X
		clampedX = math.clamp(offsetX, minOffsetX, 0)
	end

	if imageSize.Y <= viewportSize.Y then
		clampedY = (viewportSize.Y - imageSize.Y) * 0.5
	else
		local minOffsetY = viewportSize.Y - imageSize.Y
		clampedY = math.clamp(offsetY, minOffsetY, 0)
	end

	return clampedX, clampedY
end

-- 计算“缩到全图可见”的最小缩放系数（动态）
-- @return number 最小缩放，保证 baseSize * minZoom 不超过视窗，且不超过 1.0
local function getBigMapMinZoom()
	local viewportSize = _map.AbsoluteSize
	local base = MINIMAP_CONFIG.BIGMAP_IMAGE_SIZE
	if base.X <= 0 or base.Y <= 0 then return 1.0 end
	local fitZoom = math.min(viewportSize.X / base.X, viewportSize.Y / base.Y)
	return math.max(0.1, math.min(1.0, fitZoom))
end

-- 设置大地图缩放（围绕指定视窗点缩放）
-- @param newZoom number 新缩放系数（范围 BIGMAP_ZOOM_MIN~BIGMAP_ZOOM_MAX）
-- @param pivot Vector2 视窗中的缩放枢轴点（像素坐标）
-- 说明：
--   - 与 setBigMapZoom 类似，但允许围绕任意枢轴点缩放（如双指中点）
--   - 计算偏移使得枢轴点下的内容在缩放过程中尽量稳定
-- 设置大地图缩放（围绕指定视窗点缩放）
-- @param newZoom number 新缩放系数（范围 BIGMAP_ZOOM_MIN~BIGMAP_ZOOM_MAX）
-- @param pivot Vector2 视窗中的缩放枢轴点（像素坐标）
-- 说明：
--   - 基于原始图片像素尺寸（MINIMAP_CONFIG.BIGMAP_IMAGE_SIZE）进行缩放，避免被视窗拉伸
--   - 通过枢轴点计算新的偏移，使缩放时枢轴附近内容尽量稳定
-- 设置大地图缩放（围绕指定视窗点缩放）
-- @param newZoom number 新缩放系数
-- @param pivot Vector2 视窗中的缩放枢轴点（像素坐标）
-- 功能：支持缩到“全图”，并在图像小于视窗时自动居中
local function setBigMapZoomWithPivot(newZoom, pivot)
	local zmin = getBigMapMinZoom()
	newZoom = math.clamp(newZoom, zmin, BIGMAP_ZOOM_MAX)
	local oldZoom = bigMapZoom
	if math.abs(newZoom - oldZoom) < 1e-6 then
		return
	end

	local viewportSize = _map.AbsoluteSize
	local base = MINIMAP_CONFIG.BIGMAP_IMAGE_SIZE
	local oldImageSize = Vector2.new(base.X * oldZoom, base.Y * oldZoom)
	local newImageSize = Vector2.new(base.X * newZoom, base.Y * newZoom)

	local offsetX = _bigImageLabel.Position.X.Offset
	local offsetY = _bigImageLabel.Position.Y.Offset
	local scaleFactor = newZoom / oldZoom

	local pivotPoint = pivot or Vector2.new(viewportSize.X * 0.5, viewportSize.Y * 0.5)

	-- 围绕枢轴点缩放后的新偏移
	local newOffsetX = offsetX * scaleFactor + pivotPoint.X * (1 - scaleFactor)
	local newOffsetY = offsetY * scaleFactor + pivotPoint.Y * (1 - scaleFactor)

	local clampedX, clampedY = clampBigMapOffset(newOffsetX, newOffsetY, newImageSize, viewportSize)
	_bigImageLabel.Size = UDim2.fromOffset(newImageSize.X, newImageSize.Y)
	_bigImageLabel.Position = UDim2.fromOffset(clampedX, clampedY)
	bigMapZoom = newZoom
end

-- 设置大地图缩放（围绕视窗中心缩放）
-- @param newZoom number 新的缩放系数（范围 BIGMAP_ZOOM_MIN~BIGMAP_ZOOM_MAX）
-- 说明：
--   - 根据缩放系数更新 _bigImageLabel 的 Size
--   - 按缩放保持视窗中心下的内容不跳变（计算新的偏移）
--   - 对偏移进行边界夹紧，避免露出空白
-- 设置大地图缩放（围绕视窗中心缩放）
-- @param newZoom number 新的缩放系数（范围 BIGMAP_ZOOM_MIN~BIGMAP_ZOOM_MAX）
-- 说明：
--   - 基于原始图片像素尺寸进行缩放，中心作为枢轴
--   - 缩放后对偏移进行夹紧，避免露出空白
-- 设置大地图缩放（围绕视窗中心缩放）
-- @param newZoom number 新缩放系数
-- 功能：支持缩到“全图”，并在图像小于视窗时自动居中
local function setBigMapZoom(newZoom)
	local zmin = getBigMapMinZoom()
	newZoom = math.clamp(newZoom, zmin, BIGMAP_ZOOM_MAX)
	local oldZoom = bigMapZoom
	if math.abs(newZoom - oldZoom) < 1e-6 then
		return
	end

	local viewportSize = _map.AbsoluteSize
	local base = MINIMAP_CONFIG.BIGMAP_IMAGE_SIZE
	local oldImageSize = Vector2.new(base.X * oldZoom, base.Y * oldZoom)
	local newImageSize = Vector2.new(base.X * newZoom, base.Y * newZoom)

	local offsetX = _bigImageLabel.Position.X.Offset
	local offsetY = _bigImageLabel.Position.Y.Offset
	local center = Vector2.new(viewportSize.X * 0.5, viewportSize.Y * 0.5)
	local scaleFactor = newZoom / oldZoom

	-- 计算缩放后保持中心内容稳定的偏移
	local newOffsetX = offsetX * scaleFactor + center.X * (1 - scaleFactor)
	local newOffsetY = offsetY * scaleFactor + center.Y * (1 - scaleFactor)

	local clampedX, clampedY = clampBigMapOffset(newOffsetX, newOffsetY, newImageSize, viewportSize)
	_bigImageLabel.Size = UDim2.fromOffset(newImageSize.X, newImageSize.Y)
	_bigImageLabel.Position = UDim2.fromOffset(clampedX, clampedY)
	bigMapZoom = newZoom
end

-- 缩放到“全图适配”，并居中显示
-- 功能：直接将缩放设为动态最小值，并更新位置到居中
local function zoomBigMapToFit()
	local zmin = getBigMapMinZoom()
	setBigMapZoom(zmin)
end

-- 根据滚轮输入调整缩放
-- @param wheelDelta number 鼠标滚轮Z方向增量（正向放大，负向缩小）
local function applyBigMapZoomDelta(wheelDelta)
	local step = (wheelDelta > 0) and 0.15 or -0.15
	setBigMapZoom(bigMapZoom + step)
end

-- 平移大地图图像（拖拽）
-- @param dx number X方向像素偏移增量
-- @param dy number Y方向像素偏移增量
-- 说明：
--   - 在当前缩放下直接叠加偏移，并进行边界夹紧
local function panBigMapBy(dx, dy)
	local viewportSize = _map.AbsoluteSize
	local imageSize = _bigImageLabel.AbsoluteSize
	local offsetX = _bigImageLabel.Position.X.Offset + dx
	local offsetY = _bigImageLabel.Position.Y.Offset + dy
	local clampedX, clampedY = clampBigMapOffset(offsetX, offsetY, imageSize, viewportSize)
	_bigImageLabel.Position = UDim2.fromOffset(clampedX, clampedY)
end

-- 将大地图图片居中到给定世界坐标（以本地玩家为中心）
-- @param worldPosition Vector3 世界坐标位置
-- 说明：
--   - 计算该世界坐标在整张大地图图片中的相对位置（0~1）
--   - 将 _bigImageLabel 以像素偏移移动，使该位置位于 _map 视窗中心
--   - 使用当前缩放 bigMapZoom，并进行边界夹紧，避免空白溢出
local function centerBigMapOnWorldPosition(worldPosition)
	if not worldPosition then return end

	local worldSize = MINIMAP_CONFIG.WORLD_SIZE[_G.ClientData.IslandName]
	if not worldSize then return end

	-- 相对坐标（0~1），并翻转以匹配贴图方向
	local relativeX = (worldPosition.X - worldSize.MIN_X) / (worldSize.MAX_X - worldSize.MIN_X)
	local relativeZ = (worldPosition.Z - worldSize.MIN_Z) / (worldSize.MAX_Z - worldSize.MIN_Z)
	relativeX = math.clamp(relativeX, 0, 1)
	relativeZ = math.clamp(relativeZ, 0, 1)

	-- 当前图片与视窗的像素尺寸
	local viewportSize = _map.AbsoluteSize
	local imageSize = _bigImageLabel.AbsoluteSize

	-- 目标点在图片中的像素位置（考虑贴图方向与旋转）
	local orient = MINIMAP_CONFIG.ORIENTATION[_G.ClientData.IslandName] or { FLIP_X = true, FLIP_Z = true, ROTATE_DEG = 0 }
	local ux, uy = applyOrientationToUV(relativeX, relativeZ, orient)
	local targetPX = ux * imageSize.X
	local targetPY = uy * imageSize.Y

	-- 期望偏移：让目标点落在视窗中心
	local desiredOffsetX = viewportSize.X * 0.5 - targetPX
	local desiredOffsetY = viewportSize.Y * 0.5 - targetPY

	-- 边界夹紧，避免露出空白
	local clampedX, clampedY = clampBigMapOffset(desiredOffsetX, desiredOffsetY, imageSize, viewportSize)
	_bigImageLabel.Position = UDim2.fromOffset(clampedX, clampedY)
end

local _smallMap = _frame:WaitForChild("SmallMap")
local _mapButton = _smallMap:WaitForChild("MapButton")
_mapButton.MouseButton1Down:Connect(function(x, y)
	_bigMap.Visible = true
	_buttonFrame.Visible = false

	-- 打开大地图时，默认以玩家位置为中心
	local player = Players.LocalPlayer
	local character = player and player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp then
		centerBigMapOnWorldPosition(hrp.Position)
	end
end)
local _smallImageLabel = _smallMap:WaitForChild("ImageLabel")
-- 开启剪裁，确保图片平移时视窗只显示可见区域
_smallMap.ClipsDescendants = true
-- 小地图保持原始宽高比例并铺满控件，裁剪多余部分以避免拉伸
_smallImageLabel.ScaleType = Enum.ScaleType.Fit

-- 将屏幕点击坐标转换为ImageLabel图像的UV坐标，并在对应位置显示操作面板
-- @param x number 鼠标点击的屏幕X坐标（像素）
-- @param y number 鼠标点击的屏幕Y坐标（像素）
-- 说明：
--   1) 将屏幕坐标转换为相对于 _bigImageLabel 的本地坐标；
--   2) 归一化为UV(0~1)，保存到 _touchPos（便于网络同步/跨设备一致）；
--   3) 将 _buttonFrame 定位到该UV位置（父级改为 _imageLabel）。
-- 将屏幕点击坐标转换为ImageLabel图像的世界坐标，同时在点击处显示操作面板
-- @param x number 鼠标点击的屏幕X坐标（像素）
-- @param y number 鼠标点击的屏幕Y坐标（像素）
-- 说明：
--   - 面板定位使用标签UV（便于精确显示在点击位置）
--   - 标记数据使用世界坐标（跨设备/不同缩放与裁剪下保持一致）
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

	-- 面板显示：使用标签UV坐标（0~1）
	local panelUVX = absSize.X > 0 and (localX / absSize.X) or 0
	local panelUVY = absSize.Y > 0 and (localY / absSize.Y) or 0
	_buttonFrame.Position = UDim2.fromScale(panelUVX, panelUVY)

	-- 标记数据：将点击位置转换为世界坐标（兼容 Fit/Crop 内容偏移）
	local baseSize = MINIMAP_CONFIG.BIGMAP_IMAGE_SIZE
	local contentSize, contentOffset = computeImageContent(_bigImageLabel, baseSize)
	local contentPX = localX - contentOffset.X
	local contentPY = localY - contentOffset.Y
	local uvContentX = contentSize.X > 0 and (contentPX / contentSize.X) or 0
	local uvContentY = contentSize.Y > 0 and (contentPY / contentSize.Y) or 0

	local worldSize = MINIMAP_CONFIG.WORLD_SIZE[_G.ClientData.IslandName]
	local orient = MINIMAP_CONFIG.ORIENTATION[_G.ClientData.IslandName] or { FLIP_X = true, FLIP_Z = true, ROTATE_DEG = 0 }
	local cx = math.clamp(uvContentX, 0, 1)
	local cy = math.clamp(uvContentY, 0, 1)
	local rx, rz = invertOrientationFromUV(cx, cy, orient)
	local wx = worldSize.MIN_X + rx * (worldSize.MAX_X - worldSize.MIN_X)
	local wz = worldSize.MIN_Z + rz * (worldSize.MAX_Z - worldSize.MIN_Z)
	_touchWorldPos = Vector3.new(wx, 0, wz)
	_buttonFrame.Visible = true

	-- 调试：输出点击后的面板UV与对应世界坐标
	if MINIMAP_CONFIG.DEBUG_LOG then
		print(string.format("[Minimap:click] panelUV=(%.3f, %.3f) contentUV=(%.3f, %.3f) world=(%.2f, %.2f, %.2f)", panelUVX, panelUVY, cx, cy, wx, 0, wz))
	end
end

local _textButton = _bigMap:WaitForChild("TextButton")
-- 绑定大地图拖拽与缩放事件，并区分点击与拖拽（短距离点击触发标记面板）
_textButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDraggingBig = true
		dragTotalDist = 0
		local mouse = UserInputService:GetMouseLocation()
		local inset = GuiService:GetGuiInset()
		dragStartMouse = Vector2.new(mouse.X - inset.X, mouse.Y - inset.Y)
		dragStartOffset = Vector2.new(_bigImageLabel.Position.X.Offset, _bigImageLabel.Position.Y.Offset)
	elseif input.UserInputType == Enum.UserInputType.Touch then
		-- 记录触点
		local inset = GuiService:GetGuiInset()
		local pos = input.Position
		local viewportPos = Vector2.new(pos.X - inset.X, pos.Y - inset.Y)
		touchPoints[input] = viewportPos

		local count = 0
		for _ in pairs(touchPoints) do count += 1 end
		if count == 1 then
			-- 单指拖拽开始
			isDraggingBig = true
			dragTotalDist = 0
			dragStartMouse = viewportPos
			dragStartOffset = Vector2.new(_bigImageLabel.Position.X.Offset, _bigImageLabel.Position.Y.Offset)
		elseif count == 2 then
			-- 双指捏合开始
			pinchActive = true
			pinchStartZoom = bigMapZoom
			local p1, p2
			for key, v in pairs(touchPoints) do
				if not p1 then p1 = v else p2 = v end
			end
			if p1 and p2 then
				pinchStartDist = (p1 - p2).Magnitude
				if pinchStartDist < 1e-3 then
					pinchStartDist = 1.0
				end
			end
			-- 双指开始时不再视为单指拖拽
			isDraggingBig = false
		end
	end
end)

_textButton.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement and isDraggingBig then
		local mouse = UserInputService:GetMouseLocation()
		local inset = GuiService:GetGuiInset()
		local current = Vector2.new(mouse.X - inset.X, mouse.Y - inset.Y)
		local delta = current - dragStartMouse
		dragTotalDist = math.max(dragTotalDist, math.abs(delta.X) + math.abs(delta.Y))
		panBigMapBy(delta.X, delta.Y)
		-- 累计拖拽位移后，更新起点，避免累加放大
		dragStartMouse = current
	elseif input.UserInputType == Enum.UserInputType.MouseWheel and _bigMap.Visible then
		applyBigMapZoomDelta(input.Position.Z)
	elseif input.UserInputType == Enum.UserInputType.Touch then
		-- 更新触点位置
		local inset = GuiService:GetGuiInset()
		local pos = input.Position
		touchPoints[input] = Vector2.new(pos.X - inset.X, pos.Y - inset.Y)

		local count = 0
		for _ in pairs(touchPoints) do count += 1 end

		if pinchActive and count >= 2 then
			-- 取前两个触点计算当前距离与枢轴
			local p1, p2
			for _, v in pairs(touchPoints) do
				if not p1 then p1 = v else p2 = v end
				if p1 and p2 then break end
			end
			if p1 and p2 then
				local currentDist = (p1 - p2).Magnitude
				if currentDist < 1e-3 then currentDist = 1.0 end
				local ratio = currentDist / math.max(pinchStartDist, 1.0)
				-- 去除固定最小值夹紧，交由 setBigMapZoomWithPivot 使用动态最小缩放
				local newZoom = pinchStartZoom * ratio
				local pivot = (p1 + p2) * 0.5
				setBigMapZoomWithPivot(newZoom, pivot)
			end
		elseif isDraggingBig and count == 1 then
			-- 单指拖拽更新
			local currentPos
			for _, v in pairs(touchPoints) do currentPos = v break end
			if currentPos and dragStartMouse then
				local delta = currentPos - dragStartMouse
				dragTotalDist = math.max(dragTotalDist, math.abs(delta.X) + math.abs(delta.Y))
				panBigMapBy(delta.X, delta.Y)
				dragStartMouse = currentPos
			end
		end
	end
end)

_textButton.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local wasDragging = isDraggingBig
		isDraggingBig = false
		-- 若拖拽距离很小，认为是点击，弹出标记面板
		if dragTotalDist < 6 then
			local mouse = UserInputService:GetMouseLocation()
			placeMarkerOnImageFromScreenXY(mouse.X, mouse.Y)
		end
	elseif input.UserInputType == Enum.UserInputType.Touch then
		-- 清理触点
		touchPoints[input] = nil
		local count = 0
		for _ in pairs(touchPoints) do count += 1 end

		if count < 2 then
			pinchActive = false
		end
		if count == 0 then
			isDraggingBig = false
		elseif count == 1 then
			-- 回退为单指拖拽
			for _, v in pairs(touchPoints) do
				isDraggingBig = true
				dragStartMouse = v
				dragStartOffset = Vector2.new(_bigImageLabel.Position.X.Offset, _bigImageLabel.Position.Y.Offset)
				break
			end
		end
	end
end)

-- 初始化大地图的尺寸与位置（按当前视窗设置为无缩放、居中显示）
-- 说明：在脚本启动时调用一次，保证大地图可以拖拽与缩放
-- 初始化大地图布局（按原始图片大小显示，超出视窗部分由父级裁剪）
-- 说明：
--   - Size = 原图像素尺寸 * 初始缩放（1.0）
--   - 父容器 _map 必须开启 ClipsDescendants 才能隐藏超出部分
local function initBigMapLayout()
	bigMapZoom = 1.0
	local base = MINIMAP_CONFIG.BIGMAP_IMAGE_SIZE
	_bigImageLabel.Size = UDim2.fromOffset(base.X * bigMapZoom, base.Y * bigMapZoom)
	_bigImageLabel.Position = UDim2.fromOffset(0, 0)
end

initBigMapLayout()

local jhBtn = _buttonFrame:WaitForChild("JHButton")
local wxBtn = _buttonFrame:WaitForChild("WXButton")
local wzBtn = _buttonFrame:WaitForChild("WZButton")
jhBtn.MouseButton1Down:Connect(function(x, y)
	_buttonFrame.Visible = false
	Knit.GetService("MapService"):ShowFlag(1, _touchWorldPos or Vector3.new(0,0,0)):andThen(function()
	end)
end)
wxBtn.MouseButton1Down:Connect(function(x, y)
	_buttonFrame.Visible = false
	Knit.GetService("MapService"):ShowFlag(2, _touchWorldPos or Vector3.new(0,0,0)):andThen(function()
	end)
end)
wzBtn.MouseButton1Down:Connect(function(x, y)
	_buttonFrame.Visible = false
	Knit.GetService("MapService"):ShowFlag(3, _touchWorldPos or Vector3.new(0,0,0)):andThen(function()
	end)
end)

-- 在icon上添加光圈特效，播放3次
local function playCircleEffect(icon)
	local circle = Instance.new("ImageLabel")
	circle.Name = "CircleEffect"
	circle.Image = MINIMAP_CONFIG.CIRCLE_ICON
	circle.BackgroundTransparency = 1
	circle.AnchorPoint = icon.AnchorPoint
	circle.Position = icon.Position
	circle.Size = UDim2.new(0, icon.Size.X.Offset * 10, 0, icon.Size.Y.Offset * 10)
	circle.ZIndex = icon.ZIndex + 1
	circle.ImageTransparency = 0
	circle.Parent = icon.Parent

	for i = 1, 3 do
		circle.ImageTransparency = 0
		circle.Size = UDim2.new(0, icon.Size.X.Offset * 10, 0, icon.Size.Y.Offset * 10)
		-- 动画目标：缩小到icon大小，逐渐透明
		local tween = TweenService:Create(circle, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = icon.Size,
			ImageTransparency = 1
		})

		tween:Play()
		tween.Completed:Wait()
		task.wait(0.1)
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
	return UDim2.new(1 - relativeX, 0, 1 - relativeZ, 0)
end

-- 将小地图图片居中到给定世界坐标（以本地玩家为中心）
-- @param worldPosition Vector3 世界坐标位置
-- 说明：
--   - 计算玩家在整张地图图片中的相对位置（0~1）
--   - 将 _smallImageLabel 以像素偏移移动，使该位置位于 _smallMap 的中心
--   - 支持缩放系数 SMALL_MAP_ZOOM，并进行边界夹紧，避免空白溢出
--   - X轴按小地图贴图方向进行翻转，保证左右与贴图一致
-- 将小地图图片居中到给定世界坐标（以本地玩家为中心，适配Crop）
-- @param worldPosition Vector3 世界坐标位置
-- 说明：
--   - 使用内容尺寸与裁剪偏移（ScaleType=Crop/Fit）进行像素计算
--   - 调整 _smallImageLabel 的位置，使玩家位于 _smallMap 视窗中心
--   - 继续支持 SMALL_MAP_ZOOM
-- 将小地图图片始终居中到给定世界坐标（玩家永远在小地图中心）
-- @param worldPosition Vector3 世界坐标位置
-- 说明：
--   - 计算玩家在整张贴图内容中的像素位置（考虑 ScaleType=Crop 的内容尺寸与裁剪偏移）
--   - 将 _smallImageLabel 的左上角偏移设置为“视窗中心 - 玩家像素位置”，不再进行上限夹紧
--   - 当玩家接近贴图边缘时允许出现留白（由 _smallMap 的背景色显示），以保证玩家始终位于中心
--   - 可通过 MINIMAP_CONFIG.SMALL_MAP_ZOOM 控制小地图的放大倍数（默认 2.0），建议 ≥ 2.0 以减少留白比例
-- 将小地图图片居中到给定世界坐标（考虑贴图方向与ScaleType）
-- @param worldPosition Vector3 世界坐标位置
-- 说明：
--   - 使用 ORIENTATION 的 FLIP_X/FLIP_Z 配置修正贴图方向
--   - 通过 computeImageContent 获取内容尺寸与偏移，保证 Fit/Crop 一致
--   - 进行边缘夹紧，避免小地图出现留白
-- 将小地图图片始终居中到给定世界坐标（玩家永远在小地图中心，不夹紧）
-- @param worldPosition Vector3 世界坐标位置
-- 说明：
--   - 计算玩家在整张贴图内容中的像素位置（考虑 ScaleType 与方向变换）
--   - 设置 _smallImageLabel.Position = 视窗中心 - 玩家像素位置，允许边缘留白以保证玩家居中
--   - 适用于本地玩家的跟随视图，避免“到尽头仍不贴边”的错觉
local function centerSmallMapOnWorldPosition(worldPosition)
	local worldSize = MINIMAP_CONFIG.WORLD_SIZE[_G.ClientData.IslandName]
	local orient = MINIMAP_CONFIG.ORIENTATION[_G.ClientData.IslandName] or { FLIP_X = false, FLIP_Z = true, ROTATE_DEG = 0 }
	local relativeX = (worldPosition.X - worldSize.MIN_X) / (worldSize.MAX_X - worldSize.MIN_X)
	local relativeZ = (worldPosition.Z - worldSize.MIN_Z) / (worldSize.MAX_Z - worldSize.MIN_Z)

	relativeX = math.clamp(relativeX, 0, 1)
	relativeZ = math.clamp(relativeZ, 0, 1)

	local viewportSize = _smallMap.AbsoluteSize
	local zoom = MINIMAP_CONFIG.SMALL_MAP_ZOOM or 2.0

	_smallImageLabel.AnchorPoint = Vector2.new(0, 0)
	_smallImageLabel.Size = UDim2.fromOffset(viewportSize.X * zoom, viewportSize.Y * zoom)

	local baseSize = MINIMAP_CONFIG.BIGMAP_IMAGE_SIZE
	local contentSize, contentOffset = computeImageContent(_smallImageLabel, baseSize)

	local ux, uy = applyOrientationToUV(relativeX, relativeZ, orient)
	local playerPX = ux * contentSize.X + contentOffset.X
	local playerPY = uy * contentSize.Y + contentOffset.Y

	local desiredOffsetX = viewportSize.X * 0.5 - playerPX
	local desiredOffsetY = viewportSize.Y * 0.5 - playerPY

	if MINIMAP_CONFIG.SMALL_CENTERED then
		-- 居中：允许留白
		_smallImageLabel.Position = UDim2.fromOffset(desiredOffsetX, desiredOffsetY)
	else
		-- 贴边：按内容边界进行夹紧，确保图片边缘可贴到视窗边缘
		-- 使用 computeImageContent 的结果进行精确夹紧，避免因 label 留白导致“不到边”的错觉
		local contentLeft = contentOffset.X
		local contentTop = contentOffset.Y
		local contentRight = contentOffset.X + contentSize.X
		local contentBottom = contentOffset.Y + contentSize.Y
		local minOffsetX = viewportSize.X - contentRight   -- 内容右缘贴右侧
		local maxOffsetX = -contentLeft                    -- 内容左缘贴左侧
		local minOffsetY = viewportSize.Y - contentBottom  -- 内容下缘贴底部
		local maxOffsetY = -contentTop                     -- 内容上缘贴顶部
		local offsetX = math.clamp(desiredOffsetX, minOffsetX, maxOffsetX)
		local offsetY = math.clamp(desiredOffsetY, minOffsetY, maxOffsetY)
		_smallImageLabel.Position = UDim2.fromOffset(offsetX, offsetY)
	end
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
-- @param position Vector3|Vector2 标记位置：优先世界坐标(Vector3)；兼容UV(Vector2)将转换为世界坐标
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

	-- 将传入位置统一转换为世界坐标
	local worldSize = MINIMAP_CONFIG.WORLD_SIZE[_G.ClientData.IslandName]
	local worldPos
	if position and typeof(position) == "Vector3" then
		worldPos = position
	elseif position and typeof(position) == "Vector2" then
		local rx = 1 - math.clamp(position.X, 0, 1)
		local rz = 1 - math.clamp(position.Y, 0, 1)
		worldPos = Vector3.new(
			worldSize.MIN_X + rx * (worldSize.MAX_X - worldSize.MIN_X),
			0,
			worldSize.MIN_Z + rz * (worldSize.MAX_Z - worldSize.MIN_Z)
		)
	else
		worldPos = _touchWorldPos or Vector3.new(0,0,0)
	end

	-- 大地图与小地图均用世界→ImageLabel映射，保证与底图一致
	iconBig.Position = worldToImageLabelPosition(worldPos, _bigImageLabel)

	playCircleEffect(iconBig)

	local iconSmall = Instance.new("ImageLabel")
	iconSmall.Name = type
	iconSmall.Size = MINIMAP_CONFIG.SMALL_SIZE
	iconSmall.AnchorPoint = MINIMAP_CONFIG.ANCHOR_POINT
	iconSmall.BackgroundTransparency = 1
	iconSmall.Parent = _smallImageLabel
	iconSmall.Image = image
	iconSmall.Position = worldToImageLabelPosition(worldPos, _smallImageLabel)

	playCircleEffect(iconSmall)
end

-- 更新玩家图标位置和朝向
-- @param player Player 玩家对象
-- @param icon ImageLabel 玩家图标
-- @param mapFrame Frame 小地图框架
-- 说明：
--   - 小地图模式下，X轴按贴图方向翻转，修正左右反向问题
-- 更新玩家图标位置和朝向（统一使用世界→ImageLabel映射）
-- @param player Player 玩家对象
-- @param icon ImageLabel 玩家图标
-- @param mapFrame ImageLabel 图标父级（小图为 _smallImageLabel，大图为 _bigImageLabel）
-- 更新玩家图标位置和朝向（本地玩家始终居中于小地图）
-- @param player Player 玩家对象
-- @param icon ImageLabel 玩家图标
-- @param mapFrame ImageLabel 图标父级（小图为 _smallImageLabel，大图为 _bigImageLabel）
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
	if player == Players.LocalPlayer then
		if mapFrame == _smallImageLabel then
			-- 本地玩家：小地图居中跟随，并按小图映射
			centerSmallMapOnWorldPosition(worldPosition)
			icon.Position = worldToImageLabelPosition(worldPosition, _smallImageLabel)
		else
			-- 本地玩家：大地图按大图映射（不强制居中，尊重用户拖拽）
			icon.Position = worldToImageLabelPosition(worldPosition, mapFrame)
		end
	else
		-- 其他玩家/NPC：按世界→ImageLabel映射
		icon.Position = worldToImageLabelPosition(worldPosition, mapFrame)
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
-- 更新NPC图标位置（固定X翻转逻辑由 worldToMapPosition 统一处理）
-- @param npc Model NPC对象
-- @param icon ImageLabel NPC图标
-- @param mapFrame Frame 图标父级（小图为 _smallImageLabel，大图为 _bigImageLabel）
local function updateNPCIcon(npc, icon, mapFrame)
	if not npc or not npc.Parent then
		icon.Visible = false
		return
	end

	icon.Visible = true

	-- 采用Model:GetPivot获取世界位置，避免PrimaryPart缺失导致报错
	local cf = npc:GetPivot()
	local worldPosition = cf.Position

	-- 小地图与大地图均依赖贴图坐标（父级为 ImageLabel），统一考虑ScaleType与裁剪
	icon.Position = worldToImageLabelPosition(worldPosition, mapFrame)
end

local _posFrame = _frame:WaitForChild("PosFrame")
_posFrame.Visible = false
local _posLabel = _posFrame:WaitForChild("PosLabel")

-- 将位置显示框(_posFrame)贴到小地图的右侧与上方
-- @param posFrame Frame 需要定位的框
-- @param smallMap Frame 小地图容器（父级）
-- @param opts table 可选项 { outside=true, margin=8 }
--        outside=true  表示放在小地图外侧的右上角（不遮挡小地图内容）
--        outside=false 表示放在小地图内侧的右上角（覆盖在小地图之上）
-- @return void
local function attachPosFrameToSmallMap(posFrame, smallMap, opts)
    if not posFrame or not smallMap then return end
    opts = opts or {}
    local outside = (opts.outside ~= false) -- 默认外侧右上

    -- 不改变父节点：使用绝对坐标计算，并转换为 posFrame 父容器坐标
    local parent = posFrame.Parent
    if not parent then return end

    -- 提高层级，确保在地图之上（如需更高请自行调整）
    posFrame.ZIndex = math.max((posFrame.ZIndex or 1), (smallMap.ZIndex or 1) + 5)

    local function apply()
        local parentAbs = parent.AbsolutePosition
        local smallAbs = smallMap.AbsolutePosition
        local smallSize = smallMap.AbsoluteSize
        local targetAbsX, targetAbsY
        local marginX = (opts.marginX ~= nil) and opts.marginX or (opts.margin or 8)
        local marginY = (opts.marginY ~= nil) and opts.marginY or 0
        if outside then
            -- 外侧右侧顶端对齐：posFrame 顶部与 smallMap 顶部持平
            posFrame.AnchorPoint = Vector2.new(0, 0)   -- top-left 作为锚点
            targetAbsX = smallAbs.X + smallSize.X + marginX
            targetAbsY = smallAbs.Y + marginY
        else
            -- 内侧右上：顶端持平，并在水平方向向内偏移
            posFrame.AnchorPoint = Vector2.new(1, 0)   -- top-right 作为锚点
            targetAbsX = smallAbs.X + smallSize.X - marginX
            targetAbsY = smallAbs.Y + marginY
        end
        -- 转换为父容器偏移坐标
        local offsetX = targetAbsX - parentAbs.X
        local offsetY = targetAbsY - parentAbs.Y
        posFrame.Position = UDim2.fromOffset(offsetX, offsetY)
    end

    -- 初次应用
    apply()

    -- 监听尺寸与位置变化，动态跟随
    smallMap:GetPropertyChangedSignal("AbsolutePosition"):Connect(apply)
    smallMap:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
    parent:GetPropertyChangedSignal("AbsolutePosition"):Connect(apply)
    parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
end

-- 默认将 _posFrame 放到小地图“外侧右上角”，不与内容重叠
attachPosFrameToSmallMap(_posFrame, _smallMap, { outside = true, margin = 8 })

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

	-- 主更新循环：更新玩家与NPC图标
	RunService.Heartbeat:Connect(function(dt)
		-- 玩家更新
		for _, player in pairs(Players:GetPlayers()) do
			if playerIcons[player] then
				local smallFrame = _smallImageLabel
				updatePlayerIcon(player, playerIcons[player].small, smallFrame)
				updatePlayerIcon(player, playerIcons[player].big, _bigImageLabel)
			end
		end

		-- NPC更新
		for npc, icons in pairs(npcIcons) do
			if icons then
				if icons.small then
					updateNPCIcon(npc, icons.small, _smallImageLabel)
				end
				if icons.big then
					updateNPCIcon(npc, icons.big, _bigImageLabel)
				end
			end
		end

        local player = Players.LocalPlayer
		local character = player.Character
        if not character then return end
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then return end

        _posFrame.Visible = true
        local position = humanoidRootPart.Position
        _posLabel.Text = string.format(
            "%.0f, %.0f, %.0f",
            position.X,
            position.Y - humanoid.HipHeight - humanoidRootPart.Size.Y / 2,
            position.Z
        )
	end)

	local function playerAdded(player)
		-- 确保玩家有图标
		if not playerIcons[player] then
			playerIcons[player] = {}
			playerIcons[player].small = createPlayerIcon(player, _smallImageLabel)
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