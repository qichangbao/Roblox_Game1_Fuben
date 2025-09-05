local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local guiInset = game:GetService("GuiService"):GetGuiInset()
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local Players = game:GetService("Players")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local screenGui = script.Parent
local leftFrame = screenGui:WaitForChild("left")
local bottomFramd = screenGui:WaitForChild("bottom")
local rightFrame = screenGui:WaitForChild("right")

local goldFrame = leftFrame:WaitForChild("GoldFrame")
local goldLabel = goldFrame:WaitForChild("GoldLabel")
goldLabel.Text = "0"

local _slots = {}
local _toolData = {}

-- 拖拽相关变量
local isDragging = false
local dragConnection = nil
local currentDragItem = nil
local startDragIndex = 0
local isWaitingForDrag = false
local dragStartPosition = nil
local currentEquippedSlot = 0  -- 当前装备的工具槽位

local function updateTool(isSendMessage)
	for index = 1, GameConfig.SLOT_NUM do
		local slot = _slots[index]
		local itemId = _toolData[index]
		local iconImage = slot:WaitForChild("IconImage")
		if itemId then
			local itemInfo = ItemConfig:GetByIndex(itemId)
			if not itemInfo then
				iconImage.Visible = false
				continue
			end
			iconImage.Visible = true
			iconImage.Image = itemInfo.Icon
			slot:SetAttribute("ItemId", itemId)
		else
			iconImage.Visible = false
			slot:SetAttribute("ItemId", nil)
		end
	end

	if isSendMessage then
		Knit.GetService("InventoryService"):UpdateToolData(_toolData)
	end
end

local function equipTool(slot)
	Knit.GetService("InventoryService"):PressKeyBind(slot):andThen(function(index)
		if index then
			_slots[index]:FindFirstChild("UIStroke").Enabled = true
			currentEquippedSlot = index  -- 更新当前装备的槽位
		else
			for i, v in ipairs(_slots) do
				v:FindFirstChild("UIStroke").Enabled = false
			end
			currentEquippedSlot = 0  -- 没有装备工具
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

-- 开始拖拽
-- @param itemInfo table 物品信息
local function startDrag(itemInfo, x, y)
	if isDragging then
		return
	end

	isDragging = true
	currentDragItem = itemInfo

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
			local inSlot = false

			for _, slot in ipairs(_slots) do
				if isMouseInFrame(slot, mousePosition) then
					inSlot = true
					break
				end
			end

			-- 显示或隐藏丢弃标签
			if inSlot then
				Knit.GetController("UIController").ShowDragUI:Fire(itemInfo.Icon, Vector2.new(mousePosition.X, mousePosition.Y), false)
			else
				Knit.GetController("UIController").ShowDragUI:Fire(itemInfo.Icon, Vector2.new(mousePosition.X, mousePosition.Y), true)
			end
		end
	end)
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

	-- 检查是否放置在有效槽位
	local targetSlot = nil

	for _, slot in ipairs(_slots) do
		if isMouseInFrame(slot, mousePosition) then
			targetSlot = slot
			break
		end
	end

	if targetSlot and currentDragItem then
		local startSlot = _slots[startDragIndex]
		if startSlot ~= targetSlot then
			local targetIndex = tonumber(targetSlot.Name)
			local startItemId = _toolData[startDragIndex]
			if _toolData[targetIndex] then	-- 如果目标槽有工具，则互换
				local targetItemId = _toolData[targetIndex]
				_toolData[startDragIndex] = targetItemId
				_toolData[targetIndex] = startItemId
			else
				_toolData[startDragIndex] = nil
				_toolData[targetIndex] = startItemId
			end
			updateTool(true)
		else
			equipTool(startDragIndex)
		end
	else
		-- 在范围外，执行放进背包逻辑
		_toolData[startDragIndex] = nil
		updateTool(true)
		Knit.GetService("InventoryService"):DiscardTool(startDragIndex)
	end

	currentDragItem = nil
	startDragIndex = 0
end

local _toolFrame = bottomFramd:WaitForChild("ToolFrame")
for i = 1, GameConfig.SLOT_NUM do
	local slot = _toolFrame:WaitForChild(tostring(i))
	table.insert(_slots, slot)
	slot:FindFirstChild("UIStroke").Enabled = false
	-- 拖拽事件
	local iconImage = slot:WaitForChild("IconImage")
	iconImage.MouseButton1Down:Connect(function(x, y)
		if not iconImage.Visible then
			return
		end

		local itemId = slot:GetAttribute("ItemId")
		local itemInfo = ItemConfig:GetByIndex(itemId)
		if not itemInfo then
			return
		end

		-- 开始等待拖拽状态
		isWaitingForDrag = true
		startDragIndex = i
		dragStartPosition = Vector2.new(x, y)

		-- 设置0.5秒延迟计时器
		task.spawn(function()
			task.wait(0.5)
			-- 如果0.5秒后仍在等待状态，开始拖拽
			if isWaitingForDrag then
				isWaitingForDrag = false
				startDrag(itemInfo, dragStartPosition.X, dragStartPosition.Y)
			end
		end)
	end)
end

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
			if startDragIndex > 0 then
				equipTool(startDragIndex)
				startDragIndex = 0
			end
		end
	elseif input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.Two or input.KeyCode == Enum.KeyCode.Three 
		or input.KeyCode == Enum.KeyCode.Four or input.KeyCode == Enum.KeyCode.Five or input.KeyCode == Enum.KeyCode.Six 
		or input.KeyCode == Enum.KeyCode.Seven or input.KeyCode == Enum.KeyCode.Eight or input.KeyCode == Enum.KeyCode.Nine then
		local slot = nil
		-- 确定按键对应的槽位
		if input.KeyCode == Enum.KeyCode.One then
			slot = 1
		elseif input.KeyCode == Enum.KeyCode.Two then
			slot = 2
		elseif input.KeyCode == Enum.KeyCode.Three then
			slot = 3
		elseif input.KeyCode == Enum.KeyCode.Four then
			slot = 4
		elseif input.KeyCode == Enum.KeyCode.Five then
			slot = 5
		elseif input.KeyCode == Enum.KeyCode.Six then
			slot = 6
		elseif input.KeyCode == Enum.KeyCode.Seven then
			slot = 7
		elseif input.KeyCode == Enum.KeyCode.Eight then
			slot = 8
		elseif input.KeyCode == Enum.KeyCode.Nine then
			slot = 9
		else
			return
		end
		equipTool(slot)
	end
end)

-- 点击地图使用工具的函数
-- @param position Vector3 点击位置
local function useToolAtPosition()
	if currentEquippedSlot > 0 and _toolData[currentEquippedSlot] then
		local itemId = _toolData[currentEquippedSlot]
		local itemInfo = ItemConfig:GetByIndex(itemId)
		if itemInfo then
			-- 调用服务端使用工具
			Knit.GetService("InventoryService"):UseTool()
		end
	end
end

-- 监听鼠标点击地图事件
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- 如果输入被游戏UI处理了，或者正在拖拽，则不处理
	if gameProcessed or isDragging or isWaitingForDrag then
		return
	end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- 使用工具在点击位置
		useToolAtPosition()
	end
end)

Knit.OnStart():andThen(function()
	local UIController = Knit.GetController("UIController")
	UIController.ChangeGoldUI:Connect(function(gold)
		goldLabel.Text = gold
	end)
	UIController.UpdateToolUI:Connect(function(toolData)
		for index, itemId in pairs(toolData) do
			_toolData[tonumber(index)] = itemId
		end
		updateTool(false)
	end)
end)
