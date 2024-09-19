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

    pointer: number;
    buffer: buffer;
    template: {[any]:any};
    __index: BufferModule;

    Types: {string:any};
}

local Types = script:WaitForChild("Types")
local BUFFER_TYPES = {
    ["BrickColor"] = {2,24,require(Types:WaitForChild("BrickColor"))};
    ["CFrame"] = {3,768,require(Types:WaitForChild("CFrame"))};
    ["Color3"] = {4,24};
    ["DateTime"] = {7,64};
    ["TweenInfo"] = {8,216};
    ["UDim"] = {9,128};
    ["UDim2"] = {10,256};
    ["Vector2"] = {11,128};
    ["Vector2int16"] = {12,32};
    ["Vector3"] = {13,192};
    ["Vector3int16"] = {14,48};
}

--[=[
    @class Buffer
    The primary class for this module.  It is used to handle all forms of buffer serialization and deserialization.
]=]
local Buffer:BufferModule = {} :: BufferModule
Buffer.__index = Buffer
Buffer.Types = BUFFER_TYPES

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
    if options.MakeBuffer then
        local self = setmetatable({
            buffer = buffer.create(SizeOfTemplate(template));
            pointer = 0;
            template = template;
        }, Buffer);
    
        return self;
    end

    local self = setmetatable({
        pointer = 0;
        template = template;
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
end

function Buffer:Read(memorySize:number,dataType:string)
    local response = buffer[dataType](self.buffer,self.pointer)
    self:IncrementPointer(memorySize)
    return response
end

function Buffer:IncrementPointer(amount:number)
    self.pointer += amount
end

--[=[
    This function imports an external buffer, and begins using it.
    
    @method ImportBuffer
    @within Buffer
    @param buffer Buffer
]=]
function Buffer:ImportBuffer(buffer: buffer)
    self.buffer = buffer
end

return Buffer