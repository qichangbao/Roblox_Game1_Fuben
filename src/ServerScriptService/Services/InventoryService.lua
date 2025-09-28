-- InventoryService 服务
-- 使用Knit框架管理服务器数据

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local InventoryService = Knit.CreateService {
	Name = "InventoryService",
	Client = {
        SendToolData = Knit.CreateSignal(),
        SendBagData = Knit.CreateSignal(),
        EquipAdditionalBackpack = Knit.CreateSignal(),
	},

	Inventory = {},     -- 背包数据
    ToolData = {},      -- 工具栏数据
    BagData = {},       -- 包裹数据
    EscapeItems = {},   -- 撤离上交物品数据
    TurnInNum = {},     -- 上交物品数量
}

function InventoryService:KnitInit()
end

-- 服务启动时的初始化
-- @return void
function InventoryService:KnitStart()
end


function InventoryService:playerAdd(player, inventory, toolData)
	self.Inventory[player.UserId] = {}
	for _, v in pairs(inventory) do
        local attribute = GameConfig.GetItemAttribute()
        attribute.UsedTime = v.UsedTime
        attribute.UsedNum = v.UsedNum
		table.insert(self.Inventory[player.UserId], {
            ItemId = v.ItemId,
            Attribute = attribute,
        })
	end

    self.ToolData[player.UserId] = {}
    for i = 1, GameConfig.SLOT_NUM do
        local data = toolData[i]
        local attribute = GameConfig.GetItemAttribute()
        if data then
            attribute.UsedTime = data.UsedTime
            attribute.UsedNum = data.UsedNum
            table.insert(self.ToolData[player.UserId], {
                ItemId = data.ItemId,
                Attribute = attribute
            })
        else
            table.insert(self.ToolData[player.UserId], {
                ItemId = 0,
                Attribute = attribute
            })
        end
    end

    self.BagData[player.UserId] = {}
    for i = 1, GameConfig.BAG_NUM do
        table.insert(self.BagData[player.UserId], {
            ItemId = 0,
            Attribute = GameConfig.GetItemAttribute()
        })
    end

    self.EscapeItems[player.UserId] = {}
    self.TurnInNum[player.UserId] = 0
end

function InventoryService:playerRemoved(player)
    self.Inventory[player.UserId] = nil
    self.ToolData[player.UserId] = nil
    self.BagData[player.UserId] = nil
    self.EscapeItems[player.UserId] = nil
    self.TurnInNum[player.UserId] = nil
end

-- 背包数据转换为数据库格式
-- @param player Player 玩家对象
-- @return void
function InventoryService:InventoryToDB(player)
	local DBService = Knit.GetService("DBService")
    local data = {}
    for _, v in pairs(self.Inventory[player.UserId]) do
        table.insert(data, {
            ItemId = v.ItemId,
            UsedTime = v.Attribute.UsedTime,
            UsedNum = v.Attribute.UsedNum,
        })
    end
	DBService:Set(player.UserId, "PlayerInventory", data)
end

-- 工具栏数据转换为数据库格式
-- @param player Player 玩家对象
-- @return void
function InventoryService:ToolDataToDB(player)
	local DBService = Knit.GetService("DBService")
    local data = {}
    for _, v in pairs(self.ToolData[player.UserId]) do
        table.insert(data, {
            ItemId = v.ItemId,
            UsedTime = v.Attribute.UsedTime,
            UsedNum = v.Attribute.UsedNum,
        })
    end
	DBService:Set(player.UserId, "PlayerToolData", data)
end

-- 添加物品到玩家背包
-- @param player Player 玩家对象
-- @param itemData table 物品数据
-- @return void
function InventoryService:AddItem(player, itemData)
    table.insert(self.Inventory[player.UserId], itemData)
end

-- 更新玩家背包数据
-- @param player Player 玩家对象
-- @param inventory table 背包数据
-- @return void
function InventoryService:UpdateInventory(player, inventory)
    self.Inventory[player.UserId] = inventory
end

-- 更新玩家工具栏数据并创建工具
-- @param player Player 玩家对象
-- @param data table 工具栏数据
-- @return void
function InventoryService:UpdateToolData(player, data)
    self.ToolData[player.UserId] = {}
    for i = 1, GameConfig.SLOT_NUM do
        local itemId = 0
        if data and data[i] then
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
	--self:ToolDataToDB(player)
    
    -- 检查当前装备的工具是否在新的data中
    local character = player.Character
    if character then
        local currentTool = character:FindFirstChildOfClass("Tool")
        if currentTool then
            local currentItemId = currentTool:GetAttribute("ItemId")
            local toolInData = false
            
            -- 检查当前工具是否在新的data中
            for _, itemData in pairs(data) do
                if itemData.ItemId == currentItemId then
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
    self.Client.SendToolData:Fire(player, self.ToolData[player.UserId])
end

function InventoryService:UpdateBagData(player, data)
    self.BagData[player.UserId] = {}
    for i = 1, GameConfig.BAG_NUM do
        local itemId = 0
        if data and data[i] then
            table.insert(self.BagData[player.UserId], {
                ItemId = data[i].ItemId or 0,
                Attribute = data[i].Attribute or GameConfig.GetItemAttribute()
            })
        else
            table.insert(self.BagData[player.UserId], {
                ItemId = itemId,
                Attribute = GameConfig.GetItemAttribute()
            })
        end
    end
    self.Client.SendBagData:Fire(player, self.BagData[player.UserId])
end

function InventoryService:GetBagData(player)
    return self.BagData[player.UserId]
end

function InventoryService:GetToolData(player)
    return self.ToolData[player.UserId]
end

function InventoryService:GiveToolToPlayer(player, item)
    local toolData = self.ToolData[player.UserId]
    if not toolData then
        return false, "玩家数据不存在"
    end

    local itemId = item:GetAttribute("ItemId")
    local itemInfo = ItemConfig:GetByIndex(itemId)
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
        -- 先检查工具栏是否有空格
        local hasBag = false
        for i, itemData in ipairs(toolData) do
            if itemData.ItemId == GameConfig.AdditionalBackpackId then        -- 特殊处理，额外的背包ID为6
                hasBag = true
                break
            end
        end

        if hasBag then
            local bagData = self.BagData[player.UserId]
            for i, itemData in ipairs(bagData) do
                if itemData.ItemId == 0 then
                    slot = i
                    attribute = GameConfig.GetItemAttribute(item)
                    bagData[slot] = {ItemId = itemInfo.Index, Attribute = attribute}
                    isPickUp = true
                    break
                end
            end
        end

        if not isPickUp then
            return false, "背包已满"
        else
            self:UpdateBagData(player, self.BagData[player.UserId])
        end
    else
        self:UpdateToolData(player, toolData)
    end
    return true, "物品添加成功"
end

function InventoryService.Client:UpdateToolData(player, data)
    return self.Server:UpdateToolData(player, data)
end

function InventoryService.Client:UpdateBagData(player, data)
    return self.Server:UpdateBagData(player, data)
end

-- 根据物品ID创建工具实例
-- @param itemId number 物品ID
-- @return Tool|nil 创建的工具实例
function InventoryService:CreateToolFromItemId(itemData, slot)
    if itemData.ItemId == 0 then
        return
    end
    local itemInfo = ItemConfig:GetByIndex(tonumber(itemData.ItemId))
    if not itemInfo then
        warn("找不到物品ID: " .. tostring(itemData.ItemId))
        return
    end

    local itemFolder = ServerStorage:FindFirstChild("Item")
    if not itemFolder then
        warn("Item folder not found")
        return
    end

    local folder = itemFolder:FindFirstChild(GameConfig.ItemTypeFolder[itemInfo.Type])
    if not folder then
        warn("Item type folder not found: " .. GameConfig.ItemTypeFolder[itemInfo.Type])
        return
    end
    
    local template = folder:FindFirstChild(itemInfo.Model)
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
        local userId = tool:GetAttribute("PlayerId")
        if not userId then return end
        local player = game.Players:GetPlayerByUserId(userId)
        if not player then return end
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
        if currentTime < attribute.CDElapsedTime then
            return
        end

        local script = tool:FindFirstChild("ModuleScript")
        if script then
            local module = require(script)
            if module and module.Activate then
                local isSuccess = module:Activate(player, itemInfo)
                if isSuccess then
					local CDElapsedTime = currentTime + itemInfo.CD
					self.ToolData[player.UserId][slot].Attribute.CDElapsedTime = CDElapsedTime
					GameConfig.UpdateItemAttribute(tool, "CDElapsedTime", CDElapsedTime)
					self.Client.SendToolData:Fire(player, self.ToolData[player.UserId])
                end
            end

            if itemInfo.Type == GameConfig.ItemType.Weapon then    -- 进攻类
                local PlayerAnimationHnadler = require(ReplicatedStorage:WaitForChild("Animation"):WaitForChild("PlayerAnimationHnadler"))
                PlayerAnimationHnadler.playSwingAnimation(character)
            end
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

--[[
    激活玩家装备的工具
    @param player Player 玩家对象
    @param slot number 工具槽位
    @return boolean 是否成功激活工具
]]
function InventoryService:ActivateTool(player, slot)
    -- 验证玩家和角色
    if not player or not player.Character then
        warn("ActivateTool: 玩家或角色不存在")
        return false
    end
    
    local character = player.Character
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then
        warn("ActivateTool: 玩家角色没有Humanoid")
        return false
    end
    
    -- 验证槽位
    local slotNumber = tonumber(slot)
    if not slotNumber or slotNumber < 1 or slotNumber > GameConfig.SLOT_NUM then
        warn("ActivateTool: 无效的槽位号: " .. tostring(slot))
        return false
    end
    
    -- 获取玩家工具数据
    local userId = player.UserId
    local toolData = self.ToolData[userId]
    if not toolData then
        warn("ActivateTool: 玩家工具数据不存在")
        return false
    end
    
    -- 获取指定槽位的工具数据
    local itemData = toolData[slotNumber]
    if not itemData or not itemData.ItemId or itemData.ItemId == 0 then
        warn("ActivateTool: 槽位 " .. slotNumber .. " 没有装备工具")
        return false
    end
    
    -- 查找玩家当前装备的工具
    for _, tool in pairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            local itemId = tool:GetAttribute("ItemId")
            -- 获取物品信息
            local itemInfo = ItemConfig:GetByIndex(itemId)
            if not itemInfo then
                warn("ActivateTool: 无法获取物品信息，ItemId: " .. itemId)
                return false
            end

			if itemInfo.Type >= GameConfig.ItemType.Explore and itemInfo.Type <= GameConfig.ItemType.Assistance then
                tool:Activate()
            end
        end
    end
    
    print("ActivateTool: 成功激活槽位 " .. slotNumber .. " 的工具")
    return true
end

--[[
    客户端调用激活工具的接口
    @param player Player 玩家对象
    @param slot number 工具槽位
    @return boolean 是否成功激活工具
]]
function InventoryService.Client:ActivateTool(player, slot)
    return self.Server:ActivateTool(player, slot)
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
    
        -- 如果是同一个工具，则取下工具
        if isEquippingSameTool then
            if currentTool then
                for _, v in pairs(toolData) do
                    if v.ItemId == currentItemId and v.Attribute.CreateTime == attribute.CreateTime then
                        v.Attribute.IsEquipped = 0
                        break
                    end
                end
                GameConfig.UpdateItemAttribute(currentTool, "IsEquipped", 0)
                character.Humanoid:UnequipTools()
                task.delay(0.05, function()
                    currentTool:Destroy()
                end)
            end
            return 1, toolData
        end
        
        -- 否则，卸下当前工具并装备新工具
        for i, v in pairs(toolData) do
            if v.ItemId == currentItemId and v.Attribute.CreateTime == attribute.CreateTime then
                v.Attribute.IsEquipped = 0
                break
            end
        end
        GameConfig.UpdateItemAttribute(currentTool, "IsEquipped", 0)
        character.Humanoid:UnequipTools()
        task.delay(0.05, function()
            currentTool:Destroy()
        end)
    end
    
    -- 按需创建新工具
    local newTool = self:CreateToolFromItemId(itemData, slotNumber)
    if newTool then
        newTool.Parent = character
        
        -- 确保工具被正确装备
        if character:FindFirstChild("Humanoid") then
            newTool:SetAttribute("PlayerId", player.UserId)
            character.Humanoid:EquipTool(newTool)
        	itemData.Attribute.IsEquipped = 1
			GameConfig.UpdateItemAttribute(newTool, "IsEquipped", 1)
        end
        
        return 2, toolData
    end
    
    return 0
end

local function CreateItemToFloor(character, itemInfo, attribute)
    -- 获取玩家位置
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return
    end
    
    -- 在玩家前方创建物品，使用射线检测找到地面位置
    local basePosition = humanoidRootPart.Position + humanoidRootPart.CFrame.LookVector * 3
    basePosition = Vector3.new(basePosition.X + math.random(-3, 3), basePosition.Y, basePosition.Z + math.random(-3, 3))
    
    -- 创建向下的射线来检测地面
    local rayOrigin = Vector3.new(basePosition.X, basePosition.Y, basePosition.Z) -- 从玩家上方开始
    local rayDirection = Vector3.new(0, -10, 0) -- 向下射线
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {character} -- 忽略玩家自身
    
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    local dropPosition
    if raycastResult then
        -- 找到地面，使用地面Y坐标 + 一点偏移
        dropPosition = Vector3.new(basePosition.X, raycastResult.Position.Y, basePosition.Z)
    else
        -- 没找到地面，使用原始位置
        dropPosition = basePosition
    end
    
    -- 通过ItemService创建物品
    local ItemService = Knit.GetService("ItemService")
    ItemService:CreateItem(itemInfo.Index, dropPosition, attribute)
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
    local itemId = itemData.ItemId
    local attribute = itemData.Attribute
    if not itemData or itemId == 0 then
        return
    end
    
    -- 获取物品配置信息
    local itemInfo = ItemConfig:GetByIndex(itemId)
    if not itemInfo then
        return
    end

    -- 从工具栏数据中移除
    toolData[slotNumber] = {
        ItemId = 0,
        Attribute = GameConfig.GetItemAttribute()
    }
    
    -- 获取玩家当前装备的工具
    local equippedTool = character:FindFirstChildOfClass("Tool")
    if equippedTool then
        local equippedItemId = equippedTool:GetAttribute("ItemId")
        -- 如果当前装备的工具就是要丢弃的工具，则销毁它
        if equippedItemId == itemId then
            equippedTool:Destroy()
        end
    end
    
    -- 如果丢掉的是背包，则把背包里的物品也丢出来
    if itemId == GameConfig.AdditionalBackpackId then
        local data = Interface.clone(self.BagData[player.UserId])
        self:UpdateBagData(player)
        
        -- 异步处理物品丢出，每个物品间隔0.5秒
        task.spawn(function()
            local itemsToThrow = {}
            
            -- 收集需要丢出的物品
            for _, v in pairs(data) do
                if v.ItemId ~= 0 then
                    table.insert(itemsToThrow, {
                        itemInfo = ItemConfig:GetByIndex(v.ItemId),
                        attribute = v.Attribute
                    })
                end
            end
            
            -- 逐个丢出物品，每个间隔0.5秒
            for i, itemDataTemp in ipairs(itemsToThrow) do
                CreateItemToFloor(character, itemDataTemp.itemInfo, itemDataTemp.attribute)
                
                -- 如果不是最后一个物品，等待0.3秒
                if i < #itemsToThrow then
                    task.wait(0.3)
                end
            end
        end)
    end
    
    -- 把物品丢出来
    task.spawn(function()
        CreateItemToFloor(character, itemInfo, attribute)
    end)
end

function InventoryService:DiscardBag(player, slot)
    local character = player.Character
    if not character then
        return
    end

    local bagData = self.BagData[player.UserId]
    if not bagData then
        return
    end

    local slotNumber = tonumber(slot)
    local itemData = bagData[slotNumber]
    local itemId = itemData.ItemId
    local attribute = itemData.Attribute
    if not itemData or itemId == 0 then
        return
    end

    -- 获取物品配置信息
    local itemInfo = ItemConfig:GetByIndex(itemId)
    if not itemInfo then
        return
    end
    
    bagData[slotNumber] = {
        ItemId = 0,
        Attribute = GameConfig.GetItemAttribute()
    }
    CreateItemToFloor(character, itemInfo, attribute)
end

-- 丢弃工具
-- @param player Player 玩家对象
-- @param slot number 工具槽位
-- @return void
function InventoryService.Client:DiscardTool(player, slot)
    return self.Server:DiscardTool(player, slot)
end

-- 丢弃工具
-- @param player Player 玩家对象
-- @param slot number 工具槽位
-- @return void
function InventoryService.Client:DiscardBag(player, slot)
    return self.Server:DiscardBag(player, slot)
end

function InventoryService:GetEscapeItems(player)
    return self.EscapeItems[player.UserId] or {}
end

-- 上交搜集物品
-- @param player Player 玩家对象
-- @return number 获得的总金币数量
function InventoryService:TurnInCollect(player)
    -- 边界检查
    if not player or not player.UserId then
        warn("TurnInCollect: 无效的玩家对象")
        return 0
    end
    
    -- 检查玩家是否死亡
    local character = player.Character
    if not character then
        return 0
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return 0
    end
    
    local userId = player.UserId
    if not self.ToolData[userId] then
        warn("TurnInCollect: 玩家工具数据不存在", userId)
        return 0
    end
    
    local isToolChanged = false
    local gold = 0
    -- 收集所有搜集类物品
    for i = 1, #self.ToolData[userId] do
        local toolData = self.ToolData[userId][i]
        if toolData and toolData.ItemId ~= 0 then
            local itemInfo = ItemConfig:GetByIndex(toolData.ItemId)
            if itemInfo and itemInfo.Type == GameConfig.ItemType.Collect then
                if self.TurnInNum[userId] >= GameConfig.MaxTurnInItemNum then
                    break
                end
                self.TurnInNum[userId] += 1
                gold += itemInfo.SellPrice
                table.insert(self.EscapeItems[userId], {
                    ItemId = toolData.ItemId,
                    Attribute = Interface.clone(toolData.Attribute)
                })
                self.ToolData[userId][i] = {
                    ItemId = 0,
                    Attribute = GameConfig.GetItemAttribute()
                }
                isToolChanged = true
            end
        end
    end

    local isBagChanged = false
    -- 收集所有搜集类物品
    for i = 1, #self.BagData[userId] do
        local bagData = self.BagData[userId][i]
        if bagData and bagData.ItemId ~= 0 then
            local itemInfo = ItemConfig:GetByIndex(bagData.ItemId)
            if itemInfo and itemInfo.Type == GameConfig.ItemType.Collect then
                if self.TurnInNum[userId] >= GameConfig.MaxTurnInItemNum then
                    break
                end
                self.TurnInNum[userId] += 1
                gold += itemInfo.SellPrice
                table.insert(self.EscapeItems[userId], {
                    ItemId = bagData.ItemId,
                    Attribute = Interface.clone(bagData.Attribute)
                })
                self.BagData[userId][i] = {
                    ItemId = 0,
                    Attribute = GameConfig.GetItemAttribute()
                }
                isBagChanged = true
            end
        end
    end
    
    -- 如果有搜集物品被上交
    if gold > 0 then
        Knit.GetService("TaskService"):UpdateEscapeTask(gold)
        self:UpdateToolData(player, self.ToolData[player.UserId])
        if isToolChanged then
            self:UpdateToolData(player, self.ToolData[player.UserId])
        end
        if isBagChanged then
            self:UpdateBagData(player, self.BagData[player.UserId])
        end
    else
        print(string.format("玩家 %s 没有可上交的搜集物品", player.Name))
    end
    
    return gold
end

function InventoryService:EquipAdditionalBackpack(player, equip)
    self.Client.EquipAdditionalBackpack:Fire(player, equip)
end

function InventoryService:GetCurrentToolData(player, tool)
    for _, v in pairs(self.ToolData[player.UserId]) do
        if v.ItemId == tool:GetAttribute("ItemId") and v.Attribute.CreateTime == tool:GetAttribute("CreateTime") then
            return v
        end
    end
end

-- 使用工具
-- @param player Player 玩家对象
-- @param tool table 工具数据
-- @return void
function InventoryService:UseTool(player, tool, type, dt)
    if not player.character then
        return
    end

    -- 获取玩家当前装备的工具
    local itemId = tool:GetAttribute("ItemId")
    local equippedTool = player.character:FindFirstChildOfClass("Tool")
    if not equippedTool then
        return
    end
    
    local equippedItemId = equippedTool:GetAttribute("ItemId")
    if equippedItemId ~= itemId then
        return
    end

    local currentToolData = self:GetCurrentToolData(player, tool)
    if currentToolData then
        if type == 1 then
            currentToolData.Attribute.UsedNum += 1
        else
            currentToolData.Attribute.usedTime += dt
        end
        GameConfig.UpdateItemAttribute(tool, "UsedNum", currentToolData.Attribute.UsedNum)
    end
end

return InventoryService