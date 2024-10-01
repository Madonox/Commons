-- Madonox
-- 2024

--[=[
@interface PoolOptions
@within Pool
.Interval number? -- The interval to run operations at (default 0.01).
.OperationLimit number? -- The number of operations to run each step (default 5).
]=]
export type PoolOptions = {
	Interval: number?;
	OperationLimit: number?;
}

export type Pool = {
	new: (PoolOptions) -> Pool;

	Spawn: (Pool) -> Pool;
	Stop: (Pool) -> Pool;
	QueueOperation: (Pool, (number?,Pool?) -> nil) -> Pool;
	AdjustInterval: (Pool, number) -> Pool;
	AdjustOperationLimit: (Pool, number) -> Pool;
	ThreadActive: (Pool) -> boolean;
	GetCurrentId: (Pool) -> string?;

	Destroy: (Pool) -> nil;

	interval: number;
	operationLimit: number;
	operationQueue: {(number?,Pool?) -> nil};
	currentThread: thread?;

	__index: Pool;
}

--[=[

@class Pool
The Pool class is used to handle all forms of operation management.  Additionally, it manages the thread being used to run all of the queued operations.

]=]
local Pool:Pool = {} :: Pool
Pool.__index = Pool

--[=[

@function new
@within Pool
This function creates a new instance of the Pool class.
@param options PoolOptions -- The initial configuration for the class.
@return Pool

]=]
function Pool.new(options:PoolOptions)
	return setmetatable({
		interval = options.Interval or .01;
		operationLimit = options.OperationLimit or 5;
		operationQueue = {};
		currentThread = nil;
	},Pool)
end

--[=[

@within Pool
This function spawns a thread to process operations.  There can only be one thread running at once.
@return Pool

]=]
function Pool:Spawn()
	if not self.currentThread then
		local thread = coroutine.create(function()
			local queue = self.operationQueue
			while self.currentThread do
				local deltaTime = task.wait(self.interval)
				for _ = 1,math.min(self.operationLimit,#queue) do
					queue[1](deltaTime,self)
					table.remove(queue,1)
				end
			end
		end)
		self.currentThread = thread
		coroutine.resume(thread)
		return self
	end

	warn("Cannot spawn pool!  There is already a running thread!")
	return self
end

--[=[

@within Pool
This function stops the current thread.
@return Pool

]=]
function Pool:Stop()
	local thread = self.currentThread
	if thread then
		coroutine.close(thread)
		self.currentThread = nil
	end
	return self
end

--[=[

@within Pool
This function returns true if the Pool currently has a working thread.
@return boolean

]=]
function Pool:ThreadActive()
	if self.currentThread then
		return true
	end
	return false
end

--[=[

@within Pool
This function returns the current thread id if there is a working thread.
@return string?

]=]
function Pool:GetCurrentId()
	local thread = self.currentThread
	if thread then
		return tostring(thread)
	end
end

--[=[

@within Pool
This function queues a function to be executed by the pool.
@param operation (number?, Pool?) -> nil
@return Pool

]=]
function Pool:QueueOperation(operation:(number?,Pool?) -> nil)
	table.insert(self.operationQueue,operation)
	return self
end

--[=[

@within Pool
This function adjusts the interval at which the pool executes operations at.
@param interval number
@return Pool

]=]
function Pool:AdjustInterval(interval:number)
	self.interval = interval
	return self
end

--[=[

@within Pool
This function adjusts the operation limit for each frame.
@param limit number
@return Pool

]=]
function Pool:AdjustOperationLimit(limit:number)
	self.operationLimit = limit
	return self
end

--[=[

@within Pool
This function destroys the Pool instance.
	
]=]
function Pool:Destroy()
	self:Stop()
	table.clear(self.operationQueue)
	table.clear(self)
	setmetatable(self,nil)
end

return Pool