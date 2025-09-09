-- InventoryService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))

local InventoryService = Knit.CreateService {
	Name = "InventoryService",
	Client = {
        UpdateTool = Knit.CreateSignal(),
		ShowCD = Knit.CreateSignal(),
	},

    ToolData = {},      -- 工具栏数据
}

function InventoryService:KnitInit()
end

-- 服务启动时的初始化
-- @return void
function InventoryService:KnitStart()
end

function InventoryService:playerAdd(player, toolData)
    self.ToolData[player.UserId] = {}
    for i = 1, GameConfig.SLOT_NUM do
        local itemId = 0
        if toolData[i] then
            itemId = toolData[i].ItemId or 0
        end
        table.insert(self.ToolData[player.UserId], {
            ItemId = itemId,
            Attribute = GameConfig.GetItemAttribute()
        })
    end
end

function InventoryService:playerRemoved(player)
    self.ToolData[player.UserId] = nil
end

-- 更新玩家工具栏数据并创建工具
-- @param player Player 玩家对象
-- @param data table 工具栏数据，格式为 {["1"] = itemId, ["2"] = itemId, ["3"] = itemId}
-- @return void
function InventoryService:UpdateToolData(player, data)
    self.ToolData[player.UserId] = {}
    for i = 1, GameConfig.SLOT_NUM do
        local itemId = 0
        if data[i] then
            table.insert(self.ToolData[player.UserId], {
                ItemId = data[i].ItemId or 0,
                Attribute = data[i].Attribute or GameConfig.GetItemAttribute()
            })
        else
            table.insert(self.ToolData[player.UserId], {
                ItemId = itemId,
                Attribute = GameConfig.GetItemAttribute()
            })
        end
    end

    local dbToolData = {}
    for i = 1, 3 do
        dbToolData[i] = self.ToolData[player.UserId][i]
    end
    local DBService = Knit.GetService("DBService")
    DBService:Set(player.UserId, "PlayerToolData", dbToolData)
    
    -- 检查当前装备的工具是否在新的data中
    local character = player.Character
    if character then
        local currentTool = character:FindFirstChildOfClass("Tool")
        if currentTool then
            local currentItemId = currentTool:GetAttribute("ItemId")
            local toolInData = false
            
            -- 检查当前工具是否在新的data中
            for _, itemId in pairs(data) do
                if itemId == currentItemId then
                    toolInData = true
                    break
                end
            end
            
            -- 如果当前工具不在新的data中，则取下工具
            if not toolInData then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid:UnequipTools()
                end
            end
        end
    end

    self.Client.UpdateTool:Fire(player, self.ToolData[player.UserId])
end

function InventoryService:GetToolData(player)
    return self.ToolData[player.UserId]
end

function InventoryService:GiveToolToPlayer(player, item)
    local toolData = self.ToolData[player.UserId]
    if not toolData then
        return false, "玩家数据不存在"
    end

    local itemInfo = ItemConfig:GetByItem(item.Name)
    if not itemInfo then
        return false, "物品不存在"
    end
    local isPickUp = false
    local slot = 0
    local attribute = {}
    for i, itemData in ipairs(toolData) do
        if itemData.ItemId == 0 then
            slot = i
            attribute = GameConfig.GetItemAttribute(item)
            toolData[slot] = {ItemId = itemInfo.Index, Attribute = attribute}
            isPickUp = true
            break
        end
    end

    if not isPickUp then
        return false, "背包已满"
    end
    self:UpdateToolData(player, toolData)
    Knit.GetService("TaskService"):UpdateTask(player, 1)
    self.Client.ShowCD:Fire(player, slot, attribute.UseElapsedTime)
    return true, "物品添加成功"
end

function InventoryService.Client:UpdateToolData(player, data)
    self.Server:UpdateToolData(player, data)
end

-- 根据物品ID创建工具实例
-- @param itemId number 物品ID
-- @return Tool|nil 创建的工具实例
function InventoryService:CreateToolFromItemId(itemData, slot)
    if  itemData.ItemId == 0 then
        return
    end
    local itemInfo = ItemConfig:GetByIndex(tonumber(itemData.ItemId))
    if not itemInfo then
        warn("找不到物品ID: " .. tostring(itemData.ItemId))
        return
    end
    
    local template = game.ServerStorage:FindFirstChild(itemInfo.Model)
    if not template then
        warn("Tool template not found:", itemInfo.Model)
        return
    end
    
    -- 创建新的Tool实例
    local tool = Instance.new("Tool")
    
    -- 设置工具基本属性
    tool.Name = itemInfo.Item
    tool.ToolTip = itemInfo.Description or ""
    tool.CanBeDropped = true
    tool.RequiresHandle = true
    tool:SetAttribute("CD", itemInfo.CD)
    tool:SetAttribute("Duration", itemInfo.Duration)
    tool:SetAttribute("ItemId", itemData.ItemId)
    GameConfig.SetItemAttribute(tool, itemData.Attribute)
    
    -- 设置工具图标（如果ItemConfig中有Icon）
    if itemInfo.Icon and itemInfo.Icon ~= "" then
        tool.TextureId = itemInfo.Icon
    end

    local handle = nil
    
    -- 根据模板类型处理（Model 或 Part）
    if template:IsA("Model") then
        -- 处理 Model 类型的模板
        local templateModel = template:Clone()
        
        -- 确保模型有 PrimaryPart，这是作为 Handle 的关键
        handle = templateModel.PrimaryPart
        if not handle then
            warn("Warning: Tool template '" .. itemInfo.Item .. "' does not have a PrimaryPart set.")
            -- 备用方案：选择第一个找到的 BasePart
            handle = templateModel:FindFirstChildOfClass("BasePart")
            if not handle then
                warn("Error: Tool template '" .. itemInfo.Item .. "' contains no parts to use as a handle.")
                return
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
        warn("Error: Tool template '" .. itemInfo.Item .. "' is neither a Model nor a BasePart.")
        return
    end

    -- 直接设置Tool的Grip属性来控制握持方向
    tool.Grip = CFrame.Angles(0, 0, math.rad(90))  -- 只旋转，不偏移位置
    
    -- 连接工具装备事件，重置状态
    tool.Equipped:Connect(function()
        local player = game.Players:GetPlayerFromCharacter(tool.Parent)
        if not player then return end
        
        local character = player.Character
        if not character then return end
        
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then return end

		local script = tool:FindFirstChild("ModuleScript")
		if script then
			local module = require(script)
			if module and module.Equipped then
				module:Equipped(player)
			end
		end
    end)
    
    -- 连接工具卸下事件，清理状态
    tool.Unequipped:Connect(function()
        local player = game.Players:GetPlayerFromCharacter(tool.Parent)
        if not player then return end
        
        local character = player.Character
        if not character then return end
        
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then return end

		local script = tool:FindFirstChild("ModuleScript")
		if script then
			local module = require(script)
			if module and module.Unequipped then
				module:Unequipped(player)
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
        local attribute = GameConfig.GetItemAttribute(tool)
        
        -- 在冷却时间内，忽略激活
        if currentTime < attribute.UseElapsedTime then
            return
        end

        local cooldownTime = tool:GetAttribute("CD") or 0
        local useElapsedTime = currentTime + cooldownTime
		if cooldownTime > 0 then
			self.Client.ShowCD:Fire(player, slot, useElapsedTime)
		end
        self.ToolData[player.UserId][slot].Attribute.UseElapsedTime = useElapsedTime
        GameConfig.UpdateItemAttribute(tool, "UseElapsedTime", useElapsedTime)

        local script = tool:FindFirstChild("ModuleScript")
        if script then
            local module = require(script)
            if module and module.Activate then
                module:Activate(player)
            end

            if itemInfo.Type == GameConfig.ItemType.Weapon then    -- 进攻类
                local PlayerAnimationHnadler = require(ReplicatedStorage:WaitForChild("Animation"):WaitForChild("PlayerAnimationHnadler"))
                PlayerAnimationHnadler.playSwingAnimation(character)
            end
        else
        end
    end)
    
    return tool
end

-- 设置玩家按键绑定
-- @param player Player 玩家对象
-- @return void
function InventoryService.Client:PressKeyBind(player, keyCode)
    return self.Server:EquipToolByKey(player, keyCode)
end

-- 根据按键装备对应工具
-- @param player Player 玩家对象
-- @param keyCode Enum.KeyCode 按键代码
-- 根据按键装备或卸下工具
-- @param player Player 玩家对象
-- @param slot number 工具槽位
-- @return number|nil 装备的槽位号，如果没有装备则返回nil
function InventoryService:EquipToolByKey(player, slot)
    local character = player.Character
    if not character then
        return 0
    end

    local userId = player.UserId
    local slotNumber = tonumber(slot)
    
    -- 从ToolData中获取该槽位的物品ID
    local toolData = self.ToolData[userId]
    if not toolData then
        return 0
    end
    
    local itemData = toolData[slotNumber]
    if not itemData or itemData.ItemId == 0 then
        return 0
    end
    
    -- 获取当前装备的工具
    local currentTool = character:FindFirstChildOfClass("Tool")
    
    -- 检查当前工具是否是要装备的槽位对应的工具
    local isEquippingSameTool = false
    if currentTool then
        local currentItemId = currentTool:GetAttribute("ItemId")
        local attribute = GameConfig.GetItemAttribute(currentTool)
        if currentItemId == itemData.ItemId and attribute.CreateTime == itemData.Attribute.CreateTime then
            isEquippingSameTool = true
        end
    end
    
    -- 如果是同一个工具，则取下工具
    if isEquippingSameTool then
        if currentTool then
            -- 确保工具被正确写下
            if character:FindFirstChild("Humanoid") then
                character.Humanoid:UnequipTools()
            end
            currentTool:Destroy()
        end
        return 1
    end
    
    -- 否则，卸下当前工具并装备新工具
    if currentTool then
        -- 确保工具被正确写下
        if character:FindFirstChild("Humanoid") then
            character.Humanoid:UnequipTools()
        end
        currentTool:Destroy()
    end
    
    -- 按需创建新工具
    local newTool = self:CreateToolFromItemId(itemData, slotNumber)
    if newTool then
        newTool.Parent = character
        
        -- 确保工具被正确装备
        if character:FindFirstChild("Humanoid") then
            character.Humanoid:EquipTool(newTool)
        end
        
        return 2
    end
    
    return 0
end

-- 丢弃工具实现
-- @param player Player 玩家对象
-- @param slot number 工具槽位
-- @return void
function InventoryService:DiscardTool(player, slot)
    local character = player.Character
    if not character then
        return
    end
    
    local toolData = self.ToolData[player.UserId]
    if not toolData then
        return
    end
    
    local slotNumber = tonumber(slot)
    local itemData = toolData[slotNumber]
    if not itemData or itemData.ItemId == 0 then
        return
    end
    
    -- 获取物品配置信息
    local itemInfo = ItemConfig:GetByIndex(itemData.ItemId)
    if not itemInfo then
        return
    end
    
    -- 获取玩家当前装备的工具
    local equippedTool = character:FindFirstChildOfClass("Tool")
    if equippedTool then
        local equippedItemId = equippedTool:GetAttribute("ItemId")
        -- 如果当前装备的工具就是要丢弃的工具，则销毁它
        if equippedItemId == itemData.ItemId then
            equippedTool:Destroy()
        end
    end
    
    -- 从工具栏数据中移除
    toolData[slotNumber] = 0
    
    -- 获取玩家位置
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return
    end
    
    -- 在玩家前方创建物品
    local dropPosition = humanoidRootPart.Position + humanoidRootPart.CFrame.LookVector * 3
    
    -- 通过ItemService创建物品
    local ItemService = Knit.GetService("ItemService")
    ItemService:CreateItem(itemInfo.Index, dropPosition, itemData.Attribute)
    Knit.GetService("TaskService"):UpdateTask(player, 1)
end

-- 丢弃工具
-- @param player Player 玩家对象
-- @param slot number 工具槽位
-- @return void
function InventoryService.Client:DiscardTool(player, slot)
    return self.Server:DiscardTool(player, slot)
end

function InventoryService:UseTool(player)
    local character = player.Character
    if not character then
        return
    end
    
    -- 获取玩家身上当前装备的工具
    local equippedTool = character:FindFirstChildOfClass("Tool")
    if not equippedTool then
        return
    end
    
    -- 获取工具的ItemId
    local itemId = equippedTool:GetAttribute("ItemId")
    if not itemId then
        return
    end
    
    -- 获取工具配置信息
    local itemInfo = ItemConfig:GetByIndex(itemId)
    if not itemInfo then
        return
    end

    local attribute = GameConfig.GetItemAttribute(equippedTool)
    
    -- 检查工具是否在冷却中
    local currentTime = tick()
    if currentTime < attribute.UseElapsedTime then
        -- 工具还在冷却中，不能使用
        return
    end
    
    -- 执行工具使用逻辑（这里可以根据不同工具类型实现不同的效果）
    print("Player", player.Name, "used tool", itemInfo.item)
    
    -- 设置工具冷却时间
    if itemInfo.CD and itemInfo.CD > 0 then
        attribute.UseElapsedTime = currentTime + itemInfo.CD
        GameConfig.SetItemAttribute(equippedTool, attribute)
    end
end

-- 使用工具在指定位置
-- @param player Player 玩家对象
-- @param slot number 工具槽位
-- @param position Vector3 使用位置
-- @return void
function InventoryService.Client:UseTool(player)
    return self.Server:UseTool(player)
end

return InventoryService