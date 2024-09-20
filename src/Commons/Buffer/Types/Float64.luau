-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local Float64 = {}

function Float64:Serialize(value:number)
    self:Write(8,"writef64",value)
end

function Float64:Deserialize()
    return self:Read(8,"readf64")
end

return Float64