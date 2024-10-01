-- Madonox
-- 2024

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

local Pool:Pool = {} :: Pool
Pool.__index = Pool

function Pool.new(options:PoolOptions)
	return setmetatable({
		interval = options.Interval or .01;
		operationLimit = options.OperationLimit or 5;
		operationQueue = {};
		currentThread = nil;
	},Pool)
end

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

function Pool:Stop()
	local thread = self.currentThread
	if thread then
		coroutine.close(thread)
		self.currentThread = nil
	end
	return self
end

function Pool:ThreadActive()
	if self.currentThread then
		return true
	end
	return false
end

function Pool:GetCurrentId()
	local thread = self.currentThread
	if thread then
		return tostring(thread)
	end
end

function Pool:QueueOperation(operation:(number?,Pool?) -> nil)
	table.insert(self.operationQueue,operation)
	return self
end

function Pool:AdjustInterval(interval:number)
	self.interval = interval
	return self
end

function Pool:AdjustOperationLimit(limit:number)
	self.operationLimit = limit
	return self
end

function Pool:Destroy()
	self:Stop()
	table.clear(self.operationQueue)
	table.clear(self)
	setmetatable(self,nil)
end

return Pool