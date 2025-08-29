local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local Signal = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Signal"))
local PlayerAnimationHnadler = require(script.Parent.Parent.Animation.PlayerAnimationHnadler)

local player = Players.LocalPlayer

-- 背包控制器：处理背包UI交互和工具使用
local BackpackController = Knit.CreateController {
    Name = "BackpackController",
    -- 信号
    BackpackUpdated = Signal.new(),
    ToolEquipped = Signal.new(),
    ToolUnequipped = Signal.new(),
    
    -- 背包数据
    BackpackData = {
        tools = {},
        maxSlots = 10,
        equippedTool = nil,
    },
}

-- 初始化控制器
function BackpackController:KnitInit()
    -- 监听背包数据更新信号
    local BackpackService = Knit.GetService("BackpackService")
    BackpackService.UpdateBackpackData:Connect(function(backpackData)
        self:_UpdateBackpackData(backpackData)
    end)
    -- 监听播放工具动画事件
    BackpackService.PlayToolAnimation:Connect(function()
        local character = player.Character
        if not character then return end
        
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then return end
        
        -- 播放挥舞动画效果
        PlayerAnimationHnadler.playSwingAnimation(character)
    end)
    
    -- 监听角色生成
    if player.Character then
        self:_OnCharacterAdded(player.Character)
    end
    
    player.CharacterAdded:Connect(function(character)
        self:_OnCharacterAdded(character)
    end)
end

-- 启动控制器
function BackpackController:KnitStart()
    -- 请求初始背包数据
    self:RequestBackpackData()
    
    print("BackpackController started")
end

-- 角色生成时的处理
function BackpackController:_OnCharacterAdded(character)
    local humanoid = character:WaitForChild("Humanoid")
    local backpack = player:WaitForChild("Backpack")
    
    -- 监听背包中工具的变化
    backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            self:_OnToolAddedToBackpack(child)
        end
    end)
    
    backpack.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then
            self:_OnToolRemovedFromBackpack(child)
        end
    end)
end

-- 更新背包数据
function BackpackController:_UpdateBackpackData(backpackData)
    self.BackpackData = backpackData
    self.BackpackUpdated:Fire(backpackData)
end

-- 请求背包数据
function BackpackController:RequestBackpackData()
    local backpackData = Knit.GetService("BackpackService"):GetBackpackData()
    if backpackData then
        self:_UpdateBackpackData(backpackData)
    end
end

-- 工具添加到背包事件
function BackpackController:_OnToolAddedToBackpack(tool)
    -- 可以在这里添加特殊处理逻辑
    print("Tool added to backpack:", tool.Name)
end

-- 工具从背包移除事件
function BackpackController:_OnToolRemovedFromBackpack(tool)
    -- 可以在这里添加特殊处理逻辑
    print("Tool removed from backpack:", tool.Name)
end

-- 获取工具数据
function BackpackController:GetToolData(toolId)
    for _, toolData in ipairs(self.BackpackData.tools) do
        if toolData.toolId == toolId then
            return toolData
        end
    end
    return nil
end

-- 获取当前装备的工具
function BackpackController:GetEquippedTool()
    if self.BackpackData.equippedTool then
        return self:GetToolData(self.BackpackData.equippedTool)
    end
    return nil
end

return BackpackController