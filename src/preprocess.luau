--!native
--!optimize 2
local Dirs = require("./dirs")
local Grid = require("./grid")

local Preprocess = {}

local function makeOffsets(total)
	local off = table.create(8)
	local offB = table.create(8)
	for d = 1, 8 do
		local o = (d - 1) * total
		off[d] = o
		offB[d] = o * 2 -- bytes for u16
	end
	return off, offB
end

function Preprocess.build(grid, options)
	options = options or {}
	local diagPolicy = options.DiagonalPolicy or Grid.DiagonalPolicy.NoSqueeze

	local blocked = grid.Blocked
	local stride = grid.Stride
	local total = grid.Total
	local w, h = grid.Width, grid.Height

	local off, offB = makeOffsets(total)

	local clearBuf = buffer.create(8 * total * 2)
	local jumpBuf = buffer.create(8 * total * 2)

	local readu16 = buffer.readu16
	local writeu16 = buffer.writeu16

	local step = table.create(8, 0)
	for d = 1, 8 do
		step[d] = Dirs.dx[d] + Dirs.dy[d] * stride
	end

	local function canDiagFrom(id, dx, dy)
		local dest = id + dx + dy * stride
		if blocked[dest] then return false end
		if diagPolicy == Grid.DiagonalPolicy.Always then
			return true
		end
		local a = id + dx
		local b = id + dy * stride
		local fa = not blocked[a]
		local fb = not blocked[b]
		if diagPolicy == Grid.DiagonalPolicy.NoCorner then
			return fa and fb
		end
		-- NoSqueeze
		return fa or fb
	end

	local function r(buf, baseBytes, id)
		return readu16(buf, baseBytes + (id - 1) * 2)
	end
	local function w16(buf, baseBytes, id, v)
		writeu16(buf, baseBytes + (id - 1) * 2, v)
	end

	-- E
	do
		local base = offB[Dirs.E]
		for iy = 2, h + 1 do
			for ix = w + 1, 2, -1 do
				local id = (iy - 1) * stride + ix
				if blocked[id] then
					w16(clearBuf, base, id, 0)
				else
					local nid = id + 1
					if not blocked[nid] then
						w16(clearBuf, base, id, 1 + r(clearBuf, base, nid))
					else
						w16(clearBuf, base, id, 0)
					end
				end
			end
		end
	end

	-- W
	do
		local base = offB[Dirs.W]
		for iy = 2, h + 1 do
			for ix = 2, w + 1 do
				local id = (iy - 1) * stride + ix
				if blocked[id] then
					w16(clearBuf, base, id, 0)
				else
					local nid = id - 1
					if not blocked[nid] then
						w16(clearBuf, base, id, 1 + r(clearBuf, base, nid))
					else
						w16(clearBuf, base, id, 0)
					end
				end
			end
		end
	end

	-- N
	do
		local base = offB[Dirs.N]
		for iy = 2, h + 1 do
			for ix = 2, w + 1 do
				local id = (iy - 1) * stride + ix
				if blocked[id] then
					w16(clearBuf, base, id, 0)
				else
					local nid = id - stride
					if not blocked[nid] then
						w16(clearBuf, base, id, 1 + r(clearBuf, base, nid))
					else
						w16(clearBuf, base, id, 0)
					end
				end
			end
		end
	end

	-- S
	do
		local base = offB[Dirs.S]
		for iy = h + 1, 2, -1 do
			for ix = 2, w + 1 do
				local id = (iy - 1) * stride + ix
				if blocked[id] then
					w16(clearBuf, base, id, 0)
				else
					local nid = id + stride
					if not blocked[nid] then
						w16(clearBuf, base, id, 1 + r(clearBuf, base, nid))
					else
						w16(clearBuf, base, id, 0)
					end
				end
			end
		end
	end

	-- Diagonal clear
	local function diagClear(dir, ixStart, ixEnd, ixStep, iyStart, iyEnd, iyStep)
		local base = offB[dir]
		local dx, dy = Dirs.dx[dir], Dirs.dy[dir]
		local st = dx + dy * stride
		for iy = iyStart, iyEnd, iyStep do
			for ix = ixStart, ixEnd, ixStep do
				local id = (iy - 1) * stride + ix
				if blocked[id] then
					w16(clearBuf, base, id, 0)
				else
					if canDiagFrom(id, dx, dy) then
						local nid = id + st
						w16(clearBuf, base, id, 1 + r(clearBuf, base, nid))
					else
						w16(clearBuf, base, id, 0)
					end
				end
			end
		end
	end

	diagClear(Dirs.NE, w + 1, 2, -1, 2, h + 1, 1)
	diagClear(Dirs.NW, 2, w + 1, 1,  2, h + 1, 1)
	diagClear(Dirs.SE, w + 1, 2, -1, h + 1, 2, -1)
	diagClear(Dirs.SW, 2, w + 1, 1,  h + 1, 2, -1)

	local function forcedStraightAt(cId, dir)
		if dir == Dirs.E then
			return (blocked[cId - stride] and canDiagFrom(cId, 1, -1)) or (blocked[cId + stride] and canDiagFrom(cId, 1, 1))
		elseif dir == Dirs.W then
			return (blocked[cId - stride] and canDiagFrom(cId, -1, -1)) or (blocked[cId + stride] and canDiagFrom(cId, -1, 1))
		elseif dir == Dirs.N then
			return (blocked[cId - 1] and canDiagFrom(cId, -1, -1)) or (blocked[cId + 1] and canDiagFrom(cId, 1, -1))
		end
		-- S
		return (blocked[cId - 1] and canDiagFrom(cId, -1, 1)) or (blocked[cId + 1] and canDiagFrom(cId, 1, 1))
	end

	local function straightJump(dir, ixStart, ixEnd, ixStep, iyStart, iyEnd, iyStep)
		local base = offB[dir]
		local st = step[dir]
		for iy = iyStart, iyEnd, iyStep do
			for ix = ixStart, ixEnd, ixStep do
				local id = (iy - 1) * stride + ix
				if r(clearBuf, base, id) == 0 then
					w16(jumpBuf, base, id, 0)
				else
					local nid = id + st
					if forcedStraightAt(nid, dir) then
						w16(jumpBuf, base, id, 1)
					else
						local nxt = r(jumpBuf, base, nid)
						w16(jumpBuf, base, id, (nxt > 0) and (1 + nxt) or 0)
					end
				end
			end
		end
	end

	straightJump(Dirs.E, w + 1, 2, -1, 2, h + 1, 1)
	straightJump(Dirs.W, 2, w + 1, 1,  2, h + 1, 1)
	straightJump(Dirs.N, 2, w + 1, 1,  2, h + 1, 1)
	straightJump(Dirs.S, 2, w + 1, 1,  h + 1, 2, -1)

	local function forcedDiagAt(cId, dx, dy)
		if blocked[cId - dx] and canDiagFrom(cId, -dx, dy) then
			return true
		end
		if blocked[cId - dy * stride] and canDiagFrom(cId, dx, -dy) then
			return true
		end
		return false
	end

	local function isDiagJumpPoint(cId, dir)
		local dx, dy = Dirs.dx[dir], Dirs.dy[dir]
		if forcedDiagAt(cId, dx, dy) then
			return true
		end
		local a = Dirs.compA[dir]
		local b = Dirs.compB[dir]
		return r(jumpBuf, offB[a], cId) > 0 or r(jumpBuf, offB[b], cId) > 0
	end

	local function diagJump(dir, ixStart, ixEnd, ixStep, iyStart, iyEnd, iyStep)
		local base = offB[dir]
		local st = step[dir]
		for iy = iyStart, iyEnd, iyStep do
			for ix = ixStart, ixEnd, ixStep do
				local id = (iy - 1) * stride + ix
				if r(clearBuf, base, id) == 0 then
					w16(jumpBuf, base, id, 0)
				else
					local nid = id + st
					if isDiagJumpPoint(nid, dir) then
						w16(jumpBuf, base, id, 1)
					else
						local nxt = r(jumpBuf, base, nid)
						w16(jumpBuf, base, id, (nxt > 0) and (1 + nxt) or 0)
					end
				end
			end
		end
	end

	diagJump(Dirs.NE, w + 1, 2, -1, 2, h + 1, 1)
	diagJump(Dirs.NW, 2, w + 1, 1,  2, h + 1, 1)
	diagJump(Dirs.SE, w + 1, 2, -1, h + 1, 2, -1)
	diagJump(Dirs.SW, 2, w + 1, 1,  h + 1, 2, -1)

	return {
		grid = grid,
		DiagonalPolicy = diagPolicy,
		step = step,
		off = off,
		offB = offB, -- byte offsets per dir

		clearBuf = clearBuf,
		jumpBuf = jumpBuf,
	}
end

return Preprocess
