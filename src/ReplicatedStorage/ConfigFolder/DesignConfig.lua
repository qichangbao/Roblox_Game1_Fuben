
local DesignConfig = {}

DesignConfig.Data = {
    [1] = {
        DesignId = 2,
        Id = 1,
        DesignName = "珊瑚浅滩",
        MapId = 101,
        DisplayName = nil,
        MusicId = 101,
        WeatherId = 0,
        DesignTarget = 35,
        EvacuateTime = 300,
        ResourceNum = {
            {
                1,
                3
            },
            {
                2,
                1
            },
            {
                5,
                3
            }
        },
    },
    [2] = {
        DesignId = 3,
        Id = 2,
        DesignName = "迷雾海峡",
        MapId = 102,
        DisplayName = nil,
        MusicId = 102,
        WeatherId = 0,
        DesignTarget = 135,
        EvacuateTime = 330,
        ResourceNum = {
            {
                2,
                2
            },
            {
                3,
                1
            },
            {
                5,
                7
            }
        },
    },
    [3] = {
        DesignId = 4,
        Id = 3,
        DesignName = "暴风海域",
        MapId = 103,
        DisplayName = nil,
        MusicId = 103,
        WeatherId = 0,
        DesignTarget = 380,
        EvacuateTime = 360,
        ResourceNum = {
            {
                1,
                3
            },
            {
                2,
                3
            },
            {
                3,
                1
            },
            {
                4,
                1
            },
            {
                5,
                10
            }
        },
    },
    [4] = {
        DesignId = 5,
        Id = 4,
        DesignName = "幽灵深渊",
        MapId = 104,
        DisplayName = nil,
        MusicId = 104,
        WeatherId = 0,
        DesignTarget = 750,
        EvacuateTime = 390,
        ResourceNum = {
            {
                2,
                4
            },
            {
                3,
                2
            },
            {
                4,
                1
            },
            {
                5,
                13
            }
        },
    },
    [5] = {
        DesignId = 6,
        Id = 5,
        DesignName = "赤焰裂谷",
        MapId = 105,
        DisplayName = nil,
        MusicId = 105,
        WeatherId = 0,
        DesignTarget = 950,
        EvacuateTime = 420,
        ResourceNum = {
            {
                1,
                4
            },
            {
                2,
                5
            },
            {
                3,
                2
            },
            {
                4,
                1
            },
            {
                5,
                16
            }
        },
    },
    [6] = {
        DesignId = 7,
        Id = 6,
        DesignName = "废弃工厂",
        MapId = 106,
        DisplayName = nil,
        MusicId = 106,
        WeatherId = 0,
        DesignTarget = 1500,
        EvacuateTime = 450,
        ResourceNum = {
            {
                1,
                5
            },
            {
                2,
                6
            },
            {
                3,
                3
            },
            {
                4,
                1
            },
            {
                5,
                14
            }
        },
    },
    [7] = {
        DesignId = 8,
        Id = 7,
        DesignName = "极光冰窟",
        MapId = 107,
        DisplayName = nil,
        MusicId = 107,
        WeatherId = 0,
        DesignTarget = 1800,
        EvacuateTime = 480,
        ResourceNum = {
            {
                1,
                5
            },
            {
                2,
                4
            },
            {
                3,
                6
            },
            {
                4,
                1
            },
            {
                5,
                12
            }
        },
    },
    [8] = {
        DesignId = 9,
        Id = 8,
        DesignName = "铭文圣屿",
        MapId = 108,
        DisplayName = nil,
        MusicId = 108,
        WeatherId = 0,
        DesignTarget = 2000,
        EvacuateTime = 510,
        ResourceNum = {
            {
                1,
                5
            },
            {
                2,
                6
            },
            {
                3,
                4
            },
            {
                4,
                1
            },
            {
                5,
                14
            }
        },
    },
    [9] = {
        DesignId = 10,
        Id = 9,
        DesignName = "城堡要塞",
        MapId = 109,
        DisplayName = nil,
        MusicId = 109,
        WeatherId = 0,
        DesignTarget = 2000,
        EvacuateTime = 540,
        ResourceNum = {
            {
                1,
                10
            },
            {
                2,
                5
            },
            {
                3,
                6
            },
            {
                4,
                1
            }
        },
    },
    [10] = {
        DesignId = 11,
        Id = 10,
        DesignName = "新手海湾",
        MapId = 110,
        DisplayName = nil,
        MusicId = 110,
        WeatherId = 0,
        DesignTarget = 4500,
        EvacuateTime = 570,
        ResourceNum = {
            {
                1,
                14
            },
            {
                2,
                6
            },
            {
                3,
                5
            },
            {
                4,
                2
            },
            {
                5,
                16
            }
        },
    },
    [11] = {
        DesignId = 12,
        Id = 11,
        DesignName = "珊瑚浅滩",
        MapId = 111,
        DisplayName = nil,
        MusicId = 111,
        WeatherId = 0,
        DesignTarget = 380,
        EvacuateTime = 300,
        ResourceNum = {
            {
                1,
                5
            },
            {
                2,
                5
            },
            {
                3,
                5
            },
            {
                4,
                5
            }
        },
    },
}

-- 辅助函数
function DesignConfig:GetByIndex(index)
    return self.Data[index]
end

function DesignConfig:GetByDesignId(value)
    for i, item in pairs(self.Data) do
        if item.DesignId == value then
            return item
        end
    end
    return nil
end

function DesignConfig:GetById(value)
    for i, item in pairs(self.Data) do
        if item.Id == value then
            return item
        end
    end
    return nil
end

function DesignConfig:GetByDesignName(value)
    for i, item in pairs(self.Data) do
        if item.DesignName == value then
            return item
        end
    end
    return nil
end

function DesignConfig:GetByMapId(value)
    for i, item in pairs(self.Data) do
        if item.MapId == value then
            return item
        end
    end
    return nil
end

function DesignConfig:GetByDisplayName(value)
    for i, item in pairs(self.Data) do
        if item.DisplayName == value then
            return item
        end
    end
    return nil
end

function DesignConfig:GetByMusicId(value)
    for i, item in pairs(self.Data) do
        if item.MusicId == value then
            return item
        end
    end
    return nil
end

function DesignConfig:GetByWeatherId(value)
    for i, item in pairs(self.Data) do
        if item.WeatherId == value then
            return item
        end
    end
    return nil
end

function DesignConfig:GetByDesignTarget(value)
    for i, item in pairs(self.Data) do
        if item.DesignTarget == value then
            return item
        end
    end
    return nil
end

function DesignConfig:GetByEvacuateTime(value)
    for i, item in pairs(self.Data) do
        if item.EvacuateTime == value then
            return item
        end
    end
    return nil
end

function DesignConfig:GetByResourceNum(value)
    for i, item in pairs(self.Data) do
        if item.ResourceNum == value then
            return item
        end
    end
    return nil
end

function DesignConfig:GetAll()
    return self.Data
end

function DesignConfig:GetCount()
    local count = 0
    for _ in pairs(self.Data) do
        count = count + 1
    end
    return count
end

return DesignConfig