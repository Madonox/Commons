local Remote = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvent")
local RunService = game:GetService("RunService")

local RNG = Random.new(math.random())
while RunService.Heartbeat:Wait() do
	for i = 1,200 do
		Remote:FireServer(RNG:NextInteger(-100000000000,100000000000),RNG:NextInteger(-100000000000,100000000000),RNG:NextInteger(-100000000000,100000000000))
	end
end