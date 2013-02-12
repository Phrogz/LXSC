function LXSC:scxml()
	local t = LXSC:state('scxml')
	t.name      = "(lxsc)"
	t.binding   = "early"
	t.datamodel = "lua"
	t.id        = nil

	t.running   = false
	t.configuration = OrderedSet()

	setmetatable(t,LXSC.SCXML.__meta)
	return t
end

function LXSC.SCXML:expandScxmlSource()
	self:convertInitials()
	self.stateById = {}
	for _,s in ipairs(self.states) do s:cacheReference(self.stateById) end
	self:resolveReferences(self.stateById)
end

function LXSC.SCXML:isActive(stateId)
	return self.configuration[self.stateById[stateId]]
end

function LXSC.SCXML:activeStateIds()
	local a = OrderedSet()
	for _,s in ipairs(self.configuration) do
		a:add(s.id)
	end
	return a
end

function LXSC.SCXML:activeAtomicIds()
	local a = OrderedSet()
	for _,s in ipairs(self.configuration) do
		if s.isAtomic then a:add(s.id) end
	end
	return a
end