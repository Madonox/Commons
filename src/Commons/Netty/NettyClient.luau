--!native
--!optimize 2
-- Madonox
-- 2025
export type NettyClient = {
	_init: () -> nil,
	_startNetworkRelay: () -> nil,
	Start: () -> nil,
	SpawnEvent: (any,...any) -> nil,
	RegisterEvent: (any,(...any) -> nil) -> nil,
	FireServer: (any,...any) -> nil,
	FireServerUnreliable: (any,...any) -> nil,

	Events: {[any]:(...any) -> nil},
	EventIds: {[number]: any},
	Outbound: {
		reliable: {any},
		unreliable: {any},
	},
	
	Started: boolean,
}

local NettyClient = {} :: NettyClient

local RunService = game:GetService("RunService")

local ReliableChannel: RemoteEvent
local UnreliableChannel: UnreliableRemoteEvent

local Buffer = require("./Buffer")

local Initialized = false
local EventsLoaded = false

local INDEX_FORMAT = "%d_%d"

local OutboundInscriber = Buffer.Inscriber.new()
local INSTANCE_MARKER = newproxy(false)

local RelayActive = false
local RelayCallbackThreads = {}

function NettyClient._init(): ()
	if not Initialized then
		Initialized = true

		NettyClient.Events = {}
		NettyClient.EventIds = {
			[1] = "_init"
		}

		NettyClient.Outbound = {
			reliable = { {}, {} },
			unreliable = { {}, {} }
		}

		NettyClient.RegisterEvent("_init", function(eventIdMap: { [number]: string }): ()
			NettyClient.EventIds = eventIdMap
			EventsLoaded = true
			NettyClient._startNetworkRelay()
		end)
	end
end

local function GenIndexId(index: number, count: number): string
	return string.format(INDEX_FORMAT, count, index)
end

local function InboundEventHandler(inboundBuffer: buffer, argumentMap: { [string]: any }): ()
	local inscriber = Buffer.Inscriber.new(inboundBuffer)
	local packetCount = inscriber:ReadType("unsigned8", 0)

	for packetIndex = 1, packetCount do
		local eventIdentifier = inscriber:ReadType("unsigned8")
		local argumentCount = inscriber:ReadType("unsigned8")
		local unpackedArguments: { any } = table.create(argumentCount)

		for _ = 1, argumentCount do
			local argumentTypeId = inscriber:ReadType("unsigned8")
			local argumentIndex = inscriber:ReadType("unsigned8")

			local argumentValue
			if argumentTypeId == 0 then
				argumentValue = argumentMap[GenIndexId(argumentIndex, packetIndex)]
			else
				local argumentType = Buffer.IdToType(argumentTypeId)
				argumentValue = inscriber:ReadType(argumentType)
			end

			unpackedArguments[argumentIndex] = argumentValue
		end

		task.spawn(NettyClient.SpawnEvent, NettyClient.EventIds[eventIdentifier], table.unpack(unpackedArguments))
	end

	inscriber:Destroy()
end

local function ProcessOutboundPackets(packetSet: {any}, channel): ()
	local sizeList = packetSet[1]
	if #sizeList == 0 then
		return
	end

	local packetArray = packetSet[2]
	local packetCount = math.min(255, #packetArray)

	local usedMemory = 1
	for _ = 1, packetCount do
		usedMemory += sizeList[1]
		table.remove(sizeList, 1)
	end

	OutboundInscriber:SetBuffer(buffer.create(usedMemory))
	OutboundInscriber:WriteType("unsigned8", packetCount)

	local outboundTable: {[string]: any} = {}

	for i = 1, packetCount do
		local packet = packetArray[1]
		table.remove(packetArray, 1)

		OutboundInscriber:WriteType("unsigned8", packet[1])

		local bufferArgs = packet[2]
		local argSize = #bufferArgs
		OutboundInscriber:WriteType("unsigned8", argSize)

		if argSize > 0 then
			for index, arg in ipairs(bufferArgs) do
				if arg == INSTANCE_MARKER then
					OutboundInscriber:WriteType("unsigned8", 0)
					OutboundInscriber:WriteType("unsigned8", index)
				else
					local bType = Buffer.ResolveType(arg)
					OutboundInscriber:WriteType("unsigned8", Buffer.TypeToId(bType))
					OutboundInscriber:WriteType("unsigned8", index)
					OutboundInscriber:WriteType(bType, arg)
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

	OutboundInscriber:SetPointer(0)
	channel:FireServer(OutboundInscriber.buffer, outboundTable)
	table.clear(outboundTable)
end

function NettyClient.Start()
	if not NettyClient.Started then
		NettyClient.Started = true

		ReliableChannel = script.Parent:WaitForChild("RemoteEvent")
		UnreliableChannel = script.Parent:WaitForChild("UnreliableRemoteEvent")

		OutboundInscriber:SetBuffer(buffer.create(3))
		OutboundInscriber:WriteType("unsigned8",1)
		OutboundInscriber:WriteType("unsigned8",1)
		OutboundInscriber:WriteType("unsigned8",0)
		ReliableChannel:FireServer(OutboundInscriber.buffer,{})

		OutboundInscriber:SetPointer(0)
		OutboundInscriber:SetBuffer(nil)

		ReliableChannel.OnClientEvent:Connect(InboundEventHandler)
		UnreliableChannel.OnClientEvent:Connect(InboundEventHandler)
		
		NettyClient._startNetworkRelay()
	end
end

function NettyClient._startNetworkRelay(): ()
	if not EventsLoaded or RelayActive then return end
	RelayActive = true

	local reliable = NettyClient.Outbound.reliable
	local unreliable = NettyClient.Outbound.unreliable

	RunService.Heartbeat:Connect(function()
		ProcessOutboundPackets(unreliable, UnreliableChannel)
		ProcessOutboundPackets(reliable, ReliableChannel)
	end)

	for _, thread in ipairs(RelayCallbackThreads) do
		coroutine.resume(thread)
	end

	table.clear(RelayCallbackThreads)
end

function NettyClient.RegisterEvent(eventIdentifier: any, callback: (...any) -> nil): ()
	NettyClient.Events[eventIdentifier] = callback
end

function NettyClient.SpawnEvent(eventIdentifier: any, ...: any): ()
	local eventCallback = NettyClient.Events[eventIdentifier]
	if eventCallback then
		eventCallback(...)
	end
end

local function fireServer(eventIdentifier: any, ...: any): (number, { [number]: any }, { [number]: any })
	if not NettyClient.Started then
		error("Cannot call FireServer until NettyClient has been started!")
	end

	if not RelayActive then
		table.insert(RelayCallbackThreads, coroutine.running())
		coroutine.yield()
	end

	local bufferArguments: { [number]: any } = {}
	local tableArguments: { [number]: any } = {}
	local bufferSize = 2
	local arguments = { ... }

	for index = 1, #arguments do
		local argument = arguments[index]
		local resolvedType = Buffer.ResolveType(argument)

		if resolvedType then
			bufferSize += Buffer.SizeOf(resolvedType) + 2
			bufferArguments[index] = argument
		else
			bufferArguments[index] = INSTANCE_MARKER
			bufferSize += 2
			tableArguments[index] = argument
		end
	end

	return bufferSize, bufferArguments, tableArguments
end

function NettyClient.FireServer(eventIdentifier: any, ...: any): ()
	local bufferSize, bufferArguments, tableArguments = fireServer(eventIdentifier, ...)
	local reliableChannel = NettyClient.Outbound.reliable
	table.insert(reliableChannel[1], bufferSize)
	table.insert(reliableChannel[2], {
		table.find(NettyClient.EventIds, eventIdentifier),
		bufferArguments,
		tableArguments
	})
end

function NettyClient.FireServerUnreliable(eventIdentifier: any, ...: any): ()
	local bufferSize, bufferArguments, tableArguments = fireServer(eventIdentifier, ...)
	local unreliableChannel = NettyClient.Outbound.unreliable
	table.insert(unreliableChannel[1], bufferSize)
	table.insert(unreliableChannel[2], {
		table.find(NettyClient.EventIds, eventIdentifier),
		bufferArguments,
		tableArguments
	})
end

return NettyClient
