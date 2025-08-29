local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))

-- 背包服务：管理玩家背包数据和工具分发
local BackpackService = Knit.CreateService {
    Name = "BackpackService",
    Client = {
        -- 客户端可调用的远程方法
        UpdateBackpackData = Knit.CreateSignal(),
        PlayToolAnimation = Knit.CreateSignal(),
    },
    
    -- 玩家背包数据缓存
    PlayerBackpacks = {},
}

-- 初始化服务
function BackpackService:KnitInit()
    -- 监听玩家加入
    Players.PlayerAdded:Connect(function(player)
        self:_OnPlayerAdded(player)
    end)
    
    -- 监听玩家离开
    Players.PlayerRemoving:Connect(function(player)
        self:_OnPlayerRemoving(player)
    end)
end

-- 启动服务
function BackpackService:KnitStart()
    print("BackpackService started")
end

-- 玩家加入时初始化背包
function BackpackService:_OnPlayerAdded(player)
    -- 等待角色生成
    player.CharacterAdded:Connect(function(character)
        self:_InitializePlayerBackpack(player)
        self:_SetupPlayerBackpack(player, character)
    end)
end

-- 玩家离开时清理数据
function BackpackService:_OnPlayerRemoving(player)
    if self.PlayerBackpacks[player] then
        self.PlayerBackpacks[player] = nil
    end
end

-- 初始化玩家背包数据
function BackpackService:_InitializePlayerBackpack(player)
    if not self.PlayerBackpacks[player] then
        self.PlayerBackpacks[player] = {
            tools = {},
            maxSlots = GameConfig.BackpackSlotCount,
            equippedTool = nil,
        }
    end
end

function BackpackService:ChangeBackpackSlotCount(player, count)
    local playerData = self.PlayerBackpacks[player]
    if not playerData then return end
    
    playerData.maxSlots = count
    -- 通知客户端更新
    self.Client.UpdateBackpackData:Fire(player, playerData)
end

function BackpackService:GetBackpackSlotCount(player)
    local playerData = self.PlayerBackpacks[player]
    if not playerData then return end

    return playerData.maxSlots
end

-- 设置玩家背包（连接到Roblox的Backpack）
function BackpackService:_SetupPlayerBackpack(player, character)
    local backpack = player:WaitForChild("Backpack")
    local humanoid = character:WaitForChild("Humanoid")
    
    -- 清空现有工具
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            tool:Destroy()
        end
    end
    
    -- 根据数据重新创建工具
    self:_RefreshPlayerTools(player)
    
    -- 监听工具装备/卸下
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            self:_OnToolEquipped(player, child)
        end
    end)
    
    character.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then
            self:_OnToolUnequipped(player, child)
        end
    end)
end

-- 刷新玩家工具
function BackpackService:_RefreshPlayerTools(player)
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end
    
    local playerData = self.PlayerBackpacks[player]
    if not playerData then return end
    
    -- 为每个工具创建Tool实例
    for _, toolData in pairs(playerData.tools) do
        local tool = self:_CreateToolInstance(toolData)
        if tool then
            tool.Parent = backpack
        end
    end
end

-- 创建工具实例
function BackpackService:_CreateToolInstance(toolData)
    local template = game.ServerStorage:FindFirstChild(toolData.itemInfo.Model)
    if not template then
        warn("Tool template not found:", toolData.itemInfo.Model)
        return nil
    end
    
    -- 创建新的Tool实例
    local tool = Instance.new("Tool")
    
    -- 设置工具基本属性
    tool.Name = toolData.itemInfo.Item
    tool.ToolTip = toolData.itemInfo.Description or ""
    tool.CanBeDropped = true
    tool.RequiresHandle = true
    tool:SetAttribute("ToolId", toolData.toolId)
    tool:SetAttribute("CD", toolData.cd)
    tool:SetAttribute("Duration", toolData.duration)
    
    -- 设置工具图标（如果ItemConfig中有Icon）
    if toolData.itemInfo.Icon and toolData.itemInfo.Icon ~= "" then
        tool.TextureId = toolData.itemInfo.Icon
    end

    local handle = nil
    
    -- 根据模板类型处理（Model 或 Part）
    if template:IsA("Model") then
        -- 处理 Model 类型的模板
        local templateModel = template:Clone()
        
        -- 确保模型有 PrimaryPart，这是作为 Handle 的关键
        handle = templateModel.PrimaryPart
        if not handle then
            warn("Warning: Tool template '" .. toolData.itemInfo.Item .. "' does not have a PrimaryPart set.")
            -- 备用方案：选择第一个找到的 BasePart
            handle = templateModel:FindFirstChildOfClass("BasePart")
            if not handle then
                warn("Error: Tool template '" .. toolData.itemInfo.Item .. "' contains no parts to use as a handle.")
                return nil
            end
        end

        -- 遍历模型中的所有部件
        for _, part in ipairs(templateModel:GetDescendants()) do
            if part:IsA("BasePart") then
                -- 解除所有部件的锚定
                part.Anchored = false
                -- 将除 PrimaryPart 之外的所有部件焊接到 PrimaryPart
                if part ~= handle then
                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = handle
                    weld.Part1 = part
                    weld.Parent = handle
                end
            end
        end
        
        -- 将 Handle 命名为 "Handle"，这是 Tool 识别握柄的要求
        handle.Name = "Handle"
        handle.Parent = tool

        -- 将模型中除了Handle之外的其他子项也移动到Tool下
        for _, child in ipairs(templateModel:GetChildren()) do
            if child ~= handle then
                child.Parent = tool
            end
        end

        -- 销毁空的模板模型
        templateModel:Destroy()
    elseif template:IsA("BasePart") then
        -- 处理 Part 类型的模板
        handle = template:Clone()
        handle.Name = "Handle"
        handle.Anchored = false
        handle.Parent = tool
        
        -- 遍历Part下的所有子Part并焊接到Handle
        for _, part in ipairs(handle:GetDescendants()) do
            if part:IsA("BasePart") and part ~= handle then
                -- 解除子Part的锚定
                part.Anchored = false
                -- 将子Part焊接到Handle
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = handle
                weld.Part1 = part
                weld.Parent = handle
            end
        end

        -- 将模型中除了Handle之外的其他子项也移动到Tool下
        for _, child in ipairs(handle:GetChildren()) do
            if child ~= handle then
                child.Parent = tool
            end
        end
    else
        warn("Error: Tool template '" .. toolData.itemInfo.Item .. "' is neither a Model nor a BasePart.")
        return nil
    end

    -- 直接设置Tool的Grip属性来控制握持方向
    tool.Grip = CFrame.Angles(0, 0, math.rad(90))  -- 只旋转，不偏移位置
    
    -- 工具状态管理（使用工具属性存储状态，避免装备/卸下时状态丢失）
    tool:SetAttribute("LastActivated", 0)
    
    -- 连接工具装备事件，重置状态
    tool.Equipped:Connect(function()
        -- 工具装备时重置处理状态，防止状态残留
        tool:SetAttribute("LastActivated", 0)

		local script = tool:FindFirstChild("ModuleScript")
		if script then
			local module = require(script)
			if module and module.Equipped then
				module:Equipped()
			end
		end
    end)
    
    -- 连接工具卸下事件，清理状态
    tool.Unequipped:Connect(function()
        -- 工具卸下时强制重置处理状态
        tool:SetAttribute("LastActivated", 0)

		local script = tool:FindFirstChild("ModuleScript")
		if script then
			local module = require(script)
			if module and module.Unequipped then
				module:Unequipped()
			end
		end
    end)
    
    -- 连接工具激活事件（服务器端处理）
    tool.Activated:Connect(function()
        local player = game.Players:GetPlayerFromCharacter(tool.Parent)
        if not player then return end
        
        local character = player.Character
        if not character then return end
        
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then return end
        
        -- 检查冷却时间
        local currentTime = tick()
        local lastActivated = tool:GetAttribute("LastActivated") or 0
        local cooldownTime = tool:GetAttribute("CD") or 0.5
        
        if currentTime - lastActivated < cooldownTime then
            return -- 在冷却时间内，忽略激活
        end
        
        tool:SetAttribute("LastActivated", currentTime)

        local script = tool:FindFirstChild("ModuleScript")
        if script then
            local module = require(script)
            if module then
                module:Activate(player)
            end

            if toolData.itemInfo.Type == GameConfig.ItemType.Weapon then    -- 进攻类
                -- 通知客户端播放动画
                self.Client.PlayToolAnimation:Fire(player)
            end
        else
        end
    end)
    
    return tool
end

-- 给玩家添加工具
function BackpackService:GiveToolToPlayer(player, item)
    local playerData = self.PlayerBackpacks[player]
    if not playerData then return false end
    
    -- 检查背包空间
    if #playerData.tools >= playerData.maxSlots then
        return false, "背包已满"
    end

    local itemInfo = ItemConfig:GetByItem(item.Name)
    if not itemInfo then
        return false, "物品不存在"
    end
    
    -- 生成唯一工具ID
    local toolId = self:_GenerateToolId()
    -- 创建工具数据
    local toolData = {
        toolId = toolId,
        itemInfo = itemInfo,
        duration = item:GetAttribute("Duration"),
        cd = item:GetAttribute("CD"),
    }
    
    -- 添加到背包数据
    table.insert(playerData.tools, toolData)
    
    -- 如果玩家在线，立即创建工具
    if player.Character then
        local tool = self:_CreateToolInstance(toolData)
        if tool then
            tool.Parent = player.Backpack
        end
    end
    
    -- 通知客户端更新
    self.Client.UpdateBackpackData:Fire(player, playerData)
    
    return true
end

-- 移除玩家工具
function BackpackService:RemoveToolFromPlayer(player, toolId)
    local playerData = self.PlayerBackpacks[player]
    if not playerData then return false end
    
    -- 从数据中移除
    for i, toolData in ipairs(playerData.tools) do
        if toolData.toolId == toolId then
            table.remove(playerData.tools, i)
            break
        end
    end
    
    -- 从背包中移除实际工具
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                if tool:GetAttribute("ToolId") == toolId then
                    tool:Destroy()
                    break
                end
            end
        end
    end
    
    -- 通知客户端更新
    self.Client.UpdateBackpackData:Fire(player, playerData)
    
    return true
end

-- 工具装备事件
function BackpackService:_OnToolEquipped(player, tool)
    local toolId = tool:GetAttribute("ToolId")
    local playerData = self.PlayerBackpacks[player]
    if playerData then
        playerData.equippedTool = toolId
        self.Client.UpdateBackpackData:Fire(player, playerData)
    end
end

-- 工具卸下事件
function BackpackService:_OnToolUnequipped(player, tool)
    local playerData = self.PlayerBackpacks[player]
    if playerData then
        playerData.equippedTool = nil
        self.Client.UpdateBackpackData:Fire(player, playerData)
    end
end

-- 生成唯一工具ID
function BackpackService:_GenerateToolId()
    return tostring(tick()) .. "_" .. math.random(1000, 9999)
end

-- 客户端方法：获取背包数据
function BackpackService.Client:GetBackpackData(player)
    return self.Server.PlayerBackpacks[player] or {}
end

return BackpackService