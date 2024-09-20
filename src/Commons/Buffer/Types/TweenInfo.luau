-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local TweenInfoType = {}

function TweenInfoType:Serialize(value:TweenInfo)
    self:Write(8,"writef64",value.Time)
    self:Write(1,"writeu8",value.EasingStyle.Value)
    self:Write(1,"writeu8",value.EasingDirection.Value)
    self:Write(8,"writef64",value.RepeatCount)
    self:Write(1,"writeu8",(value.Reverses and 1) or 0)
    self:Write(8,"writef64",value.DelayTime)
end

function TweenInfoType:Deserialize()
    return TweenInfo.new(
        self:Read(8,"readf64"),
        Enum.EasingStyle:FromValue(self:Read(1,"readu8")),
        Enum.EasingDirection:FromValue(self:Read(1,"readu8")),
        self:Read(8,"readf64"),
        if (self:Read(1,"readu8") == 1) then true else false,
        self:Read(8,"readf64")
    )
end

return TweenInfoType