local DeadState = {}
DeadState.__index = DeadState

-- 死亡状态
function DeadState.new(AIManager, animation)
    local self = setmetatable({}, DeadState)
    self.AIManager = AIManager
    self.animation = animation
    return self
end

function DeadState:Enter()
    print("进入Dead状态")
    self.AIManager:PlayAnimation(self.animation, false)
    
    -- 禁用碰撞和移动
    self.AIManager.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    self.AIManager.Humanoid.WalkSpeed = 0

    task.delay(5, function()
        self.AIManager:Destroy()
        self.AIManager = nil
    end)
    
    -- -- 触发物品掉落
    -- local monsterType = self.AIManager.NPC:GetAttribute("MonsterType")
    -- local config = MonsterConfig[monsterType] or {Drops = {}}
    -- if config and config.Drops then
    --     local npcPosition = self.AIManager.NPC:GetPivot().Position
        
    --     for _, drop in ipairs(config.Drops) do
    --         if math.random() <= drop.Chance then
    --             local dropPart = Instance.new("Part")
    --             dropPart.Size = Vector3.new(1,1,1)
    --             dropPart.Position = npcPosition + drop.Offset
    --             dropPart.Anchored = true
    --             dropPart.BrickColor = BrickColor.Random()
    --             dropPart.Parent = workspace
                
    --             local tag = Instance.new("StringValue")
    --             tag.Name = "ItemType"
    --             tag.Value = drop.ItemId
    --             tag.Parent = dropPart
    --         end
    --     end
    -- end
end

function DeadState:Update(dt)

end

function DeadState:Exit()
    print("退出Dead状态")
end

return DeadState