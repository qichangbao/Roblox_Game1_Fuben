--[[
-- 自动生成的Lua配置文件
-- 生成时间: 2025-09-09 20:34:12
-- 源文件: examples\in\PlanConfig.xls
-- 数据维度: 1行 x 5列
--]]

-- Knit框架兼容的配置模块
local PlanConfig = {}

-- 配置数据
PlanConfig.Data = {
    [1] = {
        PlanID = 5001,
        Items = {
            {
                ItemID = 1001,
                Probability = 3000
            },
            {
                ItemID = 1002,
                Probability = 3000
            }
        },
    },
}

-- 辅助函数
function PlanConfig:GetByIndex(index)
    for i, item in pairs(self.Data) do
        if item.Index == index then
            return item
        end
    end
    return nil
end

function PlanConfig:GetByPlanID(value)
    for i, item in pairs(self.Data) do
        if item.PlanID == value then
            return item
        end
    end
    return nil
end

function PlanConfig:GetByItems(value)
    for i, item in pairs(self.Data) do
        if item.Items == value then
            return item
        end
    end
    return nil
end

function PlanConfig:GetAll()
    return self.Data
end

function PlanConfig:GetCount()
    local count = 0
    for _ in pairs(self.Data) do
        count = count + 1
    end
    return count
end

return PlanConfig