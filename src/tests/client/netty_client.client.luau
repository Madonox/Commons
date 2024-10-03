local Commons = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons"))
local NettyClient = Commons.Netty.Client

local TotalCount = 0
NettyClient.RegisterEvent("count number",function(number)
	TotalCount += number
end)
NettyClient.Start()

task.spawn(function()
	while task.wait(1) do
		print("Client tally: " .. TotalCount)
	end
end)