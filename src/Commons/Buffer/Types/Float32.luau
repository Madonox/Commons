-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local Float32 = {}

function Float32:Serialize(value:number)
    self:Write(4,"writef32",value)
end

function Float32:Deserialize()
    return self:Read(4,"readf32")
end

return Float32