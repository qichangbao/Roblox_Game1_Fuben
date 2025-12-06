local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local guiInset = game:GetService("GuiService"):GetGuiInset()
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local TeleportService = game:GetService("TeleportService")
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local _screenGui = script.Parent
local _center = _screenGui:WaitForChild("center")
local _itemFrame = _center:WaitForChild("ItemFrame")
local _itemImageLabel = _itemFrame:WaitForChild("ImageLabel")
_itemImageLabel.Visible = false
_itemImageLabel.ImageTransparency = 1
local _itemImageFadeTween = nil
local _leftFrame = _screenGui:WaitForChild("left")
local _bottomFrame = _screenGui:WaitForChild("bottom")
local _rightFrame = _screenGui:WaitForChild("right")
local _topFrame = _screenGui:WaitForChild("top")
local _toolFrame = _bottomFrame:WaitForChild("ToolFrame")
local _bagFrame = _bottomFrame:WaitForChild("BagFrame")
_bagFrame.Visible = false
local _taskTipLabel = _topFrame:WaitForChild("TaskTipLabel")
_taskTipLabel.RichText = true
_taskTipLabel.Text = ""

local _questFrame = _leftFrame:WaitForChild("QuestFrame")
local _questButton = _questFrame:WaitForChild("QuestButton")
_questButton.MouseButton1Click:Connect(function()
	Knit.GetController("UIController").ShowQuestUI:Fire(2)
end)

-- 现实秒与游戏秒的换算（1现实秒 = 96游戏秒）
local REAL_TO_GAME_SECOND = 96
-- 将真实秒数转换为游戏秒数（函数级注释）：
-- @param realSeconds number 真实世界的秒数
-- @return number 对应的游戏内秒数（按照换算比例REAL_TO_GAME_SECOND）
local function RealToGameSeconds(realSeconds)
	return realSeconds * REAL_TO_GAME_SECOND
end
-- 将游戏秒数格式化为游戏时钟（函数级注释）：
-- @param gameSeconds number 游戏内秒数（例如 57600 表示 16 小时）
-- @return string 形如 "HH:MM" 的字符串，超过 24 小时也会累加小时数
local function FormatGameClock(gameSeconds)
	local totalSeconds = math.max(0, math.floor(gameSeconds))
	local hours = math.floor(totalSeconds / 3600)
	local minutes = math.floor((totalSeconds % 3600) / 60)
	return string.format("%02d:%02d", hours, minutes)
end
-- 真实撤离时间（秒，来自服务器/传送数据）
local _escopeTimeReal = GameConfig.DefaultEscapeTime
-- 游戏时间视角下的撤离时间（秒，用于UI展示）
local _escopeTime = RealToGameSeconds(_escopeTimeReal)
local _taskGoldFrame = _topFrame:WaitForChild("TaskGoldFrame")
local _taskGoldLabelFrame = _taskGoldFrame:WaitForChild("TaskGoldLabelFrame")
local _taskCurGoldLabel = _taskGoldLabelFrame:WaitForChild("TaskCurGoldLabel")
_taskCurGoldLabel.Text = ""
local _taskTargetGoldLabel = _taskGoldLabelFrame:WaitForChild("TaskTargetGoldLabel")
_taskTargetGoldLabel.Text = ""
local _taskTargetGoldProgress = _taskGoldFrame:WaitForChild("TaskTargetGoldProgress")
_taskTargetGoldProgress.Size = UDim2.new(0, 0, 1, 0)
local _escapeButton = _topFrame:WaitForChild("EscapeButton")
_escapeButton.MouseButton1Down:Connect(function(x, y)
	if _escapeButton:FindFirstChild("Frame").Visible then
		return
	end

	local isOnBoat = Interface.isPlayerOnBoat(game.Players.LocalPlayer, _G.ClientData.IslandName)
	if not isOnBoat then
		Knit.GetController("UIController").ShowTip:Fire({Type = 1, Text = "Proceed to the Extraction Point!"})
		return
	end
	Knit.GetService("SettleService"):Settle(true):andThen(function(isSucc)
		if not isSucc then
			Knit.GetController("UIController").ShowTip:Fire({Type = 1, Text = "Proceed to the Extraction Point!"})
		else
			local Sound = Interface.safeWaitPart(game:GetService("SoundService"), "UI")
			local music = Interface.safeWaitPart(Sound, "Escape")
			if not music.IsLoaded then
				music.Loaded:Wait()
			end
			music:Play()
		end
	end)
end)

local _goldFrame = _leftFrame:WaitForChild("GoldFrame")
local _goldLabel = _goldFrame:WaitForChild("GoldLabel")
_goldLabel.Text = "0"

local _swingButton = _rightFrame:WaitForChild("SwingButton")
_swingButton.Visible = false
local _dropButton = _rightFrame:WaitForChild("DropButton")
_dropButton.Visible = false

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
		Interface.AnimateNumberIncrease(_taskCurGoldLabel, curEscapeTask)
	else
		_taskCurGoldLabel.Text = curEscapeTask
	end
	_taskTargetGoldLabel.Text = string.format("/%s", escapeTask)
	Interface.TweenProgressBarSize(_taskTargetGoldProgress, curEscapeTask / escapeTask, 0.4)
	if curEscapeTask >= escapeTask then
		-- 目标达成时启动颜色脉冲循环：1秒到黑色，再1秒回原色，持续循环（函数级注释）
		Interface.StartPulseGuiColorLoop(_taskTargetGoldProgress, Color3.new(0, 0, 0), 1.0, 1.0)
	else
		-- 未达成或回退时停止颜色脉冲循环
		Interface.StopPulseGuiColorLoop(_taskTargetGoldProgress)
	end
	_escapeButton:WaitForChild("Frame").Visible = not isTaskDone
end

local _slots = {}
local _toolData = {}
local _cdTween = {}
local _bags = {}
local _bagData = {}

-- 拖拽相关变量
local isDragging = false
local dragConnection = nil
local startDragIndex = 0
local isWaitingForDrag = false
local dragStartPosition = nil

local function stopCD(slotIndex)
	local parent = nil
	if slotIndex <= GameConfig.SLOT_NUM then
		parent = _slots[slotIndex]
	elseif slotIndex <= GameConfig.SLOT_NUM + GameConfig.BAG_NUM then
		parent = _bags[slotIndex - GameConfig.SLOT_NUM]
	end

	if _cdTween[slotIndex] then
		_cdTween[slotIndex]:Cancel()
		_cdTween[slotIndex] = nil
	end
	local clipFrame = parent:FindFirstChild("DJSFrame")
	clipFrame.Visible = false
	clipFrame.Size = UDim2.new(1, 0, 1, 0)
end

local function startCD(slotIndex, endTime, CD)
	local parent = nil
	if slotIndex <= GameConfig.SLOT_NUM then
		parent = _slots[slotIndex]
	elseif slotIndex <= GameConfig.SLOT_NUM + GameConfig.BAG_NUM then
		parent = _bags[slotIndex - GameConfig.SLOT_NUM]
	end

	if not parent then
		return
	end

	stopCD(slotIndex)

	local curTime = tick()
	local duration = endTime - curTime
	if duration <= 0 then
		return
	end

	local clipFrame = parent:FindFirstChild("DJSFrame")
	clipFrame.Visible = true
	clipFrame.Size = UDim2.new(1, 0, duration / CD, 0)
	-- 倒计时动画（从上到下裁切）
	local tweenInfo = TweenInfo.new(
		duration, -- 倒计时总时长
		Enum.EasingStyle.Linear, -- 线性动画
		Enum.EasingDirection.InOut,
		0, -- 不重复
		false -- 不反向
	)
	_cdTween[slotIndex] = game:GetService("TweenService"):Create(clipFrame, tweenInfo, {
		Size = UDim2.new(1, 0, 0, 0)
	})

	_cdTween[slotIndex]:Play()

	-- 动画完成后清理
	_cdTween[slotIndex].Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed then
			clipFrame.Visible = false
			_cdTween[slotIndex] = nil
			parent:SetAttribute("CDEndTime", 0)
		elseif playbackState == Enum.PlaybackState.Cancelled then
			print("动画被取消")
		end
	end)
end

local function updateTool(isSendMessage)
	for index = 1, GameConfig.SLOT_NUM do
		local slot = _slots[index]
		local itemData = _toolData[index]
		local iconImage = Interface.safeWaitPart(slot, "IconImage")
		local priceLabel = slot:WaitForChild("PriceLabel")
		local useNumLabel = slot:WaitForChild("UseNumLabel")
		local weightLabel = slot:WaitForChild("WeightLabel")
		if itemData and itemData.ItemId ~= 0 then
			local itemInfo = ItemConfig:GetByItemId(itemData.ItemId)
			if not itemInfo then
				iconImage.Visible = false
				useNumLabel.Visible = false
				weightLabel.Visible	= false
				slot:WaitForChild("UIStroke").Enabled = false
				slot:SetAttribute("ItemId", nil)
				continue
			end
			iconImage.Visible = true
			iconImage.Image = itemInfo.Icon
			slot:WaitForChild("UIStroke").Enabled = tonumber(itemData.Attribute.IsEquipped) == 1
			slot:SetAttribute("ItemId", itemData.ItemId)
			GameConfig.SetItemAttribute(slot, itemData.Attribute)
			if itemInfo.Type == GameConfig.ItemType.Collect then
				priceLabel.Visible = true
				priceLabel.Text = itemInfo.SellPrice
			else
				priceLabel.Visible = false
			end

			weightLabel.Visible	= true
			weightLabel.Text = itemInfo.Weight .. "KG"
			if itemInfo.Weight <= 1 then
				weightLabel.TextColor3 = Color3.new(0, 255, 0)
			elseif itemInfo.Weight <= 5 then
				weightLabel.TextColor3 = Color3.new(255, 255, 0)
			else
				weightLabel.TextColor3 = Color3.new(255, 0, 0)
			end

			if itemInfo.Duration > 0 then
				useNumLabel.Visible = true
				useNumLabel.Text = math.floor(math.max(0, itemInfo.Duration - itemData.Attribute.UsedTime or 0))
			elseif itemInfo.TimeUsed > 0 then
				useNumLabel.Visible = true
				useNumLabel.Text = math.floor(math.max(0, itemInfo.TimeUsed - itemData.Attribute.UsedNum or 0))
			else
				useNumLabel.Visible = false
			end

			local CDElapsedTime = itemData.Attribute.CDElapsedTime
			local currentTime = tick()
			if CDElapsedTime > currentTime then
				startCD(index, CDElapsedTime, itemInfo.CD)
			else
				stopCD(index)
			end
		else
			iconImage.Visible = false
			priceLabel.Visible = false
			useNumLabel.Visible = false
			weightLabel.Visible = false
			slot:WaitForChild("UIStroke").Enabled = false
			slot:SetAttribute("ItemId", nil)
			stopCD(index)
		end
	end

	if isSendMessage then
		Knit.GetService("InventoryService"):UpdateToolData(_toolData)
	end
end

local function updateBag(isSendMessage)
	for index = 1, GameConfig.BAG_NUM do
		local slot = _bags[index]
		local itemData = _bagData[index]
		local iconImage = Interface.safeWaitPart(slot, "IconImage")
		local priceLabel = slot:WaitForChild("PriceLabel")
		local useNumLabel = slot:WaitForChild("UseNumLabel")
		local weightLabel = slot:WaitForChild("WeightLabel")
		if itemData and itemData.ItemId ~= 0 then
			local itemInfo = ItemConfig:GetByItemId(itemData.ItemId)
			if not itemInfo then
				iconImage.Visible = false
				useNumLabel.Visible = false
				weightLabel.Visible = false
				slot:WaitForChild("UIStroke").Enabled = false
				slot:SetAttribute("ItemId", nil)
				continue
			end
			iconImage.Visible = true
			iconImage.Image = itemInfo.Icon
			slot:WaitForChild("UIStroke").Enabled = tonumber(itemData.Attribute.IsEquipped) == 1
			slot:SetAttribute("ItemId", itemData.ItemId)
			GameConfig.SetItemAttribute(slot, itemData.Attribute)
			if itemInfo.Type == GameConfig.ItemType.Collect then
				priceLabel.Visible = true
				priceLabel.Text = itemInfo.SellPrice
			else
				priceLabel.Visible = false
			end

			weightLabel.Visible	= true
			weightLabel.Text = itemInfo.Weight .. "KG"
			if itemInfo.Weight <= 1 then
				weightLabel.TextColor3 = Color3.new(0, 255, 0)
			elseif itemInfo.Weight <= 5 then
				weightLabel.TextColor3 = Color3.new(255, 255, 0)
			else
				weightLabel.TextColor3 = Color3.new(255, 0, 0)
			end

			if itemInfo.Duration > 0 then
				useNumLabel.Visible = true
				useNumLabel.Text = math.floor(math.max(0, itemInfo.Duration - itemData.Attribute.UsedTime or 0))
			elseif itemInfo.TimeUsed > 0 then
				useNumLabel.Visible = true
				useNumLabel.Text = math.floor(math.max(0, itemInfo.TimeUsed - itemData.Attribute.UsedNum or 0))
			else
				useNumLabel.Visible = false
			end

			local CDElapsedTime = itemData.Attribute.CDElapsedTime
			local currentTime = tick()
			if CDElapsedTime > currentTime then
				startCD(index + GameConfig.SLOT_NUM, CDElapsedTime, itemInfo.CD)
			else
				stopCD(index + GameConfig.SLOT_NUM)
			end
		else
			iconImage.Visible = false
			priceLabel.Visible = false
			useNumLabel.Visible = false
			weightLabel.Visible = false
			slot:WaitForChild("UIStroke").Enabled = false
			slot:SetAttribute("ItemId", nil)
			stopCD(index + GameConfig.SLOT_NUM)
		end
	end

	if isSendMessage then
		Knit.GetService("InventoryService"):UpdateBagData(_bagData)
	end
end

local function discardItem()
	-- 按F键丢弃物品
	for index, itemData in pairs(_toolData) do
		local attribute = itemData.Attribute
		if tonumber(attribute.IsEquipped) == 1 then
			local itemInfo = ItemConfig:GetByItemId(itemData.ItemId)
			if not itemInfo then
				return
			end

			if itemInfo.Type == GameConfig.ItemType.Chest then
				Knit.GetService("InventoryService"):DiscardBag(index)
			else
				Knit.GetService("InventoryService"):DiscardTool(index)
			end
			break
		end
	end
end

_swingButton.MouseButton1Down:Connect(function(x, y)
	for index, itemData in pairs(_toolData) do
		if tonumber(itemData.Attribute.IsEquipped) == 1 then
			local itemInfo = ItemConfig:GetByItemId(itemData.ItemId)
			if not itemInfo then
				return
			end

			if itemInfo.Type >= GameConfig.ItemType.Explore and itemInfo.Type <= GameConfig.ItemType.Assistance then
				Knit.GetService("InventoryService"):ActivateTool(index)
			end
			return
		end
	end
end)

_dropButton.MouseButton1Down:Connect(function(x, y)
	discardItem()
	_dropButton.Visible = false
end)

local function equipTool(slot)
	Knit.GetService("InventoryService"):PressKeyBind(slot):andThen(function(returnFlag, toolData)
		-- returnFlag：1为卸下工具，2为装备工具
		if returnFlag == 1 or returnFlag == 2 then
			local equipItemInfo = nil
			for index, itemData in pairs(toolData) do
				_toolData[tonumber(index)] = itemData
				if tonumber(itemData.Attribute.IsEquipped) == 1 then
					equipItemInfo = ItemConfig:GetByItemId(itemData.ItemId)
				end
			end
			updateTool(false)

			if Interface.isMobile() then
				if returnFlag == 1 then
					_dropButton.Visible = false
					_swingButton.Visible = false
				else
					_dropButton.Visible = true
					_swingButton.Visible = false
					if equipItemInfo 
						and equipItemInfo.Type >= GameConfig.ItemType.Explore
						and equipItemInfo.Type <= GameConfig.ItemType.Assistance then
						_swingButton.Visible = true
						_swingButton:FindFirstChild("IconImage").Image = equipItemInfo.Icon
						if equipItemInfo.Type == GameConfig.ItemType.Weapon then
							_swingButton:FindFirstChild("TextLabel").Text = "Swing"
						else
							_swingButton:FindFirstChild("TextLabel").Text = "Use"
						end
					end
				end
			end
		end
	end)
end

-- 检查鼠标位置是否在Slot范围内
-- @param slot Frame 要检查的Slot
-- @param mousePosition Vector2 鼠标位置
-- @return boolean 是否在范围内
local function isMouseInFrame(frame, mousePosition)
	local absolutePosition = frame.AbsolutePosition + guiInset
	local absoluteSize = frame.AbsoluteSize

	local inBounds = mousePosition.X >= absolutePosition.X and
		mousePosition.X <= absolutePosition.X + absoluteSize.X and
		mousePosition.Y >= absolutePosition.Y and
		mousePosition.Y <= absolutePosition.Y + absoluteSize.Y

	return inBounds
end

local function findTargetSlot(mousePosition)
	local targetSlot = nil
	local targetType = 0
	for i = 1, GameConfig.SLOT_NUM do
		local slot = _slots[i]
		if isMouseInFrame(slot, mousePosition) then
			return slot, 1
		end
	end

	if _bagFrame.Visible then
		for i = GameConfig.SLOT_NUM + 1, GameConfig.SLOT_NUM + GameConfig.BAG_NUM do
			local slot = _bags[i - GameConfig.SLOT_NUM]
			if isMouseInFrame(slot, mousePosition) then
				return slot, 2
			end
		end
	end
	return targetSlot, targetType
end

-- 开始拖拽
-- @param itemInfo table 物品信息
local function startDrag(itemInfo, x, y)
	if isDragging then
		return
	end

	isDragging = true

	-- 显示拖拽图像
	Knit.GetController("UIController").ShowDragUI:Fire(itemInfo.Icon, Vector2.new(x, y), false)

	-- 连接鼠标移动事件
	dragConnection = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local mousePosition = UserInputService:GetMouseLocation()

			-- 更新拖拽图像位置
			Knit.GetController("UIController").MoveDragUI:Fire(Vector2.new(mousePosition.X, mousePosition.Y))

			-- 检查是否在MainUI槽位范围内
			local targetSlot = findTargetSlot(mousePosition)

			-- 显示或隐藏丢弃标签
			if targetSlot then
				Knit.GetController("UIController").ShowDragUI:Fire(itemInfo.Icon, Vector2.new(mousePosition.X, mousePosition.Y), false)
			else
				Knit.GetController("UIController").ShowDragUI:Fire(itemInfo.Icon, Vector2.new(mousePosition.X, mousePosition.Y), true)
			end
		end
	end)
end

local function toolToTool(startSlot, targetSlot)
	if startSlot ~= targetSlot then
		local targetIndex = tonumber(targetSlot.Name)
		local startData = _toolData[startDragIndex]
		local targetData = _toolData[targetIndex]
		if targetData.ItemId > 0 then	-- 如果目标槽有工具，则互换
			_toolData[startDragIndex] = targetData
			_toolData[targetIndex] = startData
		else
			_toolData[startDragIndex] = {ItemId = 0, Attribute = GameConfig.GetItemAttribute()}
			_toolData[targetIndex] = startData
		end
		updateTool(true)
	else
		equipTool(startDragIndex)
	end
end

local function toolToBag(startSlot, targetSlot)
	local targetIndex = tonumber(targetSlot.Name)
	local startData = _toolData[startDragIndex]
	local targetData = _bagData[targetIndex]
	if targetData.ItemId > 0 then	-- 如果目标槽有工具，则互换
		_toolData[startDragIndex] = targetData
		_bagData[targetIndex] = startData
	else
		-- 特殊处理，额外的背包不能拖进自己展开的背包里
		if startData.ItemId == GameConfig.AdditionalBackpackId then
			return
		end
		_toolData[startDragIndex] = {ItemId = 0, Attribute = GameConfig.GetItemAttribute()}
		_bagData[targetIndex] = startData
	end
	updateTool(true)
	updateBag(true)
end

local function bagToTool(startSlot, targetSlot)
	local startIndex = tonumber(startSlot.Name)
	local targetIndex = tonumber(targetSlot.Name)
	local startData = _bagData[startIndex]
	local targetData = _toolData[targetIndex]
	if targetData.ItemId > 0 then	-- 如果目标槽有工具，则互换
		_bagData[startIndex] = targetData
		_toolData[targetIndex] = startData
	else
		_bagData[startIndex] = {ItemId = 0, Attribute = GameConfig.GetItemAttribute()}
		_toolData[targetIndex] = startData
	end
	updateTool(true)
	updateBag(true)
end

local function bagToBag(startSlot, targetSlot)
	if startSlot ~= targetSlot then
		local startIndex = tonumber(startSlot.Name)
		local targetIndex = tonumber(targetSlot.Name)
		local startData = _bagData[startIndex]
		local targetData = _bagData[targetIndex]
		if targetData.ItemId > 0 then	-- 如果目标槽有工具，则互换
			_bagData[startIndex] = targetData
			_bagData[targetIndex] = startData
		else
			_bagData[startIndex] = {ItemId = 0, Attribute = GameConfig.GetItemAttribute()}
			_bagData[targetIndex] = startData
		end
		updateBag(true)
	end
end

local function discardTool()
	local content = "Drop item?"
	local index = startDragIndex
	local itemData = _toolData[index]
	if not itemData then
		return
	end
	local itemInfo = ItemConfig:GetByItemId(itemData.ItemId)
	if itemInfo then
		content = string.format("Drop %s?", itemInfo.DisplayName)
	end
	Knit.GetController("UIController").ShowMessageBoxUI:Fire({
		Button1Callfunc = function()
			Knit.GetService("InventoryService"):DiscardTool(index)
		end,
		Content = content,
	})
end

local function discardBag()
	local content = "Drop item?"
	local startIndex = startDragIndex - GameConfig.SLOT_NUM
	local itemData = _bagData[startIndex]
	if not itemData then
		return
	end
	local itemInfo = ItemConfig:GetByItemId(itemData.ItemId)
	if itemInfo then
		content = string.format("Drop %s?", itemInfo.DisplayName)
	end
	Knit.GetController("UIController").ShowMessageBoxUI:Fire({
		Button1Callfunc = function()
			Knit.GetService("InventoryService"):DiscardBag(startIndex)
		end,
		Content = content,
	})
end

-- 结束拖拽
-- @param mousePosition Vector2 鼠标位置
local function endDrag(mousePosition)
	if not isDragging then
		return
	end

	isDragging = false

	-- 断开连接
	if dragConnection then
		dragConnection:Disconnect()
		dragConnection = nil
	end

	-- 隐藏拖拽图像和丢弃标签
	Knit.GetController("UIController").HideDragUI:Fire()

	if startDragIndex <= GameConfig.SLOT_NUM then
		local startSlot = _slots[startDragIndex]
		-- 检查是否放置在有效槽位
		local targetSlot, targetType = findTargetSlot(mousePosition)
		if targetType == 1 then		-- 目标是工具槽
			toolToTool(startSlot, targetSlot)
		elseif targetType == 2 then	-- 目标是背包槽
			toolToBag(startSlot, targetSlot)
		else
			discardTool()
		end
	else
		local startSlot = _bags[startDragIndex - GameConfig.SLOT_NUM]
		-- 检查是否放置在有效槽位
		local targetSlot, targetType = findTargetSlot(mousePosition)
		if targetType == 1 then		-- 目标是工具槽
			bagToTool(startSlot, targetSlot)
		elseif targetType == 2 then	-- 目标是背包槽
			bagToBag(startSlot, targetSlot)
		else
			discardBag()
		end
	end

	startDragIndex = 0
end

for i = 1, GameConfig.SLOT_NUM do
	local slot = _toolFrame:WaitForChild(tostring(i))
	table.insert(_slots, slot)
	slot:SetAttribute("ItemId", 0)
	GameConfig.SetItemAttribute(slot)
	slot:FindFirstChild("UIStroke").Enabled = false
	local clipFrame = slot:FindFirstChild("DJSFrame")
	clipFrame.Visible = false
	-- 拖拽事件
	local iconImage = slot:WaitForChild("IconImage")
	iconImage.MouseButton1Down:Connect(function(x, y)
		if not iconImage.Visible then
			return
		end

		local itemId = slot:GetAttribute("ItemId")
		local itemInfo = ItemConfig:GetByItemId(itemId)
		if not itemInfo then
			return
		end

		-- 开始等待拖拽状态
		isWaitingForDrag = true
		startDragIndex = i
		dragStartPosition = Vector2.new(x, y)

		-- 设置0.5秒延迟计时器
		task.spawn(function()
			task.wait(GameConfig.Item_DragTime)
			-- 如果0.5秒后仍在等待状态，开始拖拽
			if isWaitingForDrag then
				isWaitingForDrag = false
				startDrag(itemInfo, dragStartPosition.X, dragStartPosition.Y)
			end
		end)
	end)
end

for i = 1, GameConfig.BAG_NUM do
	local slot = _bagFrame:WaitForChild(tostring(i))
	table.insert(_bags, slot)
	_bagData[i] = {ItemId = 0, Attribute = GameConfig.GetItemAttribute()}

	slot:SetAttribute("ItemId", 0)
	GameConfig.SetItemAttribute(slot)
	slot:FindFirstChild("UIStroke").Enabled = false
	local clipFrame = slot:FindFirstChild("DJSFrame")
	clipFrame.Visible = false
	-- 拖拽事件
	local iconImage = slot:WaitForChild("IconImage")
	iconImage.MouseButton1Down:Connect(function(x, y)
		if not iconImage.Visible then
			return
		end

		local itemId = slot:GetAttribute("ItemId")
		local itemInfo = ItemConfig:GetByItemId(itemId)
		if not itemInfo then
			return
		end

		-- 开始等待拖拽状态
		isWaitingForDrag = true
		startDragIndex = GameConfig.SLOT_NUM + i
		dragStartPosition = Vector2.new(x, y)

		-- 设置0.5秒延迟计时器
		task.spawn(function()
			task.wait(GameConfig.Item_DragTime)
			-- 如果0.5秒后仍在等待状态，开始拖拽
			if isWaitingForDrag then
				isWaitingForDrag = false
				startDrag(itemInfo, dragStartPosition.X, dragStartPosition.Y)
			end
		end)
	end)
end
updateBag()

-- 监听鼠标释放事件
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		if isDragging then
			-- 如果正在拖拽，结束拖拽
			local mousePosition = UserInputService:GetMouseLocation()
			endDrag(mousePosition)
		elseif isWaitingForDrag then
			-- 如果在等待拖拽状态（0.5秒内松开），执行点击逻辑
			isWaitingForDrag = false
			if startDragIndex > 0 and startDragIndex <= GameConfig.SLOT_NUM then
				equipTool(startDragIndex)
				startDragIndex = 0
			end
		end
	elseif input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode.Value >= Enum.KeyCode.One.Value and input.KeyCode.Value <= Enum.KeyCode.Six.Value then
		-- 确定按键对应的槽位
		local slot = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
		equipTool(slot)
	elseif input.KeyCode == Enum.KeyCode.F then
		-- 按F键丢弃物品
		discardItem()
	end
end)

-- 播放拾取物品图标淡入/停留/淡出动画（函数级注释）：
-- @param imageLabel ImageLabel 要播放动画的图像标签
-- @param fadeIn number 淡入时长（秒），从不可见到完全可见
-- @param hold number 停留时长（秒），保持完全可见
-- @param fadeOut number 淡出时长（秒），从完全可见到不可见
local function PlayItemImageFade(imageLabel, fadeIn, hold, fadeOut)
	-- 先取消上一轮可能仍在进行的补间
	if _itemImageFadeTween then _itemImageFadeTween:Cancel() end
	_itemImageFadeTween = nil

	imageLabel.Visible = true
	imageLabel.ImageTransparency = 1

	-- 淡入
	local inInfo = TweenInfo.new(fadeIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	_itemImageFadeTween = TweenService:Create(imageLabel, inInfo, { ImageTransparency = 0 })
	_itemImageFadeTween:Play()
	_itemImageFadeTween.Completed:Wait()

	-- 停留
	task.wait(hold)

	-- 淡出
	local outInfo = TweenInfo.new(fadeOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	_itemImageFadeTween = TweenService:Create(imageLabel, outInfo, { ImageTransparency = 1 })
	_itemImageFadeTween:Play()
	_itemImageFadeTween.Completed:Wait()

	imageLabel.Visible = false
end

Knit.OnStart():andThen(function()
	_goldLabel.Text = _G.ClientData.Gold
	local UIController = Knit.GetController("UIController")
	UIController.ChangeGoldUI:Connect(function(gold)
		Interface.AnimateNumberIncrease(_goldLabel, gold)
	end)
	UIController.UpdateToolUI:Connect(function(toolData)
		_toolData = {}
		for _, itemData in pairs(toolData) do
			table.insert(_toolData, itemData)
		end
		updateTool(false)
	end)

	_toolData = {}
	for _, itemData in pairs(_G.ClientData.ToolData) do
		table.insert(_toolData, itemData)
	end
	updateTool(false)

	UIController.UpdateBagUI:Connect(function(bagData)
		_bagData = {}
		for index, itemData in pairs(bagData) do
			table.insert(_bagData, itemData)
		end
		updateBag(false)
	end)
	UIController.InitTaskUI:Connect(function(taskTable)
		for i, task in pairs(taskTable) do
		end
	end)
	UIController.UpdateTaskUI:Connect(function(task)
	end)
	UIController.UpdateEscapeTask:Connect(function(curEscapeTask, escapeTask)
		updateTaskLabel(curEscapeTask, escapeTask)
	end)
	updateTaskLabel(_G.ClientData.CurEscapeTask, _G.ClientData.EscapeTask)

	UIController.ShowAdditionalBackpackUI:Connect(function(isShow)
		_bagFrame.Visible = isShow
	end)
	
	UIController.PickUpItem:Connect(function(itemInfo)
		if not itemInfo then return end

		_itemImageLabel.Image = itemInfo.Icon
		PlayItemImageFade(_itemImageLabel, 0.5, 2.0, 0.5)
	end)

	local teleportData = TeleportService:GetLocalPlayerTeleportData()
	if teleportData and teleportData.EscapeTime then
		-- 传入为真实秒数，转化为游戏时间用于显示
		_escopeTimeReal = teleportData.EscapeTime
		_escopeTime = RealToGameSeconds(_escopeTimeReal)
	end
	_taskTipLabel.Text = FormatGameClock(_escopeTime)

	game:GetService("RunService").Heartbeat:Connect(function(dt)
		-- 真实时间流逝：用于保持与服务器一致
		_escopeTimeReal -= dt
		-- 转化为游戏时间秒数用于显示
		_escopeTime = math.max(0, RealToGameSeconds(_escopeTimeReal))
		if _escopeTime <= 30 then
			_taskTipLabel.TextColor3 = Color3.new(0.858823, 0.184313, 0.184313)
		end
		_taskTipLabel.Text = FormatGameClock(_escopeTime)
	end)
end)
