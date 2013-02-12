LXSC = { SCXML={}, STATE={}, TRANSITION={}, GENERIC={} }
for k,t in pairs(LXSC) do t.__meta={__index=t} end
setmetatable(LXSC.SCXML,{__index=LXSC.STATE})
setmetatable(LXSC,{__index=function(kind)
	return function(self,kind)
		local t = {kind=kind,_kids={}}
		setmetatable(t,self.GENERIC.__meta)
		return t
	end
end})

LXSC.stateKinds = {state=1,parallel=1,final=1,history=1,initial=1}
LXSC.realKinds  = {state=1,parallel=1,final=1}

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

function LXSC.GENERIC:addChild(item)
	table.insert(self._kids,item)
end

function LXSC.GENERIC:attr(name,value)
	self[name] = value
end

-- *********************************

function LXSC:datamodel()
	local t = {	kind='datamodel' }
	function t:addChild(item) table.insert(self.state.data,item) end
	return t
end

function LXSC:onentry()
	local t = {	kind='onentry' }
	function t:addChild(item) table.insert(self.state.onentrys,item) end
	return t
end

function LXSC:onexit()
	local t = {	kind='onexit' }
	function t:addChild(item) table.insert(self.state.onexits,item) end
	return t
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