local LXSC = require 'lib/lxsc'
LXSC.OrderedSet = {_kind='OrderedSet'}; LXSC.OrderedSet.__meta = {__index=LXSC.OrderedSet}

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

function LXSC.OrderedSet:union(set2)
	local i=#self
	for _,e in ipairs(set2) do
		if not self[e] then
			i = i+1
			self[i] = e
			self[e] = i
		end
	end
end

function LXSC.OrderedSet:isMember(e)
	return self[e]
end

function LXSC.OrderedSet:some(f)
	for _,o in ipairs(self) do
		if f(o) then return true end
	end
end

function LXSC.OrderedSet:every(f)
	for _,v in ipairs(self) do
		if not f(v) then return false end
	end
	return true
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

function LXSC.OrderedSet:hasIntersection(set2)
	if #self<#set2 then
		for _,e in ipairs(self) do if set2[e] then return true end end
	else
		for _,e in ipairs(set2) do if self[e] then return true end end
	end
	return false
end

function LXSC.OrderedSet:inspect()
	local t = {}
	for i,v in ipairs(self) do t[i] = v.inspect and v:inspect() or tostring(v) end
	return t[1] and "{ "..table.concat(t,', ').." }" or '{}'
end

-- *******************************************************************

LXSC.List = {_kind='List'}; LXSC.List.__meta = {__index=LXSC.List}
setmetatable(LXSC.List,{__call=function(o,...)
	return setmetatable({...},o.__meta)
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

LXSC.List.some    = LXSC.OrderedSet.some
LXSC.List.every   = LXSC.OrderedSet.every
LXSC.List.inspect = LXSC.OrderedSet.inspect

function LXSC.List:sort(f)
	table.sort(self,f)
	return self
end


-- *******************************************************************

LXSC.Queue = {_kind='Queue'}; LXSC.Queue.__meta = {__index=LXSC.Queue}
setmetatable(LXSC.Queue,{__call=function(o)
	return setmetatable({},o.__meta)
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

LXSC.Queue.inspect = LXSC.OrderedSet.inspect
