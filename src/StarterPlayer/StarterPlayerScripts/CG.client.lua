local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild('Packages'):WaitForChild('Knit'):waitForChild('Knit'))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild('GameConfig'))
local ItemConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ItemConfig"))
local RunService = game:GetService("RunService")
-- ========== 宝箱展示系统 ==========

--[[
    宝箱展示动画控制器
    获取地图中的所有宝箱并用摄像头逐个展示
]]
local ChestShowcaseSystem = {}
local AllItems = {}

-- 展示配置
local SHOWCASE_CONFIG = {
    -- 每个宝箱的展示时间（秒）
    showcaseDuration = 3,
    -- 摄像头距离宝箱的距离
    cameraDistance = 15,
    -- 摄像头高度偏移
    cameraHeightOffset = 8,
    -- 摄像头围绕宝箱旋转的角度范围（度）
    rotationAngle = 45,
    -- 切换到下一个宝箱的过渡时间（秒）
    transitionDuration = 1.5,
    -- 展示结束后是否自动切换到玩家视角
    autoSwitchToPlayer = true,
    -- 展示开始前的等待时间
    startDelay = 1,
    -- 最后一个箱子的特殊效果配置
    lastChest = {
        -- 第一阶段：至少360度旋转，在面向玩家时停止
        phase1 = {
            -- 最少旋转角度（度）
            minRotationAngle = 360,
            -- 旋转速度（度/秒）
            rotationSpeed = 120,
            -- 旋转时的摄像头距离
            rotationDistance = 20,
            -- 旋转时的高度偏移
            rotationHeightOffset = 12
        },
        -- 第二阶段：移动到玩家前方
        phase2 = {
            -- 移动到玩家前方的持续时间（秒）
            duration = 1.5,
            -- 玩家前方的距离
            frontDistance = 8,
            -- 前方位置的高度偏移
            frontHeightOffset = 2
        },
        -- 第三阶段：旋转到玩家后方
        phase3 = {
            -- 旋转到玩家后方的持续时间（秒）
            duration = 2,
            -- 玩家后方的距离
            behindPlayerDistance = 12,
            -- 玩家后方的高度
            behindPlayerHeight = 8
        }
    },
    -- 摄像头回归玩家的动画配置
    returnToPlayer = {
        -- 回归动画持续时间（秒）
        duration = 2,
        -- 回归动画缓动样式
        easingStyle = Enum.EasingStyle.Quad,
        -- 回归动画缓动方向
        easingDirection = Enum.EasingDirection.InOut
    }
}

--[[
    获取玩家位置
    @return Vector3 玩家位置，如果玩家不存在则返回nil
]]
function ChestShowcaseSystem.getPlayerPosition()
    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    
    if not localPlayer.Character then
        return nil
    end
    
    local humanoidRootPart = localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        return nil
    end
    
    return humanoidRootPart.Position
end

--[[
    计算从宝箱位置面向玩家的角度
    @param chestPosition Vector3 宝箱位置
    @param playerPosition Vector3 玩家位置
    @return number 角度（度）
]]
function ChestShowcaseSystem.calculateAngleToPlayer(chestPosition, playerPosition)
    local direction = playerPosition - chestPosition
    local angle = math.atan2(direction.Z, direction.X)
    return math.deg(angle)
end

--[[
    获取地图中的所有宝箱
    @return table 宝箱实例数组
]]
function ChestShowcaseSystem.getChestsInWorld()
    local chests = {}
    -- 遍历workspace中的所有对象
    for _, obj in pairs(AllItems) do
        -- 检查是否是宝箱（通过ItemId属性判断）
        local itemId = obj:GetAttribute("ItemId")
        if itemId then
			local itemInfo = ItemConfig:GetByItemId(itemId)
            -- 检查是否是宝箱类型（501=普通宝箱，502=黄金宝箱，503=炫彩宝箱）
            if itemInfo.Type == GameConfig.ItemType.Chest then
                table.insert(chests, obj)
            end
        end
    end
    
    -- 按ItemId排序，ID越小的优先展示
    table.sort(chests, function(a, b)
        local itemIdA = a:GetAttribute("ItemId") or 999999
        local itemIdB = b:GetAttribute("ItemId") or 999999
        return itemIdA < itemIdB
    end)
    
    return chests
end

--[[
    获取宝箱的展示位置
    @param chest Instance 宝箱实例
    @return Vector3 摄像头位置
    @return Vector3 摄像头朝向目标
]]
function ChestShowcaseSystem.getChestCameraPosition(chest)
    local chestPosition
    
    -- 获取宝箱位置
    if chest:IsA("Model") then
        chestPosition = chest:GetPivot().Position
    else
        chestPosition = chest.Position
    end
    
    -- 计算摄像头位置（在宝箱前方稍高的位置）
    local cameraPosition = Vector3.new(
        chestPosition.X + SHOWCASE_CONFIG.cameraDistance,
        chestPosition.Y + SHOWCASE_CONFIG.cameraHeightOffset,
        chestPosition.Z
    )
    
    return cameraPosition, chestPosition
end

--[[
    展示单个宝箱
    @param chest Instance 宝箱实例
    @param index number 宝箱索引
    @param totalChests number 总宝箱数量
    @return void
]]
function ChestShowcaseSystem.showcaseChest(chest, index, totalChests)
    local camera = workspace.CurrentCamera
    local TweenService = game:GetService("TweenService")
    local isLastChest = (index == totalChests)
    
    -- 获取摄像头位置
    local cameraPosition, chestPosition = ChestShowcaseSystem.getChestCameraPosition(chest)
    
    -- 如果是最后一个箱子，调整摄像头距离和高度
    if isLastChest then
        cameraPosition = Vector3.new(
            chestPosition.X + SHOWCASE_CONFIG.lastChest.phase1.rotationDistance,
            chestPosition.Y + SHOWCASE_CONFIG.lastChest.phase1.rotationHeightOffset,
            chestPosition.Z
        )
    end
    
    -- 创建摄像头移动动画
    local tweenInfo = TweenInfo.new(
        SHOWCASE_CONFIG.transitionDuration,
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.InOut
    )
    
    local targetCFrame = CFrame.lookAt(cameraPosition, chestPosition)
    local moveTween = TweenService:Create(camera, tweenInfo, {CFrame = targetCFrame})
    
    -- 播放移动动画
    moveTween:Play()
    
    -- 等待移动完成
    moveTween.Completed:Wait()
    
    -- 旋转动画
    local rotationConnection
    local startTime = tick()
    local initialAngle = 0
    
    -- 根据是否为最后一个箱子选择不同的动画
    if isLastChest then
        -- 最后一个箱子：多阶段动画
        print("[宝箱展示] 开始最后一个箱子的多阶段展示")
        
        -- 获取玩家位置
        local playerPosition = ChestShowcaseSystem.getPlayerPosition()
        print("[调试] 玩家位置:", playerPosition)
        if not playerPosition then
            print("[宝箱展示] 无法获取玩家位置，使用默认动画")
            -- 如果无法获取玩家位置，使用简单的旋转动画
            rotationConnection = RunService.Heartbeat:Connect(function()
                local elapsed = tick() - startTime
                local progress = elapsed / 3
                
                if progress >= 1 then
                    rotationConnection:Disconnect()
                    return
                end
                
                local currentAngle = initialAngle + (360 * progress)
                local rotatedX = chestPosition.X + math.cos(math.rad(currentAngle)) * SHOWCASE_CONFIG.lastChest.phase1.rotationDistance
                local rotatedZ = chestPosition.Z + math.sin(math.rad(currentAngle)) * SHOWCASE_CONFIG.lastChest.phase1.rotationDistance
                local rotatedPosition = Vector3.new(rotatedX, chestPosition.Y + SHOWCASE_CONFIG.lastChest.phase1.rotationHeightOffset, rotatedZ)
                
                camera.CFrame = CFrame.lookAt(rotatedPosition, chestPosition)
            end)
            task.wait(3)
        else
            -- 第一阶段：摄像头围绕宝箱旋转一圈（360度）
            print("[宝箱展示] 第一阶段：摄像头围绕宝箱旋转一圈")
            
            local rotationSpeed = 120 -- 每秒旋转120度，3秒完成一圈
            local targetRotation = 360 -- 旋转360度（一圈）
            local rotationDistance = SHOWCASE_CONFIG.lastChest.phase1.rotationDistance
            local heightOffset = SHOWCASE_CONFIG.lastChest.phase1.rotationHeightOffset
            
            local startAngle = 0 -- 从0度开始
            local currentAngle = startAngle
            local totalRotated = 0 -- 已旋转的总角度
            local phase1Completed = false
            
            print("[调试] 开始第一阶段旋转，目标旋转角度:", targetRotation, "度")
            
            rotationConnection = RunService.Heartbeat:Connect(function()
                local deltaTime = RunService.Heartbeat:Wait()
                local angleIncrement = rotationSpeed * deltaTime
                
                currentAngle = currentAngle + angleIncrement
                totalRotated = totalRotated + angleIncrement
                
                -- 计算摄像头位置（围绕宝箱旋转）
                local rotatedX = chestPosition.X + math.cos(math.rad(currentAngle)) * rotationDistance
                local rotatedZ = chestPosition.Z + math.sin(math.rad(currentAngle)) * rotationDistance
                local cameraPosition = Vector3.new(rotatedX, chestPosition.Y + heightOffset, rotatedZ)
                
                -- 摄像头始终面向宝箱
                camera.CFrame = CFrame.lookAt(cameraPosition, chestPosition)
                
                -- 停止条件：旋转至少360度，且玩家在摄像头视野范围内
                if totalRotated >= targetRotation then
                    -- 计算摄像头朝向（看向宝箱的方向）
                    local cameraLookDirection = (chestPosition - cameraPosition).Unit
                    
                    -- 计算摄像头到玩家的方向
                    local cameraToPlayerDirection = (playerPosition - cameraPosition).Unit
                    
                    -- 只考虑XZ轴的水平方向
                    local cameraLookDirection2D = Vector2.new(cameraLookDirection.X, cameraLookDirection.Z).Unit
                    local cameraToPlayerDirection2D = Vector2.new(cameraToPlayerDirection.X, cameraToPlayerDirection.Z).Unit
                    
                    -- 计算玩家是否在摄像头视野范围内（假设视野角度为60度，左右各30度）
                    local dotProduct = cameraLookDirection2D:Dot(cameraToPlayerDirection2D)
                    local angleToPlayer = math.acos(math.clamp(dotProduct, -1, 1))
                    local fieldOfViewHalf = math.rad(30) -- 视野角度的一半
                    
                    -- 如果玩家在视野范围内，停止旋转
                    if angleToPlayer <= fieldOfViewHalf then
                        rotationConnection:Disconnect()
                        phase1Completed = true
                        print("[调试] 第一阶段完成，总旋转角度:", totalRotated, "度，玩家在摄像头视野内")
                        return
                    end
                end
                
                -- 调试信息：每90度输出一次
                if math.floor(totalRotated / 90) > math.floor((totalRotated - angleIncrement) / 90) then
                    print("[调试] 旋转进度:", math.floor(totalRotated), "度，目标：至少360度且玩家在视野内")
                    if totalRotated >= targetRotation then
                        local cameraLookDirection = (chestPosition - cameraPosition).Unit
                        local cameraToPlayerDirection = (playerPosition - cameraPosition).Unit
                        local cameraLookDirection2D = Vector2.new(cameraLookDirection.X, cameraLookDirection.Z).Unit
                        local cameraToPlayerDirection2D = Vector2.new(cameraToPlayerDirection.X, cameraToPlayerDirection.Z).Unit
                        local dotProduct = cameraLookDirection2D:Dot(cameraToPlayerDirection2D)
                        local angleToPlayer = math.acos(math.clamp(dotProduct, -1, 1))
                        local fieldOfViewHalf = math.rad(30)
                        print("[调试] 已达到最小旋转角度，玩家与摄像头朝向角度差:", math.deg(angleToPlayer), "度，视野范围:", math.deg(fieldOfViewHalf), "度")
                    end
                end
            end)
            
            -- 等待第一阶段完成
            while not phase1Completed do
                task.wait(0.1)
            end
            print("[调试] 第一阶段完成，准备进入第二阶段")
            
            -- 获取第一阶段结束时的摄像头位置
            local phase1EndPosition = camera.CFrame.Position
            print("[调试] 第一阶段结束位置:", phase1EndPosition)
            
            -- 第一阶段完成后停顿1秒
            print("[调试] 第一阶段停顿1秒")
            task.wait(1)
            
            -- 第二阶段：向后上方拉升摄像头
            print("[宝箱展示] 第二阶段：向后上方拉升摄像头")
            
            local pullBackDistance = 30 -- 向后拉远30个单位
            local pullBackHeight = 25 -- 向上拉升25个单位
            
            -- 计算向后上方的目标位置
            local cameraToPlayer = (playerPosition - phase1EndPosition).Unit
            local backDirection = -cameraToPlayer -- 背离玩家的方向
            local phase2TargetPosition = phase1EndPosition + backDirection * pullBackDistance + Vector3.new(0, pullBackHeight, 0)
            
            
            -- 第二阶段拉升动画
            local phase2Duration = 2 -- 2秒拉升时间
            local phase2StartTime = tick()
            local phase2Connection
            local phase2Completed = false
            
            phase2Connection = RunService.Heartbeat:Connect(function()
                local elapsed = tick() - phase2StartTime
                local progress = elapsed / phase2Duration
                
                if progress >= 1 then
                    phase2Connection:Disconnect()
                    phase2Completed = true
                    print("[调试] 第二阶段拉升完成")
                    return
                end
                
                -- 从第一阶段结束位置向后上方拉升
                local currentPosition = phase1EndPosition:lerp(phase2TargetPosition, progress)
                
                -- 摄像头朝向从宝箱慢慢转向玩家
                local lookAtTarget = chestPosition:lerp(playerPosition, progress)
                camera.CFrame = CFrame.lookAt(currentPosition, lookAtTarget)
                
                -- 调试信息
                print(string.format("[调试] 第二阶段进度: %.2f%%, 朝向目标: %s", progress * 100, tostring(lookAtTarget)))
            end)
            
            -- 等待第二阶段完成
            while not phase2Completed do
                task.wait(0.1)
            end
            
            -- 第三阶段：停顿1秒
            print("[宝箱展示] 第三阶段：停顿1秒")
            task.wait(1)
            
            -- 第四阶段：摄像头移动到玩家前方
            print("[宝箱展示] 第四阶段：摄像头移动到玩家前方")
            
            -- 获取第二阶段结束时的摄像头位置
            local phase3StartPosition = phase2TargetPosition
            
            -- 计算玩家前方6个单位、高度8个单位的目标位置
            local playerLookDirection = game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector
            local phase4TargetPosition = playerPosition + playerLookDirection * 6 + Vector3.new(0, 8, 0)
            
            -- 第四阶段移动动画
            local phase4Duration = 3 -- 3秒移动时间
            local phase4StartTime = tick()
            local phase4Connection
            local phase4Completed = false
            
            phase4Connection = RunService.Heartbeat:Connect(function()
                local elapsed = tick() - phase4StartTime
                local progress = elapsed / phase4Duration
                
                if progress >= 1 then
                    phase4Connection:Disconnect()
                    phase4Completed = true
                    print("[调试] 第四阶段移动完成")
                    return
                end
                
                -- 从第三阶段位置移动到玩家前方
                local currentPosition = phase3StartPosition:lerp(phase4TargetPosition, progress)
                
                -- 摄像头始终面向玩家
                camera.CFrame = CFrame.lookAt(currentPosition, playerPosition)
                
                -- 调试信息
                print(string.format("[调试] 第四阶段进度: %.2f%%, 当前位置: %s", progress * 100, tostring(currentPosition)))
            end)
            
            -- 等待第四阶段完成
            while not phase4Completed do
                task.wait(0.1)
            end
            
            -- 第五阶段：从玩家前方旋转到玩家后方（Y轴保持不变）
            print("[宝箱展示] 第五阶段：围绕玩家旋转到后方（Y轴固定）")
            
            -- 获取第四阶段结束时摄像头的Y轴位置（保持不变）
            local fixedYPosition = phase4TargetPosition.Y
            
            -- 计算旋转半径（基于第四阶段结束位置到玩家的XZ距离）
            local xzDistance = math.sqrt((phase4TargetPosition.X - playerPosition.X)^2 + (phase4TargetPosition.Z - playerPosition.Z)^2)
            local rotationRadius = xzDistance
            
            -- 重新设计旋转逻辑：从当前位置旋转180度到达后方
            local startAngle = 0 -- 从0度开始（前方）
            local totalRotation = 180 -- 总共旋转180度到达后方
            
            -- 计算起始位置（标准化到前方）
            local startDirection = (phase4TargetPosition - playerPosition)
            startDirection = Vector3.new(startDirection.X, 0, startDirection.Z).Unit -- 只保留XZ分量
            
            local phase5Duration = 1.5 -- 4秒旋转时间
            local phase5StartTime = tick()
            local phase5Connection
            local phase5Completed = false
            
            print("[调试] 第五阶段 - 固定Y轴位置:", fixedYPosition, "旋转半径:", rotationRadius)
            print("[调试] 起始方向:", startDirection)
            print("[调试] 将旋转", totalRotation, "度到达后方")
            
            phase5Connection = RunService.Heartbeat:Connect(function()
                local elapsed = tick() - phase5StartTime
                local progress = elapsed / phase5Duration
                
                if progress >= 1 then
                    phase5Connection:Disconnect()
                    phase5Completed = true
                    print("[调试] 第五阶段旋转完成")
                    return
                end
                
                -- 获取玩家实时位置
                local currentPlayerPosition = game.Players.LocalPlayer.Character.HumanoidRootPart.Position
                
                -- 计算当前旋转角度（从0度旋转到180度）
                local currentRotationAngle = totalRotation * progress
                
                -- 使用CFrame旋转起始方向向量
                local rotationCFrame = CFrame.Angles(0, math.rad(currentRotationAngle), 0)
                local rotatedDirection = rotationCFrame:VectorToWorldSpace(startDirection)
                
                -- 计算摄像头位置（只在XZ平面旋转，Y轴保持不变）
                local cameraPosition = currentPlayerPosition + rotatedDirection * rotationRadius
                cameraPosition = Vector3.new(cameraPosition.X, fixedYPosition, cameraPosition.Z)
                
                -- 摄像头始终面向玩家的实时位置
                camera.CFrame = CFrame.lookAt(cameraPosition, currentPlayerPosition)
                
                -- 调试信息
                print(string.format("[调试] 第五阶段旋转进度: %.2f%%, 当前旋转角度: %.1f度", progress * 100, currentRotationAngle))
                print(string.format("[调试] 玩家实时位置: (%.1f, %.1f, %.1f)", currentPlayerPosition.X, currentPlayerPosition.Y, currentPlayerPosition.Z))
                print(string.format("[调试] 摄像头位置: (%.1f, %.1f, %.1f)", cameraPosition.X, cameraPosition.Y, cameraPosition.Z))
            end)
            
            -- 等待第五阶段完成
            while not phase5Completed do
                task.wait(0.1)
            end
            
            -- 第六阶段：恢复Custom默认的卫视
            print("[宝箱展示] 第六阶段：恢复Custom默认的卫视")
            
            -- 恢复摄像头类型为Custom（默认跟随玩家的卫视）
            camera.CameraType = Enum.CameraType.Custom
            print("[调试] 第六阶段完成，摄像头已恢复为Custom默认卫视")
            
            print("[宝箱展示] 所有阶段完成！")
            local Players = game:GetService("Players")
            local localPlayer = Players.LocalPlayer
            local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
            local humanoid = character:WaitForChild("Humanoid")
            
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = humanoid
            
            -- 恢复光照设置
            Lighting.Brightness = 0.1
            local Atmosphere = Lighting:WaitForChild("Atmosphere")
            Atmosphere.Density = 0.6
            
            -- 清除全局标志
            _G.CGPlaying = false
            
            print("[宝箱展示] 最后一个宝箱展示完全完成")
        end
        
    else
        -- 普通箱子：小幅摆动
        rotationConnection = RunService.Heartbeat:Connect(function()
            local elapsed = tick() - startTime
            local progress = elapsed / SHOWCASE_CONFIG.showcaseDuration
            
            if progress >= 1 then
                rotationConnection:Disconnect()
                return
            end
            
            -- 计算旋转角度
            local currentAngle = initialAngle + (SHOWCASE_CONFIG.rotationAngle * math.sin(progress * math.pi * 2))
            
            -- 计算新的摄像头位置
            local rotatedX = chestPosition.X + math.cos(math.rad(currentAngle)) * SHOWCASE_CONFIG.cameraDistance
            local rotatedZ = chestPosition.Z + math.sin(math.rad(currentAngle)) * SHOWCASE_CONFIG.cameraDistance
            local rotatedPosition = Vector3.new(rotatedX, cameraPosition.Y, rotatedZ)
            
            -- 更新摄像头
            camera.CFrame = CFrame.lookAt(rotatedPosition, chestPosition)
        end)
        
        -- 等待展示时间结束
        task.wait(SHOWCASE_CONFIG.showcaseDuration)
    end
    
    -- 清理连接
    if rotationConnection then
        rotationConnection:Disconnect()
    end
end

--[[
    开始宝箱展示动画
    @return void
]]
function ChestShowcaseSystem.start()
    local camera = workspace.CurrentCamera
    
    -- 设置全局标志，防止其他摄像头脚本干扰
    _G.CGPlaying = true
    
    -- 设置摄像头为脚本控制模式
    camera.CameraType = Enum.CameraType.Scriptable
    
    -- 获取所有宝箱
    local chests = ChestShowcaseSystem.getChestsInWorld()
    
    if #chests == 0 then
        print("[宝箱展示] 没有发现宝箱，结束展示")
        ChestShowcaseSystem.switchToPlayerView()
        return
    end
    
    -- 等待开始延迟
    --task.wait(SHOWCASE_CONFIG.startDelay)
    
    -- 逐个展示宝箱
    for i, chest in ipairs(chests) do
        ChestShowcaseSystem.showcaseChest(chest, i, #chests)
    end
    
    -- 展示完成，切换回玩家视角（只有当全局标志还存在时才调用，说明没有宝箱或者普通宝箱）
    -- 注释掉自动切换，因为最后一个宝箱的第四阶段会自己处理摄像头恢复
    -- if SHOWCASE_CONFIG.autoSwitchToPlayer and _G.CGPlaying then
    --     task.wait(0.1) -- 稍微等待一下
    --     ChestShowcaseSystem.switchToPlayerView()
    -- end
end

--[[
    切换到玩家视角
    @return void
]]
function ChestShowcaseSystem.switchToPlayerView()
    local camera = workspace.CurrentCamera
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local localPlayer = Players.LocalPlayer
    
    print("[宝箱展示] 开始切换回玩家视角")
    
    -- 等待玩家角色加载
    local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    -- 计算目标摄像头位置（玩家后方稍高的位置）
    local playerPosition = humanoidRootPart.Position
    local targetPosition = playerPosition + Vector3.new(0, 5, 10) -- 玩家后方5单位高度，10单位距离
    local targetCFrame = CFrame.lookAt(targetPosition, playerPosition)
    
    -- 创建平滑的摄像头回归动画
    local tweenInfo = TweenInfo.new(
        SHOWCASE_CONFIG.returnToPlayer.duration,
        SHOWCASE_CONFIG.returnToPlayer.easingStyle,
        SHOWCASE_CONFIG.returnToPlayer.easingDirection
    )
    
    local returnTween = TweenService:Create(camera, tweenInfo, {CFrame = targetCFrame})
    
    -- 播放回归动画
    returnTween:Play()
    
    -- 等待动画完成
    returnTween.Completed:Wait()
    
    -- 切换回自定义摄像头模式
    camera.CameraType = Enum.CameraType.Custom
    camera.CameraSubject = humanoid
    
    Lighting.Brightness = 0.1
    local Atmosphere = Lighting:WaitForChild("Atmosphere")
    Atmosphere.Density = 0.6
    
    -- 清除全局标志
    _G.CGPlaying = false
    
    print("[宝箱展示] 摄像头已回归玩家视角")
end

--[[
    创建测试按钮
    @return void
]]
local function createTestButton()
    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer
    local playerGui = localPlayer:WaitForChild("PlayerGui")
    
    -- 创建ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ChestShowcaseTestUI"
    screenGui.Parent = playerGui
    
    -- 创建测试按钮
    local testButton = Instance.new("TextButton")
    testButton.Name = "ChestShowcaseButton"
    testButton.Size = UDim2.new(0, 200, 0, 50)
    testButton.Position = UDim2.new(0, 10, 0, 10)
    testButton.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
    testButton.BorderSizePixel = 0
    testButton.Text = "展示宝箱"
    testButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    testButton.TextScaled = true
    testButton.Font = Enum.Font.SourceSansBold
    testButton.Parent = screenGui
    
    -- 添加圆角
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = testButton
    
    -- 按钮点击事件
    testButton.MouseButton1Click:Connect(function()
        -- 检查是否已经在播放动画
        if _G.CGPlaying then
            print("已有摄像头动画在播放中，请等待完成")
            return
        end
        
        -- 开始宝箱展示
        ChestShowcaseSystem.start()
    end)
    
    print("[测试UI] 宝箱展示测试按钮已创建")
end

Knit.OnStart():andThen(function()
	Knit.GetController("UIController").ShowCG:Connect(function()
        if game:GetService("RunService"):IsStudio() then
            return
        end
        while #AllItems == 0 do
            Knit.GetService("ItemService"):GetItems():andThen(function(items)
                AllItems = items
            end)
            task.wait(1)
        end
        
        Lighting.Brightness = 5
        local Atmosphere = Lighting:WaitForChild("Atmosphere")
        Atmosphere.Density = 0.1
        ChestShowcaseSystem.start()
        --createTestButton()
	end)
end)