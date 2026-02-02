local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))
local TweenInterface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("TweenInterface"))

local _screenGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("SettleUI")
_screenGui.Enabled = false
local _winFrame = _screenGui:WaitForChild("WinFrame")
_winFrame.Visible = false
_winFrame:WaitForChild("TitleImage"):WaitForChild("TextLabel").Text = "NICE JOB"
_winFrame:WaitForChild("ItemsLabel").Text = "Items Extracted："
local _winTurninFrame = _winFrame:WaitForChild("TurninFrame")
_winTurninFrame:WaitForChild("TextLabel").Text = "Turn-in Value："
local _winMonsterFrame = _winFrame:WaitForChild("MonsterFrame")
_winMonsterFrame:WaitForChild("TextLabel").Text = "Monsters Defeated："

local _loseFrame = _screenGui:WaitForChild("LoseFrame")
_loseFrame.Visible = false
_loseFrame:WaitForChild("TitleImage"):WaitForChild("TextLabel").Text = "FAILURE"
_loseFrame:WaitForChild("ItemsLabel").Text = "Items Extracted："
local _loseTurninFrame = _loseFrame:WaitForChild("TurninFrame")
_loseTurninFrame:WaitForChild("TextLabel").Text = "Turn-in Value："
local _loseMonsterFrame = _loseFrame:WaitForChild("MonsterFrame")
_loseMonsterFrame:WaitForChild("TextLabel").Text = "Monsters Defeated："

local _winEscapeButton = _winFrame:WaitForChild("EscapeButton")
_winEscapeButton:WaitForChild("TextLabel").Text = "Back to Spawn"
local _loseEscapeButton = _loseFrame:WaitForChild("EscapeButton")
_loseEscapeButton:WaitForChild("TextLabel").Text = "Back to Spawn"

local _needCheckPos = false

local function escape()
	Knit.GetService("SettleService"):Escape(_needCheckPos):andThen(function(succ)
		if not succ then
			Knit.GetController("UIController").ShowTip:Fire({Type = 1, Text = "Proceed to the Extraction Point!"})
		end
	end)
	_screenGui.Enabled = false
end

_winEscapeButton.MouseButton1Down:Connect(function(x, y)
	escape()
end)

_loseEscapeButton.MouseButton1Down:Connect(function(x, y)
	escape()
end)

local function showBase(frame, data)
	local isWin = false
	if frame == _winFrame then
		isWin = true
	end
	local killMonstersNum = data.KillMonsterNum
	local totalValue = data.TotalValue
	local TurninFrame = Interface.safeWaitPart(frame, "TurninFrame")
	local turninTextLabel = TurninFrame:WaitForChild("Frame"):WaitForChild("TextLabel")
	turninTextLabel.Text = data.TotalValue
	local monsterTextLabel = frame:WaitForChild("MonsterFrame"):WaitForChild("Frame"):WaitForChild("TextLabel")
	monsterTextLabel.Text = data.KillMonsterNum
	
	local levelData = data.LevelData
	local newData = Interface.calculateDuanWei(levelData, isWin)
	local levelConfig = GameConfig.DuanWeiType[newData.duanWei]
	local levelFrame = frame:WaitForChild("LevelFrame")
	local starLabel = levelFrame:WaitForChild("StarLabel")
	if isWin then
		starLabel.Text = "Star+1"
	else
		if levelConfig.allowDeduction then
			starLabel.Text = "Star-1"
		else
			starLabel.Text = "Star-0"
		end
	end
	
	local infoFrame = levelFrame:WaitForChild("InfoFrame")
	local iconImage = infoFrame:WaitForChild("IconImage")
	iconImage.Image = Interface.GetDuanWeiIcon(newData)
	local star3 = infoFrame:WaitForChild("Stars3")
	star3.Visible = false
	local star4 = infoFrame:WaitForChild("Stars4")
	star4.Visible = false
	local star5 = infoFrame:WaitForChild("Stars5")
	star5.Visible = false
	if levelConfig.levelStarNum > 0 then
		local curStarFrame = nil
		if levelConfig.levelStarNum == 3 then
			curStarFrame = star3
		elseif levelConfig.levelStarNum == 4 then
			curStarFrame = star4
		elseif levelConfig.levelStarNum == 5 then
			curStarFrame = star5
		end
		curStarFrame.Visible = true
		for i = 1, newData.star do
			local starImage = curStarFrame:WaitForChild("Star" .. i)
			starImage.Image = "rbxassetid://133652567414188"
		end
	end
end

local function showWin(data)
	local items = data.EscapeItems
	
	showBase(_winFrame, data)
	
	local scrollingFrame = _winFrame:WaitForChild("ScrollingFrame")
	local templateFrame = scrollingFrame:WaitForChild("Template")
	templateFrame.Visible = false
	-- 清空现有物品槽（保留模板）
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA('Frame') and child ~= templateFrame then
			child:Destroy()
		end
	end
	
	for _, itemData in ipairs(items) do
		local itemInfo = ItemConfig:GetByItemId(itemData.ItemId)
		if itemInfo and itemInfo.Type == GameConfig.ItemType.Collect then
			local newFrame = templateFrame:Clone()
			local icon = newFrame:WaitForChild("Frame"):WaitForChild("IconImage")
			icon.Image = itemInfo.Icon
			newFrame.Visible = true
			newFrame.Name = itemInfo.Item
			newFrame.Parent = scrollingFrame
		end
	end

	local ui = game:GetService("SoundService"):WaitForChild("UI")
	local sound = ui:WaitForChild("EscapeSucc")
	sound:Play()
end

local function showLose(data)
	local items = data.EscapeItems

	showBase(_loseFrame, data)

	local ui = game:GetService("SoundService"):WaitForChild("UI")
	local sound = ui:WaitForChild("EscapeFail")
	sound:Play()
end

Knit.OnStart():andThen(function()
	Knit.GetController("UIController").ShowSettleUI:Connect(function(data)
		if _screenGui.Enabled then return end
		_screenGui.Enabled = true
		if data.IsSuccess then
			TweenInterface.AnimateUIShowScale(_winFrame)
		else
			TweenInterface.AnimateUIShowScale(_loseFrame)
		end
		_winFrame.Visible = data.IsSuccess
		_loseFrame.Visible = not data.IsSuccess
		_needCheckPos = data.needCheckPos

		local ui = game:GetService("SoundService"):WaitForChild("UI")
		local sound = ui:WaitForChild("Escape")
		sound:Play()
		if data.IsSuccess then
			showWin(data)
		else
			showLose(data)
		end
	end)
end)