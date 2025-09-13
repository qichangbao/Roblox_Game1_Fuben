--[[
-- 自动生成的Lua配置文件
-- 生成时间: 2025-09-09 20:34:14
-- 源文件: examples\in\WeaponConfig.xls
-- 数据维度: 1行 x 3列
--]]

-- Knit框架兼容的配置模块
local WeaponConfig = {}

-- 配置数据
WeaponConfig.Data = {
    [1] = {
        ItemId = 10001,
        Damage = 20,
        AttackRange = 1,
    },
}

-- 辅助函数
function WeaponConfig:GetByIndex(index)
    for i, item in pairs(self.Data) do
        if item.Index == index then
            return item
        end
    end
    return nil
end

function WeaponConfig:GetByItemId(value)
    for i, item in pairs(self.Data) do
        if item.ItemId == value then
            return item
        end
    end
    return nil
end

function WeaponConfig:GetByDamage(value)
    for i, item in pairs(self.Data) do
        if item.Damage == value then
            return item
        end
    end
    return nil
end

function WeaponConfig:GetByAttackRange(value)
    for i, item in pairs(self.Data) do
        if item.AttackRange == value then
            return item
        end
    end
    return nil
end

function WeaponConfig:GetAll()
    return self.Data
end

function WeaponConfig:GetCount()
    local count = 0
    for _ in pairs(self.Data) do
        count = count + 1
    end
    return count
end

return WeaponConfig