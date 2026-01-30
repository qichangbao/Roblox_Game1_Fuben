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
-- 规范化动画ID并创建 Animation 列表（函数级注释）：
-- @return Animation[]
-- 行为：遍历 GameConfig.AnimationMap，支持如下输入格式：
-- 1) 字符串："rbxassetid://123"、"123"、"http(s)://...asset?id=123"
-- 2) 数字：123
-- 3) 数组：{ "rbxassetid://123", "456" }（同名多动画）
-- 将所有有效ID转换为 Animation 实例并返回，用于后续预加载与预热。
local function createAnimationsFromIds()
    local function normalizeId(id)
        if typeof(id) == "number" then
            return "rbxassetid://" .. tostring(id)
        elseif typeof(id) == "string" then
            local direct = id:match("^rbxassetid://(%d+)$")
            if direct then
                return "rbxassetid://" .. direct
            end
            local fromUrl = id:match("[?&]id=(%d+)")
            if fromUrl then
                return "rbxassetid://" .. fromUrl
            end
            local plain = id:match("^(%d+)$")
            if plain then
                return "rbxassetid://" .. plain
            end
            warn("[AnimationPreload] 无效的动画ID格式:", id)
            return nil
        else
            warn("[AnimationPreload] 不支持的动画ID类型:", typeof(id))
            return nil
        end
    end

    local animations = {}
    local function createAnimationsFromId(id, animName)
        local normalized = normalizeId(id)
        if normalized then
            local anim = Instance.new("Animation")
            anim.Name = animName
            anim.AnimationId = normalized
            table.insert(animations, anim)
        end
    end

    for animName, value in pairs(GameConfig.AnimationMap) do
        if typeof(value) == "table" then
            for _, id in ipairs(value) do
                createAnimationsFromId(id, animName)
            end
        else
            createAnimationsFromId(value, animName)
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
    local humanoid = character:WaitForChild("Humanoid")
    if not humanoid then return end
    local animator = humanoid:WaitForChild("Animator")
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

local function onCharacterAdded(character: Model)
    -- 从常用ID创建 Animation 实例（供通用预热）
    local idAnimations = createAnimationsFromIds()

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
