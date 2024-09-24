local Netty = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Netty.Server

local c = 0
Netty.RegisterEvent("test",function(player,...)
	c += 1
end)

Netty.Start()

while task.wait(1) do
	print(c)
end