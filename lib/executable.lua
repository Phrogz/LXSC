LXSC.EXECUTABLE = {}

function LXSC.EXECUTABLE:log(scxml)
	print(scxml.datamodel:run(self.expr))
end

function LXSC.EXECUTABLE:raise(scxml)
	scxml:fireEvent(self.event,nil,true)
end

function LXSC.SCXML:executeContent(item)
	local handler = LXSC.EXECUTABLE[item.kind] 
	if handler then
		handler(item,self) -- TODO: pcall this and inject error event on failure
	else
		print(string.format("Warning: skipping unhandled executable type %s | %s",item.kind,dump(item)))
	end
end
