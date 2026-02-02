local _screenUI = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("LoadingUI")
_screenUI.Enabled = false

task.delay(5, function()
	_screenUI.Enabled = false
end)