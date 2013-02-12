LXSC.EXECUTABLE = {}
function LXSC.EXECUTABLE:log(datamodel)
	print(datamodel:run(self.expr))
end

function LXSC.SCXML:executeContent(item)
	local handler = LXSC.EXECUTABLE[item.kind] 
	if handler then
		-- TODO: pcall this and inject error event on failure
		handler(item,self.datamodel)
	else
		print(string.format("Warning: skipping unhandled executable type %s | %s",item.kind,dump(item)))
	end
end
