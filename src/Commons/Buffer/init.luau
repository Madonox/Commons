-- Madonox
-- 2025
export type BufferOptions = {
	MakeBuffer: boolean;
	Template: {string}
}

export type BufferModule = {
	new: (BufferOptions) -> BufferModule;
	Write: (BufferModule,number,string,number) -> BufferModule;
	Read: (BufferModule,number,string) -> any;
	IncrementPointer: (BufferModule,number) -> BufferModule;
	Serialize: (BufferModule,{any}) -> buffer;
	Deserialize: (BufferModule) -> {any};
	ImportBuffer: (BufferModule,buffer) -> BufferModule;
	SetTemplate: (BufferModule,{string}) -> BufferModule;
	MakeNewBuffer: (BufferModule) -> BufferModule;
	Destroy: (BufferModule) -> nil;

	pointer: number;
	buffer: buffer;
	template: {[any]:any};
	__index: BufferModule;

	Types: {string:any};
}

local Types = script:WaitForChild("Types")
local BUFFER_TYPES = {
	["BrickColor"] = {0,24,require(Types:WaitForChild("BrickColor"))};
	["CFrame"] = {0,96,require(Types:WaitForChild("CFrame"))};
	["Color3"] = {0,24,require(Types:WaitForChild("Color3"))};
	["DateTime"] = {0,8,require(Types:WaitForChild("DateTime"))};
	["TweenInfo"] = {0,19,require(Types:WaitForChild("TweenInfo"))};
	["UDim"] = {0,16,require(Types:WaitForChild("Udim"))};
	["UDim2"] = {0,32,require(Types:WaitForChild("Udim2"))};
	["Vector2"] = {0,16,require(Types:WaitForChild("Vector2"))};
	["Vector2int16"] = {0,4,require(Types:WaitForChild("Vector2int16"))};
	["Vector3"] = {0,24,require(Types:WaitForChild("Vector3"))};
	["Vector3int16"] = {0,6,require(Types:WaitForChild("Vector3int16"))};

	["unsigned8"] = {0,1,require(Types:WaitForChild("Unsigned8"))};
	["unsigned16"] = {0,2,require(Types:WaitForChild("Unsigned16"))};
	["unsigned32"] = {0,4,require(Types:WaitForChild("Unsigned32"))};

	["int8"] = {0,1,require(Types:WaitForChild("Integer8"))};
	["int16"] = {0,2,require(Types:WaitForChild("Integer16"))};
	["int32"] = {0,4,require(Types:WaitForChild("Integer32"))};

	["float32"] = {0,4,require(Types:WaitForChild("Float32"))};
	["float64"] = {0,8,require(Types:WaitForChild("Float64"))};
}

local BufferTypeIndex = 0
for _,bufferType in BUFFER_TYPES do
	BufferTypeIndex += 1
	bufferType[1] = BufferTypeIndex
end

local Buffer:BufferModule = {} :: BufferModule
Buffer.__index = Buffer
Buffer.Types = BUFFER_TYPES

local function SizeOfTemplate(template: { string }): number
	local totalSize = 0
	
	for _, typeMarker in ipairs(template) do
		local sizeInfo = BUFFER_TYPES[typeMarker]
		if sizeInfo then
			totalSize += sizeInfo[2]
		end
	end
	
	return totalSize
end

local function SizeOf(typeMarker: string): number
	return BUFFER_TYPES[typeMarker][2]
end

function Buffer.new(options: BufferOptions): BufferModule
	local template = options.Template
	local size = SizeOfTemplate(template)

	if options.MakeBuffer then
		local self = setmetatable({
			buffer = buffer.create(size),
			size = size,
			pointer = 0,
			template = template,
		}, Buffer)
		return self
	end

	local self = setmetatable({
		pointer = 0,
		template = template,
		size = size,
	}, Buffer)

	return self
end

function Buffer:Serialize(data: { any }): buffer
	local template = self.template
	
	for index, entry in ipairs(data) do
		local bufferType = BUFFER_TYPES[template[index]]
		
		if bufferType then
			bufferType[3].Serialize(self, entry)
		end
	end
	
	self.pointer = 0
	return self.buffer
end

function Buffer:Deserialize(): { any }
	self.pointer = 0
	local response: { any } = {}
	
	for index, entry in ipairs(self.template) do
		local bufferType = BUFFER_TYPES[entry]
		
		if bufferType then
			response[index] = bufferType[3].Deserialize(self)
		end
	end
	
	return response
end

function Buffer:Write(memorySize: number, dataType: string, value: number)
	buffer[dataType](self.buffer, self.pointer, value)
	self:IncrementPointer(memorySize)
	return self
end

function Buffer:Read(memorySize: number, dataType: string): number
	local response = buffer[dataType](self.buffer, self.pointer)
	self:IncrementPointer(memorySize)
	return response
end

function Buffer:IncrementPointer(amount: number)
	self.pointer += amount
	return self
end

function Buffer:SetTemplate(template: { string })
	self.template = template
	return self
end

function Buffer:MakeNewBuffer()
	self.buffer = buffer.create(self.size)
	return self
end

function Buffer:ImportBuffer(newBuffer: buffer)
	self.buffer = newBuffer
	return self
end

function Buffer:Destroy(): ()
	table.clear(self.template)
	table.clear(self)
	setmetatable(self, nil)
end

export type BufferInscriber = {
	new: (buffer?) -> BufferInscriber;

	IncrementPointer: (BufferInscriber,number) -> BufferInscriber;
	SetPointer: (BufferInscriber,number) -> BufferInscriber;

	Write: (BufferInscriber,number,string,number) -> BufferInscriber;
	Read: (BufferInscriber,number,string) -> number;

	WriteType: (BufferInscriber,string,any) -> BufferInscriber;
	ReadType: (BufferInscriber,string,number?) -> (any,number);

	SetBuffer: (BufferInscriber,buffer?) -> BufferInscriber;
	Destroy: (BufferInscriber) -> nil;

	pointer: number;
	buffer: buffer;
	__index: BufferInscriber;
}

local BufferInscriber:BufferInscriber = {} :: BufferInscriber
BufferInscriber.__index = BufferInscriber

function BufferInscriber.new(instance:buffer?)
	return setmetatable({
		buffer = instance;
		pointer = 0;
	},BufferInscriber)
end

function BufferInscriber:IncrementPointer(amount: number): BufferInscriber
	self.pointer += amount
	return self
end

function BufferInscriber:SetPointer(amount: number): BufferInscriber
	self.pointer = amount
	return self
end

function BufferInscriber:Write(memorySize: number, dataType: string, value: number): BufferInscriber
	buffer[dataType](self.buffer, self.pointer, value)
	self:IncrementPointer(memorySize)
	return self
end

function BufferInscriber:Read(memorySize: number, dataType: string): number
	local response = buffer[dataType](self.buffer, self.pointer)
	self:IncrementPointer(memorySize)
	return response
end

function BufferInscriber:ReadType(dataType: string, offset: number?): (any, number)
	if offset then
		self.pointer = offset
	end
	return BUFFER_TYPES[dataType][3].Deserialize(self), self.pointer
end

function BufferInscriber:WriteType(dataType: string, data: any): BufferInscriber
	BUFFER_TYPES[dataType][3].Serialize(self, data)
	return self
end

function BufferInscriber:SetBuffer(newBuffer: buffer?): BufferInscriber
	self.buffer = newBuffer
	return self
end

function BufferInscriber:Destroy(): ()
	table.clear(self)
	setmetatable(self, nil)
end

local function TypeToId(dataType: string): number
	return BUFFER_TYPES[dataType][1]
end

local function IdToType(dataId: number): string?
	for index, data in pairs(BUFFER_TYPES) do
		if data[1] == dataId then
			return index
		end
	end
	return nil
end

local F32_NUMERICAL_MIN: number = -3.4e+38
local F32_NUMERICAL_MAX: number = 3.4e+38

local I8_NUMERICAL_MIN: number = -128
local I8_NUMERICAL_MAX: number = 127

local I16_NUMERICAL_MIN: number = -32_768
local I16_NUMERICAL_MAX: number = 32_767

local U8_NUMERICAL_MIN: number = 0
local U8_NUMERICAL_MAX: number = 255

local U16_NUMERICAL_MIN: number = 0
local U16_NUMERICAL_MAX: number = 65_535

local U32_NUMERICAL_MIN: number = 0
local U32_NUMERICAL_MAX: number = 4_294_967_295

local function resolveNumberType(value: number): string
	if value % 1 ~= 0 then
		if value >= F32_NUMERICAL_MIN and value <= F32_NUMERICAL_MAX then
			return "float32"
		end
		return "float64"
	end

	if value < 0 then
		if value >= I8_NUMERICAL_MIN then
			return "int8"
		end
		if value >= I16_NUMERICAL_MIN then
			return "int16"
		end
		return "int32"
	end

	if value <= U8_NUMERICAL_MAX then
		return "unsigned8"
	end
	if value <= U16_NUMERICAL_MAX then
		return "unsigned16"
	end
	if value <= U32_NUMERICAL_MAX then
		return "unsigned32"
	end
	if value <= F32_NUMERICAL_MAX then
		return "float32"
	end

	return "float64"
end

local function ResolveType(data:any)
	local dataType = typeof(data)

	if dataType == "number" then
		return resolveNumberType(data)
	end

	if BUFFER_TYPES[dataType] then
		return dataType
	end
end

export type BufferLibrary = {
	Buffer: BufferModule;
	Inscriber: BufferInscriber;
	SizeOf: (string) -> number;
	TypeToId: (string) -> number;
	IdToType: (number) -> string?;
	ResolveType: (any) -> string?;
}
local BufferLibrary:BufferLibrary = {
	Buffer = Buffer;
	Inscriber = BufferInscriber;
	SizeOf = SizeOf;
	TypeToId = TypeToId;
	IdToType = IdToType;
	ResolveType = ResolveType;
}

return BufferLibrary
