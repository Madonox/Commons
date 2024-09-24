-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local Integer16 = {}

function Integer16:Serialize(value:number)
    self:Write(2,"writei16",value)
end

function Integer16:Deserialize()
    return self:Read(2,"readi16")
end

return Integer16