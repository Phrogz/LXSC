local LXSC = require 'lib/lxsc'

local function triggersDescriptor(self,descriptor)
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

local function triggersTransition(self,t)
	return t:matchesEvent(self)
end

local defaultEventMeta = {__index={origintype='http://www.w3.org/TR/scxml/#SCXMLEventProcessor',type="platform",sendid="",origin="",invokeid="",triggersDescriptor=triggersDescriptor,triggersTransition=triggersTransition}}
LXSC.Event = function(name,data,fields)
	local e = {name=name,data=data,_tokens={}}
	setmetatable(e,defaultEventMeta)
	for k,v in pairs(fields) do e[k] = v end
	for token in string.gmatch(name,'[^.*]+') do table.insert(e._tokens,token) end
	return e
end
