local Commons = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons"))
local NettyClient = Commons.Netty.Client

local TotalCount = 0
NettyClient.RegisterEvent("count number",function(number)
	TotalCount += number
end)

local Count2 = 0
NettyClient.RegisterEvent("count number 2",function()
	Count2 += 1
end)

NettyClient.Start()

task.spawn(function()
	while task.wait(1) do
		print("Client tally: " .. TotalCount)
		print("Tally 2: " .. Count2)
	end
end)