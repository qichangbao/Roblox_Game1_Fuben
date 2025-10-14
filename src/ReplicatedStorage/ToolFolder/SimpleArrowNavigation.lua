--[[
	简化箭头导航系统
	使用现有的PathfindingMove来计算路径并显示箭头
	作者: AI Assistant
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ModelFolder = ReplicatedStorage:WaitForChild("ModelFolder")

local SimpleArrowNavigation = {}

-- 当前活跃的箭头
local activeArrows = {}
local arrowConnections = {}
local arrowTweens = {} -- 存储箭头的动画对象

-- 实时更新相关变量
local currentTarget = nil -- 当前目标位置
local updateConnection = nil -- 更新连接
local lastPlayerPosition = nil -- 上次玩家位置
local updateInterval = 0.5 -- 更新间隔（秒）
local lastUpdateTime = 0 -- 上次更新时间

--[[
	创建单个箭头模型
	@param position Vector3 箭头位置
	@param direction Vector3 箭头方向
	@return Model 箭头模型
]]
local function createArrow(position, direction)
	-- 射线检测地面高度
	local raycast = workspace:Raycast(position + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0))
	local groundY = raycast and raycast.Position.Y or position.Y
	local arrowPosition = Vector3.new(position.X, groundY + 0.1, position.Z) -- 稍微抬高一点避免Z-fighting
	
	-- 使用预制的箭头模型
	local arrowModel = ModelFolder:WaitForChild("Arrow"):Clone()
	arrowModel.Name = "NavigationArrow"
	
	-- 计算箭头朝向（考虑预制模型的默认朝向）
	local lookDirection = direction.Unit
	
	-- 调试信息
	print("箭头位置:", arrowPosition)
	print("目标方向:", lookDirection)
	
	-- 尝试不同的朝向计算，预制模型可能默认朝向不同
	local arrowCFrame = CFrame.lookAt(arrowPosition, arrowPosition + lookDirection)
	
	-- 调试：尝试不同的旋转来找到正确的朝向
	-- 选项1：不旋转（默认）
	-- 选项2：绕Y轴旋转180度
	--arrowCFrame = arrowCFrame * CFrame.Angles(0, math.rad(180), 0)
	-- 选项3：绕X轴旋转180度
	arrowCFrame = arrowCFrame * CFrame.Angles(math.rad(-90), 0, math.rad(180))
	-- 选项4：绕Y轴旋转90度
	--arrowCFrame = arrowCFrame * CFrame.Angles(0, math.rad(90), 0)
	-- 选项5：绕Y轴旋转-90度
	-- arrowCFrame = arrowCFrame * CFrame.Angles(0, math.rad(-90), 0)
	
	print("最终箭头CFrame:", arrowCFrame)
	
	-- 设置整个模型的位置和朝向
	if arrowModel.PrimaryPart then
		arrowModel:SetPrimaryPartCFrame(arrowCFrame)
	end
	
	-- 确保所有部件都是锚定的（预制模型应该已经正确设置）
	for _, part in pairs(arrowModel:GetChildren()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
	
	-- 添加向前移动动画，增强指向效果
	local moveDistance = 1.5 -- 向前移动的距离
	local tweenTargets = {}
	
	-- 向前移动动画（整个模型一起动）
	if arrowModel.PrimaryPart then
		-- 使用PrimaryPart作为基准，但通过MoveTo移动整个模型
		local originalCFrame = arrowModel.PrimaryPart.CFrame
		local targetCFrame = originalCFrame + CFrame.new(0, 0, moveDistance)
		
		local moveInfo = TweenInfo.new(
			1.5, -- 持续时间
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1, -- 无限重复
			true -- 反向播放
		)
		
		-- 创建一个虚拟对象来驱动整个模型的移动
		local moveDriver = Instance.new("CFrameValue")
		moveDriver.Value = originalCFrame
		
		local moveTween = TweenService:Create(moveDriver, moveInfo, {Value = targetCFrame})
		
		-- 连接动画更新事件，移动整个模型
		local connection = moveDriver.Changed:Connect(function(newCFrame)
			if arrowModel.PrimaryPart then
				arrowModel:SetPrimaryPartCFrame(newCFrame)
			end
		end)
		
		moveTween:Play()
		tweenTargets[#tweenTargets + 1] = moveTween
		tweenTargets[#tweenTargets + 1] = connection -- 存储连接以便清理
		tweenTargets[#tweenTargets + 1] = moveDriver -- 存储驱动对象以便清理
	end
	
	-- 存储动画对象以便后续清理
	arrowTweens[arrowModel] = tweenTargets
	
	arrowModel.Parent = Workspace
	return arrowModel
end

--[[
	使用PathfindingService获取路径点
	@param startPos Vector3 起始位置
	@param targetPos Vector3 目标位置
	@return table 路径点数组
]]
local function getPathWaypoints(startPos, targetPos)
	-- 参数验证
	if not startPos or not targetPos then
		warn("getPathWaypoints: 起始位置或目标位置为空")
		return nil
	end
	
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 6,
		AgentCanJump = true,
	})
	
	local success, errorMessage = pcall(function()
		path:ComputeAsync(startPos, targetPos)
	end)
	
	if not success or path.Status ~= Enum.PathStatus.Success then
		warn("路径计算失败:", errorMessage or "未知错误")
		return nil
	end
	
	local waypoints = path:GetWaypoints()
	local pathPoints = {}
	
	-- 过滤掉水面路径点
	for i, wp in ipairs(waypoints) do
		if wp.Label == "Water" then
			break
		end
		table.insert(pathPoints, wp.Position)
	end
	
	return pathPoints
end


--[[
	显示箭头导航路径
	@param targetPosition Vector3 目标位置
	@param startPosition Vector3 起始位置（可选，默认使用玩家位置）
	@return boolean 是否成功创建路径
]]
function SimpleArrowNavigation.ShowPath(targetPosition, startPosition)
	-- 清理现有箭头
	SimpleArrowNavigation.ClearPath()
	
	-- 获取起始位置
	local startPos = startPosition
	if not startPos then
		local Players = game:GetService("Players")
		local LocalPlayer = Players.LocalPlayer
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
			startPos = LocalPlayer.Character.HumanoidRootPart.Position
		else
			warn("无法获取玩家位置")
			return false
		end
	end
	
	-- 获取路径点
	local pathPoints = getPathWaypoints(startPos, targetPosition)
	if not pathPoints or #pathPoints < 2 then
		warn("无法计算有效路径")
		return false
	end
	
	-- 创建箭头（跳过起点和终点）
	for i = 2, #pathPoints - 1 do
		local currentPos = pathPoints[i]
		local nextPos = pathPoints[i + 1]
		local direction = (nextPos - currentPos).Unit
		
		-- 创建箭头
		local arrow = createArrow(currentPos, direction)
		table.insert(activeArrows, arrow)
	end
	
	
	print("箭头导航路径已创建，共", #activeArrows, "个箭头")
	return true
end

--[[
	清理所有箭头
]]
function SimpleArrowNavigation.ClearPath()
	for _, arrow in ipairs(activeArrows) do
		if arrow and arrow.Parent then
			-- 停止动画和清理资源
		local tweens = arrowTweens[arrow]
		if tweens then
			for _, item in ipairs(tweens) do
				if item then
					-- 检查是否是Tween对象
					if typeof(item) == "Instance" and item:IsA("Tween") then
						item:Cancel()
					-- 检查是否是连接对象
					elseif typeof(item) == "RBXScriptConnection" then
						item:Disconnect()
					-- 检查是否是驱动对象
					elseif typeof(item) == "Instance" then
						item:Destroy()
					end
				end
			end
			arrowTweens[arrow] = nil
		end
			
			-- 删除箭头
			arrow:Destroy()
		end
	end
	activeArrows = {}
	
	-- 断开连接
	for _, connection in ipairs(arrowConnections) do
		if connection then
			connection:Disconnect()
		end
	end
	arrowConnections = {}
	
	-- 停止实时更新
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end
	
	-- 清理状态
	currentTarget = nil
	lastPlayerPosition = nil
	lastUpdateTime = 0
	
	print("箭头导航路径已清理")
end

--[[
	获取玩家当前位置
	@return Vector3 玩家位置
]]
local function getPlayerPosition()
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		return player.Character.HumanoidRootPart.Position
	end
	return nil
end

--[[
	检查玩家是否移动了足够的距离
	@param newPosition Vector3 新位置
	@param oldPosition Vector3 旧位置
	@param threshold number 移动阈值（默认3）
	@return boolean 是否需要更新
]]
local function shouldUpdatePath(newPosition, oldPosition, threshold)
	threshold = threshold or 3
	if not oldPosition then return true end
	local distance = (newPosition - oldPosition).Magnitude
	return distance >= threshold
end

--[[
	实时更新箭头路径
]]
local function updateArrowPath()
	if not currentTarget then return end
	
	local currentTime = tick()
	if currentTime - lastUpdateTime < updateInterval then return end
	
	local playerPosition = getPlayerPosition()
	if not playerPosition then return end
	
	-- 检查是否需要更新路径
	if not shouldUpdatePath(playerPosition, lastPlayerPosition, 3) then return end
	
	lastPlayerPosition = playerPosition
	lastUpdateTime = currentTime
	
	-- 清理当前箭头
	for i = #activeArrows, 1, -1 do
		local arrow = activeArrows[i]
		-- 清理箭头
		if arrow and arrow.Parent then
			local tweens = arrowTweens[arrow]
			if tweens then
				for _, item in ipairs(tweens) do
					if item then
						-- 检查是否是Tween对象
						if typeof(item) == "Instance" and item:IsA("Tween") then
							item:Cancel()
						-- 检查是否是连接对象
						elseif typeof(item) == "RBXScriptConnection" then
							item:Disconnect()
						-- 检查是否是驱动对象
						elseif typeof(item) == "Instance" then
							item:Destroy()
						end
					end
				end
				arrowTweens[arrow] = nil
			end
			arrow:Destroy()
		end
		table.remove(activeArrows, i)
	end
	
	-- 重新计算路径并创建箭头
	local waypoints = getPathWaypoints(playerPosition, currentTarget)
	if waypoints and #waypoints > 1 then
		-- 创建新的箭头（跳过起点和终点）
		for i = 2, #waypoints - 1 do
			local currentWaypoint = waypoints[i]
			local nextWaypoint = waypoints[i + 1]
			local direction = (nextWaypoint - currentWaypoint).Unit
			
			local arrow = createArrow(currentWaypoint, direction)
			table.insert(activeArrows, arrow)
		end
		
		print("箭头路径已更新，当前箭头数量:", #activeArrows)
	end
end

--[[
	启动实时更新
	@param targetPosition Vector3 目标位置
	@param interval number 更新间隔（秒，默认0.5）
]]
function SimpleArrowNavigation.StartRealTimeUpdate(targetPosition, interval)
	-- 停止之前的更新
	if updateConnection then
		updateConnection:Disconnect()
	end
	
	currentTarget = targetPosition
	updateInterval = interval or 0.5
	lastPlayerPosition = getPlayerPosition()
	lastUpdateTime = tick()
	
	-- 启动实时更新循环
	updateConnection = RunService.Heartbeat:Connect(updateArrowPath)
	
	print("实时更新已启动，更新间隔:", updateInterval, "秒")
end

--[[
	停止实时更新
]]
function SimpleArrowNavigation.StopRealTimeUpdate()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end
	currentTarget = nil
	lastPlayerPosition = nil
	print("实时更新已停止")
end

--[[
	检查玩家是否接近目标
	@param targetPosition Vector3 目标位置
	@param threshold number 距离阈值（默认5）
	@return boolean 是否接近目标
]]
function SimpleArrowNavigation.IsNearTarget(targetPosition, threshold)
	threshold = threshold or 5
	
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer
	if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
		return false
	end
	
	local playerPos = LocalPlayer.Character.HumanoidRootPart.Position
	local distance = (targetPosition - playerPos).Magnitude
	
	return distance <= threshold
end

--[[
	启动自动清理（当玩家接近目标时自动清理箭头）
	@param targetPosition Vector3 目标位置
	@param threshold number 距离阈值（默认5）
]]
function SimpleArrowNavigation.StartAutoCleanup(targetPosition, threshold)
	threshold = threshold or 5
	
	local connection = RunService.Heartbeat:Connect(function()
		if SimpleArrowNavigation.IsNearTarget(targetPosition, threshold) then
			SimpleArrowNavigation.ClearPath()
			print("已到达目标，自动清理箭头")
		end
	end)
	
	table.insert(arrowConnections, connection)
end

--[[
	显示路径并启动自动清理和实时更新
	@param targetPosition Vector3 目标位置
	@param startPosition Vector3 起始位置（可选）
	@param autoCleanupDistance number 自动清理距离（默认5）
	@param enableRealTimeUpdate boolean 是否启用实时更新（默认true）
	@param updateInterval number 更新间隔（秒，默认0.5）
	@return boolean 是否成功创建路径
]]
function SimpleArrowNavigation.NavigateTo(targetPosition, startPosition, autoCleanupDistance, enableRealTimeUpdate, updateInterval)
	local success = SimpleArrowNavigation.ShowPath(targetPosition, startPosition)
	if success then
		SimpleArrowNavigation.StartAutoCleanup(targetPosition, autoCleanupDistance)
		
		-- 默认启用实时更新
		if enableRealTimeUpdate ~= false then
			SimpleArrowNavigation.StartRealTimeUpdate(targetPosition, updateInterval)
		end
	end
	return success
end

--[[
	获取当前活跃箭头数量
	@return number 箭头数量
]]
function SimpleArrowNavigation.GetActiveArrowCount()
	return #activeArrows
end

return SimpleArrowNavigation