--!native
--!optimize 2
-- Madonox
-- 2024

export type NettyServer = {
	_init: () -> nil;
	Start: () -> nil;

	SpawnEvent: (Player,any,...any) -> nil;
	FireClient: (Player,any,...any) -> nil;
	RegisterEvent: (any,(Player,...any) -> nil) -> nil;

	Started: boolean;
	Events: {[any]: (Player,...any) -> nil};
	EventIds: {any};
	Outbound: {
		reliable: {Player:{any}};
		unreliable: {Player:{any}};
	};
}

local Players = game:GetService("Players")
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
	print(player,inboundBuffer,args)
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
		--NettyServer.SpawnEvent(player,NettyServer.EventIds[event_id],table.unpack(args))
	end

	inscriber:Destroy()
end

function NettyServer._init()
	if not Initialized then
		Initialized = true
		NettyServer.Events = {}
		NettyServer.EventIds = {}

		local reliableOut = {}
		local unreliableOut = {}

		NettyServer.Outbound = {
			reliable = reliableOut;
			unreliable = unreliableOut;
		}

		Players.PlayerAdded:Connect(function(player)
			reliableOut[player] = {0,{},BufferInscriber.new()}
			unreliableOut[player] = {0,{},BufferInscriber.new()}
		end)
		Players.PlayerRemoving:Connect(function(player)
			table.clear(reliableOut[player][2])
			table.clear(unreliableOut[player][2])

			reliableOut[player][3]:Destroy()
			unreliableOut[player][3]:Destroy()

			table.clear(reliableOut[player])
			table.clear(unreliableOut[player])

			reliableOut[player] = nil
			unreliableOut[player] = nil
		end)

		NettyServer.RegisterEvent("_init",function(player,...)
			print(player,...)
			NettyServer.FireClient(player,"_init",NettyServer.EventIds)
		end)

		ReliableChannel = Instance.new("RemoteEvent")
		UnreliableChannel = Instance.new("UnreliableRemoteEvent")
		ReliableChannel.OnServerEvent:Connect(InoundEventHandler)
		UnreliableChannel.OnServerEvent:Connect(InoundEventHandler)
	end
end

local INSTANCE_MARKER = newproxy(false)
--[[

BUFFER FORMAT:
[(unsigned8) number_of_packets,(unsigned8) packet_type,(unsigned8) packet_arg_count, {(unsigned8) arg_type,(unsigned8) arg_index,(any) arg_data...}]

]]

local function ProcessOutboundPackets(playerSet:{[Player]:{any}},channel:RemoteEvent|UnreliableRemoteEvent)
	for player,profile in playerSet do
		local size = profile[1]
		if size > 0 then
			local inscriber:Buffer.BufferInscriber = profile[3]
			inscriber:SetBuffer(buffer.create(size + 1)) -- 1 for global header
			local outboundTable = {}

			local packetArray = profile[2]
			local packetCount = math.min(255,#packetArray)

			inscriber:WriteType("unsigned8",packetCount) -- total # of calls
			for i = 1,packetCount do
				local packet = packetArray[1]
				table.remove(packetArray,1)

				inscriber:WriteType("unsigned8",packet[1]) -- event id
				local bufferArgs = packet[2]
				inscriber:WriteType("unsigned8",#bufferArgs) -- bufferArgs contains markers where instances should be

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

				for id,arg in packet[3] do
					outboundTable[GenIndexId(id,i)] = arg
				end
			end

			inscriber:SetPointer(0)
			profile[1] = 0
			channel:FireClient(player,inscriber.buffer,outboundTable)
		end
	end
end

function NettyServer.Start()
	if not NettyServer.Started then
		NettyServer.Started = true
		UnreliableChannel.Parent = script.Parent
		ReliableChannel.Parent = script.Parent

		local reliableOut = NettyServer.Outbound.reliable
		local unreliableOut = NettyServer.Outbound.unreliable
		game:GetService("RunService").Heartbeat:Connect(function()
			ProcessOutboundPackets(reliableOut,ReliableChannel)
			ProcessOutboundPackets(unreliableOut,UnreliableChannel)
		end)
	end
end

function NettyServer.SpawnEvent(player:Player,eventType:any,...:any)
	--local event = NettyServer.Events[eventType]
	NettyServer.Events[eventType](player,...)
end

function NettyServer.RegisterEvent(id:any,callback:(Player,...any) -> nil)
	if (not NettyServer.Events[id]) and (not NettyServer.Started) then
		NettyServer.Events[id] = callback
		table.insert(NettyServer.EventIds,id)
		return
	end

	error("Cannot create event " .. id ..";  The event might already exist, or NettyServer has already been started!")
end

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
	profile[1] += bufferSize
	table.insert(profile[2],{table.find(NettyServer.EventIds,eventId),bufferArgs,tableArgs})
end

return NettyServer