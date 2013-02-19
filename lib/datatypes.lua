local LXSC = require 'lib/lxsc'
LXSC.OrderedSet = {}; LXSC.OrderedSet.__meta = {__index=LXSC.OrderedSet}

setmetatable(LXSC.OrderedSet,{__call=function(o)
	return setmetatable({},o.__meta)
end})

function LXSC.OrderedSet:add(e)
	if not self[e] then
		local idx = #self+1
		self[idx] = e
		self[e] = idx
	end
end

function LXSC.OrderedSet:delete(e)
	local index = self[e]
	if index then
		table.remove(self,index)
		self[e] = nil
		for i,o in ipairs(self) do self[o]=i end -- Store new indexes
	end
end

function LXSC.OrderedSet:member(e)
	return self[e]
end

function LXSC.OrderedSet:isEmpty()
	return not self[1]
end

function LXSC.OrderedSet:clear()
	for k,v in pairs(self) do self[k]=nil end
end

function LXSC.OrderedSet:toList()
	return LXSC.List(unpack(self))
end

-- *******************************************************************

LXSC.List = {}; LXSC.List.__meta = {__index=LXSC.List}
setmetatable(LXSC.List,{__call=function(o,...)
	local l = {...}
	setmetatable(l,o.__meta)
	return l
end})

function LXSC.List:head()
	return self[1]
end

function LXSC.List:tail()
	local l = LXSC.List(unpack(self))
	table.remove(l,1)
	return l
end

function LXSC.List:append(...)
	local len=#self
	for i,v in ipairs{...} do self[len+i] = v end
	return self
end

function LXSC.List:filter(f)
	local t={}
	local i=1
	for _,v in ipairs(self) do
		if f(v) then
			t[i]=v; i=i+1
		end
	end
	return LXSC.List(unpack(t))
end

function LXSC.List:some(f)
	for _,v in ipairs(self) do
		if f(v) then return true end
	end
end

function LXSC.List:every(f)
	for _,v in ipairs(self) do
		if not f(v) then return false end
	end
	return true
end

function LXSC.List:sort(f)
	table.sort(self,f)
	return self
end

-- *******************************************************************

LXSC.Queue = {}; LXSC.Queue.__meta = {__index=LXSC.Queue}
setmetatable(LXSC.Queue,{__call=function(o)
	local q = {}
	setmetatable(q,o.__meta)
	return q
end})

function LXSC.Queue:enqueue(e)
	self[#self+1] = e
end

function LXSC.Queue:dequeue()
	return table.remove(self,1)
end

function LXSC.Queue:isEmpty()
	return not self[1]
end