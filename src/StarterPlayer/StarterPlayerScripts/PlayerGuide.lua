local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local SimpleArrowNavigation = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("SimpleArrowNavigation"))

local Module = {}

function Module:ShowGuide()
    Knit.GetService("ItemService"):FindNearestItem(game.Players.LocalPlayer):andThen(function(item)
        if not item then
            return
        end

        local itemPosition
        if item:IsA("BasePart") then
            itemPosition = item.Position
        elseif item:IsA("Model") then
            itemPosition = item:GetPivot().Position
        end
        
        if not itemPosition then
            return
        end

        SimpleArrowNavigation.NavigateTo(itemPosition, nil, 5, true, 0.5)
    end)
end

return Module