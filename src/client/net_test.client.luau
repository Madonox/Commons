local Remote = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvent")
local RunService = game:GetService("RunService")

while RunService.Heartbeat:Wait() do
	for i = 1,200 do
		Remote:FireServer()
	end
end