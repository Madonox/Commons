--!strict
-- Madonox
-- 2025
local RunService = game:GetService("RunService")

local NettyClient = require("@self/NettyClient")
local NettyServer = require("@self/NettyServer")

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
