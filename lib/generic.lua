-- Horribly simple xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
function LXSC.uuid4()
	return table.concat({
		string.format('%04x', math.random(0, 0xffff))..string.format('%04x',math.random(0, 0xffff)),
		string.format('%04x', math.random(0, 0xffff)),
		string.format('4%03x',math.random(0, 0xfff)),
		string.format('a%03x',math.random(0, 0xfff)),
		string.format('%06x', math.random(0, 0xffffff))..string.format('%06x',math.random(0, 0xffffff))
	},'-')
end

-- *********************************

LXSC.scxmlNS = "http://www.w3.org/2005/07/scxml"

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

-- *********************************
