local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local TweenInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))

local _screenGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("CaptainPromiseUI")
_screenGui.Enabled = false
local _frame = _screenGui:WaitForChild("Frame")
local _contentFrame = _frame:WaitForChild("ContentFrame")
local _titleImage = _contentFrame:WaitForChild("TitleImage")
local _closeButton = _titleImage:WaitForChild("CloseButton")
_closeButton.MouseButton1Click:Connect(function()
	_screenGui.Enabled = false
end)

local _submitButton = _contentFrame:WaitForChild("SubmitButton")
_submitButton.MouseButton1Click:Connect(function()
	local tools = {}
	local bags = {}
	local bagIndex = 0
	for index, toolData in ipairs(_G.ClientData.ToolData) do
		local itemId = toolData.ItemId
		local itemInfo = ItemConfig:GetByItemId(itemId)
		if not itemInfo then continue end
		if itemId == 6 then
			bagIndex = index
		end
		if itemInfo.Type ~= GameConfig.ItemType.Collect then continue end
		table.insert(tools, index)
	end
	for index, bagData in ipairs(_G.ClientData.BagData) do
		local itemId = bagData.ItemId
		local itemInfo = ItemConfig:GetByItemId(itemId)
		if not itemInfo then continue end
		if itemInfo.Type ~= GameConfig.ItemType.Collect then continue end
		table.insert(bags, index)
	end
	Knit.GetService("InventoryService"):TurnInCollect(game.Players.LocalPlayer):andThen(function(gold)
		if gold > 0 then
			local PlayerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
			local MainUI = PlayerGui:WaitForChild("MainUI")
			local top = MainUI:WaitForChild("top")
			local bottom = MainUI:WaitForChild("bottom")
			local BagFrame = bottom:WaitForChild("BagFrame")
			local ToolFrame = bottom:WaitForChild("ToolFrame")
			local TaskGoldFrame = top:WaitForChild("TaskGoldFrame")
			for i, index in ipairs(tools) do
				local frame = ToolFrame:FindFirstChild(tostring(index))
				if not frame then continue end
				local image = frame:FindFirstChild("IconImage")
				Knit.GetController("UIController").ShowFlyItemUI:Fire(image, image, TaskGoldFrame)
			end
			if bagIndex ~= 0 then
				local bagItemFrame = ToolFrame:FindFirstChild(tostring(bagIndex))
				if bagItemFrame then
					for i, index in ipairs(bags) do
						local frame = BagFrame:FindFirstChild(tostring(index))
						if not frame then continue end
						local image = frame:FindFirstChild("IconImage")
						Knit.GetController("UIController").ShowFlyItemUI:Fire(image, bagItemFrame, TaskGoldFrame)
					end
				end
			end
			
			if game.Players.LocalPlayer.Character then
				Interface.PlayEffectByName("SubmitItemEffect", game.Players.LocalPlayer.Character:GetPivot(), 30, 2)
			end
			
			local uiSound = Interface.safeWaitPart(game:GetService("SoundService"), "UI")
			local music = Interface.safeWaitPart(uiSound, "SubmitItems")
			if not music.IsLoaded then
				music.Loaded:Wait()
			end
			music:Play()
		end
	end)
	_screenGui.Enabled = false
end)

Knit.OnStart():andThen(function()
	Knit.GetController("UIController").OpenSubmitUI:Connect(function()
		if _screenGui.Enabled then return end
		_screenGui.Enabled = true
		TweenInterface.AnimateUIShowScale(_frame)

		local ui = game:GetService("SoundService"):WaitForChild("UI")
		local sound = ui:WaitForChild("OpenUI")
		sound:Play()
	end)
end)