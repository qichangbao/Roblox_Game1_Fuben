local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))

-- 归一化图像ID（函数级注释）
-- 功能：
--   - 将不同格式的图像ID统一转成可用于 ImageLabel.Image 的字符串
-- 支持输入：
--   - number：例如 123456789 转成 "rbxassetid://123456789"
--   - string：
--       * 已含前缀："rbxassetid://123456" -> 原样返回
--       * 纯数字串："123456" -> 补前缀返回
--       * URL 格式："https://...id=123456" -> 提取数字后补前缀
-- 返回：
--   - string | nil：合法字符串返回；非法或空返回 nil
local function normalizeId(raw)
    if raw == nil then return nil end
    local t = typeof(raw)
    if t == "number" then
        if raw > 0 then
            return "rbxassetid://" .. tostring(math.floor(raw))
        else
            return nil
        end
    elseif t == "string" then
        local s = raw
        if s == "" then return nil end
        if s:find("rbxassetid://", 1, true) then
            return s
        end
        local idStr = s:match("id=(%d+)") or s:match("^(%d+)$")
        if idStr then
            return "rbxassetid://" .. idStr
        end
        -- 兜底：若是非数字但可能是有效内容ID（如开发期自定义），直接返回
        return s
    else
        return nil
    end
end

-- 收集需要预加载的全部图标ID（函数级注释）
-- 功能：
--   - 合并 ImageConfig.Icons 与 ItemConfig.Data[*].Icon 中的所有图标
--   - 自动去重与过滤非法ID
-- 返回：
--   - {string} 归一化后的图标ID列表
local function collectAllIconIds()
    local uniq = {}
    local result = {}

    local function addOne(id)
        local norm = normalizeId(id)
        if norm and not uniq[norm] then
            uniq[norm] = true
            table.insert(result, norm)
        end
    end

    for _, item in pairs(ItemConfig:GetAll()) do
        if item and item.Icon then
            addOne(item.Icon)
        end
    end

    return result
end

-- 为每个图标ID创建一个临时 ImageLabel 实例（函数级注释）
-- 功能：
--   - 创建未挂载到UI层级的 ImageLabel，仅用于 ContentProvider:PreloadAsync 预加载
-- 参数：
--   - iconIds {string} 归一化后的图标ID列表
-- 返回：
--   - {Instance} 实例数组，可直接传入 PreloadAsync
local function createImageInstances(iconIds)
    local instances = {}
    for i, id in ipairs(iconIds) do
        local img = Instance.new("ImageLabel")
        img.Name = "__PreloadIcon__" .. tostring(i)
        img.BackgroundTransparency = 1
        img.Image = id
        -- 避免影响布局：保持未挂载，或最小尺寸
        img.Size = UDim2.fromOffset(1, 1)
        table.insert(instances, img)
    end
    return instances
end

-- 预加载图标（函数级注释）
-- 功能：
--   - 调用 ContentProvider:PreloadAsync 预加载图片资源，避免首次显示时卡顿
-- 参数：
--   - instances {Instance} 由 createImageInstances 返回的实例数组
-- 行为：
--   - 使用 pcall 捕获错误；预加载完成后销毁临时实例
local function preloadIcons(instances)
    if #instances == 0 then return end
    local ok, err = pcall(function()
        ContentProvider:PreloadAsync(instances)
    end)
    -- 预加载结束后销毁临时实例
    for _, inst in ipairs(instances) do
        inst:Destroy()
    end
    if not ok then
        warn("[ImagePreload] 预加载失败：", err)
    end
end

-- 脚本入口：在客户端加载时启动图标预加载（函数级注释）
-- 行为：
--   - 异步收集与预加载，避免阻塞其它 UI 初始化
--   - 输出简单日志以便调试
task.spawn(function()
    local ids = collectAllIconIds()
    print(("[ImagePreload] 准备预加载 %d 个图标"):format(#ids))
    local instances = createImageInstances(ids)
    preloadIcons(instances)
    print("[ImagePreload] 图标预加载完成")
end)

