local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- 初始化Knit框架
local Knit = require(ReplicatedStorage:WaitForChild('Packages'):WaitForChild('Knit'):waitForChild('Knit'))
local Interface = require(ReplicatedStorage:WaitForChild('ToolFolder'):WaitForChild('Interface'))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild('GameConfig'))

local ClientData = {}
ClientData.Inventory = {}
ClientData.ToolData = {}
ClientData.BagData = {}
ClientData.CurEscapeTask = 0    -- 当前完成的撤离任务
ClientData.EscapeTask = 0       -- 目标完成撤离任务
ClientData.Difficulty = GameConfig.Difficulty.Easy -- 难度

local function setInitData(data)
    ClientData.Inventory = data.Inventory or {}
    ClientData.ToolData = data.ToolData or {}
    ClientData.EscapeTask = data.EscapeTask or 0
    ClientData.EscapeTime = data.EscapeTime or 0
    ClientData.Difficulty = data.Difficulty or GameConfig.Difficulty.Easy -- 难度
    -- local playerGui = Interface.safeWaitPart(game.Players.LocalPlayer, "PlayerGui")
	-- local loadingUI = Interface.safeWaitPart(playerGui, "LoadingUI")
    -- loadingUI.Enabled = false
    Knit.GetController("UIController").UpdateToolUI:Fire(ClientData.ToolData)
    Knit.GetController("UIController").UpdateEscapeTask:Fire(ClientData.CurEscapeTask, ClientData.EscapeTask)
    Knit.GetController("UIController").ShowStartGameUI:Fire(ClientData.Difficulty) -- 显示开始游戏UI

    require(script.Parent:WaitForChild("Sound"))
end

local function init()
    local KnitInitClient = require(script.Parent:WaitForChild("KnitInitClient"))
    KnitInitClient.AddListener(function()
        Knit.GetService("PlayerService").GetInitData():andThen(function(data)
            setInitData(data)
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

        Knit.GetService("TaskService").OpenTaskUI:Connect(function()
            Knit.GetController("UIController").OpenTaskUI:Fire()
        end)

        Knit.GetService("ClientUIService").ShowTip:Connect(function(player, tip)
            Knit.GetController("UIController").ShowTip:Fire(player, tip)
        end)

        Knit.GetService("ClientUIService").ShowUI:Connect(function(player, ui)
            if ui == "DangerUI" then
                Knit.GetController("UIController").ShowDangerUI:Fire(player)
            end
        end)

        Knit.GetService("SettleService").SendShowUI:Connect(function(player, data)
            Knit.GetController("UIController").ShowSettleUI:Fire(player, data)
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
    end)
end

init()

return ClientData