local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Knit"))
local ConstantConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("ConstantConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("ConfigFolder"):WaitForChild("GameConfig"))
local _escapeTime = ConstantConfig:GetByConstant("VoteFastcCountdown").Effect1

local BoatService = Knit.CreateService({
    Name = 'BoatService',
    Client = {
        ChooseEscape = Knit.CreateSignal(),
        ChooseNextIsland = Knit.CreateSignal(),
        ResetBoat = Knit.CreateSignal(),
    },

    ChooseVote = {},    -- 1 选择逃生 2 选择下一个岛屿
})

-- 获取投票结果
function BoatService:GetChooseVote()
    local escapeVote = 0
    local nextIslandVote = 0
    for _, vote in pairs(self.ChooseVote) do
        if vote == 1 then
            escapeVote += 1
        elseif vote == 2 then
            nextIslandVote += 1
        end
    end
    return escapeVote, nextIslandVote
end

-- 检查投票结果
function BoatService:CheckVote()
    local playerCount = Knit.GetService("PlayerService"):GetPlayerCount()
    local escapeVote, nextIslandVote = self:GetChooseVote()
    local totalVote = escapeVote + nextIslandVote
    if totalVote > playerCount / 2 then
        local escapeTime = Knit.GetService("TaskService"):GetEscapeTime()
        if escapeTime > _escapeTime then
            Knit.GetService("TaskService"):SetEscapeTime(_escapeTime)
        end
    end
end

-- 获取玩家选择
function BoatService:GetPlayerChoose(player)
    return self.ChooseVote[player.UserId]
end

-- 获取选择下一个岛屿的玩家
function BoatService:GetNextIslandPlayers()
    local gotoNextIslandPlayers = {}
    for userId, v in pairs(self.ChooseVote) do
        if v == 2 then
            table.insert(gotoNextIslandPlayers, userId)
        end
    end
    return gotoNextIslandPlayers
end

-- 选择逃生
function BoatService:ChooseEscape(player)
    if self.ChooseVote[player.UserId] then return end
    self.ChooseVote[player.UserId] = 1
    self.Client.ChooseEscape:Fire(player)

    self:CheckVote()
end

-- 选择下一个岛屿
function BoatService:ChooseNextIsland(player)
    if self.ChooseVote[player.UserId] then return end
    self.ChooseVote[player.UserId] = 2
    self.Client.ChooseNextIsland:Fire(player)

    self:CheckVote()
end

function BoatService:SetBoatPos(isLandId, player)
    local land = workspace:FindFirstChild(isLandId)
    if not land then return end
    local boatAttribute = land:GetAttribute("Boat")
    if not boatAttribute then return end
    local boat = workspace:FindFirstChild(GameConfig.TeleportPartNames)
    if not boat then return end

    local playerUserIds = {}
    if not player then
        playerUserIds = self:GetNextIslandPlayers()
    else
        table.insert(playerUserIds, player.UserId)
    end
	local originalBoatFrame = boat:GetPivot()
    local hrpOffsetCF = {}
    for _, playerUserId in ipairs(playerUserIds) do
        local playerTemp = game.Players:GetPlayerByUserId(playerUserId)
        if not playerTemp then continue end
        local playerCharacter = playerTemp.Character or playerTemp.CharacterAdded:Wait()
        local playerHumanoidRootPart = playerCharacter:FindFirstChild("HumanoidRootPart")
        if not playerHumanoidRootPart then continue end
		local offset = originalBoatFrame:ToObjectSpace(playerHumanoidRootPart.CFrame)
        hrpOffsetCF[player.Character] = offset
    end

    boat:PivotTo(boatAttribute)
	for character, offset in pairs(hrpOffsetCF) do
		local playerHumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not playerHumanoidRootPart then continue end
		local targetCF = boatAttribute * offset
		local landPos = land:GetPivot().Position
		local pos = targetCF.Position
		local lookTarget = Vector3.new(landPos.X, pos.Y, landPos.Z)
		local dir = lookTarget - pos
		if dir.Magnitude > 1e-4 then
			targetCF = CFrame.lookAt(pos, pos + dir.Unit, Vector3.yAxis)
		end
		playerHumanoidRootPart.CFrame = targetCF
	end
end

function BoatService:KnitInit()
end

function BoatService:KnitStart()
end

return BoatService
