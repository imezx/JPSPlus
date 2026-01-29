--!native
--!optimize 2
local PQ = {}
PQ.__index = PQ

function PQ.new(capacity)
	return setmetatable({
		n = 0,
		id = table.create(capacity or 0),
		f  = table.create(capacity or 0),
		g  = table.create(capacity or 0),
	}, PQ)
end

local function swap(self, a, b)
	self.id[a], self.id[b] = self.id[b], self.id[a]
	self.f[a],  self.f[b]  = self.f[b],  self.f[a]
	self.g[a],  self.g[b]  = self.g[b],  self.g[a]
end

function PQ:push(nodeId, fScore, gScore)
	local n = self.n + 1
	self.n = n
	self.id[n] = nodeId
	self.f[n] = fScore
	self.g[n] = gScore

	local i = n
	while i > 1 do
		local p = i // 2
		if self.f[p] <= self.f[i] then break end
		swap(self, p, i)
		i = p
	end
end

function PQ:pop()
	local n = self.n
	if n == 0 then return nil end

	local topId = self.id[1]
	local topG  = self.g[1]

	if n == 1 then
		self.n = 0
		return topId, topG
	end

	self.id[1] = self.id[n]
	self.f[1]  = self.f[n]
	self.g[1]  = self.g[n]
	self.n = n - 1

	local i = 1
	while true do
		local l = i * 2
		if l > self.n then break end
		local r = l + 1
		local s = l
		if r <= self.n and self.f[r] < self.f[l] then
			s = r
		end
		if self.f[i] <= self.f[s] then break end
		swap(self, i, s)
		i = s
	end

	return topId, topG
end

return PQ
