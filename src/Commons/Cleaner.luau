-- Madonox
-- 2024

export type Cleaner = {
	Cleanup: (any,string?) -> nil;
	CleanupTable: ({[any]: any}) -> nil;
}

--[=[
@class Cleaner
The Cleaner class provides a set of functions for cleaning up instances, and tables.
]=]
local Cleaner:Cleaner = {} :: Cleaner

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

--[=[
@within Cleaner
@param item any -- The item to cleanup
@param itemType string? -- The item's type (impacts the cleanup function used)

This function can be used to cleanup the passed item argument.
```lua
local Cleaner = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Cleaner
Cleaner.Cleanup(workspace.MyPart)
```
]=]
function Cleaner.Cleanup(item:any,itemType:string?)
	itemType = itemType or typeof(item)
	local handle = CleanupFunctions[itemType]
	if handle then
		handle(item)
	end
end

--[=[
@within Cleaner
@param table {[any]:any} -- The table to cleanup

This function goes through a table, and deep cleans it (cleans up all values and nested tables).

```lua
local Cleaner = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Cleaner.Cleaner
local MyTable = {
	workspace.MyPart;
	{
		workspace.MyOtherPart;
	};
}

Cleaner.CleanupTable(MyTable) -- Will destroy Workspace.MyPart, and workspace.MyOther part, as well as clear up the table's metatables and contents
```
]=]
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
	__index: TrackedCleaner;
}

--[=[
@class TrackedCleaner
The TrackedCleaner class allows for real time tracking and cleaning of variables.
]=]
local TrackedCleaner:TrackedCleaner = {} :: TrackedCleaner
TrackedCleaner.__index = TrackedCleaner

--[=[
@within TrackedCleaner
@return TrackedCleaner
Creates a new TrackedCleaner object.
]=]
function TrackedCleaner.new()
	return setmetatable({},TrackedCleaner)
end

--[=[
@within TrackedCleaner
@param item any -- The item to add to the tracker.
@return TrackedCleaner
Add an item to the tracker.

```lua
local TrackedCleaner = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Cleaner.TrackedCleaner
local MyCleaner = TrackedCleaner.new()

MyCleaner:Add(workspace.MyPart)

local MyTable = {
	workspace.MyOtherPart
}

MyCleaner:Add(MyTable)
```
]=]
function TrackedCleaner:Add(item:any)
	table.insert(self,item)
	return self
end

--[=[
@within TrackedCleaner
@param item any -- The item to remove from the tracker.
@return TrackedCleaner
Remove an item from the tracker.

```lua
local TrackedCleaner = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Cleaner.TrackedCleaner
local MyCleaner = TrackedCleaner.new()

MyCleaner:Add(workspace.MyPart)

MyCleaner:Remove(workspace.MyPart)
```
]=]
function TrackedCleaner:Remove(item:any)
	local ref = table.find(self,item)
	if ref then
		table.remove(self,item)
	end
	return self
end

--[=[
@within TrackedCleaner

Destroy the tracker, and cleanup everything inside it.

```lua
local TrackedCleaner = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Cleaner.TrackedCleaner
local MyCleaner = TrackedCleaner.new()

MyCleaner:Add(workspace.MyPart)

MyCleaner:Destroy() -- workspace.MyPart is destroyed, as it is being tracked by the cleaner.
```
]=]
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