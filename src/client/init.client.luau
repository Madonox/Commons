local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Commons = require(ReplicatedStorage:WaitForChild("Commons"))
local NettyClient = Commons.Netty.Client
NettyClient.Start()

local RNG = Random.new()
local RunService = game:GetService("RunService")
task.spawn(function()
	while RunService.Heartbeat:Wait() do
		for i = 1,200 do
			NettyClient.FireServer("test")
		end
	end
end)

local counter = 0
NettyClient.RegisterEvent("test",function()
	counter += 1
end)

task.spawn(function()
	while task.wait(1) do
		print("client: " .. counter)
	end
end)