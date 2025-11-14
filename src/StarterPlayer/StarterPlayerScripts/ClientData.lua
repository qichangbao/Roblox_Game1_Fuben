local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- 初始化Knit框架
local Knit = require(ReplicatedStorage:WaitForChild('Packages'):WaitForChild('Knit'):waitForChild('Knit'))
local Interface = require(ReplicatedStorage:WaitForChild('ToolFolder'):WaitForChild('Interface'))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild('GameConfig'))
local SimpleArrowNavigation = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("SimpleArrowNavigation"))

local ClientData = {}
ClientData.Gold = 0
ClientData.Inventory = {}
ClientData.ToolData = {}
ClientData.BagData = {}
ClientData.CurEscapeTask = 0    -- 当前完成的撤离任务
ClientData.EscapeTask = 0       -- 目标完成撤离任务
ClientData.Difficulty = GameConfig.Difficulty.Easy -- 难度
ClientData.IsFirstLoginFuben = 0 -- 是否是第一次登录游戏
ClientData.IslandName = GameConfig.LandName -- 岛屿名称
ClientData.Overwhelmed = 0 -- 当前负重
ClientData.MaxOverwhelmed = 0 -- 最大负重

local function setInitData(data)
    ClientData.Inventory = data.Inventory or {}
    ClientData.ToolData = data.ToolData or {}
    ClientData.EscapeTask = data.EscapeTask or 0
    ClientData.EscapeTime = data.EscapeTime or 0
    ClientData.Difficulty = data.Difficulty or GameConfig.Difficulty.Easy -- 难度
    ClientData.IsFirstLoginFuben = data.IsFirstLoginFuben or 0 -- 是否是第一次登录游戏
    ClientData.Gold = data.Gold or 0 -- 金币
    ClientData.IslandName = data.IslandName or GameConfig.LandName -- 岛屿名称
    if ClientData.IsFirstLoginFuben == 0 then
        require(script.Parent:WaitForChild("PlayerGuide")):ShowGuide()
    end
    -- local playerGui = Interface.safeWaitPart(game.Players.LocalPlayer, "PlayerGui")
	-- local loadingUI = Interface.safeWaitPart(playerGui, "LoadingUI")
    -- loadingUI.Enabled = false
    Knit.GetController("UIController").ChangeGoldUI:Fire(ClientData.Gold)
    Knit.GetController("UIController").UpdateToolUI:Fire(ClientData.ToolData)
    Knit.GetController("UIController").UpdateEscapeTask:Fire(ClientData.CurEscapeTask, ClientData.EscapeTask)
    Knit.GetController("UIController").ShowStartGameUI:Fire(ClientData.Difficulty) -- 显示开始游戏UI

    local land = Interface.safeWaitPart(game.Workspace, ClientData.IslandName)
    local Special = Interface.safeWaitPart(land, "Special")
    local SpawnLocation = Interface.safeWaitPart(Special, "SpawnLocation")
    local spawnLocation1 = Interface.safeWaitPart(SpawnLocation, "SpawnLocation1")
    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    if not workspace.CurrentCamera.CameraSubject then
        workspace.CurrentCamera.CameraSubject = spawnLocation1
    end
end

local function showMonsterChaseFlag(monster, isShow)
    if not monster then return end
    local chaseFlag = monster:FindFirstChild("ChaseFlag")
    if not chaseFlag then return end

    -- 根据 isShow 显示/隐藏模型
    for _, obj in ipairs(chaseFlag:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Transparency = isShow and 0 or 1
        end
    end
end

local function init()
    local KnitInitClient = require(script.Parent:WaitForChild("KnitInitClient"))
    KnitInitClient.AddListener(function()
        Knit.GetService("PlayerService").GetInitData():andThen(function(data)
            setInitData(data)
        end)

        -- 监听服务器的发送负重数据请求
        Knit.GetService("PlayerService").UpdateOverwhelmed:Connect(function(overwhelmed, maxOverwhelmed)
            ClientData.Overwhelmed = overwhelmed
            ClientData.MaxOverwhelmed = maxOverwhelmed
            Knit.GetController("UIController").UpdateOverwhelmedUI:Fire(overwhelmed, maxOverwhelmed)
        end)

        -- 监听服务器的发送金币数据请求
        Knit.GetService("GoldService").ChangeGold:Connect(function(gold)
			ClientData.Gold = gold
			Knit.GetController("UIController").ChangeGoldUI:Fire(gold)
		end)

        Knit.GetService("InventoryService").SendToolData:Connect(function(toolData)
            ClientData.ToolData = toolData or {}
			Knit.GetController("UIController").UpdateToolUI:Fire(toolData)
		end)

        Knit.GetService("InventoryService").SendBagData:Connect(function(bagData)
            ClientData.BagData = bagData or {}
			Knit.GetController("UIController").UpdateBagUI:Fire(bagData)
		end)

        Knit.GetService("InventoryService").EquipAdditionalBackpack:Connect(function(equip)
            Knit.GetController("UIController").ShowAdditionalBackpackUI:Fire(equip)
        end)

        Knit.GetService("InventoryService").PlayPickUpSound:Connect(function(itemInfo)
            if not itemInfo then
                return
            end

            local gameSound = Interface.safeWaitPart(game:GetService("SoundService"), "GAME")
            local sound = nil
            if itemInfo.Type == GameConfig.ItemType.Collect then
                if itemInfo.SellPrice > 0 and itemInfo.SellPrice < 3000 then
                    sound = Interface.safeWaitPart(gameSound, "PickUpLow")
                elseif itemInfo.SellPrice >= 3000 and itemInfo.SellPrice < 1000 then
                    sound = Interface.safeWaitPart(gameSound, "PickUpMiddle")
                else
                    sound = Interface.safeWaitPart(gameSound, "PickUpHigh")
                end
            else
                sound = Interface.safeWaitPart(gameSound, "PicpUpSound")
            end
            sound.Looped = false
            sound:Play()
        end)

        Knit.GetService("TaskService").UpdateEscapeTask:Connect(function(curEscapeTask, escapeTask)
            ClientData.CurEscapeTask = curEscapeTask
            ClientData.EscapeTask = escapeTask
            Knit.GetController("UIController").UpdateEscapeTask:Fire(curEscapeTask, escapeTask)
        end)

        Knit.GetService("TaskService").OpenSubmitUI:Connect(function()
            Knit.GetController("UIController").OpenSubmitUI:Fire()
        end)

        Knit.GetService("TaskService").OpenTaskUI:Connect(function(taskId)
            Knit.GetController("UIController").OpenTaskUI:Fire(taskId)
        end)

        Knit.GetService("ClientUIService").ShowTip:Connect(function(tip)
            Knit.GetController("UIController").ShowTip:Fire(tip)
        end)
        -- 监听服务器的触发NPC事件
        Knit.GetService("NPCTrggeredService").Triggered:Connect(function(npcType)
            if npcType == GameConfig.NpcUIType.Store then
                Knit.GetController("UIController").ShowStoreUI:Fire()
            elseif npcType == GameConfig.NpcUIType.Sell then
                Knit.GetController("UIController").ShowSellUI:Fire()
            elseif npcType == GameConfig.NpcUIType.Ability then
                Knit.GetController("UIController").ShowAbilityUI:Fire()
            elseif npcType == GameConfig.NpcUIType.Quest then
                Knit.GetController("UIController").ShowQuestUI:Fire(1)
            end
        end)

        Knit.GetService("ClientUIService").ShowUI:Connect(function(ui, data)
            if ui == "NoticeUI" then
                Knit.GetController("UIController").ShowNoticeUI:Fire(data)
            elseif ui == "MessageBoxUI" then
                Knit.GetController("UIController").ShowMessageBoxUI:Fire(data)
            elseif ui == "DragonOrbLostUI" then
                Knit.GetController("UIController").ShowDragonOrbLostUI:Fire(data)
            end
        end)

        Knit.GetService("ClientUIService").HideUI:Connect(function(ui)
            if ui == "MessageBoxUI" then
                Knit.GetController("UIController").HideMessageBoxUI:Fire()
            end
        end)

        Knit.GetService("ClientUIService").ResetUI:Connect(function(ui)
            if ui == "MessageBoxUI" then
                Knit.GetController("UIController").ResetMessageBoxUI:Fire()
            end
        end)
        
        Knit.GetService("ClientUIService").ShowArrow:Connect(function(targetPosition)
            SimpleArrowNavigation.NavigateTo(targetPosition, nil, 10, true, 0.5)
        end)

        Knit.GetService("ClientUIService").HideArrow:Connect(function()
            SimpleArrowNavigation.ClearPath()
        end)

        Knit.GetService("SettleService").SendShowUI:Connect(function(data)
            Knit.GetController("UIController").HideMessageBoxUI:Fire()
            Knit.GetController("UIController").ShowSettleUI:Fire(data)
        end)

        Knit.GetService("SettleService").SuccEvacuation:Connect(function(userId)
            Knit.GetController("UIController").SuccEvacuation:Fire(userId)
        end)

        Knit.GetService("TeleportService").SendStartTeleport:Connect(function()
			local playerGui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
            if not playerGui then
                return
            end
			local teleportUI = playerGui:FindFirstChild("TeleportUI")
            if not teleportUI then
                return
            end
			
			teleportUI.Enabled = true

            local ui = game:GetService("SoundService"):WaitForChild("UI")
            local sound = ui:WaitForChild("Loading")
            sound:Play()
        end)

        Knit.GetService("MonsterService").Chase:Connect(function(npc, isShow)
            showMonsterChaseFlag(npc, isShow)
        end)

        Knit.GetService("MapService").SendShowFlag:Connect(function(data)
            Knit.GetController("UIController").ShowMapFlag:Fire(data)
        end)

        -- 监听服务器的任务数据请求
        Knit.GetService("QuestService").QuestUpdated:Connect(function(questData)
            ClientData.QuestData = questData or {}
            Knit.GetController("UIController").UpdateQuestData:Fire(ClientData.QuestData)
        end)
    end)
end

init()

return ClientData