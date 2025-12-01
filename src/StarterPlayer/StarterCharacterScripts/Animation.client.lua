-- 动画预加载与预热（客户端）
-- 目的：解决“第一次播放动画很久、第二次正常”的问题
-- 原理：在角色生成后，提前下载动画资源并让 Animator 建立播放管线
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local localPlayer = Players.LocalPlayer

-- 将数字或字符串ID标准化为 Animation 实例列表
-- @function createAnimationsFromIds
-- @param ids {number|string}[] 动画ID数组（支持纯数字或带rbxassetid://的字符串）
-- @return Animation[] 返回创建好的 Animation 实例数组
local function createAnimationsFromIds()
    local animations = {}
    for animName, animId in pairs(GameConfig.AnimationMap) do
        local anim = Instance.new("Animation")
        if typeof(animId) == "string" then
            if animId:match("^rbxassetid://") then
                anim.AnimationId = animId
            else
                local normalized = animId:gsub("/", "")
                anim.AnimationId = "rbxassetid://" .. normalized
            end
        else
            anim.AnimationId = "rbxassetid://" .. tostring(animId)
        end
        table.insert(animations, anim)
    end
    return animations
end

-- 从角色模型中收集已挂载的 Animation 实例
-- @function collectCharacterAnimations
-- @param character Model 玩家角色
-- @return Animation[] 返回角色下的 Animation 实例数组（包含所有子孙）
local function collectCharacterAnimations(character: Model): {Animation}
    local animations: {Animation} = {}
    for _, desc in ipairs(character:GetDescendants()) do
        if desc:IsA("Animation") then
            table.insert(animations, desc)
        end
    end
    return animations
end

-- 预加载并预热动画资源（核心函数）
-- @function preloadAndWarmupAnimations
-- @param character Model 玩家角色
-- @param animations Animation[] 需要预加载与预热的动画实例列表
-- @return nil 无返回；内部进行 ContentProvider 预加载与 Animator 预热
local function preloadAndWarmupAnimations(character: Model, animations: {Animation})
    if #animations == 0 then return end

    -- 1) 预加载到客户端缓存，避免第一次播放才下载
    local okPreload, errPreload = pcall(function()
        ContentProvider:PreloadAsync(animations)
    end)
    if not okPreload then
        warn("[AnimationPreload] PreloadAsync failed:", errPreload)
    end

    -- 2) 构建 Animator 播放管线：以 speed=0 的短暂播放进行预热
    local humanoid = character:FindFirstChildOfClass("Humanoid")
        or character:FindFirstChild("Humanoid")
        or character:WaitForChild("Humanoid", 5)
    if not humanoid then return end

    local animator = humanoid:FindFirstChildOfClass("Animator")
        or humanoid:WaitForChild("Animator", 5)
    if not animator then return end

    for _, anim in ipairs(animations) do
        local okTrack, trackOrErr = pcall(function()
            return animator:LoadAnimation(anim)
        end)
        if okTrack and trackOrErr then
            local track: AnimationTrack = trackOrErr :: any
            -- 以 speed=0 播放一帧，促使 Animator 建立混合与骨骼映射缓存
            track:Play(0, 0, 0)
            track:AdjustSpeed(0)
            task.wait()
            track:Stop()
        else
            warn("[AnimationPreload] LoadAnimation failed:", trackOrErr)
        end
    end
end

-- 角色生成时进行动画预加载与预热
-- @function onCharacterAdded
-- @param character Model 玩家角色
-- 行为：合并角色内动画与通用ID动画，统一预加载与预热
local function onCharacterAdded(character: Model)
    -- 收集角色上已有的 Animation 实例
    --local charAnimations = collectCharacterAnimations(character)

    -- 从常用ID创建 Animation 实例（供通用预热）
    local idAnimations = createAnimationsFromIds()

    -- 合并列表（避免重复即可，简单拼接）
    --local allAnimations = {}
    --for _, a in ipairs(charAnimations) do table.insert(allAnimations, a) end
    --for _, a in ipairs(idAnimations) do table.insert(allAnimations, a) end

    preloadAndWarmupAnimations(character, idAnimations)
end

-- 绑定 CharacterAdded，并处理已存在角色
-- @function bindCharacterAdded
-- 行为：确保在玩家加入后立即对角色执行预加载与预热逻辑
local function bindCharacterAdded()
    localPlayer.CharacterAdded:Connect(onCharacterAdded)
    if localPlayer.Character then
        onCharacterAdded(localPlayer.Character)
    end
end

bindCharacterAdded()

