LXSC.EXECUTABLE = {}

function LXSC.EXECUTABLE:log(scxml)
	print(scxml.datamodel:run(self.expr))
end

function LXSC.EXECUTABLE:raise(scxml)
	scxml:fireEvent(self.event,nil,true)
end

function LXSC.EXECUTABLE:send(scxml)
	-- TODO: warn about delay/delayexpr no support
	-- TODO: support type/typeexpr/target/targetexpr 
	local dm = scxml.datamodel
	local name = self.event or dm:run(self.eventexpr)
	local data
	if self.namelist then
		data = {}
		for name in string.gmatch(self.namelist,'[^%s]+') do data[name] = dm:get(name) end
	end
	if self.idlocation and not self.id then dm:set( dm:run(self.idlocation), LXSC.uuid4() ) end
	scxml:fireEvent(name,data,false)
end

function LXSC.SCXML:executeContent(item)
	local handler = LXSC.EXECUTABLE[item.kind] 
	if handler then
		handler(item,self) -- TODO: pcall this and inject error event on failure
	else
		print(string.format("Warning: skipping unhandled executable type %s | %s",item.kind,dump(item)))
	end
end
