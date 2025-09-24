local InitLand = workspace:FindFirstChild("恐龙岛")
while not InitLand do
	task.wait(1)
	InitLand = workspace:FindFirstChild("恐龙岛")
end

local Sound = InitLand:WaitForChild("Special"):WaitForChild("Sound")
Sound:WaitForChild("Firetree"):WaitForChild("Fire1"):WaitForChild("FireSound"):Play()
Sound:WaitForChild("SageEvo"):WaitForChild("Frog"):WaitForChild("FrogSound"):Play()
Sound:WaitForChild("HuoShan"):WaitForChild("Part1"):WaitForChild("FireSound"):Play()
Sound:WaitForChild("Torch1"):WaitForChild("Light"):WaitForChild("FireSound"):Play()
Sound:WaitForChild("Torch2"):WaitForChild("Light"):WaitForChild("FireSound"):Play()
Sound:WaitForChild("Torch3"):WaitForChild("Part"):WaitForChild("FireSound"):Play()
Sound:WaitForChild("Torch4"):WaitForChild("Fire"):WaitForChild("FireSound"):Play()
Sound:WaitForChild("Torch5"):WaitForChild("FireSound"):Play()