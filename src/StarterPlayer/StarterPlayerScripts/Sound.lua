local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Interface = require(ReplicatedStorage:WaitForChild("ToolFolder"):WaitForChild("Interface"))

local Module = {}

local InitLand = workspace:WaitForChild("恐龙岛")
local SoundFolder = InitLand:WaitForChild("Special"):WaitForChild("Sound")
local function playSound1()
    local child = Interface.safeWaitPart(SoundFolder, "Firetree")
    local child1 = Interface.safeWaitPart(child, "Fire1")
    local child2 = Interface.safeWaitPart(child1, "FireSound")
    child2:Play()
end
local function playSound2()
    local child = Interface.safeWaitPart(SoundFolder, "SageEvo")
    local child1 = Interface.safeWaitPart(child, "Frog")
    local child2 = Interface.safeWaitPart(child1, "FrogSound")
    child2:Play()
end
local function playSound3()
    local child = Interface.safeWaitPart(SoundFolder, "HuoShan")
    local child1 = Interface.safeWaitPart(child, "Part1")
    local child2 = Interface.safeWaitPart(child1, "FireSound")
    child2:Play()
end
local function playSound4()
    local child = Interface.safeWaitPart(SoundFolder, "Torch1")
    local child1 = Interface.safeWaitPart(child, "Light")
    local child2 = Interface.safeWaitPart(child1, "FireSound")
    child2:Play()
end
local function playSound5()
    local child = Interface.safeWaitPart(SoundFolder, "Torch2")
    local child1 = Interface.safeWaitPart(child, "Light")
    local child2 = Interface.safeWaitPart(child1, "FireSound")
    child2:Play()
end
local function playSound6()
    local child = Interface.safeWaitPart(SoundFolder, "Torch3")
    local child1 = Interface.safeWaitPart(child, "Part")
    local child2 = Interface.safeWaitPart(child1, "FireSound")
    child2:Play()
end
local function playSound7()
    local child = Interface.safeWaitPart(SoundFolder, "Torch4")
    local child1 = Interface.safeWaitPart(child, "Fire")
    local child2 = Interface.safeWaitPart(child1, "FireSound")
    child2:Play()
end
local function playSound8()
    local child = Interface.safeWaitPart(SoundFolder, "Torch5")
    local child2 = Interface.safeWaitPart(child, "FireSound")
    child2:Play()
end

playSound1()
playSound2()
playSound3()
playSound4()
playSound5()
playSound6()
playSound7()
playSound8()

return Module