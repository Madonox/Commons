-- Madonox
-- 2024

--@type BufferOptions { MakeBuffer: boolean, Template: {string} }
--@within Buffer
-- Defines construction configuration
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

    Proxy: {[any]:any};
}

local Types = script:WaitForChild("Types")
local BUFFER_TYPES = {
    ["BrickColor"] = {0,24,require(Types:WaitForChild("BrickColor"))};
    ["CFrame"] = {0,96,require(Types:WaitForChild("CFrame"))};
    ["Color3"] = {0,24,require(Types:WaitForChild("Color3"))};
    ["DateTime"] = {0,8,require(Types:WaitForChild("DateTime"))};
    ["TweenInfo"] = {0,19,require(Types:WaitForChild("TweenInfo"))};
    ["UDim"] = {0,128};
    ["UDim2"] = {0,256};
    ["Vector2"] = {0,128};
    ["Vector2int16"] = {0,32};
    ["Vector3"] = {0,192};
    ["Vector3int16"] = {0,48};
    ["unsigned8"] = {0,1,require(Types:WaitForChild("Unsigned8"))};
    ["int8"] = {0,1,require(Types:WaitForChild("Integer8"))};
    ["float32"] = {0,4,require(Types:WaitForChild("Float32"))};
    ["float64"] = {0,8,require(Types:WaitForChild("Float64"))};
}

local BufferTypeIndex = 0
for _,bufferType in BUFFER_TYPES do
    BufferTypeIndex += 1
    bufferType[1] = BufferTypeIndex
end

--[=[
    @class Buffer
    The primary class for this module.  It is used to handle all forms of buffer serialization and deserialization.
]=]
local Buffer:BufferModule = {} :: BufferModule
Buffer.__index = Buffer
Buffer.Types = BUFFER_TYPES

local function SizeOf(typeMarker:string): number
    return BUFFER_TYPES[typeMarker][2]
end

local function SizeOfTemplate(template): number
    local baseSize = 0
    for _,typeMarker in template do
        baseSize += BUFFER_TYPES[typeMarker][2]
    end

    return baseSize
end

--[=[
    Create an instance of the Buffer class.
    
    @within Buffer
    @param options BufferOptions -- Configuration options for class initialization
    @return BufferModule -- Returns an instance of the Buffer class.
]=]
function Buffer.new(options:BufferOptions): BufferModule
    local template = options.Template
    local size = SizeOfTemplate(template)
    if options.MakeBuffer then
        local self = setmetatable({
            buffer = buffer.create(size);
            size = size;
            pointer = 0;
            template = template;
        }, Buffer);
    
        return self;
    end

    local self = setmetatable({
        pointer = 0;
        template = template;
        size = size;
    }, Buffer);

    return self;
end

--[=[
    This function takes an array of data and serializes it according to the supplied template.
    
    @method Serialize
    @within Buffer
    @param data {any} -- The data you want to serialize.
    @return buffer
]=]
function Buffer:Serialize(data:{any})
    local template = self.template
    --self:Write(8, "writeu8", #template) -- Store count of entries
    for index, entry in data do
        BUFFER_TYPES[template[index]][3].Serialize(self,entry)
    end

    self.pointer = 0
    return self.buffer
end

--[=[
    This function outputs a deserialized table corresponding to the contents of the current buffer.
    
    @method Deserialize
    @within Buffer
    @return {any}
]=]
function Buffer:Deserialize()
    self.pointer = 0
    local response = {}
    for index,entry in self.template do
        response[index] = BUFFER_TYPES[entry][3].Deserialize(self)
    end
    return response
end

function Buffer:Write(memorySize:number,dataType:string,value:number)
    buffer[dataType](self.buffer,self.pointer,value)
    self:IncrementPointer(memorySize)
    return self
end

function Buffer:Read(memorySize:number,dataType:string)
    local response = buffer[dataType](self.buffer,self.pointer)
    self:IncrementPointer(memorySize)
    return response
end

function Buffer:IncrementPointer(amount:number)
    self.pointer += amount
end

function Buffer:SetTemplate(template:{string})
    self.template = template
    return self
end

function Buffer:MakeNewBuffer()
    self.buffer = buffer.create(self.size)
    return self
end

--[=[
    This function imports an external buffer, and begins using it.
    
    @method ImportBuffer
    @within Buffer
    @param buffer Buffer
]=]
function Buffer:ImportBuffer(buffer: buffer)
    self.buffer = buffer
    return self
end

function Buffer:Destroy()
    table.clear(self.template)
    table.clear(self)
    setmetatable(self,nil)
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
}

local BufferInscriber = {}
BufferInscriber.__index = BufferInscriber

function BufferInscriber.new(instance:buffer?)
    return setmetatable({
        buffer = instance;
        pointer = 0;
    },BufferInscriber)
end

function BufferInscriber:IncrementPointer(amount:number)
    self.pointer += amount
    return self
end

function BufferInscriber:SetPointer(number:number)
    self.pointer = number
    return self
end

function BufferInscriber:Write(memorySize:number,dataType:string,value:number)
    buffer[dataType](self.buffer,self.pointer,value)
    self:IncrementPointer(memorySize)
    return self
end

function BufferInscriber:Read(memorySize:number,dataType:string)
    local response = buffer[dataType](self.buffer,self.pointer)
    self:IncrementPointer(memorySize)
    return response
end

function BufferInscriber:ReadType(dataType:string,offset:number?)
    if offset then
        self.pointer = offset
    end
    return BUFFER_TYPES[dataType][3].Deserialize(self),self.pointer
end

function BufferInscriber:WriteType(dataType:string,data:any)
    BUFFER_TYPES[dataType][3].Serialize(self,data)
    return self
end

function BufferInscriber:SetBuffer(instance:buffer)
    self.buffer = instance
    return self
end

function BufferInscriber:Destroy()
    table.clear(self)
    setmetatable(self,nil)
end

local function TypeToId(dataType:string)
    return BUFFER_TYPES[dataType][1]
end

local function IdToType(dataId:number)
    for index,data in BUFFER_TYPES do
        if data[1] == dataId then
            return index
        end
    end
end

local F32_NUMERICAL_MIN = -3.4e+38
local F32_NUMERICAL_MAX = 3.4e+38

local I8_NUMERICAL_MIN = -128
local I8_NUMERICAL_MAX = 127

local I16_NUMERICAL_MIN = -32_768
local I16_NUMERICAL_MAX = 32_767

local U8_NUMERICAL_MIN = 0
local U8_NUMERICAL_MAX = 255

local U16_NUMERICAL_MIN = 0
local U16_NUMERICAL_MAX = 65535

local U32_NUMERICAL_MIN = 0
local U32_NUMERICAL_MAX = 4294967295

local function _resolveNumberType(number:number)
    if math.floor(number) ~= number then
        if number <= F32_NUMERICAL_MAX and number >= F32_NUMERICAL_MIN then
            return "float32"
        end
        return "float64"
    end

    if math.sign(number) < 0 then
        if number <= I8_NUMERICAL_MAX and number >= I8_NUMERICAL_MIN then
            return "int8"
        end

        if number <= I16_NUMERICAL_MAX and number >= I16_NUMERICAL_MIN then
            return "int16"
        end
        return "int32"
    end

    if number <= U8_NUMERICAL_MAX and number >= U8_NUMERICAL_MIN then
        return "unsigned8"
    end

    if number <= U16_NUMERICAL_MAX and number >= U16_NUMERICAL_MIN then
        return "unsigned16"
    end

    if number <= U32_NUMERICAL_MAX and number >= U32_NUMERICAL_MIN then
        return "unsigned32"
    end

    -- number is too big to use any of the aformentioned data type- default to floats for extra size
    if number <= F32_NUMERICAL_MAX and number >= F32_NUMERICAL_MIN then
        return "float32"
    end
    return "float64"
end

local function ResolveType(data:any)
    local dataType = typeof(data)

    if dataType == "number" then -- resolve reducer
        return _resolveNumberType(data)
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