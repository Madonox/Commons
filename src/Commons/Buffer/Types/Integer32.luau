-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local Integer32 = {}

function Integer32:Serialize(value:number)
    self:Write(4,"writei32",value)
end

function Integer32:Deserialize()
    return self:Read(4,"readi32")
end

return Integer32