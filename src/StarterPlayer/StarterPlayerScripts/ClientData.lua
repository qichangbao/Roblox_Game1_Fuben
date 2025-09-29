local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- 初始化Knit框架
local Knit = require(ReplicatedStorage:WaitForChild('Packages'):WaitForChild('Knit'):waitForChild('Knit'))
local DataRetryUtil = require(ReplicatedStorage:WaitForChild('ToolFolder'):WaitForChild('DataRetryUtil'))
local Interface = require(ReplicatedStorage:WaitForChild('ToolFolder'):WaitForChild('Interface'))

local ClientData = {}
ClientData.Gold = 0
ClientData.ToolData = {}
ClientData.BagData = {}
ClientData.CurEscapeTask = 0    -- 当前完成的撤离任务
ClientData.EscapeTask = 0       -- 目标完成撤离任务

-- 添加重试控制器变量
local retryController = nil

local function setInitData(data)
    ClientData.Gold = data.Gold or 0
    ClientData.ToolData = data.ToolData or {}
    local playerGui = Interface.safeWaitPart(game.Players.LocalPlayer, "PlayerGui")
	local loadingUI = Interface.safeWaitPart(playerGui, "LoadingUI")
    loadingUI.Enabled = false
    Knit.GetController("UIController").ChangeGoldUI:Fire(data.Gold)
    Knit.GetController("UIController").UpdateToolUI:Fire(data.ToolData)

    require(script.Parent:WaitForChild("Sound"))
end

local function init()
    local KnitInitClient = require(script.Parent:WaitForChild("KnitInitClient"))
    KnitInitClient.AddListener(function()
        print("ClientData AddListener")

        -- 使用通用重试工具获取登录数据
        retryController = DataRetryUtil.RetryDataFetch(
            function()
                return Knit.GetService("ServerDataService").GetInitData()
            end,
            {
                maxRetries = 15,
                retryDelay = 2,
                operationName = "登录数据获取",
                dataValidator = function(data)
                    return data and type(data) == "table" and data.Gold ~= nil and data.ToolData ~= nil
                end,
                onSuccess = function(data)
                    setInitData(data)
                end,
                onFailure = function(errorMsg)
                    warn("登录数据获取失败:", errorMsg)
                end
            }
        )

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

        Knit.GetService("TaskService").UpdateEscapeTask:Connect(function(curEscapeTask, escapeTask)
            ClientData.CurEscapeTask = curEscapeTask
            ClientData.EscapeTask = escapeTask
            Knit.GetController("UIController").UpdateEscapeTask:Fire(curEscapeTask, escapeTask)
        end)

        Knit.GetService("ServerDataService").SendInitData:Connect(function(data)
            -- 停止重试
            if retryController then
                retryController.stop()
                print("通过SendInitData接收到数据，已停止DataRetryUtil重试")
            end
            
            setInitData(data)
        end)

        Knit.GetService("ServerDataService").ShowTip:Connect(function(player, tip)
            Knit.GetController("UIController").ShowTip:Fire(player, tip)
        end)

        Knit.GetService("SettleService").SendShowUI:Connect(function(player, data)
            Knit.GetController("UIController").ShowSettleUI:Fire(player, data)
        end)

        Knit.GetService("TeleportService").SendStartTeleport:Connect(function()
			local playerGui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
			local loadingUI = playerGui:FindFirstChild("LoadingUI")
			loadingUI.Enabled = true
        end)
    end)
end

init()

return ClientData