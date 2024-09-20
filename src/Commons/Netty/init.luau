-- Madonox
-- 2024

local RunService = game:GetService("RunService")
local NettyClient = require(script:WaitForChild("NettyClient"))
local NettyServer = require(script:WaitForChild("NettyServer"))
export type Netty = {
    Client: NettyClient.NettyClient;
    Server: NettyServer.NettyServer;

    Proxy: {[any]:any};
    ProxyEvent: () -> nil;
}

local Netty = {
    Client = NettyClient;
    Server = NettyServer;
}

if RunService:IsServer() then
    print("server")
    function Netty.ProxyEvent()
        print("proxy event")
        NettyServer._init(Netty.Proxy)
    end
    NettyServer._init(Netty.Proxy) -- call here in case this is routed from a secondary require

    return Netty
end

print("client")
function Netty.ProxyEvent()
    NettyClient._init(Netty.Proxy)
end
NettyServer._init(Netty.Proxy) -- call here in case this is routed from a secondary require

return Netty