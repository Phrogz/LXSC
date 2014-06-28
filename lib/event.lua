local LXSC = require 'lib/lxsc'
LXSC.Event={
	origintype="http://www.w3.org/TR/scxml/#SCXMLEventProcessor",
	type      ="platform",
	sendid    ="",
	origin    ="",
	invokeid  ="",	
}
local EventMeta; EventMeta = { __index=LXSC.Event, __tostring=function(e) return e:inspect() end }
setmetatable(LXSC.Event,{__call=function(_,name,data,fields)
	local e = {name=name,data=data,_tokens={}}
	setmetatable(e,EventMeta)
	for k,v in pairs(fields) do e[k] = v end
	for token in string.gmatch(name,'[^.*]+') do table.insert(e._tokens,token) end
	return e
end})



function LXSC.Event:triggersDescriptor(descriptor)
	if self.name==descriptor or descriptor=="*" then
		return true
	else
		local i=1
		for token in string.gmatch(descriptor,'[^.*]+') do
			if self._tokens[i]~=token then return false end
			i=i+1
		end
		return true
	end
	return false
end

function LXSC.Event:triggersTransition(t) return t:matchesEvent(self) end

function LXSC.Event:inspect(detailed)
	if detailed then
		return string.format(
			"<event '%s' type=%s sendid=%s origin=%s origintype=%s invokeid=%s data=%s>",
			self.name,
			tostring(self.type),
			tostring(self.sendid),
			tostring(self.origin),
			tostring(self.origintype),
			tostring(self.invokeid),
			tostring(self.data)
		)
	else
		return string.format("<event '%s' type=%s>",self.name,self.type)
	end
end