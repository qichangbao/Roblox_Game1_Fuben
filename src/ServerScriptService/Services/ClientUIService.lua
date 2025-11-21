local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))

local ClientUIService = Knit.CreateService({
    Name = 'ClientUIService',
    Client = {
        ShowTip = Knit.CreateSignal(),
        ShowUI = Knit.CreateSignal(),
        HideUI = Knit.CreateSignal(),
        ResetUI = Knit.CreateSignal(),
        ShowArrow = Knit.CreateSignal(),
        HideArrow = Knit.CreateSignal(),
        ChangeHp = Knit.CreateSignal(),
    },
})

function ClientUIService:ShowTip(player, tip)
    self.Client.ShowTip:Fire(player, {Type = 1, Text = tip})
end

function ClientUIService:ShowTipAll(tip)
    self.Client.ShowTip:FireAll({Type = 1, Text = tip})
end

function ClientUIService:PickUpItem(player, itemId)
    self.Client.ShowTip:FireAll({Type = 2, Name = player.Name, ItemId = itemId})
end

function ClientUIService:ShowUISingle(player, ui, data)
    self.Client.ShowUI:Fire(player, ui, data)
end

function ClientUIService:HideSingleUI(player, ui)
    self.Client.HideUI:Fire(player, ui)
end

function ClientUIService:ResetSingleUI(player, ui)
    self.Client.ResetUI:Fire(player, ui)
end

function ClientUIService:ShowUIAll(ui, data)
    self.Client.ShowUI:FireAll(ui, data)
end

function ClientUIService:ShowArrow(player, targetPosition)
    self.Client.ShowArrow:Fire(player, targetPosition)
end

function ClientUIService:HideArrow(player)
    self.Client.HideArrow:Fire(player)
end

function ClientUIService:ChangeHp(part, hp, isCrit)
    self.Client.ChangeHp:FireAll(part, hp, isCrit)
end

function ClientUIService:KnitInit()
end

function ClientUIService:KnitStart()
end

return ClientUIService
