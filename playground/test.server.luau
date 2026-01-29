--!optimize 2
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local JPSPlus = require("./JPSPlus")
local WorldGrid = require("./WorldGrid")

local npcModel = workspace:WaitForChild("Rig")

local origin = Vector3.new(-512, 0, -512)
local cellSize = 2
local width, height = 512, 512

local adapter = WorldGrid.new(origin, cellSize, width, height)

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = CollectionService:GetTagged("NavBlock")

local queryBoxSize = Vector3.new(cellSize * 0.9, 10, cellSize * 0.9)

local grid = JPSPlus.grid.new(width, height, function(x, y)
	local center = adapter:cellToWorldCenter(x, y) + Vector3.new(0, 5, 0)
	local parts = workspace:GetPartBoundsInBox(CFrame.new(center), queryBoxSize, overlap)
	return (#parts > 0)
end)

local db = JPSPlus.preprocess.build(grid, {
	DiagonalPolicy = JPSPlus.grid.DiagonalPolicy.NoSqueeze,
})

local planner = JPSPlus.planner.new(db)

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = CollectionService:GetTagged("NavGround")
groundParams.IgnoreWater = true

local function snapToGround(p: Vector3, fallbackY: number)
	local hit = workspace:Raycast(p + Vector3.new(0, 200, 0), Vector3.new(0, -600, 0), groundParams)
	if hit then
		return Vector3.new(p.X, hit.Position.Y, p.Z)
	end
	return Vector3.new(p.X, fallbackY, p.Z)
end

local function makePathVisualizer(folderName: string)
	local folder = workspace:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = workspace
	end

	local pool: {BasePart} = {}

	local function getPart(i: number): BasePart
		local part = pool[i]
		if part then return part end

		part = Instance.new("Part")
		part.Name = tostring(i)
		part.Size = Vector3.new(0.5, 0.5, 0.5)
		part.Anchored = true
		part.CanCollide = false
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(255, 255, 255)
		part.Transparency = 0.5
		part.Parent = folder

		pool[i] = part
		return part
	end

	local function render(points: {Vector3})
		for i, p in ipairs(points) do
			local part = getPart(i)
			part.Position = p
			part.Transparency = 0.5
		end

		for i = #points + 1, #pool do
			local part = pool[i]
			if part then
				part.Transparency = 1
			end
		end
	end

	local function clear()
		for i = 1, #pool do
			local part = pool[i]
			if part then
				part.Transparency = 1
			end
		end
	end

	return {
		Render = render,
		Clear = clear,
		Folder = folder,
	}
end

local visual = makePathVisualizer("Visual")

local function findWorldPath(startPos: Vector3, goalPos: Vector3, yHint: number): {Vector3}?
	local sx, sy = adapter:worldToCell(startPos)
	local gx, gy = adapter:worldToCell(goalPos)
	if not sx or not gx then
		return nil
	end

	if sx < 1 or sx > width or sy < 1 or sy > height then return nil end
	if gx < 1 or gx > width or gy < 1 or gy > height then return nil end

	local cells = planner:findPath(sx, sy, gx, gy, { Expand = true })
	if not cells then return nil end

	--cells = JPSPlus.smoothing.simplify(grid, cells) -- this is optional

	local points = table.create(#cells)
	for i = 1, #cells do
		local c = cells[i]
		local p = adapter:cellToWorldCenter(c.x, c.y)
		points[i] = snapToGround(p, yHint)
	end

	return points
end

local function chaseNPC(npc: Model, getTargetPos: () -> Vector3?)
	local humanoid = npc:WaitForChild("Humanoid") :: Humanoid
	local root = npc:WaitForChild("HumanoidRootPart") :: BasePart

	local replanHz = 10 -- 15 replans/sec is usually enough
	local replanInterval = 1 / replanHz
	local moveUpdateHz = 20 -- how often to re-issue MoveTo
	local moveUpdateInterval = 1 / moveUpdateHz
	local waypointReach = 3 -- studs

	local currentPath: {Vector3}? = nil
	local wpIndex = 1
	local pathVersion = 0

	local computing = false
	local lastReplanTime = 0
	local failedReplans = 0

	task.spawn(function()
		local lastMoveToTime = 0
		while npc.Parent do
			task.wait()
			
			local targetPos = getTargetPos()
			if not targetPos then
				currentPath = nil
				continue
			end

			local path = currentPath
			if not path or wpIndex > #path then
				continue
			end

			while path and wpIndex <= #path and (root.Position - path[wpIndex]).Magnitude <= waypointReach do
				wpIndex += 1
			end
			if not path or wpIndex > #path then
				continue
			end

			if (os.clock() - lastMoveToTime) >= moveUpdateInterval then
				humanoid:MoveTo(path[wpIndex])
				lastMoveToTime = os.clock()
			end
		end
	end)
	
	while npc.Parent do
		local now = os.clock()
		local targetPos = getTargetPos()
		if not targetPos then
			task.wait(0.1)
			continue
		end

		local shouldReplan = false
		if (now - lastReplanTime) >= replanInterval then
			shouldReplan = true
		end

		if shouldReplan and not computing then
			computing = true
			lastReplanTime = now

			local myVersion = pathVersion + 1
			pathVersion = myVersion

			task.spawn(function()
				local path = findWorldPath(root.Position, targetPos, root.Position.Y)
				computing = false

				if myVersion ~= pathVersion then
					return
				end
				
				if path and #path > 0 then
					failedReplans = 0
					currentPath = path
					wpIndex = 1
					visual.Render(path)
				else
					failedReplans += 1
					if failedReplans >= 20 then -- ~2 seconds at 10Hz
						visual.Clear()
					end
				end
			end)
		end
		task.wait(0.01)
	end
end

task.spawn(function()
	chaseNPC(npcModel, function()
		local plr = Players:GetPlayers()[1]
		local char = plr and plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		return hrp and hrp.Position or nil
	end)
end)
