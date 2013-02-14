LXSC.Exec = {}

function LXSC.Exec:log(scxml)
	local message = {self.label}
	if self.expr then table.insert(message,scxml:eval(self.expr)) end
	print(table.concat(message,": "))
end

function LXSC.Exec:assign(scxml)
	-- TODO: support child executable content in place of expr
	scxml:set( self.location, scxml:eval(self.expr) )
end

function LXSC.Exec:raise(scxml)
	scxml:fireEvent(self.event,nil,true)
end

function LXSC.Exec:send(scxml)
	-- TODO: warn about delay/delayexpr no support
	-- TODO: support type/typeexpr/target/targetexpr
	local name = self.event or scxml:eval(self.eventexpr)
	local data
	if self.namelist then
		data = {}
		for name in string.gmatch(self.namelist,'[^%s]+') do data[name] = scxml:get(name) end
	end
	if self.idlocation and not self.id then scxml:set( scxml:eval(self.idlocation), LXSC.uuid4() ) end
	scxml:fireEvent(name,data,false)
end

function LXSC.SCXML:executeContent(item)
	local handler = LXSC.Exec[item._kind]
	if handler then
		handler(item,self)
	else
		self:fireEvent('error.execution.unhandled',{message="unhandled executable type "..item._kind},true)
		-- print('error.execution.unhandled',item._kind)
	end
end
