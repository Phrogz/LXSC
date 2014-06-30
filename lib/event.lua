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
		return "<event>"..LXSC.serializeLua( self, {sort=self.__sorter, nokey={_tokens=1}} )
	else
		return string.format("<event '%s' type=%s>",self.name,self.type)
	end
end

function LXSC.Event.__sorter(a,b)
	local keyorder = {name='_____________',type='___',data='~~~~~~~~~~~~'}
	a = keyorder[a[1]] or a[1]
	b = keyorder[b[1]] or b[1]
	return a<b
end