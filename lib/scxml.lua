function LXSC:scxml()
	local t = LXSC:state('scxml')
	t.name      = "(lxsc)"
	t.binding   = "early"
	t.datamodel = "lua"
	t.id        = nil

	t.running   = false
	t._data     = LXSC.Datamodel(t)
	t._config   = OrderedSet()

	setmetatable(t,LXSC.SCXML.__meta)
	return t
end

function LXSC.SCXML:get(key)
	return self._data:get(key)
end

function LXSC.SCXML:set(key,value)
	self._data:set(key,value)
end

function LXSC.SCXML:clear()
	self._data:clear()
end

function LXSC.SCXML:expandScxmlSource()
	self:convertInitials()
	self._stateById = {}
	for _,s in ipairs(self.states) do s:cacheReference(self._stateById) end
	self:resolveReferences(self._stateById)
end

function LXSC.SCXML:isActive(stateId)
	return self._config[self._stateById[stateId]]
end

function LXSC.SCXML:activeStateIds()
	local a = OrderedSet()
	for _,s in ipairs(self._config) do
		a:add(s.id)
	end
	return a
end

function LXSC.SCXML:activeAtomicIds()
	local a = OrderedSet()
	for _,s in ipairs(self._config) do
		if s.isAtomic then a:add(s.id) end
	end
	return a
end