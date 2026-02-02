local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"):WaitForChild("Knit"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local Players = game:GetService("Players")
local Model3DViewer = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Model3DViewer"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local TweenInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))

local _screenGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("StartGameUI")
_screenGui.Enabled = false
local _frame = _screenGui:WaitForChild("Frame")
local _scrollingFrame = _frame:WaitForChild("ScrollingFrame")
local _templateFrame = _scrollingFrame:WaitForChild("Template")
_templateFrame.Visible = false
local _continueButton = _frame:WaitForChild("ContinueButton")
_continueButton.MouseButton1Down:Connect(function(x, y)
	_screenGui.Enabled = false
end)

local _levelFrame = _frame:WaitForChild("LevelFrame")
-- 创建Model3DViewer实例
local viewer = Model3DViewer.new(_levelFrame, {
	size = UDim2.new(1, 0, 1, 0),
	position = UDim2.new(0, 0, 0, 0),
	backgroundColor = Color3.fromRGB(30, 30, 30),
	enableRotation = true,
	enableZoom = false,
	autoRotate = true,
	rotationSpeed = 0.5
})
local chestModel = ReplicatedStorage:WaitForChild("ModelFolder"):WaitForChild("宝箱3"):Clone()
viewer:setModel(chestModel)

local function UpdateUI(difficulty)
	-- 清空现有物品槽（保留模板）
	for _, child in ipairs(_scrollingFrame:GetChildren()) do
		if child:IsA('Frame') and child ~= _templateFrame then
			child:Destroy()
		end
	end
	
	local itemInfos = {}
	for _, itemInfo in ipairs(ItemConfig:GetAll()) do
		if itemInfo and itemInfo.Type == GameConfig.ItemType.Collect then
			table.insert(itemInfos, itemInfo)
		end
	end

	-- 按价格降序排序
	table.sort(itemInfos, function(a, b)
		return a.SellPrice > b.SellPrice
	end)
	-- 取前6个最高价值的物品
	local topSixItems = {}
	local totalPrice = 0
	for i = 1, math.min(6, #itemInfos) do
		local itemInfo = itemInfos[i]
		local newFrame = _templateFrame:Clone()
		newFrame.Name = itemInfo.Item
		newFrame.Visible = true
		newFrame.Parent = _scrollingFrame
		
		local frame = newFrame:WaitForChild("Frame")
		local icon = frame:WaitForChild("IconImage")
		icon.Image = itemInfo.Icon
		local JinseIconImage = frame:WaitForChild("JinseIconImage")
		JinseIconImage.Visible = false
		local ZiseIconImage = frame:WaitForChild("ZiseIconImage")
		ZiseIconImage.Visible = false
		if itemInfo.SellPrice >= 10000 then
			JinseIconImage.Visible = true
		elseif itemInfo.SellPrice >= 3000 then
			ZiseIconImage.Visible = true
		end
		totalPrice += itemInfo.SellPrice
		
		local textButton = newFrame:FindFirstChild("TextButton")
		textButton.MouseButton1Down:Connect(function(x, y)
			Knit.GetController("UIController").ShowItemAttributeUI:Fire(itemInfo.ItemId)
		end)
	end

	local _playersNumValueLabel = _frame:WaitForChild("PlayersNumValueLabel")
	_playersNumValueLabel.Text = #Players:GetPlayers()

	local _totalPriceFrame = _frame:WaitForChild("TotalPriceFrame")
	_totalPriceFrame:WaitForChild("PriceLabel").Text = "Total Price："
	_totalPriceFrame:WaitForChild("Frame"):WaitForChild("TextLabel").Text = totalPrice
end

Knit.OnStart():andThen(function()
	Knit.GetController("UIController").ShowStartGameUI:Connect(function(difficulty)
		if _screenGui.Enabled then return end
		_screenGui.Enabled = true
		TweenInterface.AnimateUIShowScale(_frame)
		UpdateUI(difficulty)
	end)
end)