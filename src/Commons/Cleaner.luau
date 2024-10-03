-- Madonox
-- 2024

export type Cleaner = {
	Cleanup: (any) -> nil;
	CleanupTable: ({[any]: any}) -> nil;
}

local Cleaner:Cleaner = {}

local CleanupFunctions = {
	Instance = function(object)
		object:Destroy()
	end;
	thread = function(thread)
		pcall(coroutine.close,thread)
	end;
	SharedTable = function(object)
		object.clear()
	end;
	RBXScriptConnection = function(connection)
		connection:Disconnect()
	end;

}
function Cleaner.Cleanup(item:any,itemType:string?)
	itemType = itemType or typeof(item)
	local handle = CleanupFunctions[itemType]
	if handle then
		handle(item)
	end
end

function Cleaner.CleanupTable(table:{[any]:any})
	for index, value in table do
		local itemType = typeof(value)
		if itemType == "table" then
			table[index] = nil
			if value.Destroy then -- allows for custom destruction
				value:Destroy()
			end

			setmetatable(value, nil)
			Cleaner.CleanupTable(value)
			continue
		end
		Cleaner.Cleanup(value, itemType)
	end
end

export type TrackedCleaner = {
	new: () -> TrackedCleaner;
	
	Add: (TrackedCleaner, any) -> TrackedCleaner;
	Remove: (TrackedCleaner, any) -> TrackedCleaner;

	Destroy: (TrackedCleaner) -> nil;
}

local TrackedCleaner:TrackedCleaner = {}
TrackedCleaner.__index = TrackedCleaner

function TrackedCleaner.new()
	return setmetatable({},TrackedCleaner)
end

function TrackedCleaner:Add(item:any)
	table.insert(self,item)
	return self
end

function TrackedCleaner:Remove(item:any)
	local ref = table.find(self,item)
	if ref then
		table.remove(self,item)
	end
	return self
end

function TrackedCleaner:Destroy()
	setmetatable(self,nil)
	Cleaner.CleanupTable(self)
end

export type CleanerModule = {
	Cleaner: Cleaner;
	TrackedCleaner: TrackedCleaner;
}

local CleanerModule:CleanerModule = {
	Cleaner = Cleaner;
	TrackedCleaner = TrackedCleaner;
}

return CleanerModule