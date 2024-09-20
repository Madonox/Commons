-- Madonox
-- 2024

local math = math
local buffer = buffer

type NettyDataTypes = {
    Data: any;
    Instance: any;
}

type NettyEventArgument = {
    Id: string;
    Type: NettyDataTypes;
}

export type NettyClientEventOptions = {
    Name: string;
    Arguments: {NettyEventArgument};
}

type Disconnectable = {
    Disconnect: (Disconnectable) -> nil;
}

export type NettyClient = {
    _init: ({[any]:any}) -> nil;
    _awaitStart: () -> nil;
    _outboundPool: {
        reliable: {any};
        unreliable: {any};
    };
    _startupThreads: {thread};
    _outboundArguments: {[string]:{any}};

    Start: () -> nil;
    SpawnEvent: (buffer,number,{[any]:any}) -> nil;
    RegisterEvent: (NettyClientEventOptions,(...any) -> nil) -> Disconnectable;
    FireServer: (string,...any) -> nil;
    DataTypes: NettyDataTypes;
    EventIds: {[number]:string};
    Events: {[string]:{[any]:any}};
    Started: boolean;
}

local RunService = game:GetService("RunService")
local NettyClient:NettyClient = {} :: NettyClient

local ReliableChannel:RemoteEvent
local UnreliableChannel:UnreliableRemoteEvent
local DataTypes
local Proxy

local Initialized = false
local InitializationThreads = {}
function NettyClient._init(proxy:{[any]:any})
    if not Initialized and proxy then
        Initialized = true
        Proxy = proxy
        NettyClient._startupThreads = {}
        NettyClient.Events = {}
        ReliableChannel = script.Parent:WaitForChild("RemoteEvent")
        UnreliableChannel = script.Parent:WaitForChild("UnreliableRemoteEvent")
        DataTypes = {
            Data = newproxy(false);
            Instance = newproxy(false);
        }
        NettyClient.DataTypes = DataTypes
        NettyClient.EventIds = {
            [1] = "_init";
        }
        NettyClient._outboundPool = {
            reliable = {};
            unreliable = {};
        }

        local importEvent
        importEvent = NettyClient.RegisterEvent({
            Name = "_init";
            Arguments = {
                {
                    Id = "EventIds";
                    Type = DataTypes.Instance
                };
                {
                    Id = "EventArguments";
                    Type = DataTypes.Instance;
                }
            }
        },function(eventIds:{[string]:number},eventArguments:{[string]:{[any]:any}})
            importEvent:Disconnect()
            for eventName,id in eventIds do
                NettyClient.EventIds[id] = eventName
            end
            NettyClient._outboundArguments = eventArguments
        end)

        for _,thread in InitializationThreads do
            coroutine.resume(thread)
        end
        table.clear(InitializationThreads)
    end
end

function NettyClient._awaitStart()
    if not NettyClient.Started then
        table.insert(NettyClient._startupThreads,coroutine.running())
        coroutine.yield()
    end
end

function NettyClient.Start()
    if not NettyClient.Started then
        if not Initialized then
            table.insert(InitializationThreads,coroutine.running())
            coroutine.yield()
        end

        ReliableChannel.OnClientEvent:Connect(function(headers,dataPool,bufferSet)
            local headerCount = buffer.readu8(headers,0)
            local headerOffset = 0
            for i = 1,headerCount do
                headerOffset += 1
                NettyClient.SpawnEvent(bufferSet[i],buffer.readu8(headerCount,headerCount),dataPool)
            end
        end)
        local reliablePool = NettyClient._outboundPool.reliable
        local unreliablePool = NettyClient._outboundPool.unreliable

        local headerBuffer = buffer.create(255)

        local outboundBuffers = {}
        local instancePool = {}

        -- hard-coded id fetching (triggers id download)
        buffer.writeu8(headerBuffer,0,1)
        ReliableChannel:FireServer(headerBuffer,instancePool,outboundBuffers)

        RunService.Heartbeat:Connect(function()
            local reliableSize = #reliablePool
            if reliableSize > 0 then
                local outboundPackages = math.min(reliableSize,255)
                buffer.writeu8(headerBuffer,0,outboundPackages)
                for i = 1,outboundPackages do
                    local package = reliablePool[1]
                    table.remove(reliablePool,1)
                    buffer.writeu8(headerBuffer,i,package[1])
                    for k,v in package[2] do
                        instancePool[k] = v
                    end
                    table.insert(outboundBuffers,
                    package[3]
                        :MakeNewBuffer()
                        :Serialize(package[4])
                    )
                    table.clear(package)
                end

                ReliableChannel:FireServer(headerBuffer,instancePool,outboundBuffers)
                table.clear(instancePool)
                table.clear(outboundBuffers)
            end

            -- TODO: implement unreliable channel
        end)

        NettyClient.Started = true
        for _,thread in NettyClient._startupThreads do
            coroutine.resume(thread)
        end
        table.clear(NettyClient._startupThreads)
    end
end

local EventDestructable = {}
EventDestructable.__index = EventDestructable
function EventDestructable.fromEvent(event,name)
    return setmetatable({Event = event;Name = name},EventDestructable)
end
function EventDestructable:Disconnect()
    NettyClient.Events[self.Name] = nil
    self.Event[1]:Destroy()
    table.clear(self.Event[2])
    table.clear(self)
    setmetatable(self,nil)
end

function NettyClient.RegisterEvent(options:NettyClientEventOptions,callback:(...any) -> nil)
    local name = options.Name
    if NettyClient.Events[name] then
        error("Cannot register event " .. name .. ";  The event is already registered.")
    end

    local genTemplate = {}
    local argTemplate = {}

    for i,option:NettyEventArgument in options.Arguments do
        if option.Type == DataTypes.Data then
            table.insert(genTemplate,option.Id)
            continue
        end
        argTemplate[i] = option.Id
    end
    local id
    for _id,_name in NettyClient.EventIds do
        if name == _name then
            id = _id
            break
        end
    end
    local event = {Proxy.Buffer.new({
        MakeBuffer = false;
        Template = genTemplate;
    }),argTemplate,callback,id}
    NettyClient.Events[name] = event

    return EventDestructable.fromEvent(event,name)
end


function NettyClient.SpawnEvent(eventBuffer:buffer,eventType:number,pool:{[any]:any})
    local args = {}
    local event = NettyClient.Events[NettyClient.EventIds[eventType]]

    local bufferArgs = event[1]
        :ImportBuffer(eventBuffer)
        :Deserialize()
    local poolArgs = event[2]

    local offset = 0
    local bufferCount = 0
    for i = 1,#bufferArgs + #poolArgs do
        local poolArg = poolArgs[i]
        if poolArg then
            args[i + offset] = pool[poolArg]
            offset += 1
            continue
        end
        bufferCount += 1
        args[i + offset] = bufferArgs[bufferCount]
    end

    event[3](table.unpack(args))
end

function NettyClient.FireServer(event:string,...)
    NettyClient._awaitStart()
    local eventData = NettyClient.Events[event]
    local instanceArguments = {}
    local bufferArguments = {}

    table.insert(NettyClient._outboundPool.reliable,{
        eventData[4];
        instanceArguments;
        eventData[1];
        bufferArguments;
    })
end

return NettyClient