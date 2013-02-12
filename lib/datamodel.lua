LXSC.Datamodel = {}
LXSC.Datamodel.__meta = {__index=LXSC.Datamodel}
setmetatable(LXSC.Datamodel,{__call=function(o)
	local dm = { data={}, statesInited={} }
	setmetatable(dm,o.__meta)
	return dm
end})

function LXSC.Datamodel:initAll(scxml)
	local function recurse(state)
		self:initState(state)
		for _,s in ipairs(state.reals) do recurse(s) end
	end
	recurse(scxml)
end

function LXSC.Datamodel:initState(state)
	if not self.statesInited[state] then
		for _,datum in ipairs(state.data) do
			-- TODO: support data.src
			self:set( datum.id, self:run(datum.expr or tostring(datum._text)) )
		end
		self.statesInited[state] = true
	end
end

function LXSC.Datamodel:run(expression)
	local f = assert(loadstring('return '..expression))
	setfenv(f,self.data)
	return f()
end

function LXSC.Datamodel:set(id,value)
	self.data[id] = value
end