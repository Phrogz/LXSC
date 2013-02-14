LXSC = { SCXML={}, State={}, Transition={}, Generic={} }
for k,t in pairs(LXSC) do t.__meta={__index=t} end

LXSC.VERSION = "0.2"

setmetatable(LXSC,{__index=function(kind)
	return function(self,kind)
		return setmetatable({_kind=kind,_kids={}},self.Generic.__meta)
	end
end})

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

function LXSC.Generic:addChild(item)
	table.insert(self._kids,item)
end

function LXSC.Generic:attr(name,value)
	self[name] = value
end

-- *********************************

-- These elements pass their children through to the appropriate collection on the state
for kind,collection in pairs{ datamodel='_datamodels', donedata='_donedatas', onentry='_onentrys', onexit='_onexits' } do
	LXSC[kind] = function()
		local t = {_kind=kind}
		function t:addChild(item) table.insert(self.state[collection],item) end
		return t
	end
end

-- *********************************

function dump(o,seen)
	if not seen then seen = {} end
	if not seen[o] and type(o) == 'table' then
		seen[o] = true
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..tostring(k)..'"' end
			s = s .. '['..k..'] = ' .. dump(v,seen) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

-- TODO: register attribute handlers for each class and use a common attr() function that uses these.