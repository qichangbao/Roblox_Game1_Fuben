local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- 初始化Knit框架
local Knit = require(ReplicatedStorage:WaitForChild('Packages'):WaitForChild('Knit'):waitForChild('Knit'))
Knit.AddControllers(script.Parent:WaitForChild('ControllersFolder'))

_G.ClientData = require(game.Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("ClientData"))

-- 等待RemoteEvent创建
local isServerStartOverEvent = ReplicatedStorage:WaitForChild("IsServerStartOver")

-- 向服务器发送启动状态查询
-- @return void
local function checkServerStartStatus()
    print("向服务器发送启动状态查询...")
    isServerStartOverEvent:FireServer()
end

-- 处理服务器返回的启动状态
-- @param isStarted boolean 服务器是否已启动完成
isServerStartOverEvent.OnClientEvent:Connect(function(isStarted)
    if isStarted then
        print("服务器已启动完成！")
        
        -- 通知KnitInit服务器已启动完成
        local success, KnitInitClient = pcall(function()
            return require(script.Parent:WaitForChild("KnitInitClient"))
        end)
        
        if success and KnitInitClient then
            print("通知KnitInit执行监听器")
            KnitInitClient.executePendingListeners()
        else
            warn("KnitInitClient执行失败")
        end
    else
        print("服务器尚未启动完成，继续等待...")
        -- 等待1秒后重新查询
        task.wait(1)
        checkServerStartStatus()
    end
end)

local StarterGui = game:GetService("StarterGui")
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

-- 启动Knit框架并初始化系统
Knit.Start():andThen(function()
    -- 开始检查服务器启动状态
    checkServerStartStatus()
end):catch(warn)