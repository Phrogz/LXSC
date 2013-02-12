OrderedSet = {}
OrderedSet.__meta = {__index=OrderedSet}
setmetatable(OrderedSet,{__call=function(o)
	local s = {}
	setmetatable(s,o.__meta)
	return s
end})

function OrderedSet:add(e)
	if not self[e] then
		local idx = #self+1
		self[idx] = e
		self[e] = idx
	end
end

function OrderedSet:delete(e)
	local index = self[e]
	if index then
		table.remove(self,index)
		self[e] = nil
		for i,o in ipairs(self) do self[o]=i end -- Store new indexes
	end
end

function OrderedSet:member(e)
	return self[e]
end

function OrderedSet:isEmpty()
	return not self[1]
end

function OrderedSet:clear()
	for k,v in pairs(self) do self[k]=nil end
end

function OrderedSet:toList()
	return List(unpack(self))
end

-- *******************************************************************

List = {}
List.__meta = {__index=List}
setmetatable(List,{__call=function(o,...)
	local l = {...}
	setmetatable(l,o.__meta)
	return l
end})

function List:head()
	return self[1]
end

function List:tail()
	local l = List(unpack(self))
	table.remove(l,1)
	return l
end

function List:append(...)
	local len=#self
	for i,v in ipairs{...} do self[len+i] = v end
	return self
end

function List:filter(f)
	local t={}
	local i=1
	for _,v in ipairs(self) do
		if f(v) then
			t[i]=v; i=i+1
		end
	end
	return List(unpack(t))
end

function List:some(f)
	for _,v in ipairs(self) do
		if f(v) then return true end
	end
end

function List:every(f)
	for _,v in ipairs(self) do
		if not f(v) then return false end
	end
	return true
end

function List:sort(f)
	table.sort(self,f)
	return self
end

-- *******************************************************************

Queue = {}
Queue.__meta = {__index=Queue}
setmetatable(Queue,{__call=function(o)
	local q = {}
	setmetatable(q,o.__meta)
	return q
end})

function Queue:enqueue(e)
	self[#self+1] = e
end

function Queue:dequeue()
	return table.remove(self,1)
end

function Queue:isEmpty()
	return not self[1]
end