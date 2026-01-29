--!native
--!optimize 2
local RunService = game:GetService("RunService")

local JPSPlus = require("./JPSPlus")

local WIDTH, HEIGHT = 384, 384
local OBSTACLE_DENSITY = 0.25
local SEED = 12345

local NUM_QUERIES = 5000
local WARMUP = 200

local DIAG_POLICY = JPSPlus.grid.DiagonalPolicy.NoSqueeze

local YIELD_EVERY = 100

local function percentile(sorted, p)
	local n = #sorted
	if n == 0 then return 0 end
	local idx = math.floor(p * n)
	if idx < 1 then idx = 1 end
	if idx > n then idx = n end
	return sorted[idx]
end

local function summarize(times)
	table.sort(times)
	local n = #times
	local total = 0
	local maxv = 0
	for i = 1, n do
		local t = times[i]
		total += t
		if t > maxv then maxv = t end
	end
	return {
		n = n,
		avg = total / n,
		p50 = percentile(times, 0.50),
		p95 = percentile(times, 0.95),
		p99 = percentile(times, 0.99),
		max = maxv,
	}
end

local function fmtSeconds(s)
	return string.format("%.6f", s)
end

local function printSummary(label, summary, found, total)
	print(("[%s] n=%d found=%d/%d avg=%ss p50=%ss p95=%ss p99=%ss max=%ss")
		:format(
			label,
			summary.n,
			found, total,
			fmtSeconds(summary.avg),
			fmtSeconds(summary.p50),
			fmtSeconds(summary.p95),
			fmtSeconds(summary.p99),
			fmtSeconds(summary.max)
		)
	)
end

local rng = Random.new(SEED)
local grid = JPSPlus.grid.new(WIDTH, HEIGHT, function(x, y)
	return rng:NextNumber() < OBSTACLE_DENSITY
end)

local walkable = {}
walkable.reserve = WIDTH * HEIGHT

for y = 1, HEIGHT do
	for x = 1, WIDTH do
		local id = grid:id(x, y)
		if grid:isWalkableId(id) then
			walkable[#walkable + 1] = { x = x, y = y }
		end
	end
end

assert(#walkable > 0, "No walkable cells; reduce obstacle density.")

task.wait(5)

local memBefore = gcinfo()
local t0 = os.clock()

local db = JPSPlus.preprocess.build(grid, {
	DiagonalPolicy = DIAG_POLICY,
})

local t1 = os.clock()
local memAfter = gcinfo()

print(("Preprocess: time=%ss  memDelta=%.1f KB  grid=%dx%d  walkable=%d")
	:format(fmtSeconds(t1 - t0), (memAfter - memBefore), WIDTH, HEIGHT, #walkable))

local planner = JPSPlus.planner.new(db)

local pairs = table.create(NUM_QUERIES)
for i = 1, NUM_QUERIES do
    local a = walkable[rng:NextInteger(1, #walkable)]
    local b = walkable[rng:NextInteger(1, #walkable)]
    pairs[i] = { ax = a.x, ay = a.y, bx = b.x, by = b.y }
end

for i = 1, WARMUP do
    local q = pairs[i]
    planner:findPath(q.ax, q.ay, q.bx, q.by, { Expand = false })
end

do
    local timesA = table.create(NUM_QUERIES)
    local foundA = 0
    
    local startA = os.clock()
    
    for i = 1, NUM_QUERIES do
        local q = pairs[i]
        local t = os.clock()
        local path = planner:findPath(q.ax, q.ay, q.bx, q.by, { Expand = false })
        timesA[i] = os.clock() - t
        if path then foundA += 1 end
    
        if (i % YIELD_EVERY) == 0 then
            task.wait()
        end
    end
    
    local totalA = os.clock() - startA
    
    local summaryA = summarize(timesA)
    printSummary("JPS+ Expand=false", summaryA, foundA, NUM_QUERIES)
    print(("Total wall time (Expand=false): %ss  QPS=%.1f")
        :format(fmtSeconds(totalA), NUM_QUERIES / totalA))
end

do
    local timesB = table.create(NUM_QUERIES)
    local foundB = 0

    local startB = os.clock()

    for i = 1, NUM_QUERIES do
        local q = pairs[i]
        local t = os.clock()
        local path = planner:findPath(q.ax, q.ay, q.bx, q.by, { Expand = true })
        timesB[i] = os.clock() - t
        if path then foundB += 1 end

        if (i % YIELD_EVERY) == 0 and RunService:IsStudio() then
            task.wait()
        end
    end

    local totalB = os.clock() - startB

    local summaryB = summarize(timesB)
    printSummary("JPS+ Expand=true", summaryB, foundB, NUM_QUERIES)
    print(("Total wall time (Expand=true): %ss  QPS=%.1f")
        :format(fmtSeconds(totalB), NUM_QUERIES / totalB))
end

do
    local timesD = table.create(NUM_QUERIES)
    local foundD = 0

    local startD = os.clock()

    for i = 1, NUM_QUERIES do
        local q = pairs[i]
        local t = os.clock()
        local path = planner:findPath(q.ax, q.ay, q.bx, q.by, { NoReconstruct = true })
        timesD[i] = os.clock() - t
        if path then foundD += 1 end

        if (i % YIELD_EVERY) == 0 and RunService:IsStudio() then
            task.wait()
        end
    end

    local totalD = os.clock() - startD

    local summaryD = summarize(timesD)
    printSummary("JPS+ NoReconstruct=true", summaryD, foundD, NUM_QUERIES)
    print(("Total wall time (NoReconstruct=true): %ss  QPS=%.1f")
        :format(fmtSeconds(totalD), NUM_QUERIES / totalD))
end

do
    local timesC = table.create(NUM_QUERIES)
    local foundC = 0

    local startC = os.clock()

    for i = 1, NUM_QUERIES do
        local q = pairs[i]
        local t = os.clock()
        local path = planner:findPath(q.ax, q.ay, q.bx, q.by, { Expand = true })
        if path then
            path = JPSPlus.smoothing.simplify(grid, path)
            foundC += 1
        end
        timesC[i] = os.clock() - t

        if (i % YIELD_EVERY) == 0 and RunService:IsStudio() then
            task.wait()
        end
    end

    local totalC = os.clock() - startC

    local summaryC = summarize(timesC)
    printSummary("JPS+ Expand=true+Smooth", summaryC, foundC, NUM_QUERIES)
    print(("Total wall time (Expand+Smooth): %ss  QPS=%.1f")
        :format(fmtSeconds(totalC), NUM_QUERIES / totalC))
end