local LXSC = require 'lib/lxsc'
local generic = {}
local genericMeta = {__index=generic }

function LXSC:_generic(kind,nsURI)
	return setmetatable({_kind=kind,_kids={},_nsURI=nsURI},genericMeta)
end

function generic:addChild(item)
	table.insert(self._kids,item)
end

function generic:attr(name,value)
	self[name] = value
end

setmetatable(LXSC,{__index=function() return LXSC._generic end})
