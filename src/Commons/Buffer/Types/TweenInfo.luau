-- Madonox
-- 2025

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local TweenInfoType = {}

function TweenInfoType:Serialize(value: TweenInfo): ()
	self:Write(8, "writef64", value.Time)
	self:Write(1, "writeu8", value.EasingStyle.Value)
	self:Write(1, "writeu8", value.EasingDirection.Value)
	self:Write(8, "writef64", value.RepeatCount)
	self:Write(1, "writeu8", value.Reverses and 1 or 0)
	self:Write(8, "writef64", value.DelayTime)
end

function TweenInfoType:Deserialize(): TweenInfo
	local time = self:Read(8, "readf64")
	local easingStyleValue = self:Read(1, "readu8")
	local easingDirectionValue = self:Read(1, "readu8")
	local repeatCount = self:Read(8, "readf64")
	local reverses = self:Read(1, "readu8") == 1
	local delayTime = self:Read(8, "readf64")

	return TweenInfo.new(
		time,
		Enum.EasingStyle:FromValue(easingStyleValue),
		Enum.EasingDirection:FromValue(easingDirectionValue),
		repeatCount,
		reverses,
		delayTime
	)
end

return TweenInfoType
