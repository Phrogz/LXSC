LXSC.Datamodel = {}
LXSC.Datamodel.__meta = {__index=LXSC.Datamodel}
setmetatable(LXSC.Datamodel,{__call=function(o,scxml)
	local dm = setmetatable({ statesInited={}, scxml=scxml },o.__meta)
	dm:clear()
	return dm
end})

function LXSC.Datamodel:clear()
	self.data = { In=function(id) return self.scxml:isActive(id) end }
end

function LXSC.Datamodel:initAll()
	local function recurse(state)
		self:initState(state)
		for _,s in ipairs(state.reals) do recurse(s) end
	end
	recurse(self.scxml)
end

function LXSC.Datamodel:initState(state)
	if not self.statesInited[state] then
		for _,data in ipairs(state._datamodels) do
			-- TODO: support data.src
			self:set( data.id, self:run(data.expr or tostring(data._text)) )
		end
		self.statesInited[state] = true
	end
end

function LXSC.Datamodel:run(expression)
	-- TODO: cache string->function
	local f,message = loadstring('return '..expression)
	if not f then
		self.scxml:fireEvent("error.execution.syntax",{message=message},true)
		-- print("error.execution.syntax",message)
	else
		setfenv(f,self.data)
		local ok,result = pcall(f)
		if not ok then
			self.scxml:fireEvent("error.execution.evaluation",{message=result},true)
			-- print("error.execution.evaluation",result)
		else
			return result
		end
	end
end

function LXSC.Datamodel:set(id,value)
	self.data[id] = value
end

function LXSC.Datamodel:get(id)
	return self.data[id]
end