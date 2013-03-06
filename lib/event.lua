local LXSC = require 'lib/lxsc'

local function triggers(self,descriptor)
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

LXSC.Event = function(name,data)
	local e = {name=name,data=data,_tokens={},triggers=triggers}
	for token in string.gmatch(name,'[^.*]+') do table.insert(e._tokens,token) end
	return e
end
