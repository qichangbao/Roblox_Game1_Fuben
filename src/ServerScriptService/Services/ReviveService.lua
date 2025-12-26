local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local HeroConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("HeroConfig"))
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local ReviveData = {
    {Type = 1, Value = 1000, Description = "Revive for 1000 Gold"},
    {Type = 1, Value = 3000, Description = "Revive for 3000 Gold"},
    {Type = 2, Value = 69, Description = "Revive for 69 Robux"},
}

local ReviveService = Knit.CreateService({
    Name = 'ReviveService',
    Client = {
    },

    PlayerReviveCount = {},
    FreeReviveCount = {},
})

function ReviveService:PlayerAdded(player)
    self.PlayerReviveCount[player.UserId] = 0

    local jobEffect = Interface.GetJobEffect(player)
    self.FreeReviveCount[player.UserId] = jobEffect and jobEffect.FreeReviveCount or 0
    -- 监听玩家角色生成
    local function onCharacterAdded(character)
        local humanoid = character:WaitForChild("Humanoid")
        
        -- 监听玩家死亡事件
        humanoid.Died:Connect(function()
            local tool = Knit.GetService("InventoryService"):GetToolData(player)
            for _, itemData in pairs(tool) do
                itemData.Attribute.IsEquipped = 0
            end
            Knit.GetService("InventoryService"):SendToolData(player)

            -- 如果撤离时间到了，不能复活
            local taskEscapeTime = Knit.GetService("TaskService"):GetEscapeTime(player)
            if taskEscapeTime <= 0 then
                return
            end

            local freeReviveCount = self.FreeReviveCount[player.UserId]
            if freeReviveCount > 0 then
                Knit.GetService("ClientUIService"):ShowUISingle(player, "MessageBoxUI", {
                    Type = 1,
                    Content = "You can revive once for free",
                    ButtonText1 = "Revive",
                    ButtonText2 = "Leave",
                    Button2Time = 20,
                })
                return
            end

            local reviveCount = self.PlayerReviveCount[player.UserId]
            local reviveData = ReviveData[reviveCount + 1]
            if not reviveData then
                Knit.GetService("SettleService"):Settle(player, false, true)
                return
            end

            Knit.GetService("ClientUIService"):ShowUISingle(player, "MessageBoxUI", {
                Type = 1,
                Content = string.format(reviveData.Description, reviveData.Value),
                ButtonText1 = "Revive",
                ButtonText2 = "Leave",
                Button2Time = 20,
            })
        end)
    end
    
    -- 如果玩家已经有角色，立即监听
    if player.Character then
        onCharacterAdded(player.Character)
    end
    
    -- 监听玩家角色重新生成
    player.CharacterAdded:Connect(onCharacterAdded)
end

function ReviveService:PlayerRemoved(player)
    self.PlayerReviveCount[player.UserId] = nil
end

local function loadPlayer(player)
    local frame = player.Character:GetPivot()
    player:LoadCharacter()
    player.Character:PivotTo(CFrame.new(frame.Position))

    Knit.GetService("DBService"):Update(player.UserId, "BuyReviveCount", function(BuyReviveCount)
        return BuyReviveCount + 1
    end)
    Knit.GetService("JobService"):TriggerJob(player, GameConfig.JobUnlockCondition.Relive, Knit.GetService("DBService"):Get(player.UserId, "BuyReviveCount"))
end

function ReviveService:RevivePlayer(player)
    -- 如果有免费复活次数，直接复活
    if self.FreeReviveCount[player.UserId] > 0 then
        loadPlayer(player)
        self.FreeReviveCount[player.UserId] -= 1
        return 2
    end

    local reviveCount = self.PlayerReviveCount[player.UserId]
    if reviveCount >= #ReviveData then
        Knit.GetService("ClientUIService"):ShowUISingle(player, "MessageBoxUI", {
            Type = 2,
            Content = "Revive times exhausted",
            ButtonText1 = "Leave",
            Button2Time = 20,
        })
        return 0
    end
    
    local success = false
    local reviveData = ReviveData[reviveCount + 1]
    if reviveData.Type == 1 then
        success = self:BuyReviveByGold(player, reviveData.Value)
    elseif reviveData.Type == 2 then
        Knit.GetService("PurchaseService"):BuyRevive(player)
        return 1
    end
    
    if not success then
        return 0
    end
    
    loadPlayer(player)
    self.PlayerReviveCount[player.UserId] += 1
    return 2
end

function ReviveService.Client:RevivePlayer(player)
    return self.Server:RevivePlayer(player)
end

function ReviveService:BuyReviveByGold(player, needGold)
    local gold = Knit.GetService("GoldService"):GetGoldData(player)
    if gold < needGold then
        Knit.GetService("ClientUIService"):ShowTip(player, "Insuffcient gold")
        return false
    end
    Knit.GetService("GoldService"):ChangeGold(player, -needGold)
    return true
end

-- 购买复活
function ReviveService:BuyReviveByRob(player)
    loadPlayer(player)
    self.PlayerReviveCount[player.UserId] += 1
    Knit.GetService("ClientUIService"):HideSingleUI(player, "MessageBoxUI")
end

-- 取消购买复活
function ReviveService:CannelReviveByRobux(player)
    Knit.GetService("ClientUIService"):ResetSingleUI(player, "MessageBoxUI")
end

function ReviveService:KnitInit()
end

function ReviveService:KnitStart()
end

return ReviveService
