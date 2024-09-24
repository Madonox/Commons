local Netty = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Netty.Server

Netty.RegisterEvent("test",function(player,arg1,arg3)
	print(arg1,arg3)
	print(player)
end)

Netty.Start()