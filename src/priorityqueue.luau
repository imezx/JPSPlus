--!native
--!optimize 2
local PQ = {}
PQ.__index = PQ

function PQ.new(capacity)
	capacity = capacity or 256
	return setmetatable({
		n = 0,
		id = table.create(capacity),
		f  = table.create(capacity),
		g  = table.create(capacity),
	}, PQ)
end

function PQ:push(nodeId, fScore, gScore)
	local n = self.n + 1
	self.n = n

	local id, f, g = self.id, self.f, self.g
	id[n] = nodeId
	f[n] = fScore
	g[n] = gScore

	local i = n
	while i > 1 do
		local p = i // 2
		local pf, cf = f[p], f[i]
		if pf <= cf then break end

		id[p], id[i] = id[i], id[p]
		f[p], f[i] = cf, pf
		g[p], g[i] = g[i], g[p]
		i = p
	end
end

function PQ:pop()
	local n = self.n
	if n == 0 then return nil end

	local id, f, g = self.id, self.f, self.g
	local topId = id[1]
	local topG = g[1]

	if n == 1 then
		self.n = 0
		return topId, topG
	end

	id[1] = id[n]
	f[1] = f[n]
	g[1] = g[n]
	n -= 1
	self.n = n

	local i = 1
	while true do
		local l = i + i -- i * 2
		if l > n then break end

		local r = l + 1
		local s = l
		local sf = f[l]

		if r <= n then
			local rf = f[r]
			if rf < sf then
				s = r
				sf = rf
			end
		end

		local cf = f[i]
		if cf <= sf then break end

		id[i], id[s] = id[s], id[i]
		f[i], f[s] = sf, cf
		g[i], g[s] = g[s], g[i]
		i = s
	end

	return topId, topG
end

function PQ:peek()
	if self.n == 0 then return nil end
	return self.id[1], self.f[1], self.g[1]
end

function PQ:isEmpty()
	return self.n == 0
end

return PQ
