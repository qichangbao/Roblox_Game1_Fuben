-- 摄像机控制脚本
-- 在角色加载后设置摄像头朝向玩家的前方
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local camera = workspace.CurrentCamera

local _connection = nil
local shakeIntensity = 0.3 -- 持续晃动的强度 (值越大晃动越剧烈)
local shakeSpeed = 20 -- 持续晃动的速度 (值越大晃动越频繁)
local impactShake = 0 -- 当前冲击晃动的强度，由外部函数设置
local impactDecay = 5 -- 冲击晃动的衰减速度
-- 持续晃动的内部状态
local shakeOffset = Vector3.new(0, 0, 0)
local shakeTime = 0
-- 晃动时长控制
local shakeDuration = 0.6 -- 镜头晃动的持续时间（秒）
local shakeElapsed = 0 -- 已累计的晃动时间（秒）
-- 函数：应用镜头晃动
-- 应用镜头晃动（函数级注释）：
-- @param deltaTime number 每帧时间间隔（秒），由 RenderStepped 提供
-- 行为：
-- 1) 在 shakeDuration 时间内应用持续晃动与冲击晃动（叠加）
-- 2) 当累计时间达到 shakeDuration 时自动停止并断开连接
local function applyShake(deltaTime)
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end

	-- 计时与自动停止
	shakeElapsed = shakeElapsed + deltaTime
	if shakeElapsed >= shakeDuration then
		impactShake = 0
		shakeOffset = Vector3.new(0, 0, 0)
		if _connection then
			_connection:Disconnect()
			_connection = nil
		end
		return
	end

	-- 1. 更新并应用持续晃动
    shakeTime = shakeTime + deltaTime * shakeSpeed
    -- 使用 sine 和 cosine 函数生成平滑的、随机的偏移量
    local x = math.sin(shakeTime * 1.2) * shakeIntensity
    local y = math.cos(shakeTime * 0.9) * shakeIntensity
    local z = math.sin(shakeTime * 1.5) * shakeIntensity * 0.5 -- Z轴晃动较小，避免头晕
    shakeOffset = Vector3.new(x, y, z)

	-- 2. 更新并应用冲击晃动
	if impactShake > 0 then
		-- 在持续晃动的基础上，叠加一个随机的冲击偏移
		local randomShake = Vector3.new(
			math.random(-1, 1) * impactShake,
			math.random(-1, 1) * impactShake,
			math.random(-1, 1) * impactShake * 0.5
		)
		camera.CFrame = camera.CFrame * CFrame.new(randomShake)

		-- 让冲击晃动的强度随时间衰减
		impactShake = impactShake - impactDecay * deltaTime
		if impactShake < 0 then
			impactShake = 0
		end
	elseif shakeOffset ~= Vector3.new(0, 0, 0) then
		-- 如果只有持续晃动，则直接应用偏移
		camera.CFrame = camera.CFrame * CFrame.new(shakeOffset)
	end
end

Knit.OnStart():andThen(function()
    Knit.GetController("UIController").ShakeCarame:Connect(function(info)
        if _connection then
            _connection:Disconnect()
            _connection = nil
        end
        
        shakeIntensity = info and info.ShakeIntensity or 0.3 -- 持续晃动的强度 (值越大晃动越剧烈)
        shakeSpeed = info and info.ShakeSpeed or 20 -- 持续晃动的速度 (值越大晃动越频繁)
        shakeElapsed = 0    -- 每次触发时重置计时与参数
        shakeDuration = info and info.ShakeDuration or 0.6 -- 固定为0.5秒，如需可改为从item读取
        
        -- 连接到渲染步进事件，每一帧都更新镜头位置
        _connection = game:GetService("RunService").RenderStepped:Connect(applyShake)
    end)
end)
