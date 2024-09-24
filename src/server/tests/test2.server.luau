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

while task.wait() do
	for i = 1,200 do
		Netty.FireAllClients("test")
	end
end