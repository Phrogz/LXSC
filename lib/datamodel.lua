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
			local value, err
			if data.src then
				local colon = data.src:find(':')
				local scheme,hierarchy = data.src:sub(1,colon-1), data.src:sub(colon+1)
				if scheme=='file' then
					local f,msg = io.open(hierarchy,"r")
					if not f then
						self.scxml:fireEvent("error.execution.invalid-file",msg)
					else
						value = self:eval(f:read("*all"))
						f:close()
					end
				else
					self.scxml:fireEvent("error.execution.invalid-data-scheme","LXSC does not support <data src='"..scheme..":...'>")
				end
			else
				value = self:eval(data.expr or tostring(data._text))
			end

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
			self.scxml:fireEvent("error.execution.syntax",message)
			return LXSC.Datamodel.EVALERROR
		end
	end
	if func then
		local ok,result = pcall(func)
		if not ok then
			self.scxml:fireEvent("error.execution.evaluation",result)
			return LXSC.Datamodel.EVALERROR
		else
			return result
		end
	end
end

-- Reserved for internal use; should not be used by user scripts
function LXSC.Datamodel:_setSystem(location,value)
	self.scope[location] = value
	if rawget(self.scxml,'onDataSet') then self.scxml.onDataSet(location,value) end
end

function LXSC.Datamodel:set(location,value)
	-- TODO: support foo.bar location dereferencing
	if location~=nil then
		if type(location)=='string' and string.sub(location,1,1)=='_' then
			self.scxml:fireEvent("error.execution.invalid-set","Cannot set system variables")
		else
			self.scope[location] = value
			if rawget(self.scxml,'onDataSet') then self.scxml.onDataSet(location,value) end
			return true
		end
	else
		self.scxml:fireEvent("error.execution.invalid-set","Location must not be nil")
	end
end

function LXSC.Datamodel:get(id)
	if id==nil or id=='' then
		return LXSC.Datamodel.INVALIDLOCATION
	else
		return self.scope[id]
	end
end

function LXSC.Datamodel:serialize(pretty)
	if pretty then
		return LXSC.serializeLua(self.scope,{sort=self.__sorter,indent='  '})
	else
		return LXSC.serializeLua(self.scope)
	end
end

function LXSC.Datamodel.__sorter(a,b)
	local ak,av,bk,bv     = a[1],a[2],b[1],b[2]
	local tak,tav,tbk,tbv = type(a[1]),type(a[2]),type(b[1]),type(b[2])
	a,b = ak,bk
	if tav=='function' then a='~~~'..ak end
	if tak=='function' then a='~~~~' end
	if tbv=='function' then b='~~~'..bk end
	if tbk=='function' then b='~~~~' end
	if tak=='string' and ak:find('_')==1 then a='~~'..ak end
	if tbk=='string' and bk:find('_')==1 then b='~~'..bk end
	if type(a)==type(b) then return a<b end
end

 -- unique identifiers for comparision
LXSC.Datamodel.EVALERROR = {}
LXSC.Datamodel.INVALIDLOCATION = {}