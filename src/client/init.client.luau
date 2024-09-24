local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Commons = require(ReplicatedStorage:WaitForChild("Commons"))
local NettyClient = Commons.Netty.Client
NettyClient.Start()