local Pool = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons")).Pool

local operationPool = Pool.new({
	Interval = .5;
	OperationLimit = 3;
})

task.spawn(function()
	while task.wait(4) do
		operationPool:QueueOperation(function(interval,pool)
			print("Interval: " .. interval)
			print("ThreadId: " .. pool:GetCurrentId())
		end)
	end
end)

operationPool:Spawn()