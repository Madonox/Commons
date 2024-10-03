local Commons = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons"))
local NettyServer = Commons.Netty.Server

NettyServer.RegisterEvent("count number")

NettyServer.Start()

task.spawn(function()
	while task.wait(1) do
		for i = 1,200 do
			NettyServer.FireAllClients("count number",1)
		end
	end
end)