setmetatable(LXSC.SCXML,{__index=LXSC.State})

function LXSC:scxml()
	local t = LXSC:state('scxml')
	t.name      = "(lxsc)"
	t.binding   = "early"
	t.datamodel = "lua"
	t.id        = nil

	t.running   = false
	t._config   = OrderedSet()

	return setmetatable(t,LXSC.SCXML.__meta)
end

-- Fetch a single named value from the data model
function LXSC.SCXML:get(location)
	return self._data:get(location)
end

-- Set a single named value in the data model
function LXSC.SCXML:set(location,value)
	self._data:set(location,value)
end

-- Evaluate a single Lua expression and return the value
function LXSC.SCXML:eval(expression)
	return self._data:eval(expression)
end

-- Run arbitrary script code (multiple lines) with no return value
function LXSC.SCXML:run(code)
	self._data:run(code)
end

function LXSC.SCXML:isActive(stateId)
	return self._config[self._stateById[stateId]]
end

function LXSC.SCXML:activeStateIds()
	local a = OrderedSet()
	for _,s in ipairs(self._config) do a:add(s.id) end
	return a
end

function LXSC.SCXML:activeAtomicIds()
	local a = OrderedSet()
	for _,s in ipairs(self._config) do
		if s.isAtomic then a:add(s.id) end
	end
	return a
end

function LXSC.SCXML:allEvents()
	local all = {}
	local function crawl(state)
		for _,s in ipairs(state.states) do
			for _,t in ipairs(s._eventedTransitions) do
				for _,e in ipairs(t.events) do
					all[e.name] = true
				end
			end
			crawl(s)
		end
	end
	crawl(self)
	return all
end

function LXSC.SCXML:availableEvents()
	local all = {}
	for _,s in ipairs(self._config) do
		for _,t in ipairs(s._eventedTransitions) do
			for _,e in ipairs(t.events) do
				all[e.name] = true
			end
		end
	end
	return all
end

function LXSC.SCXML:addChild(item)
	if item._kind=='script' then
		self._script = item
	else
		LXSC.State.addChild(self,item)
	end
end