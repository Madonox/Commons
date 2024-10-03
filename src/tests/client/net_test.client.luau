-- Basic Roblox test

local Remote = game:GetService("ReplicatedStorage"):WaitForChild("MyRemote")

local TotalCount = 0
Remote.OnClientEvent:Connect(function(count)
	TotalCount += count
end)

task.spawn(function()
	while task.wait(1) do
		print(TotalCount)
	end
end)