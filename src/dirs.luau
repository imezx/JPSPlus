--!optimize 2
local Dirs = {}

@native
local function bit(d) return bit32.lshift(1, d-1) end

Dirs.E = 1
Dirs.W = 2
Dirs.N = 3
Dirs.S = 4
Dirs.NE = 5
Dirs.NW = 6
Dirs.SE = 7
Dirs.SW = 8

Dirs.dx = { [1]= 1, [2]=-1, [3]= 0, [4]= 0, [5]= 1, [6]=-1, [7]= 1, [8]=-1 }
Dirs.dy = { [1]= 0, [2]= 0, [3]=-1, [4]= 1, [5]=-1, [6]=-1, [7]= 1, [8]= 1 }
Dirs.isDiag = { [1]=false,[2]=false,[3]=false,[4]=false,[5]=true,[6]=true,[7]=true,[8]=true }

Dirs.compA = { [5]=Dirs.E, [6]=Dirs.W, [7]=Dirs.E, [8]=Dirs.W }
Dirs.compB = { [5]=Dirs.N, [6]=Dirs.N, [7]=Dirs.S, [8]=Dirs.S }

Dirs.NAT_MASK = {
	[0]= bit(1)+bit(2)+bit(3)+bit(4)+bit(5)+bit(6)+bit(7)+bit(8),
	[Dirs.E] = bit(Dirs.E) + bit(Dirs.NE) + bit(Dirs.SE),
	[Dirs.W] = bit(Dirs.W) + bit(Dirs.NW) + bit(Dirs.SW),
	[Dirs.N] = bit(Dirs.N) + bit(Dirs.NE) + bit(Dirs.NW),
	[Dirs.S] = bit(Dirs.S) + bit(Dirs.SE) + bit(Dirs.SW),
	[Dirs.NE] = bit(Dirs.NE) + bit(Dirs.E) + bit(Dirs.N),
	[Dirs.NW] = bit(Dirs.NW) + bit(Dirs.W) + bit(Dirs.N),
	[Dirs.SE] = bit(Dirs.SE) + bit(Dirs.E) + bit(Dirs.S),
	[Dirs.SW] = bit(Dirs.SW) + bit(Dirs.W) + bit(Dirs.S),
}

-- d1 = (-dx, dy), d2 = (dx, -dy)
Dirs.diagForced1 = {
	[Dirs.NE] = Dirs.NW,
	[Dirs.NW] = Dirs.NE,
	[Dirs.SE] = Dirs.SW,
	[Dirs.SW] = Dirs.SE,
}
Dirs.diagForced2 = {
	[Dirs.NE] = Dirs.SE,
	[Dirs.NW] = Dirs.SW,
	[Dirs.SE] = Dirs.NE,
	[Dirs.SW] = Dirs.NW,
}

return Dirs
