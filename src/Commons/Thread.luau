-- Madonox
-- 2024

--[=[
@interface ThreadOptions
@within Thread
.Interval number? -- The interval to run operations at (default 0.01).
.OperationLimit number? -- The number of operations to run each step (default 5).
]=]
export type ThreadOptions = {
	Interval: number?;
	OperationLimit: number?;
}

export type Thread = {
	new: (ThreadOptions) -> Thread;

	Spawn: (Thread) -> Thread;
	Stop: (Thread) -> Thread;
	QueueOperation: (Thread, (number?,Thread?) -> nil) -> Thread;
	AdjustInterval: (Thread, number) -> Thread;
	AdjustOperationLimit: (Thread, number) -> Thread;
	ThreadActive: (Thread) -> boolean;
	GetCurrentId: (Thread) -> string?;

	Destroy: (Thread) -> nil;

	interval: number;
	operationLimit: number;
	operationQueue: {(number?,Thread?) -> nil};
	currentThread: thread?;

	__index: Thread;
}

--[=[

@class Thread
The Thread class is used to handle all forms of operation management.  Additionally, it manages the thread being used to run all of the queued operations.

]=]
local Thread:Thread = {} :: Thread
Thread.__index = Thread

--[=[

@function new
@within Thread
This function creates a new instance of the Thread class.
@param options ThreadOptions -- The initial configuration for the class.
@return Thread

]=]
function Thread.new(options:ThreadOptions)
	return setmetatable({
		interval = options.Interval or .01;
		operationLimit = options.OperationLimit or 5;
		operationQueue = {};
		currentThread = nil;
	},Thread)
end

--[=[

@within Thread
This function spawns a thread to process operations.  There can only be one thread running at once.
@return Thread

]=]
function Thread:Spawn()
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

	warn("Cannot spawn Thread!  There is already a running thread!")
	return self
end

--[=[

@within Thread
This function stops the current thread.
@return Thread

]=]
function Thread:Stop()
	local thread = self.currentThread
	if thread then
		coroutine.close(thread)
		self.currentThread = nil
	end
	return self
end

--[=[

@within Thread
This function returns true if the Thread currently has a working thread.
@return boolean

]=]
function Thread:ThreadActive()
	if self.currentThread then
		return true
	end
	return false
end

--[=[

@within Thread
This function returns the current thread id if there is a working thread.
@return string?

]=]
function Thread:GetCurrentId()
	local thread = self.currentThread
	if thread then
		return tostring(thread)
	end
end

--[=[

@within Thread
This function queues a function to be executed by the Thread.
@param operation (number?, Thread?) -> nil
@return Thread

]=]
function Thread:QueueOperation(operation:(number?,Thread?) -> nil)
	table.insert(self.operationQueue,operation)
	return self
end

--[=[

@within Thread
This function adjusts the interval at which the Thread executes operations at.
@param interval number
@return Thread

]=]
function Thread:AdjustInterval(interval:number)
	self.interval = interval
	return self
end

--[=[

@within Thread
This function adjusts the operation limit for each frame.
@param limit number
@return Thread

]=]
function Thread:AdjustOperationLimit(limit:number)
	self.operationLimit = limit
	return self
end

--[=[

@within Thread
This function destroys the Thread instance.
	
]=]
function Thread:Destroy()
	self:Stop()
	table.clear(self.operationQueue)
	table.clear(self)
	setmetatable(self,nil)
end

return Thread