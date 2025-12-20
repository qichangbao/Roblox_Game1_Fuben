
local SignConfig = {}

SignConfig.Data = {
    [1] = {
        ID = 1,
        days = 1,
        SignReward = {
            {
                202,
                5
            },
            {
                2,
                50
            }
        },
    },
    [2] = {
        ID = 2,
        days = 2,
        SignReward = {
            {
                9,
                1
            },
            {
                2,
                50
            }
        },
    },
    [3] = {
        ID = 3,
        days = 3,
        SignReward = {
            {
                7,
                10
            },
            {
                2,
                50
            }
        },
    },
    [4] = {
        ID = 4,
        days = 4,
        SignReward = {
            {
                202,
                5
            },
            {
                2,
                50
            }
        },
    },
    [5] = {
        ID = 5,
        days = 5,
        SignReward = {
            {
                10,
                1
            },
            {
                2,
                50
            }
        },
    },
    [6] = {
        ID = 6,
        days = 6,
        SignReward = {
            {
                8,
                50
            },
            {
                2,
                50
            }
        },
    },
    [7] = {
        ID = 7,
        days = 7,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [8] = {
        ID = 8,
        days = 8,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [9] = {
        ID = 9,
        days = 9,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [10] = {
        ID = 10,
        days = 10,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [11] = {
        ID = 11,
        days = 11,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [12] = {
        ID = 12,
        days = 12,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [13] = {
        ID = 13,
        days = 13,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [14] = {
        ID = 14,
        days = 14,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [15] = {
        ID = 15,
        days = 15,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [16] = {
        ID = 16,
        days = 16,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [17] = {
        ID = 17,
        days = 17,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [18] = {
        ID = 18,
        days = 18,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [19] = {
        ID = 19,
        days = 19,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [20] = {
        ID = 20,
        days = 20,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [21] = {
        ID = 21,
        days = 21,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [22] = {
        ID = 22,
        days = 22,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [23] = {
        ID = 23,
        days = 23,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [24] = {
        ID = 24,
        days = 24,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [25] = {
        ID = 25,
        days = 25,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [26] = {
        ID = 26,
        days = 26,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [27] = {
        ID = 27,
        days = 27,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [28] = {
        ID = 28,
        days = 28,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [29] = {
        ID = 29,
        days = 29,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [30] = {
        ID = 30,
        days = 30,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
    [31] = {
        ID = 31,
        days = 31,
        SignReward = {
            {
                202,
                5
            },
            {
                4,
                1
            }
        },
    },
}

-- 辅助函数
function SignConfig:GetByIndex(index)
    return self.Data[index]
end

function SignConfig:GetByID(value)
    for i, item in pairs(self.Data) do
        if item.ID == value then
            return item
        end
    end
    return nil
end

function SignConfig:GetBydays(value)
    for i, item in pairs(self.Data) do
        if item.days == value then
            return item
        end
    end
    return nil
end

function SignConfig:GetBySignReward(value)
    for i, item in pairs(self.Data) do
        if item.SignReward == value then
            return item
        end
    end
    return nil
end

function SignConfig:GetAll()
    return self.Data
end

function SignConfig:GetCount()
    local count = 0
    for _ in pairs(self.Data) do
        count = count + 1
    end
    return count
end

return SignConfig