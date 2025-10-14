--[[
    3D模型UI显示系统
    使用ViewportFrame在UI中显示3D模型
    支持模型旋转、缩放、光照等功能
    @author AI Assistant
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Model3DViewer = {}

--[[
    创建3D模型查看器
    @param parent GuiObject 父级UI对象
    @param config table 配置参数
    @return table 查看器实例
]]
function Model3DViewer.new(parent, config)
    config = config or {}
    
    local self = {
        -- UI组件
        viewportFrame = nil,
        camera = nil,
        
        -- 3D对象
        model = nil,
        worldModel = nil,
        
        -- 配置
        size = config.size or UDim2.new(0, 200, 0, 200),
        position = config.position or UDim2.new(0, 0, 0, 0),
        backgroundColor = config.backgroundColor or Color3.fromRGB(50, 50, 50),
        backgroundTransparency = config.backgroundTransparency or 0,
        
        -- 相机设置
        cameraDistance = config.cameraDistance or 6, -- 从10调整为6，让模型显示得更大
        cameraAngle = config.cameraAngle or Vector3.new(0, 0, 0),
        fieldOfView = config.fieldOfView or 70,
        
        -- 交互设置
        enableRotation = config.enableRotation ~= false, -- 默认启用
        enableZoom = config.enableZoom ~= false, -- 默认启用
        autoRotate = config.autoRotate or false,
        rotationSpeed = config.rotationSpeed or 1,
        
        -- 光照设置
        ambientColor = config.ambientColor or Color3.fromRGB(100, 100, 100),
        lightDirection = config.lightDirection or Vector3.new(-1, -1, -1),
        lightColor = config.lightColor or Color3.fromRGB(255, 255, 255),
        
        -- 内部状态
        connections = {},
        isDestroyed = false,
        currentRotation = 0,
    }
    
    -- 设置metatable以便访问方法
    setmetatable(self, {__index = Model3DViewer})
    
    -- 创建UI组件
    self:_createUI(parent)
    
    -- 设置光照
    self:_setupLighting()
    
    -- 设置交互
    if self.enableRotation or self.enableZoom then
        self:_setupInteraction()
    end
    
    -- 设置自动旋转
    if self.autoRotate then
        self:_setupAutoRotation()
    end
    
    return self
end

--[[
    创建UI组件
    @param parent GuiObject 父级UI对象
]]
function Model3DViewer:_createUI(parent)
    -- 创建ViewportFrame
    self.viewportFrame = Instance.new("ViewportFrame")
    self.viewportFrame.Size = self.size
    self.viewportFrame.Position = self.position
    self.viewportFrame.BackgroundColor3 = self.backgroundColor
    self.viewportFrame.BackgroundTransparency = self.backgroundTransparency
    self.viewportFrame.BorderSizePixel = 0
    self.viewportFrame.Parent = parent
    
    -- 添加圆角（可选）
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = self.viewportFrame
    
    -- 创建WorldModel
    self.worldModel = Instance.new("WorldModel")
    self.worldModel.Parent = self.viewportFrame
    
    -- 创建相机
    self.camera = Instance.new("Camera")
    self.camera.Parent = self.worldModel
    self.viewportFrame.CurrentCamera = self.camera
    self.camera.FieldOfView = self.fieldOfView
end

--[[
    设置光照
    注意：ViewportFrame中不能直接使用Lighting对象
    我们使用PointLight和SurfaceLight来模拟光照效果
]]
function Model3DViewer:_setupLighting()
    -- 创建一个隐藏的Part来放置光源
    local lightPart = Instance.new("Part")
    lightPart.Name = "LightSource"
    lightPart.Size = Vector3.new(1, 1, 1)
    lightPart.Transparency = 1 -- 完全透明
    lightPart.CanCollide = false
    lightPart.Anchored = true
    lightPart.Position = Vector3.new(0, 5, 10) -- 放在模型前上方
    lightPart.Parent = self.worldModel
    
    -- 添加点光源
    local pointLight = Instance.new("PointLight")
    pointLight.Brightness = 1
    pointLight.Color = self.lightColor
    pointLight.Range = 50
    pointLight.Parent = lightPart
    
    -- 添加环境光（使用另一个点光源模拟环境光）
    local ambientLight = Instance.new("PointLight")
    ambientLight.Brightness = 0.3
    ambientLight.Color = self.ambientColor
    ambientLight.Range = 100
    ambientLight.Parent = self.worldModel
    
    -- 保存引用以便后续调整
    self.lightSources = {
        lightPart = lightPart,
        pointLight = pointLight,
        ambientLight = ambientLight
    }
end

--[[
    设置交互功能
]]
function Model3DViewer:_setupInteraction()
    local UserInputService = game:GetService("UserInputService")
    local dragging = false
    local lastMousePosition = nil
    
    -- 鼠标拖拽旋转
    if self.enableRotation then
        local connection1 = self.viewportFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                lastMousePosition = input.Position
            end
        end)
        
        local connection2 = self.viewportFrame.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - lastMousePosition
                self:rotateModel(delta.X * 0.01, delta.Y * 0.01)
                lastMousePosition = input.Position
            end
        end)
        
        local connection3 = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        
        table.insert(self.connections, connection1)
        table.insert(self.connections, connection2)
        table.insert(self.connections, connection3)
    end
    
    -- 鼠标滚轮缩放
    if self.enableZoom then
        local connection4 = self.viewportFrame.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseWheel then
                local zoomFactor = input.Position.Z > 0 and 0.9 or 1.1
                self:zoomCamera(zoomFactor)
            end
        end)
        
        table.insert(self.connections, connection4)
    end
end

--[[
    设置自动旋转
]]
function Model3DViewer:_setupAutoRotation()
    local connection = RunService.Heartbeat:Connect(function(dt)
        if not self.isDestroyed and self.model then
            self.currentRotation = self.currentRotation + dt * self.rotationSpeed
            self:updateCameraPosition()
        end
    end)
    
    table.insert(self.connections, connection)
end

--[[
    设置要显示的3D模型
    @param model Model 要显示的模型
]]
function Model3DViewer:setModel(model)
    -- 检查必要的组件是否存在
    if not self.worldModel then
        warn("Model3DViewer: WorldModel不存在，无法设置模型")
        return
    end
    
    if not model then
        warn("Model3DViewer: 传入的模型为nil")
        return
    end
    
    -- 清理旧模型
    if self.model then
        self.model:Destroy()
    end
    
    -- 克隆新模型
    local success, clonedModel = pcall(function()
        return model:Clone()
    end)
    
    if not success or not clonedModel then
        warn("Model3DViewer: 模型克隆失败")
        return
    end
    
    self.model = clonedModel
    self.model.Parent = self.worldModel
    
    -- 设置模型位置，稍微往下移动
    if self.model.PrimaryPart then
        self.model:SetPrimaryPartCFrame(CFrame.new(0, -1, 0)) -- Y坐标从0改为-1，往下移动
    else
        -- 如果没有PrimaryPart，移动第一个Part
        local firstPart = self.model:FindFirstChildOfClass("BasePart")
        if firstPart then
            firstPart.CFrame = CFrame.new(0, -1, 0) -- Y坐标从0改为-1，往下移动
        end
    end
    
    -- 自动调整相机距离
    self:_autoFitCamera()
    
    -- 更新相机位置
    self:updateCameraPosition()
end

--[[
    自动调整相机距离以适应模型大小
]]
function Model3DViewer:_autoFitCamera()
    if not self.model then return end
    
    local cf, size = self.model:GetBoundingBox()
    local maxSize = math.max(size.X, size.Y, size.Z)
    -- 调整倍数从2改为1.2，让模型显示得更大
    self.cameraDistance = maxSize * 0.7
end

--[[
    更新相机位置
]]
function Model3DViewer:updateCameraPosition()
    if not self.camera or not self.model then return end
    
    local angle = self.cameraAngle + Vector3.new(0, self.currentRotation, 0)
    local x = math.sin(angle.Y) * self.cameraDistance
    local z = math.cos(angle.Y) * self.cameraDistance
    local y = math.sin(angle.X) * self.cameraDistance
    
    local cameraPosition = Vector3.new(x, y, z)
    self.camera.CFrame = CFrame.lookAt(cameraPosition, Vector3.new(0, 0, 0))
end

--[[
    旋转模型
    @param deltaX number X轴旋转增量
    @param deltaY number Y轴旋转增量
]]
function Model3DViewer:rotateModel(deltaX, deltaY)
    self.cameraAngle = self.cameraAngle + Vector3.new(deltaY, deltaX, 0)
    self:updateCameraPosition()
end

--[[
    缩放相机（改变距离）
    @param factor number 缩放因子
]]
function Model3DViewer:zoomCamera(factor)
    self.cameraDistance = math.clamp(self.cameraDistance * factor, 1, 100)
    self:updateCameraPosition()
end

--[[
    设置相机视野
    @param fov number 视野角度
]]
function Model3DViewer:setFieldOfView(fov)
    self.fieldOfView = fov
    if self.camera then
        self.camera.FieldOfView = fov
    end
end

--[[
    播放模型动画（如果模型有Humanoid）
    @param animationId string 动画ID
]]
function Model3DViewer:playAnimation(animationId)
    if not self.model then return end
    
    local humanoid = self.model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end
        
        local animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://" .. animationId
        
        local track = animator:LoadAnimation(animation)
        track:Play()
        
        return track
    end
end

--[[
    销毁查看器
]]
function Model3DViewer:destroy()
    self.isDestroyed = true
    
    -- 断开所有连接
    for _, connection in ipairs(self.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    -- 销毁UI组件
    if self.viewportFrame then
        self.viewportFrame:Destroy()
    end
    
    -- 清理引用
    self.model = nil
    self.worldModel = nil
    self.camera = nil
    self.viewportFrame = nil
    self.lightSources = nil
end

return Model3DViewer