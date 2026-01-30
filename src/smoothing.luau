--!native
--!optimize 2
local Smoothing = {}

local function hasLOS(blocked, stride, x0, y0, x1, y1)
	local dx = x1 - x0
	local dy = y1 - y0
	local adx = math.abs(dx)
	local ady = math.abs(dy)
	local sx = (dx > 0 and 1) or (dx < 0 and -1) or 0
	local sy = (dy > 0 and 1) or (dy < 0 and -1) or 0
	
	local ix, iy = x0 + 1, y0 + 1
	local id = (iy - 1) * stride + ix
	
	local stepX = sx
	local stepY = sy * stride
	
	local err = adx - ady

	local targetIx = x1 + 1
	local targetIy = y1 + 1
	
	while true do
		if blocked[id] then
			return false
		end
		if ix == targetIx and iy == targetIy then 
			return true 
		end
		
		local e2 = err + err
		local moveX = e2 > -ady
		local moveY = e2 < adx
		
		if moveX and moveY then
			if blocked[id + stepX] and blocked[id + stepY] then
				return false
			end
		end
		
		if moveX then 
			err -= ady
			ix += sx
			id += stepX
		end
		if moveY then 
			err += adx
			iy += sy
			id += stepY
		end
	end
end

function Smoothing.simplify(grid, path)
	if not path or #path <= 2 then return path end
	
	local blocked = grid.Blocked
	local stride = grid.Stride
	local n = #path
	
	local out = { path[1] }
	local outN = 1
	local i = 1
	
	while i < n do
		-- binary search could be faster for long paths, but greedy from end is usually good tho
		local best = i + 1
		local pi = path[i]
		local pix, piy = pi.x, pi.y
		
		for j = n, i + 2, -1 do
			local pj = path[j]
			if hasLOS(blocked, stride, pix, piy, pj.x, pj.y) then
				best = j
				break
			end
		end
		
		outN += 1
		out[outN] = path[best]
		i = best
	end
	
	return out
end

return Smoothing
