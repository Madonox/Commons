local Netty = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Netty.Server

local c = 0
Netty.RegisterEvent("test",function(player,...)
	c += 1
end)

Netty.Start()

task.spawn(function()
	while task.wait(1) do
		print(c)
	end
end)

local RNG = Random.new(math.random())
while task.wait() do
	local lSent = 0
	for i = 1,200 do
		Netty.FireAllClients("test",RNG:NextInteger(-100000000000,100000000000),RNG:NextInteger(-100000000000,100000000000),RNG:NextInteger(-100000000000,100000000000))
	end
end