--!native
--!optimize 2
local Dirs = require("./dirs")
local PQ = require("./priorityqueue")

local Planner = {}
Planner.__index = Planner

local function octile(ix, iy, gx, gy, D, D2)
	local dx = math.abs(ix - gx)
	local dy = math.abs(iy - gy)
	local mn = (dx < dy) and dx or dy
	local mx = (dx > dy) and dx or dy
	return D2 * mn + D * (mx - mn)
end

local function sign(a)
	return (a > 0 and 1) or (a < 0 and -1) or 0
end

local function alignedSteps(ix, iy, gx, gy, dx, dy)
	local rx = gx - ix
	local ry = gy - iy

	if dx == 0 then
		if rx ~= 0 then return nil end
		if ry == 0 then return 0 end
		if (ry > 0 and dy > 0) or (ry < 0 and dy < 0) then
			return math.abs(ry)
		end
		return nil
	elseif dy == 0 then
		if ry ~= 0 then return nil end
		if rx == 0 then return 0 end
		if (rx > 0 and dx > 0) or (rx < 0 and dx < 0) then
			return math.abs(rx)
		end
		return nil
	end
	if math.abs(rx) ~= math.abs(ry) then return nil end
	if rx == 0 then return 0 end
	if ((rx > 0 and dx > 0) or (rx < 0 and dx < 0)) and ((ry > 0 and dy > 0) or (ry < 0 and dy < 0)) then
		return math.abs(rx)
	end
	return nil
end

function Planner.new(db)
	local total = db.grid.Total
	return setmetatable({
		db = db,
		stamp = 0,

		seen = table.create(total, 0),
		closed = table.create(total, 0),
		g = table.create(total, 0),
		parent = table.create(total, 0),
		inDir = table.create(total, 0),

		ix = table.create(total, 0),
		iy = table.create(total, 0),

		open = PQ.new(total),
	}, Planner)
end

local function successorMask(db, id, inDir)
	local grid = db.grid
	local blocked = grid.Blocked
	local stride = grid.Stride

	local mask = Dirs.NAT_MASK[inDir] or Dirs.NAT_MASK[0]
	if inDir == 0 then return mask end

	local function bit(d) return bit32.lshift(1, d - 1) end

	if inDir == Dirs.E then
		if blocked[id - stride] then mask = bit32.bor(mask, bit(Dirs.NE)) end
		if blocked[id + stride] then mask = bit32.bor(mask, bit(Dirs.SE)) end
	elseif inDir == Dirs.W then
		if blocked[id - stride] then mask = bit32.bor(mask, bit(Dirs.NW)) end
		if blocked[id + stride] then mask = bit32.bor(mask, bit(Dirs.SW)) end
	elseif inDir == Dirs.N then
		if blocked[id - 1] then mask = bit32.bor(mask, bit(Dirs.NW)) end
		if blocked[id + 1] then mask = bit32.bor(mask, bit(Dirs.NE)) end
	elseif inDir == Dirs.S then
		if blocked[id - 1] then mask = bit32.bor(mask, bit(Dirs.SW)) end
		if blocked[id + 1] then mask = bit32.bor(mask, bit(Dirs.SE)) end
	else
		local d1 = Dirs.diagForced1[inDir]
		local d2 = Dirs.diagForced2[inDir]

		local dx = Dirs.dx[inDir]
		local dy = Dirs.dy[inDir]

		if blocked[id - dx] then
			mask = bit32.bor(mask, bit(d1))
		end
		if blocked[id - dy * stride] then
			mask = bit32.bor(mask, bit(d2))
		end
	end

	return mask
end

local function expandJumpIdsToCells(grid, ids)
	local out = {}
	if #ids == 0 then return out end

	local x0, y0 = grid:xy(ids[1])
	table.insert(out, { x = x0, y = y0 })

	for i = 2, #ids do
		local x1, y1 = grid:xy(ids[i - 1])
		local x2, y2 = grid:xy(ids[i])

		local sx = sign(x2 - x1)
		local sy = sign(y2 - y1)
		local steps = math.max(math.abs(x2 - x1), math.abs(y2 - y1))

		for s = 1, steps do
			table.insert(out, { x = x1 + sx * s, y = y1 + sy * s })
		end
	end

	return out
end

function Planner:findPath(sx, sy, gx, gy, options)
	options = options or {}
	local D = options.StraightCost or 1.0
	local D2 = options.DiagonalCost or math.sqrt(2)
	local expand = options.Expand or false
	local maxIter = options.MaxIterations or 2e6

	local noReconstruct = options.NoReconstruct or false
	local returnIds = options.ReturnIds or false

	local db = self.db
	local grid = db.grid
	local blocked = grid.Blocked

	local start = grid:id(sx, sy)
	local goal = grid:id(gx, gy)
	if blocked[start] or blocked[goal] then
		return nil
	end
	if start == goal then
		if noReconstruct then return true end
		if returnIds then return { start } end
		return { { x = sx, y = sy } }
	end

	local six, siy = sx + 1, sy + 1
	local gix, giy = gx + 1, gy + 1

	self.stamp += 1
	local stamp = self.stamp

	local seen = self.seen
	local closed = self.closed
	local gScore = self.g
	local parent = self.parent
	local inDirArr = self.inDir
	local ixArr = self.ix
	local iyArr = self.iy

	local open = self.open
	open.n = 0

	-- buffers + offsets
	local offB = db.offB
	local clearBuf = db.clearBuf
	local jumpBuf = db.jumpBuf
	local step = db.step

	local readu16 = buffer.readu16

	seen[start] = stamp
	closed[start] = 0
	gScore[start] = 0
	parent[start] = 0
	inDirArr[start] = 0
	ixArr[start] = six
	iyArr[start] = siy

	open:push(start, octile(six, siy, gix, giy, D, D2), 0)

	local iter = 0

	while true do
		iter += 1
		if iter > maxIter then return nil end

		local current, currentG = open:pop()
		if not current then return nil end

		if seen[current] ~= stamp or currentG ~= gScore[current] then
			continue
		end
		if closed[current] == stamp then
			continue
		end
		closed[current] = stamp

		if current == goal then
			break
		end

		local cix, ciy = ixArr[current], iyArr[current]
		local inDir = inDirArr[current]
		local mask = successorMask(db, current, inDir)

		local curByte = (current - 1) * 2

		for dir = 1, 8 do
			if bit32.band(mask, bit32.lshift(1, dir - 1)) ~= 0 then
				local baseB = offB[dir]
				local c = readu16(clearBuf, baseB + curByte)
				if c > 0 then
					local dx, dy = Dirs.dx[dir], Dirs.dy[dir]

					local goalSteps = alignedSteps(cix, ciy, gix, giy, dx, dy)
					local stepsTaken = nil
					local nid = nil

					if goalSteps and goalSteps > 0 and goalSteps <= c then
						stepsTaken = goalSteps
						nid = goal
					else
						local j = readu16(jumpBuf, baseB + curByte)
						if j > 0 and j <= c then
							stepsTaken = j
							nid = current + j * step[dir]
						end
					end

					if nid then
						local addG = (Dirs.isDiag[dir] and (stepsTaken * D2) or (stepsTaken * D))
						local ng = gScore[current] + addG

						if seen[nid] ~= stamp or ng < gScore[nid] then
							seen[nid] = stamp
							gScore[nid] = ng
							parent[nid] = current
							inDirArr[nid] = dir

							local nix, niy
							if nid == goal then
								nix, niy = gix, giy
							else
								nix = cix + dx * stepsTaken
								niy = ciy + dy * stepsTaken
							end
							ixArr[nid] = nix
							iyArr[nid] = niy

							local h = octile(nix, niy, gix, giy, D, D2)
							open:push(nid, ng + h, ng)
						end
					end
				end
			end
		end
	end

	if noReconstruct then
		return true
	end

	-- Reconstruct ids
	local ids = {}
	local node = goal
	while node ~= 0 do
		table.insert(ids, node)
		node = parent[node]
	end
	for i = 1, (#ids // 2) do
		ids[i], ids[#ids - i + 1] = ids[#ids - i + 1], ids[i]
	end

	if returnIds then
		return ids
	end

	if expand then
		return expandJumpIdsToCells(grid, ids)
	end
	local out = table.create(#ids)
	for i = 1, #ids do
		local x, y = grid:xy(ids[i])
		out[i] = { x = x, y = y }
	end
	return out
end

return Planner
