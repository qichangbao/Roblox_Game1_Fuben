-- 台阶跨越功能测试脚本
-- 将此脚本放在ServerScriptService中运行

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- 创建测试台阶
local function createTestSteps()
    -- 清除旧的测试台阶
    for _, obj in pairs(workspace:GetChildren()) do
        if obj.Name == "TestStep" then
            obj:Destroy()
        end
    end
    
    -- 创建不同高度的测试台阶
    local stepHeights = {0.5, 1.0, 1.5, 2.0}  -- 不同高度台阶
    local startPos = Vector3.new(380, 2.47, -160)
    
    for i, height in ipairs(stepHeights) do
        local step = Instance.new("Part")
        step.Name = "TestStep"
        step.Size = Vector3.new(8, 1, 4)
        step.Position = startPos + Vector3.new(i * 6, height, 0)
        step.Anchored = true
        step.CanCollide = true
        step.Color = Color3.fromRGB(255, 100, 100)
        step.Material = Enum.Material.Concrete
        step.Parent = workspace
        
        -- 添加标签显示高度
        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 100, 0, 40)
        billboard.StudsOffset = Vector3.new(0, 2, 0)
        billboard.Adornee = step
        billboard.Parent = step
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.Text = string.format("高度: %.1f", height)
        textLabel.TextColor3 = Color3.new(1, 1, 1)
        textLabel.BackgroundTransparency = 1
        textLabel.Parent = billboard
    end
    
    print("测试台阶创建完成！")
end

-- 创建测试NPC
local function createTestNPC()
    -- 清除旧的测试NPC
    for _, obj in pairs(workspace:GetChildren()) do
        if obj.Name == "TestNPC" then
            obj:Destroy()
        end
    end
    
    -- 创建简单的NPC模型
    local npc = Instance.new("Model")
    npc.Name = "TestNPC"
    
    local humanoidRootPart = Instance.new("Part")
    humanoidRootPart.Name = "HumanoidRootPart"
    humanoidRootPart.Size = Vector3.new(2, 2, 1)
    humanoidRootPart.Position = Vector3.new(375, 2.47, -160)
    humanoidRootPart.Anchored = false
    humanoidRootPart.CanCollide = true
    humanoidRootPart.Parent = npc
    
    local humanoid = Instance.new("Humanoid")
    humanoid.Parent = npc
    
    npc.PrimaryPart = humanoidRootPart
    npc.Parent = workspace
    
    print("测试NPC创建完成！位置:", humanoidRootPart.Position)
    return npc
end

-- 运行测试
createTestSteps()
local testNPC = createTestNPC()

print("=== 台阶跨越测试开始 ===")
print("已创建4个不同高度的测试台阶（0.5, 1.0, 1.5, 2.0）")
print("NPC初始位置:", testNPC.HumanoidRootPart.Position)
print("请观察NPC是否能成功跨越不同高度的台阶！")

return true