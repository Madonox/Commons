--!native
--!optimize 2
-- Madonox
-- 2024

export type NettyClient = {
	_init: () -> nil;
	Start: () -> nil;
	SpawnEvent: (any,...any) -> nil;
	RegisterEvent: (any,(...any) -> nil) -> nil;

	Events: {[any]:(...any) -> nil};
	EventIds: {[number]: any};
	Started: boolean;
}

local NettyClient:NettyClient = {}
local Buffer = require(script.Parent.Parent:WaitForChild("Buffer"))

local ReliableChannel:RemoteEvent
local UnreliableChannel:UnreliableRemoteEvent

local BufferInscriber = Buffer.Inscriber.new()

--[[

BUFFER FORMAT:
[(unsigned8) number_of_packets,(unsigned8) packet_type,(unsigned8) packet_arg_count, {(unsigned8) arg_type,(unsigned8) arg_index,(any) arg_data...}]

]]

local Initialized = false
function NettyClient._init()
	if not Initialized then
		Initialized = true

		NettyClient.Events = {}
		NettyClient.EventIds = {
			[1] = "_init"
		}
		NettyClient.RegisterEvent("_init",function(ids)
			print(ids)
			NettyClient.EventIds = ids
		end)

		ReliableChannel = script.Parent:WaitForChild("RemoteEvent")
		UnreliableChannel = script.Parent:WaitForChild("UnreliableRemoteEvent")
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

local OutboundInscriber = BufferInscriber.new()
local function ProcessOutboundPackets(packetSet:{number:{any}},channel:RemoteEvent|UnreliableRemoteEvent)
	local size = packetSet[1]
	if size > 0 then
		OutboundInscriber:SetBuffer(buffer.create(size + 1))
		local outboundTable = {}

		local packetArray = packetSet[2]
		local packetCount = math.min(255,#packetArray)

		OutboundInscriber:WriteType("unsigned8",packetCount) -- total # of calls
	end
end

function NettyClient.Start()
	if not NettyClient.Started then
		NettyClient.Started = true

		BufferInscriber:SetBuffer(buffer.create(5))
		BufferInscriber:WriteType("unsigned8",1)
		BufferInscriber:WriteType("unsigned8",1)
		BufferInscriber:WriteType("unsigned8",1)
		BufferInscriber:WriteType("unsigned8",0)
		BufferInscriber:WriteType("unsigned8",1)
		ReliableChannel:FireServer(BufferInscriber.buffer,{[1] = "a"})

		ReliableChannel.OnClientEvent:Connect(InoundEventHandler)
		UnreliableChannel.OnClientEvent:Connect(InoundEventHandler)
	end
end

function NettyClient.RegisterEvent(id:any,callback:(...any) -> nil)
	NettyClient.Events[id] = callback
end

function NettyClient.SpawnEvent(eventType:any,...:any)
	NettyClient.Events[eventType](...)
end

function NettyClient.FireServer(id:any,...:any)
	
end

return NettyClient