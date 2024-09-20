-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local DateTimeType = {}

function DateTimeType:Serialize(value:DateTime)
    self:Write(8,"writef64",value.UnixTimestamp)
end

function DateTimeType:Deserialize()
    return DateTime.fromUnixTimestamp(self:Read(8,"readf64"))
end

return DateTimeType