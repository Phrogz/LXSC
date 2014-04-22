local LXSC = require 'lib/lxsc'
LXSC.Datamodel = {}; LXSC.Datamodel.__meta = {__index=LXSC.Datamodel}

setmetatable(LXSC.Datamodel,{__call=function(dm,scxml,scope)
	if not scope then scope = {} end
	function scope.In(id) return scxml:isActive(id) end
	return setmetatable({ statesInited={}, scxml=scxml, scope=scope, cache={} },dm.__meta)
end})

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
			local value = self:eval(data.expr or tostring(data._text))
			if value~=LXSC.Datamodel.EVALERROR then 
				self:set( data.id, value )
			else
				self:set( data.id, nil )
			end
		end
		self.statesInited[state] = true
	end
end

function LXSC.Datamodel:eval(expression)
	return self:run('return '..expression)
end

function LXSC.Datamodel:run(code)
	local func,message = self.cache[code]
	if not func then
		func,message = loadstring(code)
		if func then
			self.cache[code] = func
			setfenv(func,self.scope)
		else
			self.scxml:fireEvent("error.execution.syntax",message,true)
			return LXSC.Datamodel.EVALERROR
		end
	end
	if func then
		local ok,result = pcall(func)
		if not ok then
			self.scxml:fireEvent("error.execution.evaluation",result,true)
			return LXSC.Datamodel.EVALERROR
		else
			return result
		end
	end
end

-- Reserved for internal use; should not be used by user scripts
function LXSC.Datamodel:_setSystem(location,value)
	self.scope[location] = value
end

function LXSC.Datamodel:set(location,value)
	-- TODO: support foo.bar location dereferencing
	if location~=nil then
		if type(location)=='string' and string.sub(location,1,1)=='_' then
			self.scxml:fireEvent("error.execution.invalid-set","Cannot set system variables",true)
		else
			self.scope[location] = value
			if self.scxml.onDataSet then self.scxml.onDataSet(location,value) end
		end
	else
		self.scxml:fireEvent("error.execution.invalid-set","Location must not be nil",true)
	end
end

function LXSC.Datamodel:get(id)
	return self.scope[id]
end

LXSC.Datamodel.EVALERROR = {} -- a unique identifier for comparision