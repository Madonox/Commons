--!native
--!optimize 2
-- Madonox
-- 2024

export type NettyServer = {
	_init: () -> nil;
	Start: () -> nil;

	FireClient: (Player,any,...any) -> nil;
	FireClientUnreliable: (Player,any,...any) -> nil;

	FireAllClients: (any,...any) -> nil;
	FireAllClientsUnreliable: (any,...any) -> nil;

	FireList: ({Player},any,...any) -> nil;
	FireListUnreliable: ({Player},any,...any) -> nil;

	RegisterEvent: (any,(Player,...any) -> nil?) -> nil;
	SpawnEvent: (Player,any,...any) -> nil;

	Started: boolean;
	Events: {[any]: (Player,...any) -> nil};
	EventIds: {any};
	Outbound: {
		reliable: {[Player]:{any}};
		unreliable: {[Player]:{any}};
	};
}

local Players = game:GetService("Players")

--[=[
@class NettyServer
NettyServer is the server module for the Netty framework.    It is used to handle all forms of inbound and outbound traffic.
NettyServer serializes any data it can into buffers.  Due to the nature of how Netty sends remote data, this approach to networking results in a significant decrease in outbound and inbound traffic, as well as lowering ping.
]=]
local NettyServer:NettyServer = {} :: NettyServer

local Buffer = require(script.Parent.Parent:WaitForChild("Buffer"))
local BufferInscriber = Buffer.Inscriber

local ReliableChannel
local UnreliableChannel

local Initialized = false

--[[

BUFFER FORMAT:
[(unsigned8) number_of_packets,(unsigned8) packet_type,(unsigned8) packet_arg_count, {(unsigned8) arg_type,(unsigned8) arg_index,(any) arg_data...}]

]]

local INDEX_FORMAT = "%d_%d"
local function GenIndexId(index,count)
	return string.format(INDEX_FORMAT,count,index)
end

local function InoundEventHandler(player:Player,inboundBuffer:buffer,args:{[any]:any})
	local inscriber = BufferInscriber.new(inboundBuffer)
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

		pcall(NettyServer.SpawnEvent,player,NettyServer.EventIds[event_id],table.unpack(b_args))
	end

	inscriber:Destroy()
end

--[=[
@within NettyServer
@private
This function handles NettyServer initialization.  Since both the Server and Client modules exist under ReplicatedStorage, we use this function to prevent the server from constructing a client as well.
]=]
function NettyServer._init()
	if not Initialized then
		Initialized = true
		NettyServer.Events = {}
		NettyServer.EventIds = {}

		NettyServer.Outbound = {
			reliable = {} :: {[Player]: {any}};
			unreliable = {} :: {[Player]: {any}};
		}

		-- built in sync event
		NettyServer.RegisterEvent("_init",function(player,...)
			NettyServer.FireClient(player,"_init",NettyServer.EventIds)
		end)
	end
end

local INSTANCE_MARKER = newproxy(false)
--[[

BUFFER FORMAT:
[(unsigned8) number_of_packets,(unsigned8) packet_type,(unsigned8) packet_arg_count, {(unsigned8) arg_type,(unsigned8) arg_index,(any) arg_data...}]

]]

local OUTBOUND_CONNECTION
local function ProcessOutboundPackets(playerSet:{[Player]:{any}},channel)
	for player,profile in playerSet do
		local size = profile[1]
		if #size > 0 then
			local inscriber:Buffer.BufferInscriber = profile[3]

			local packetArray = profile[2]
			local packetCount = math.min(255,#packetArray)

			local memSize = 1 -- initialize with 1 for the length header
			for _ = 1,packetCount do
				local refSize = size[1]
				if refSize then
					memSize += refSize
					table.remove(size,1)
					continue
				end
				-- error catching
				OUTBOUND_CONNECTION:Disconnect()
				warn("[NettyServer]: An error was detected during outbound replication!  Please report this to the maintainer!")
				return
			end

			inscriber:SetBuffer(buffer.create(memSize)) -- 1 for global header
			local outboundTable = {}

			inscriber:WriteType("unsigned8",packetCount) -- total # of calls
			for i = 1,packetCount do
				local packet = packetArray[1]
				table.remove(packetArray,1)

				inscriber:WriteType("unsigned8",packet[1]) -- event id
				local bufferArgs = packet[2]
				local argSize = #bufferArgs
				inscriber:WriteType("unsigned8",argSize) -- bufferArgs contains markers where instances should be

				if argSize > 0 then
					for index,arg in bufferArgs do
						if arg == INSTANCE_MARKER then
							inscriber:WriteType("unsigned8",0)
							inscriber:WriteType("unsigned8",index)
							continue
						end

						local bType = Buffer.ResolveType(arg)
						inscriber:WriteType("unsigned8",Buffer.TypeToId(bType))
						inscriber:WriteType("unsigned8",index)
						inscriber:WriteType(bType,arg)
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

			inscriber:SetPointer(0)
			channel:FireClient(player,inscriber.buffer,outboundTable)
			table.clear(outboundTable)
		end
	end
end

local function SafeAddPlayer(player)
	local outbound = NettyServer.Outbound
	if not outbound.reliable[player] then
		outbound.reliable[player] = {{},{},BufferInscriber.new()}
	end
	if not outbound.unreliable[player] then
		outbound.unreliable[player] = {{},{},BufferInscriber.new()}
	end
end

--[=[
@within NettyServer
This function starts the network inbound and outbound handler.  Once NettyServer is started, you can no longer register new events.
]=]
function NettyServer.Start()
	if not NettyServer.Started then
		NettyServer.Started = true

		-- Player packet tracking
		local reliableOut = NettyServer.Outbound.reliable
		local unreliableOut = NettyServer.Outbound.unreliable
		Players.PlayerAdded:Connect(SafeAddPlayer)

		for _,player in Players:GetPlayers() do
			SafeAddPlayer(player)
		end

		Players.PlayerRemoving:Connect(function(player)
			table.clear(reliableOut[player][1])
			table.clear(unreliableOut[player][1])

			table.clear(reliableOut[player][2])
			table.clear(unreliableOut[player][2])

			reliableOut[player][3]:Destroy()
			unreliableOut[player][3]:Destroy()

			table.clear(reliableOut[player])
			table.clear(unreliableOut[player])

			reliableOut[player] = nil
			unreliableOut[player] = nil
		end)

		-- Actual network handling
		ReliableChannel = Instance.new("RemoteEvent")
		UnreliableChannel = Instance.new("UnreliableRemoteEvent")
		ReliableChannel.OnServerEvent:Connect(InoundEventHandler)
		UnreliableChannel.OnServerEvent:Connect(InoundEventHandler)

		UnreliableChannel.Parent = script.Parent
		ReliableChannel.Parent = script.Parent

		OUTBOUND_CONNECTION = game:GetService("RunService").Heartbeat:Connect(function()
			ProcessOutboundPackets(unreliableOut,UnreliableChannel)
			ProcessOutboundPackets(reliableOut,ReliableChannel)
		end)
	end
end

--[=[
@within NettyServer
@param player Player -- The player triggering the event.
@param eventType any -- The event id to trigger.
@param ... any -- The arguments to pass to the event.
This function spawns an event in the current thread.

:::note
This function is mainly used internally, so it doesn't offer much configuration / outside influence.
]=]
function NettyServer.SpawnEvent(player:Player,eventType:any,...:any)
	local event = NettyServer.Events[eventType]
	if event then
		event(player,...)
	end
end

local function BLANK_FUNCTION()
	
end

--[=[
@within NettyServer
@param id any -- The event id to bind to.
@param callback (Player,...any) -> nil? -- The callback function to run when this event is triggered.  If no callback is given, then a blank function will be used if the event is ever called.
This function registers an event on the server.  All events need to be registered on the server, even if it is only used `server -> client`.  Events can only have **one** callback.

```lua
local NettyServer = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Netty.Server
NettyServer.RegisterEvent("my event", function(player, some_number)
	print(player.Name .. " has send " .. some_number .. " to the server")
end)

NettyServer.Start()
```

:::info
There can only be a maximum of 255 events registered.  This limit was determined by the amount of bytes allocated to the outbound / inbound header for packet size.
Additionally, you need to register events before you call `NettyServer.Start()`
]=]
function NettyServer.RegisterEvent(id:any,callback:(Player,...any) -> nil?)
	if (not NettyServer.Events[id]) and (not NettyServer.Started) then
		if #NettyServer.EventIds < 255 then
			NettyServer.Events[id] = callback or BLANK_FUNCTION
			table.insert(NettyServer.EventIds,id)
			return
		end
		error("Cannot register another event!  You have hit the 255 event limit!")
	end

	error("Cannot create event " .. id ..";  The event might already exist, or NettyServer has already been started!")
end

--[=[
@within NettyServer
@param player Player -- The player you are sending the event to.
@param eventId any -- The event id.
@param ... any -- The arguments being sent to the player.

This function sends an event to the specified client.
```lua
local NettyServer = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Netty.Server
NettyServer.RegisterEvent("my event")

NettyServer.Start()
NettyServer.FireClient(game:GetService("Players"):WaitForChild("Player1"), "my event", 123, "abc", ...)
```

:::tip
Netty supports any arguments.  Due to Netty's encoding design, any arguments that cannot be serialized are still passed in a table, allowing Netty to support all data types.
]=]
function NettyServer.FireClient(player:Player,eventId:any,...:any)
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

	local profile = NettyServer.Outbound.reliable[player]
	table.insert(profile[1],bufferSize)
	table.insert(profile[2],{table.find(NettyServer.EventIds,eventId),bufferArgs,tableArgs})
end

--[=[
@within NettyServer
@param eventId any -- The event id.
@param ... any -- The arguments being sent to all players.

This function sends an event to all clients.

```lua
local NettyServer = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Netty.Server
NettyServer.RegisterEvent("my event")

NettyServer.Start()
NettyServer.FireAllClients("my event", 123, "abc", ...)
```
]=]
function NettyServer.FireAllClients(eventId:any,...:any)
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

	-- less calculations this way
	local ref = table.find(NettyServer.EventIds,eventId)
	for _,player in Players:GetPlayers() do
		local profile = NettyServer.Outbound.reliable[player]
		table.insert(profile[1],bufferSize)
		table.insert(profile[2],{ref,table.clone(bufferArgs),table.clone(tableArgs)}) -- clone for manual gc
	end

	table.clear(bufferArgs)
	table.clear(tableArgs)
end

--[=[
@within NettyServer
@param players {Player} -- The list of players to send the event to.
@param eventId any -- The event id.
@param ... any -- The arguments being sent to all players.

This function sends an event to all clients.

```lua
local Players = game:GetService("Players")
local NettyServer = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Netty.Server
NettyServer.RegisterEvent("my event")

NettyServer.Start()
NettyServer.FireList({Players:WaitForChild("Player1"), Players:WaitForChild("Player2"), ...}, "my event", 123, "abc", ...)
```
]=]
function NettyServer.FireList(players:{Player},eventId:any,...:any)
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

	-- less calculations this way
	local ref = table.find(NettyServer.EventIds,eventId)
	for _,player in players do
		local profile = NettyServer.Outbound.reliable[player]
		table.insert(profile[1],bufferSize)
		table.insert(profile[2],{ref,table.clone(bufferArgs),table.clone(tableArgs)}) -- clone for manual gc
	end

	table.clear(bufferArgs)
	table.clear(tableArgs)
end

--[=[
@within NettyServer
@param player Player -- The player you are sending the event to.
@param eventId any -- The event id.
@param ... any -- The arguments being sent to the player.

This function sends an event to the specified client **over the unreliable channel**.
```lua
local NettyServer = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Netty.Server
NettyServer.RegisterEvent("my event")

NettyServer.Start()
NettyServer.FireClientUnreliable(game:GetService("Players"):WaitForChild("Player1"), "my event", 123, "abc", ...)
```
]=]
function NettyServer.FireClientUnreliable(player:Player,eventId:any,...:any)
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

	local profile = NettyServer.Outbound.unreliable[player]
	table.insert(profile[1],bufferSize)
	table.insert(profile[2],{table.find(NettyServer.EventIds,eventId),bufferArgs,tableArgs})
end

--[=[
@within NettyServer
@param eventId any -- The event id.
@param ... any -- The arguments being sent to all players.

This function sends an event to all clients **over the unreliable channel**.

```lua
local NettyServer = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Netty.Server
NettyServer.RegisterEvent("my event")

NettyServer.Start()
NettyServer.FireAllClientsUnreliable("my event", 123, "abc", ...)
```
]=]
function NettyServer.FireAllClientsUnreliable(eventId:any,...:any)
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

	-- less calculations this way
	local ref = table.find(NettyServer.EventIds,eventId)
	for _,player in Players:GetPlayers() do
		local profile = NettyServer.Outbound.unreliable[player]
		table.insert(profile[1],bufferSize)
		table.insert(profile[2],{ref,table.clone(bufferArgs),table.clone(tableArgs)}) -- clone for manual gc
	end

	table.clear(bufferArgs)
	table.clear(tableArgs)
end

--[=[
@within NettyServer
@param players {Player} -- The list of players to send the event to.
@param eventId any -- The event id.
@param ... any -- The arguments being sent to all players.

This function sends an event to all clients **over the unreliable channel**.

```lua
local Players = game:GetService("Players")
local NettyServer = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Netty.Server
NettyServer.RegisterEvent("my event")

NettyServer.Start()
NettyServer.FireListUnreliable({Players:WaitForChild("Player1"), Players:WaitForChild("Player2"), ...}, "my event", 123, "abc", ...)
```
]=]
function NettyServer.FireListUnreliable(players:{Player},eventId:any,...:any)
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

	-- less calculations this way
	local ref = table.find(NettyServer.EventIds,eventId)
	for _,player in players do
		local profile = NettyServer.Outbound.unreliable[player]
		table.insert(profile[1],bufferSize)
		table.insert(profile[2],{ref,table.clone(bufferArgs),table.clone(tableArgs)}) -- clone for manual gc
	end

	table.clear(bufferArgs)
	table.clear(tableArgs)
end

return NettyServer