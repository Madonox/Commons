--!native
--!optimize 2
-- Madonox
-- 2024

export type NettyClient = {
	_init: () -> nil;
	_startNetworkRelay: () -> nil;
	Start: () -> nil;
	SpawnEvent: (any,...any) -> nil;
	RegisterEvent: (any,(...any) -> nil) -> nil;
	FireServer: (any,...any) -> nil;
	FireServerUnreliable: (any,...any) -> nil;

	Events: {[any]:(...any) -> nil};
	EventIds: {[number]: any};
	Outbound: {
		reliable: {any};
		unreliable: {any};
	};
	Started: boolean;
}

--[=[
@class NettyClient
NettyClient is the client module for the Netty framework.  It is used to handle all forms of inbound and outbound traffic.
NettyClient serializes any data it can into buffers.  Due to the nature of how Netty sends remote data, this approach to networking results in a significant decrease in outbound and inbound traffic, as well as lowering ping.
]=]
local NettyClient:NettyClient = {} :: NettyClient

local Buffer = require(script.Parent.Parent:WaitForChild("Buffer"))

local ReliableChannel:RemoteEvent
local UnreliableChannel:UnreliableRemoteEvent

--[[

BUFFER FORMAT:
[(unsigned8) number_of_packets,(unsigned8) packet_type,(unsigned8) packet_arg_count, {(unsigned8) arg_type,(unsigned8) arg_index,(any) arg_data...}]

]]

local Initialized = false
local EventsLoaded = false

--[=[
@within NettyClient
@private
This function handles NettyClient initialization.  Since both the Server and Client modules exist under ReplicatedStorage, we use this function to prevent the server from constructing a client as well.
]=]
function NettyClient._init()
	if not Initialized then
		Initialized = true

		NettyClient.Events = {}
		NettyClient.EventIds = {
			[1] = "_init"
		}
		NettyClient.Outbound = {
			reliable = {{},{}};
			unreliable = {{},{}};
		}

		NettyClient.RegisterEvent("_init",function(ids)
			NettyClient.EventIds = ids
			EventsLoaded = true
			NettyClient._startNetworkRelay() -- call again in case the first attempt failed
		end)
	end
end

local INDEX_FORMAT = "%d_%d"
local function GenIndexId(index,count)
	return string.format(INDEX_FORMAT,count,index)
end

local function InoundEventHandler(inboundBuffer:buffer,args:{[any]:any})
	local inscriber = Buffer.Inscriber.new(inboundBuffer)

	local numPackets = inscriber:ReadType("unsigned8",0)
	for packId = 1,numPackets do
		local b_args = {}

		local event_id,_ = inscriber:ReadType("unsigned8")
		local arg_c,_ = inscriber:ReadType("unsigned8")
		if arg_c > 0 then
			for _ = 1,arg_c do
				local argType,_ = inscriber:ReadType("unsigned8") -- NEEDS to be a variable as it's read first
				local index,_ = inscriber:ReadType("unsigned8")
				if argType == 0 then
					b_args[index] = args[GenIndexId(index,packId)]
					continue
				end
				local response,_ = inscriber:ReadType(Buffer.IdToType(argType))
				b_args[index] = response
			end
		end

		pcall(NettyClient.SpawnEvent,NettyClient.EventIds[event_id],table.unpack(b_args))
	end

	inscriber:Destroy()
end

local OutboundInscriber = Buffer.Inscriber.new()
local INSTANCE_MARKER = newproxy(false)

local function ProcessOutboundPackets(packetSet:{any},channel)
	local size = packetSet[1]
	if #size > 0 then
		--local OutboundInscriber = Buffer.Inscriber.new()
		local packetArray = packetSet[2]
		local packetCount = math.min(255,#packetArray)

		local usedMemory = 1

		for _ = 1,packetCount do
			usedMemory += size[1]
			table.remove(size,1)
		end

		OutboundInscriber:SetBuffer(buffer.create(usedMemory))
		local outboundTable = {}

		OutboundInscriber:WriteType("unsigned8",packetCount) -- total # of calls

		for i = 1,packetCount do
			local packet = packetArray[1]
			table.remove(packetArray,1)
			
			OutboundInscriber:WriteType("unsigned8",packet[1]) -- event id

			local bufferArgs = packet[2]
			local argSize = #bufferArgs
			OutboundInscriber:WriteType("unsigned8",argSize) -- bufferArgs contains markers where instances should be
			if argSize > 0 then
				for index,arg in bufferArgs do
					if arg == INSTANCE_MARKER then
						OutboundInscriber:WriteType("unsigned8",0)
						OutboundInscriber:WriteType("unsigned8",index)
						continue
					end

					local bType = Buffer.ResolveType(arg)
					OutboundInscriber:WriteType("unsigned8",Buffer.TypeToId(bType))
					OutboundInscriber:WriteType("unsigned8",index)
					OutboundInscriber:WriteType(bType,arg)
				end
				table.clear(bufferArgs)
			end

			local instanceArgs = packet[3]
			for id,arg in instanceArgs do
				outboundTable[GenIndexId(id,i)] = arg
			end
			table.clear(instanceArgs)
			table.clear(packet)
		end
		
		OutboundInscriber:SetPointer(0)
		channel:FireServer(OutboundInscriber.buffer,outboundTable)
		table.clear(outboundTable)
	end
end

--[=[
@within NettyClient
This function starts the network inbound and outbound handler.  Additionally, once NettyClient is started, you can begin to send and receive data to and from the server.
]=]
function NettyClient.Start()
	if not NettyClient.Started then
		NettyClient.Started = true

		ReliableChannel = script.Parent:WaitForChild("RemoteEvent")
		UnreliableChannel = script.Parent:WaitForChild("UnreliableRemoteEvent")

		-- force gen get remote
		OutboundInscriber:SetBuffer(buffer.create(3))
		OutboundInscriber:WriteType("unsigned8",1)
		OutboundInscriber:WriteType("unsigned8",1)
		OutboundInscriber:WriteType("unsigned8",0)
		ReliableChannel:FireServer(OutboundInscriber.buffer,{})

		-- reset
		OutboundInscriber:SetPointer(0)
		OutboundInscriber:SetBuffer(nil) -- set to nil to allow gc to work it's magic

		ReliableChannel.OnClientEvent:Connect(InoundEventHandler)
		UnreliableChannel.OnClientEvent:Connect(InoundEventHandler)
		
		NettyClient._startNetworkRelay()
	end
end

local RelayActive = false
local RelayCallbackThreads = {}

--[=[
@within NettyClient
@private
This function spawns the Netty outbound network connection.
]=]
function NettyClient._startNetworkRelay()
	if EventsLoaded and not RelayActive then
		RelayActive = true
		local reliable = NettyClient.Outbound.reliable
		local unreliable = NettyClient.Outbound.unreliable

		game:GetService("RunService").Heartbeat:Connect(function()
			ProcessOutboundPackets(unreliable,UnreliableChannel)
			ProcessOutboundPackets(reliable,ReliableChannel)
		end)

		for _,thread in RelayCallbackThreads do
			coroutine.resume(thread)
		end
		table.clear(RelayCallbackThreads)
	end
end

--[=[
@within NettyClient
@param id any -- The event id to bind to.
@param callback (...any) -> nil -- The callback function to run when this event is triggered.
This function registers an event locally.  This is used when the server wants to send data to the client.  Events can only have **one** callback.

:::info
Events also need to be registered on the server, even if they have no callback.  Since Netty uses an identity based system, the client and server need to share event ids.
]=]
function NettyClient.RegisterEvent(id:any,callback:(...any) -> nil)
	NettyClient.Events[id] = callback
end

--[=[
@within NettyClient
@param eventType any -- The event id to trigger.
@param ... any -- The arguments to pass to the event.
This function spawns an event in the current thread.

:::note
This function is mainly used internally, so it doesn't offer much configuration / outside influence.
]=]
function NettyClient.SpawnEvent(eventType:any,...:any)
	local event = NettyClient.Events[eventType]
	if event then
		event(...)
	end
end

--[=[
@within NettyClient
@param eventId any -- The event id to trigger.
@param ... any -- The arguments to pass to the server.
This function fires a reliable remote event with proper data serialization to the server.

:::note
Events aren't fire instantly.  They're queued into an outbound pool, and a maximum of 255 events of each type(unreliable, reliable) are fired to the server at once per Heartbeat (RunService.Heartbeat).
This function supports all data types, even if they aren't able to be serialized into buffers.
Example:
```lua
local NettyClient = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Netty.Client
NettyClient.Start()

NettyClient.FireServer("my event", 123, CFrame.identity,"abc", workspace.MyPart) -- All of these arguments will be passed to the server.
```
]=]
function NettyClient.FireServer(eventId:any,...:any)
	if NettyClient.Started then
		if not RelayActive then
			table.insert(RelayCallbackThreads,coroutine.running())
			coroutine.yield()
		end
		local bufferArgs = {}
		local bufferSize = 2
		local tableArgs = {}

		for index,arg in {...} do
			local bType = Buffer.ResolveType(arg)
			if bType then
				bufferSize += Buffer.SizeOf(bType) + 2
				bufferArgs[index] = arg
				continue
			end

			bufferArgs[index] = INSTANCE_MARKER
			bufferSize += 2
			tableArgs[index] = arg
		end

		local channel = NettyClient.Outbound.reliable
		table.insert(channel[1],bufferSize)
		--channel[1] += bufferSize
		table.insert(channel[2],{table.find(NettyClient.EventIds,eventId),bufferArgs,tableArgs})
		return
	end
	error("Cannot call FireServer until NettyClient has been started!")
end

--[=[
@within NettyClient
@param eventId any -- The event id to trigger.
@param ... any -- The arguments to pass to the server.
This function fires an unreliable remote event with proper data serialization to the server.

:::note
Events aren't fire instantly.  They're queued into an outbound pool, and a maximum of 255 events of each type(unreliable, reliable) are fired to the server at once per Heartbeat (RunService.Heartbeat).
This function supports all data types, even if they aren't able to be serialized into buffers.
Example:
```lua
local NettyClient = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Netty.Client
NettyClient.Start()

NettyClient.FireServerUnreliable("my event", 123, CFrame.identity,"abc", workspace.MyPart) -- All of these arguments will be passed to the server.
```
]=]
function NettyClient.FireServerUnreliable(eventId:any,...:any)
	if NettyClient.Started then
		if not RelayActive then
			table.insert(RelayCallbackThreads,coroutine.running())
			coroutine.yield()
		end
		local bufferArgs = {}
		local bufferSize = 2
		local tableArgs = {}

		for index,arg in {...} do
			local bType = Buffer.ResolveType(arg)
			if bType then
				bufferSize += Buffer.SizeOf(bType) + 2
				bufferArgs[index] = arg
				continue
			end

			bufferArgs[index] = INSTANCE_MARKER
			bufferSize += 2
			tableArgs[index] = arg
		end

		local channel = NettyClient.Outbound.unreliable
		table.insert(channel[1],bufferSize)
		--channel[1] += bufferSize
		table.insert(channel[2],{table.find(NettyClient.EventIds,eventId),bufferArgs,tableArgs})
		return
	end
	error("Cannot call FireServer until NettyClient has been started!")
end

return NettyClient