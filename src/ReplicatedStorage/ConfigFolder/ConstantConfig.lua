
local ConstantConfig = {}

ConstantConfig.Data = {
    [1] = {
        ID = 1,
        Constant = "CopyPersonnelTarget",
        Desc = "副本人员目标系数（人数_系数）",
        Effect1 = {
            {
                1,
                10000
            },
            {
                2,
                11000
            },
            {
                3,
                12000
            },
            {
                4,
                13000
            },
            {
                5,
                15000
            }
        },
    },
    [2] = {
        ID = 2,
        Constant = "RunValue",
        Desc = "初始体力值上限",
        Effect1 = 100,
    },
    [3] = {
        ID = 3,
        Constant = "RunRecoverEfficiency",
        Desc = "（体力）耐力恢复【秒_（体力）耐力值】",
        Effect1 = {
            1,
            10
        },
    },
    [4] = {
        ID = 4,
        Constant = "VoteFastcCountdown",
        Desc = "玩家投票进入下一层，快速倒计时/秒",
        Effect1 = 30,
    },
    [5] = {
        ID = 5,
        Constant = "InitialHealth",
        Desc = "初始生命",
        Effect1 = 100,
    },
    [6] = {
        ID = 6,
        Constant = "InitialMovementSpeed",
        Desc = "初始移动速度",
        Effect1 = 16,
    },
    [7] = {
        ID = 7,
        Constant = "InitialSprintSpeed",
        Desc = "初始奔跑速度",
        Effect1 = 30,
    },
}

-- 辅助函数
function ConstantConfig:GetByIndex(index)
    return self.Data[index]
end

function ConstantConfig:GetByID(value)
    for i, item in pairs(self.Data) do
        if item.ID == value then
            return item
        end
    end
    return nil
end

function ConstantConfig:GetByConstant(value)
    for i, item in pairs(self.Data) do
        if item.Constant == value then
            return item
        end
    end
    return nil
end

function ConstantConfig:GetByDesc(value)
    for i, item in pairs(self.Data) do
        if item.Desc == value then
            return item
        end
    end
    return nil
end

function ConstantConfig:GetByEffect1(value)
    for i, item in pairs(self.Data) do
        if item.Effect1 == value then
            return item
        end
    end
    return nil
end

function ConstantConfig:GetAll()
    return self.Data
end

function ConstantConfig:GetCount()
    local count = 0
    for _ in pairs(self.Data) do
        count = count + 1
    end
    return count
end

return ConstantConfig