--!native
--!optimize 2
-- Madonox
-- 2024

local RunService = game:GetService("RunService")
local NettyClient = require(script:WaitForChild("NettyClient"))
local NettyServer = require(script:WaitForChild("NettyServer"))
export type Netty = {
    Client: NettyClient.NettyClient;
    Server: NettyServer.NettyServer;
}

local Netty = {
    Client = NettyClient;
    Server = NettyServer;
}

if RunService:IsServer() then
    NettyServer._init()
    return Netty
end

NettyClient._init()

return Netty