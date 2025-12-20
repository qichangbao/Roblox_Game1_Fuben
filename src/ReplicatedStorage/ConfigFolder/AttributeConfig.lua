
local AttributeConfig = {}

AttributeConfig.Data = {
    [1] = {
        ID = 1001,
        AttributeNotes = "攻击",
        AttributeType = 1,
        NumValueType = 1,
    },
    [2] = {
        ID = 1002,
        AttributeNotes = "生命",
        AttributeType = 1,
        NumValueType = 1,
    },
    [3] = {
        ID = 1003,
        AttributeNotes = "体力",
        AttributeType = 1,
        NumValueType = 1,
    },
    [4] = {
        ID = 1004,
        AttributeNotes = "移动速度",
        AttributeType = 1,
        NumValueType = 1,
    },
    [5] = {
        ID = 1005,
        AttributeNotes = "（体力）耐力恢复",
        AttributeType = 1,
        NumValueType = 1,
    },
    [6] = {
        ID = 1006,
        AttributeNotes = "攻击速度(每秒攻击X次）",
        AttributeType = 1,
        NumValueType = 1,
    },
    [7] = {
        ID = 1007,
        AttributeNotes = "攻击范围",
        AttributeType = 1,
        NumValueType = 1,
    },
    [8] = {
        ID = 1008,
        AttributeNotes = "跳跃（跳跃高度）",
        AttributeType = 1,
        NumValueType = 1,
    },
    [9] = {
        ID = 1009,
        AttributeNotes = "负重",
        AttributeType = 1,
        NumValueType = 1,
    },
    [10] = {
        ID = 1010,
        AttributeNotes = "幸运",
        AttributeType = 1,
        NumValueType = 1,
    },
    [11] = {
        ID = 2001,
        AttributeNotes = "攻击加成",
        AttributeType = 1,
        NumValueType = 2,
    },
    [12] = {
        ID = 2002,
        AttributeNotes = "生命加成",
        AttributeType = 1,
        NumValueType = 2,
    },
    [13] = {
        ID = 2003,
        AttributeNotes = "体力加成",
        AttributeType = 1,
        NumValueType = 2,
    },
    [14] = {
        ID = 2004,
        AttributeNotes = "移动速度加成",
        AttributeType = 1,
        NumValueType = 2,
    },
    [15] = {
        ID = 2005,
        AttributeNotes = "暴击率",
        AttributeType = 1,
        NumValueType = 2,
    },
    [16] = {
        ID = 2006,
        AttributeNotes = "暴击伤害",
        AttributeType = 1,
        NumValueType = 2,
    },
}

-- 辅助函数
function AttributeConfig:GetByIndex(index)
    return self.Data[index]
end

function AttributeConfig:GetByID(value)
    for i, item in pairs(self.Data) do
        if item.ID == value then
            return item
        end
    end
    return nil
end

function AttributeConfig:GetByAttributeNotes(value)
    for i, item in pairs(self.Data) do
        if item.AttributeNotes == value then
            return item
        end
    end
    return nil
end

function AttributeConfig:GetByAttributeType(value)
    for i, item in pairs(self.Data) do
        if item.AttributeType == value then
            return item
        end
    end
    return nil
end

function AttributeConfig:GetByNumValueType(value)
    for i, item in pairs(self.Data) do
        if item.NumValueType == value then
            return item
        end
    end
    return nil
end

function AttributeConfig:GetAll()
    return self.Data
end

function AttributeConfig:GetCount()
    local count = 0
    for _ in pairs(self.Data) do
        count = count + 1
    end
    return count
end

return AttributeConfig