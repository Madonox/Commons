-- Madonox
-- 2024

export type NettyServer = {
    _init: ({[any]:any}) -> nil;
    Start: () -> nil;
}

local NettyServer:NettyServer = {}

local ReliableChannel:RemoteEvent
local UnreliableChannel:UnreliableRemoteEvent

local Initialized = false
local InitializationThreads = {}
function NettyServer._init(proxy:{[any]:any})
    if not Initialized and proxy then
        Initialized = true
        ReliableChannel = Instance.new("RemoteEvent")
        UnreliableChannel = Instance.new("UnreliableRemoteEvent")
        ReliableChannel.Parent = script.Parent
        UnreliableChannel.Parent = script.Parent
        print("netty init")
        Initialized = true
        for _,thread in InitializationThreads do
            coroutine.resume(thread)
        end
        table.clear(InitializationThreads)
    end
end

function NettyServer.Start()
    print("netty start")
end

return NettyServer