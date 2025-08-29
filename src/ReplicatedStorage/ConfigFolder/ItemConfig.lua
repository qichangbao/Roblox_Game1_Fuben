--[[
-- 自动生成的Lua配置文件
-- 生成时间: 2025-08-27 16:10:11
-- 源文件: examples\in\ItemConfig.xls
-- 数据维度: 10行 x 12列
--]]

-- Knit框架兼容的配置模块
local ItemConfig = {}

-- 配置数据
ItemConfig.Data = {
    [1] = {
        Index = 1,
        Item = "刺刀",
        DisplayName = "Bayonet",
        Icon = "rbxassetid://140046656736906",
        Model = "刺刀",
        Description = "A sharp close-combat weapon designed for piercing and slashing.",
        Type = 2,
        Price = 500,
        SellPrice = 250,
        PickTime = 0,
        CD = 1.8,
        Duration = 0,
    },
    [2] = {
        Index = 2,
        Item = "手电",
        DisplayName = "Flashlight",
        Icon = "rbxassetid://140046656736906",
        Model = "手电",
        Description = "A portable light source that helps you see in dark environments.",
        Type = 1,
        Price = 300,
        SellPrice = 150,
        PickTime = 0,
        CD = 0,
        Duration = 3,
    },
    [3] = {
        Index = 3,
        Item = "夜视仪",
        DisplayName = "Night Vision Goggles",
        Icon = "rbxassetid://140046656736906",
        Model = "夜视仪",
        Description = "Specialized goggles that allow clear vision in total darkness.",
        Type = 1,
        Price = 2000,
        SellPrice = 1000,
        PickTime = 0,
        CD = 60,
        Duration = 30,
    },
    [4] = {
        Index = 4,
        Item = "荧光棒-红色",
        DisplayName = "Glow Stick - Red",
        Icon = "rbxassetid://140046656736906",
        Model = "荧光棒-红色",
        Description = "A disposable light source that emits a bright red glow, useful for marking areas or signaling.",
        Type = 1,
        Price = 50,
        SellPrice = 25,
        PickTime = 0,
        CD = 0,
        Duration = 3,
    },
    [5] = {
        Index = 5,
        Item = "铲子",
        DisplayName = "Shovel",
        Icon = "rbxassetid://140046656736906",
        Model = "铲子",
        Description = "A sturdy digging tool, can also be used as a blunt weapon in emergencies.",
        Type = 2,
        Price = 400,
        SellPrice = 200,
        PickTime = 0,
        CD = 1.5,
        Duration = 0,
    },
    [6] = {
        Index = 6,
        Item = "猎枪",
        DisplayName = "Shotgun",
        Icon = "rbxassetid://140046656736906",
        Model = "猎枪",
        Description = "A powerful short-range firearm that deals heavy damage up close.",
        Type = 2,
        Price = 2500,
        SellPrice = 1250,
        PickTime = 0,
        CD = 1.8,
        Duration = 0,
    },
    [7] = {
        Index = 7,
        Item = "猎枪子弹",
        DisplayName = "Shotgun Ammo",
        Icon = "rbxassetid://140046656736906",
        Model = "猎枪子弹",
        Description = "Ammunition compatible with shotguns, delivering devastating impact.",
        Type = 2,
        Price = 100,
        SellPrice = 50,
        PickTime = 0,
        CD = 0,
        Duration = 0,
    },
    [8] = {
        Index = 8,
        Item = "急救包",
        DisplayName = "First Aid Kit",
        Icon = "rbxassetid://140046656736906",
        Model = "急救包",
        Description = "A medical kit containing supplies to restore health and stop bleeding.",
        Type = 3,
        Price = 800,
        SellPrice = 400,
        PickTime = 0,
        CD = 120,
        Duration = 0,
    },
    [9] = {
        Index = 9,
        Item = "额外的背包",
        DisplayName = "Extra Backpack",
        Icon = "rbxassetid://140046656736906",
        Model = "额外的背包",
        Description = "Increases your carrying capacity for additional supplies.",
        Type = 3,
        Price = 1200,
        SellPrice = 600,
        PickTime = 0,
        CD = 0,
        Duration = 0,
    },
    [10] = {
        Index = 10,
        Item = "传送装置",
        DisplayName = "Teleport Device",
        Icon = "rbxassetid://140046656736906",
        Model = "传送装置",
        Description = "A rare tool that instantly transports the user to a safe location.",
        Type = 3,
        Price = 5000,
        SellPrice = 2500,
        PickTime = 0,
        CD = 120,
        Duration = 60,
    },
}

-- 辅助函数
function ItemConfig:GetByIndex(index)
    return self.Data[index]
end

function ItemConfig:GetByItem(value)
    for i, item in pairs(self.Data) do
        if item.Item == value then
            return item
        end
    end
    return nil
end

function ItemConfig:GetByDisplayName(value)
    for i, item in pairs(self.Data) do
        if item.DisplayName == value then
            return item
        end
    end
    return nil
end

function ItemConfig:GetByIcon(value)
    for i, item in pairs(self.Data) do
        if item.Icon == value then
            return item
        end
    end
    return nil
end

function ItemConfig:GetByModel(value)
    for i, item in pairs(self.Data) do
        if item.Model == value then
            return item
        end
    end
    return nil
end

function ItemConfig:GetByDescription(value)
    for i, item in pairs(self.Data) do
        if item.Description == value then
            return item
        end
    end
    return nil
end

function ItemConfig:GetByType(value)
    for i, item in pairs(self.Data) do
        if item.Type == value then
            return item
        end
    end
    return nil
end

function ItemConfig:GetByPrice(value)
    for i, item in pairs(self.Data) do
        if item.Price == value then
            return item
        end
    end
    return nil
end

function ItemConfig:GetBySellPrice(value)
    for i, item in pairs(self.Data) do
        if item.SellPrice == value then
            return item
        end
    end
    return nil
end

function ItemConfig:GetByPickTime(value)
    for i, item in pairs(self.Data) do
        if item.PickTime == value then
            return item
        end
    end
    return nil
end

function ItemConfig:GetByCD(value)
    for i, item in pairs(self.Data) do
        if item.CD == value then
            return item
        end
    end
    return nil
end

function ItemConfig:GetByDuration(value)
    for i, item in pairs(self.Data) do
        if item.Duration == value then
            return item
        end
    end
    return nil
end

function ItemConfig:GetAll()
    return self.Data
end

function ItemConfig:GetCount()
    local count = 0
    for _ in pairs(self.Data) do
        count = count + 1
    end
    return count
end

function ItemConfig:GetAllByType(itemType)
    local result = {}
    for i, item in pairs(self.Data) do
        if item.Type == itemType then
            table.insert(result, item)
        end
    end
    return result
end

return ItemConfig