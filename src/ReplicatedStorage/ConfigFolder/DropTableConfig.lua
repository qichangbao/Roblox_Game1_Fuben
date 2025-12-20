
local DropTableConfig = {}

DropTableConfig.Data = {
    [1] = {
        ID = 1,
        type = 2,
        minDrop = 1,
        maxDrop = 1,
        dropInfo = {
            {
                101,
                1,
                1000
            },
            {
                102,
                1,
                1000
            }
        },
    },
    [2] = {
        ID = 2,
        type = 2,
        minDrop = 1,
        maxDrop = 1,
        dropInfo = {
            {
                101,
                1,
                1000
            },
            {
                102,
                1,
                1000
            }
        },
    },
    [3] = {
        ID = 3,
        type = 2,
        minDrop = 1,
        maxDrop = 1,
        dropInfo = {
            {
                201,
                1,
                1000
            },
            {
                202,
                1,
                1000
            }
        },
    },
    [4] = {
        ID = 4,
        type = 2,
        minDrop = 1,
        maxDrop = 1,
        dropInfo = {
            {
                201,
                1,
                1000
            },
            {
                202,
                1,
                1000
            }
        },
    },
}

-- 辅助函数
function DropTableConfig:GetByIndex(index)
    return self.Data[index]
end

function DropTableConfig:GetByID(value)
    for i, item in pairs(self.Data) do
        if item.ID == value then
            return item
        end
    end
    return nil
end

function DropTableConfig:GetBytype(value)
    for i, item in pairs(self.Data) do
        if item.type == value then
            return item
        end
    end
    return nil
end

function DropTableConfig:GetByminDrop(value)
    for i, item in pairs(self.Data) do
        if item.minDrop == value then
            return item
        end
    end
    return nil
end

function DropTableConfig:GetBymaxDrop(value)
    for i, item in pairs(self.Data) do
        if item.maxDrop == value then
            return item
        end
    end
    return nil
end

function DropTableConfig:GetBydropInfo(value)
    for i, item in pairs(self.Data) do
        if item.dropInfo == value then
            return item
        end
    end
    return nil
end

function DropTableConfig:GetAll()
    return self.Data
end

function DropTableConfig:GetCount()
    local count = 0
    for _ in pairs(self.Data) do
        count = count + 1
    end
    return count
end

return DropTableConfig