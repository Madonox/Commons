-- Madonox
-- 2024

export type Proxy = {
	onRead: ((any) -> nil) -> nil;
	onWrite: ((any,any) -> nil) -> nil;

	__readEmitters: {(any) -> nil};
	__writeEmitters: {(any,any) -> nil};
	[any]: any;
}

export type Observer = {
	new: () -> Proxy;
	cleanup: (any) -> nil;
}

--[=[

@class Observer
The Observer class allows for the construction of tables with observational capabilities.

]=]
local Observer:Observer = {} :: Observer

local OBSERVER_REF = {}

local ProxyFunctions = {
	__index = function(proxy,key)
		local container = OBSERVER_REF[proxy]
		for _,callback in container.__readEmitters do
			callback(key)
		end

		return container[key]
	end;
	__newindex = function(proxy,key,value)
		local container = OBSERVER_REF[proxy]
		for _,callback in container.__writeEmitters do
			callback(key,value)
		end
		container[key] = value
	end;
	__iter = function(proxy)
		return next, OBSERVER_REF[proxy]
	end;
	__len = function(proxy)
		return #OBSERVER_REF[proxy]
	end;

}

--[=[

@within Observer
This function allows you to create a new observational table.
@return {[any]:any} -- Returns a table with observational capabilities.

:::note
The returned data type is actually a `userdata`.  In order to performantly emit table read / write events, we need to use this setup.

```lua
local Observer = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Observer
local MyTable = Observer.new()

MyTable.onRead(function(key)
	print("Someone read " .. key .. " from MyTable!")
end)

MyTable.abc = 123

print(MyTable.abc) -- Triggers the pre-defined onRead function
```
]=]
function Observer.new()
	local readEmitters = {}
	local writeEmitters = {}

	local container = {
		onRead = function(callback)
			table.insert(readEmitters,callback)
		end;
		onWrite = function(callback)
			table.insert(writeEmitters,callback)
		end;
		__readEmitters = readEmitters;
		__writeEmitters = writeEmitters;
	}
	local proxy = newproxy(true)
	OBSERVER_REF[proxy] = container
	local proxyMetatable = getmetatable(proxy)

	proxyMetatable.__index = ProxyFunctions.__index
	proxyMetatable.__newindex = ProxyFunctions.__newindex
	proxyMetatable.__len = ProxyFunctions.__len
	proxyMetatable.__iter = ProxyFunctions.__iter

	return proxy
end

--[=[

@within Observer
This function cleans up an observational table.
@param proxy {[any]:any} -- The observational table you want to clean up.

```lua
local Observer = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Observer
local MyTable = Observer.new()

MyTable.onRead(function(key)
	print("Someone read " .. key .. " from MyTable!")
end)

MyTable.abc = 123

print(MyTable.abc) -- Triggers the pre-defined onRead function

Observer.cleanup(MyTable)
```
]=]
function Observer.cleanup(proxy)
	local proxyTable = OBSERVER_REF[proxy]
	if proxyTable then
		table.clear(proxyTable.__readEmitters)
		table.clear(proxyTable.__writeEmitters)
		table.clear(proxyTable)
		table.clear(getmetatable(proxy))
		OBSERVER_REF[proxy] = nil
		return
	end
	error(proxy .. " is not registered as an Observer!")
end

return Observer