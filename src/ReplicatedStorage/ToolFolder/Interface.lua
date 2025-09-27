local Interface = {}

-- 获取服务
local UserInputService = game:GetService("UserInputService")

--[[
    深拷贝函数 - 递归复制表结构
    @param original table 原始表
    @return table 深拷贝后的新表
]]
function Interface.clone(original)
    if type(original) ~= "table" then
        return original
    end
    
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = Interface.clone(value)
    end
    
    return copy
end

function Interface.formatTimeMMSS(seconds)
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", minutes, secs)
end

-- 使用多层射线检测获取真正的地面位置
-- @param startPosition Vector3 起始位置
-- @param ignoreList table 忽略的实例列表
-- @return Vector3 地面位置，如果没有检测到则返回原位置
function Interface.getGroundPosition(startPosition, ignoreList)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = ignoreList or {}
    
    local currentPosition = startPosition
    local totalHeightDrop = 0
    local maxLayers = 5 -- 最多检测5层
    local minHeightDrop = 3 -- 最小高度差要求
    
    for layer = 1, maxLayers do
        -- 从当前位置向下发射射线
        local rayDirection = Vector3.new(0, -100, 0)
        local raycastResult = workspace:Raycast(currentPosition, rayDirection, raycastParams)
        
        if raycastResult then
            local hitPosition = raycastResult.Position
            local layerHeightDrop = currentPosition.Y - hitPosition.Y
            totalHeightDrop = totalHeightDrop + layerHeightDrop
            
            -- 检查是否是足够厚的地面
            if layerHeightDrop >= minHeightDrop and totalHeightDrop >= minHeightDrop then
                local groundPosition = hitPosition + Vector3.new(0, 0.1, 0)
                return groundPosition
            elseif layerHeightDrop < 0.5 then
                -- 击中了很薄的结构，继续向下检测
                currentPosition = hitPosition - Vector3.new(0, 0.1, 0) -- 稍微向下偏移继续检测
                
                -- 将击中的物体加入忽略列表，避免重复击中
                if raycastResult.Instance then
                    table.insert(raycastParams.FilterDescendantsInstances, raycastResult.Instance)
                end
            else
                -- 找到了有一定厚度的地面
                if totalHeightDrop >= minHeightDrop then
                    local groundPosition = hitPosition + Vector3.new(0, 0.1, 0)
                    return groundPosition
                else
                    -- 高度差不够，继续检测
                    currentPosition = hitPosition - Vector3.new(0, 0.1, 0)
                end
            end
        else
            -- 没有击中任何物体
            print("第", layer, "层未击中任何物体")
            break
        end
    end
    
    -- 所有检测都失败，返回一个安全的地面位置
    local safeGroundPosition = Vector3.new(startPosition.X, startPosition.Y - 10, startPosition.Z)
    return safeGroundPosition
end

--[[
    更精确的手机检测（推荐使用）
    结合多种因素判断，包括屏幕尺寸、安全区域、输入方式等
    @return boolean 如果是手机设备返回true，否则返回false
]]
function Interface.isMobile()
    if game:GetService("RunService"):IsStudio() then
        return true
    end
    -- 必须有触摸屏
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and
           not UserInputService.MouseEnabled then
        return true
    end
    return false
end

return Interface