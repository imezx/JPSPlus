--!optimize 2
local Grid = {}
Grid.__index = Grid

Grid.DiagonalPolicy = {
	Always = "Always", -- diagonal allowed if destination is free
	NoSqueeze = "NoSqueeze", -- (default) diagonal allowed if dest free AND (at least one orthogonal adjacent is free)
	NoCorner = "NoCorner", -- diagonal allowed if dest free AND (both orthogonal adjacents are free)
}

function Grid.new(width, height, isBlockedFn)
	assert(width > 0 and height > 0)
	local stride = width + 2
	local totalW = width + 2
	local totalH = height + 2
	local total = totalW * totalH

	local blocked = table.create(total, true)
	-- fill interior
	for y = 1, height do
		local iy = y + 1
		for x = 1, width do
			local ix = x + 1
			local id = (iy - 1) * stride + ix
			if isBlockedFn then
				blocked[id] = isBlockedFn(x, y) and true or false
			else
				blocked[id] = false
			end
		end
	end

	return setmetatable({
		Width = width,
		Height = height,
		Stride = stride,
		Total = total,
		Blocked = blocked, -- includes padded border
	}, Grid)
end

function Grid:id(x, y)
	-- external (1..W,1..H) -> internal id
	local ix = x + 1
	local iy = y + 1
	return (iy - 1) * self.Stride + ix
end

function Grid:xy(id)
	-- internal id -> external (x,y)
	local stride = self.Stride
	local iy = ((id - 1) // stride) + 1
	local ix = (id - 1) - (iy - 1) * stride + 1
	return ix - 1, iy - 1
end

function Grid:isWalkableId(id)
	return not self.Blocked[id]
end

function Grid:setBlocked(x, y, value)
	local id = self:id(x, y)
	self.Blocked[id] = value and true or false
end

return Grid
