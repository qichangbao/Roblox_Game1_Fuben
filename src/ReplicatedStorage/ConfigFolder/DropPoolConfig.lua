
local DropPoolConfig = {}

DropPoolConfig.Data = {
    [1] = {
        ID = 1,
        dropType = 1,
        weight = {
            {
                1,
                6000
            },
            {
                2,
                3500
            }
        },
    },
    [2] = {
        ID = 2,
        dropType = 1,
        weight = {
            {
                3,
                6000
            },
            {
                4,
                3500
            }
        },
    },
}

-- 辅助函数
function DropPoolConfig:GetByIndex(index)
    return self.Data[index]
end

function DropPoolConfig:GetByID(value)
    for i, item in pairs(self.Data) do
        if item.ID == value then
            return item
        end
    end
    return nil
end

function DropPoolConfig:GetBydropType(value)
    for i, item in pairs(self.Data) do
        if item.dropType == value then
            return item
        end
    end
    return nil
end

function DropPoolConfig:GetByweight(value)
    for i, item in pairs(self.Data) do
        if item.weight == value then
            return item
        end
    end
    return nil
end

function DropPoolConfig:GetAll()
    return self.Data
end

function DropPoolConfig:GetCount()
    local count = 0
    for _ in pairs(self.Data) do
        count = count + 1
    end
    return count
end

return DropPoolConfig