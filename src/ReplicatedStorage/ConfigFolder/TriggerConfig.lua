return {
    -- 单独的物品捡取触发器
    {
        ConditionType = "ItemPickUp", -- 条件类型：基于物品拾取的触发器
        MaxConditions = -1, -- 最大触发次数，超过此次数后不再触发
        ItemId = 1035, -- 触发物品的ID
        Cooldown = 0, -- 触发冷却时间（秒），在此时间内不会再次触发
        RandomChance = 100, -- 随机触发的概率，10%的概率触发
        Action = {
            ActionType = "ChangeMonsterAttribute",
            AttributeName = "VisionRange",
            AttributeValue = 70,
        }
    },
    -- 单独的物品丢弃触发器
    {
        ConditionType = "ItemDrop", -- 条件类型：基于物品丢弃的触发器
        MaxConditions = -1, -- 最大触发次数，超过此次数后不再触发
        ItemId = 1035, -- 触发物品的ID
        Cooldown = 0, -- 触发冷却时间（秒），在此时间内不会再次触发
        RandomChance = 100, -- 随机触发的概率，10%的概率触发
        Action = {
            ActionType = "ChangeMonsterAttribute",
            AttributeName = "VisionRange",
            AttributeValue = -1,
        }
    },
    -- 单独的物品捡取触发器
    {
        ConditionType = "ItemPickUp", -- 条件类型：基于物品拾取的触发器
        MaxConditions = -1, -- 最大触发次数，超过此次数后不再触发
        ItemId = 1035, -- 触发物品的ID
        Cooldown = 0, -- 触发冷却时间（秒），在此时间内不会再次触发
        RandomChance = 100, -- 随机触发的概率，10%的概率触发
        Action = {
            ActionType = "ShowUI",
            UI = "DangerUI",
        }
    },
}