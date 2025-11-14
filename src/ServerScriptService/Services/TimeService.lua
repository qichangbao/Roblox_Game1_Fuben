local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local Lighting = game:GetService("Lighting")
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))

local TimeService = Knit.CreateService({
    Name = 'TimeService',
    Client = {
    },

    IsLongZhuPickUp = false
})

-- 时间系统配置
local _gameTime = 8 -- 游戏时间（小时，0-24）
local _lastUpdateTime = tick() -- 上次更新的真实时间
local _isNight = false -- 是否是晚上

-- 时间系统更新函数
-- @param deltaTime number 距离上次更新的真实时间间隔（秒）
function TimeService:updateGameTime(deltaTime)
    -- 计算游戏时间增量（小时）
    local gameTimeIncrement = (deltaTime * GameConfig.Real_To_Game_Second) / 3600
    
    -- 更新游戏时间
    _gameTime = _gameTime + gameTimeIncrement
    
    -- 确保时间在0-24小时范围内循环
    if _gameTime >= 24 then
        _gameTime = _gameTime - 24
    elseif _gameTime < 0 then
        _gameTime = _gameTime + 24
    end
    
    if not _isNight then
        -- 更新是否是晚上
        _isNight = (_gameTime >= 18 or _gameTime < 6)
        if _isNight and not self.IsLongZhuPickUp then
            Knit.GetService("MonsterService"):ChangeAllMonsterAttribute(0.3)
            Knit.GetService("ClientUIService"):ShowUIAll("NoticeUI", {Type = 1, Title = "Monsters are active", Text  = "Nighttime: Attributes increased by 30%"})
        end
    else
        -- 更新是否是白天
        _isNight = (_gameTime >= 18 or _gameTime < 6)
        if not _isNight and not self.IsLongZhuPickUp  then
            Knit.GetService("MonsterService"):ChangeAllMonsterAttribute(-0.3)
            Knit.GetService("ClientUIService"):ShowUIAll("NoticeUI", {Type = 2, Title = "Monsters are resting", Text  = "Daytime: Attributes decreased by 30%"})
        end
    end
    
    -- 更新Lighting的ClockTime
    Lighting.ClockTime = _gameTime
end

function TimeService:LongZhuPickUp()
    self.IsLongZhuPickUp = true
end

function TimeService:KnitInit()
end

function TimeService:KnitStart()
    -- 连接到Heartbeat事件进行实时更新
    game:GetService("RunService").Heartbeat:Connect(function(dt)
        local currentTime = tick()
        local deltaTime = currentTime - _lastUpdateTime
        
        -- 更新游戏时间
        self:updateGameTime(deltaTime)
        
        -- 记录当前时间用于下次计算
        _lastUpdateTime = currentTime
    end)
end

return TimeService
