--!native
--!optimize 2
-- Madonox
-- 2025
export type NettyServer = {
	_init: () -> nil,
	Start: () -> nil,

	FireClient: (Player,any,...any) -> nil,
	FireClientUnreliable: (Player,any,...any) -> nil,

	FireAllClients: (any,...any) -> nil,
	FireAllClientsUnreliable: (any,...any) -> nil,

	FireList: ({Player},any,...any) -> nil,
	FireListUnreliable: ({Player},any,...any) -> nil,

	RegisterEvent: (any,(Player,...any) -> nil?) -> nil,
	SpawnEvent: (Player,any,...any) -> nil,

	Started: boolean,
	Events: {[any]: (Player,...any) -> nil},
	EventIds: {any},
	Outbound: {
		reliable: {[Player]:{any}},
		unreliable: {[Player]:{any}},
	},
}

local NettyServer = {} :: NettyServer

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Observers = require(Packages.Observers)

local Buffer = require("./Buffer")
local BufferInscriber = Buffer.Inscriber

local ReliableChannel: RemoteEvent
local UnreliableChannel: UnreliableRemoteEvent

local Initialized = false
local INDEX_FORMAT = "%d_%d"

local INSTANCE_MARKER = newproxy(false)
local OUTBOUND_CONNECTION

function NettyServer._init(): ()
	if not Initialized then
		Initialized = true

		NettyServer.Events = {}
		NettyServer.EventIds = {}

		NettyServer.Outbound = {
			reliable = {} :: { [Player]: { any } },
			unreliable = {} :: { [Player]: { any } }
		}

		NettyServer.RegisterEvent("_init", function(player: Player, ...: any): ()
			NettyServer.FireClient(player, "_init", NettyServer.EventIds)
		end)
	end
end

local function GenIndexId(index: number, count: number): string
	return string.format(INDEX_FORMAT, count, index)
end

local function InboundEventHandler(player: Player, inboundBuffer: buffer, argumentMap: { [string]: any }): ()
	local inscriber = BufferInscriber.new(inboundBuffer)
	local packetCount = inscriber:ReadType("unsigned8", 0)

	for packetIndex = 1, packetCount do
		local eventIdentifier = inscriber:ReadType("unsigned8")
		local argumentCount = inscriber:ReadType("unsigned8")
		local unpackedArguments = table.create(argumentCount)

		for _ = 1, argumentCount do
			local argumentTypeId = inscriber:ReadType("unsigned8")
			local argumentIndex = inscriber:ReadType("unsigned8")

			local argumentValue
			if argumentTypeId == 0 then
				argumentValue = argumentMap[GenIndexId(argumentIndex, packetIndex)]
			else
				argumentValue = inscriber:ReadType(Buffer.IdToType(argumentTypeId))
			end

			unpackedArguments[argumentIndex] = argumentValue
		end

		task.spawn(NettyServer.SpawnEvent, player, NettyServer.EventIds[eventIdentifier], table.unpack(unpackedArguments))
	end

	inscriber:Destroy()
end

local function ProcessOutboundPackets(playerSet: {[Player]: {any}}, channel: RemoteEvent): ()
	for player, profile in pairs(playerSet) do
		local sizeList = profile[1]
		if #sizeList == 0 then
			continue
		end

		local inscriber: Buffer.BufferInscriber = profile[3]
		local packetArray = profile[2]
		local packetCount = math.min(255, #packetArray)

		local memSize = 1
		for _ = 1, packetCount do
			local refSize = sizeList[1]
			if not refSize then
				OUTBOUND_CONNECTION:Disconnect()
				warn("[NettyServer]: An error was detected during outbound replication! Please report this to the maintainer!")
				return
			end
			memSize += refSize
			table.remove(sizeList, 1)
		end

		inscriber:SetBuffer(buffer.create(memSize))
		inscriber:WriteType("unsigned8", packetCount)

		local outboundTable: {[string]: any} = {}

		for i = 1, packetCount do
			local packet = packetArray[1]
			table.remove(packetArray, 1)

			inscriber:WriteType("unsigned8", packet[1])

			local bufferArgs = packet[2]
			local argSize = #bufferArgs
			inscriber:WriteType("unsigned8", argSize)

			if argSize > 0 then
				for index, arg in ipairs(bufferArgs) do
					if arg == INSTANCE_MARKER then
						inscriber:WriteType("unsigned8", 0)
						inscriber:WriteType("unsigned8", index)
					else
						local bType = Buffer.ResolveType(arg)
						inscriber:WriteType("unsigned8", Buffer.TypeToId(bType))
						inscriber:WriteType("unsigned8", index)
						inscriber:WriteType(bType, arg)
					end
				end
				
				table.clear(bufferArgs)
			end

			local instanceArgs = packet[3]
			for id, arg in pairs(instanceArgs) do
				outboundTable[GenIndexId(id, i)] = arg
			end

			table.clear(instanceArgs)
			table.clear(packet)
		end

		inscriber:SetPointer(0)
		channel:FireClient(player, inscriber.buffer, outboundTable)
		table.clear(outboundTable)
	end
end

local function playerAdded(player: Player): ()
	local outbound = NettyServer.Outbound
	if not outbound.reliable[player] then
		outbound.reliable[player] = { {}, {}, BufferInscriber.new() }
	end
	
	if not outbound.unreliable[player] then
		outbound.unreliable[player] = { {}, {}, BufferInscriber.new() }
	end
end

function NettyServer.Start(): ()
	if NettyServer.Started then return end
	NettyServer.Started = true

	local reliableOutbound = NettyServer.Outbound.reliable
	local unreliableOutbound = NettyServer.Outbound.unreliable
	
	Observers.observePlayer(function(player: Player)
		playerAdded(player)
		
		return function()
			local reliableData = reliableOutbound[player]
			local unreliableData = unreliableOutbound[player]

			if reliableData then
				reliableData[3]:Destroy()
				reliableOutbound[player] = nil
			end

			if unreliableData then
				unreliableData[3]:Destroy()
				unreliableOutbound[player] = nil
			end
		end
	end)

	local ReliableChannel = Instance.new("RemoteEvent")
	local UnreliableChannel = Instance.new("UnreliableRemoteEvent")

	ReliableChannel.OnServerEvent:Connect(InboundEventHandler)
	UnreliableChannel.OnServerEvent:Connect(InboundEventHandler)

	ReliableChannel.Parent = script.Parent
	UnreliableChannel.Parent = script.Parent

	OUTBOUND_CONNECTION = RunService.Heartbeat:Connect(function()
		ProcessOutboundPackets(reliableOutbound, ReliableChannel)
		ProcessOutboundPackets(unreliableOutbound, UnreliableChannel)
	end)
end

function NettyServer.SpawnEvent(player: Player, eventType: any, ...: any): ()
	local eventCallback = NettyServer.Events[eventType]
	
	if eventCallback then
		eventCallback(player, ...)
	end
end

function NettyServer.RegisterEvent(id: string | number, callback: ((player: Player, ...any) -> ())?): ()
	if NettyServer.Events[id] or NettyServer.Started then
		error("Cannot create event " .. tostring(id) .. ", The event might already exist, or NettyServer has already been started!")
	end

	if #NettyServer.EventIds >= 255 then
		error("Cannot register another event! You have hit the 255 event limit!")
	end

	NettyServer.Events[id] = callback
	table.insert(NettyServer.EventIds, id)
end

local function prepareBuffers(eventId: any, args: { any }): (number, { [number]: any }, { [number]: any })
	local bufferArgs: { [number]: any } = {}
	local tableArgs: { [number]: any } = {}
	local bufferSize = 2

	for index = 1, #args do
		local arg = args[index]
		local bufferType = Buffer.ResolveType(arg)

		if bufferType then
			bufferSize += Buffer.SizeOf(bufferType) + 2
			bufferArgs[index] = arg
		else
			bufferArgs[index] = INSTANCE_MARKER
			bufferSize += 2
			tableArgs[index] = arg
		end
	end

	return bufferSize, bufferArgs, tableArgs
end

function NettyServer.FireClient(player: Player, eventId: any, ...: any): ()
	local args = { ... }
	local bufferSize, bufferArgs, tableArgs = prepareBuffers(eventId, args)
	local profile = NettyServer.Outbound.reliable[player]

	table.insert(profile[1], bufferSize)
	table.insert(profile[2], { table.find(NettyServer.EventIds, eventId), bufferArgs, tableArgs })
end

function NettyServer.FireAllClients(eventId: any, ...: any): ()
	local args = { ... }
	local bufferSize, bufferArgs, tableArgs = prepareBuffers(eventId, args)
	local ref = table.find(NettyServer.EventIds, eventId)

	for _, player in Players:GetPlayers() do
		local profile = NettyServer.Outbound.reliable[player]
		table.insert(profile[1], bufferSize)
		table.insert(profile[2], { ref, table.clone(bufferArgs), table.clone(tableArgs) })
	end

	table.clear(bufferArgs)
	table.clear(tableArgs)
end

function NettyServer.FireList(players: { Player }, eventId: any, ...: any): ()
	local args = { ... }
	local bufferSize, bufferArgs, tableArgs = prepareBuffers(eventId, args)
	local ref = table.find(NettyServer.EventIds, eventId)

	for _, player in players do
		local profile = NettyServer.Outbound.reliable[player]
		table.insert(profile[1], bufferSize)
		table.insert(profile[2], { ref, table.clone(bufferArgs), table.clone(tableArgs) })
	end

	table.clear(bufferArgs)
	table.clear(tableArgs)
end

function NettyServer.FireClientUnreliable(player: Player, eventId: any, ...: any): ()
	local args = { ... }
	local bufferSize, bufferArgs, tableArgs = prepareBuffers(eventId, args)
	local profile = NettyServer.Outbound.unreliable[player]

	table.insert(profile[1], bufferSize)
	table.insert(profile[2], { table.find(NettyServer.EventIds, eventId), bufferArgs, tableArgs })
end

function NettyServer.FireAllClientsUnreliable(eventId: any, ...: any): ()
	local args = { ... }
	local bufferSize, bufferArgs, tableArgs = prepareBuffers(eventId, args)
	local ref = table.find(NettyServer.EventIds, eventId)

	for _, player in Players:GetPlayers() do
		local profile = NettyServer.Outbound.unreliable[player]
		table.insert(profile[1], bufferSize)
		table.insert(profile[2], { ref, table.clone(bufferArgs), table.clone(tableArgs) })
	end

	table.clear(bufferArgs)
	table.clear(tableArgs)
end

function NettyServer.FireListUnreliable(players: { Player }, eventId: any, ...: any): ()
	local args = { ... }
	local bufferSize, bufferArgs, tableArgs = prepareBuffers(eventId, args)
	local ref = table.find(NettyServer.EventIds, eventId)

	for _, player in players do
		local profile = NettyServer.Outbound.unreliable[player]
		table.insert(profile[1], bufferSize)
		table.insert(profile[2], { ref, table.clone(bufferArgs), table.clone(tableArgs) })
	end

	table.clear(bufferArgs)
	table.clear(tableArgs)
end

return NettyServer
