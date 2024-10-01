local Observer = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Observer

local myTable = Observer.new()
myTable.onRead(function(key)
	print("Reading from myTable;  key: " .. key)
end)
myTable.onWrite(function(key,value)
	print("Writing to myTable; key: " .. key .. "; value: " .. value)
end)

myTable["abc"] = 123
print(myTable["abc"])

myTable[123] = "abc"
print(myTable[123])

Observer.cleanup(myTable)