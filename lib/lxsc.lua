LXSC = { STATE={}, TRANSITION={}, GENERIC={}, SCXML={} }
for k,t in pairs(LXSC) do t.__meta={__index=t} end
setmetatable(LXSC.SCXML,{__index=LXSC.STATE})
setmetatable(LXSC,{__index=function(kind)
	return function(self,kind)
		local t = {kind=kind,kids={}}
		setmetatable(t,self.GENERIC.__meta)
		return t
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

function LXSC:state(kind)
	local t = {
		kind=kind or 'state',
		id=LXSC.uuid4(),
		atomic=true,
		compound=false,
		parallel=false,
		history=false,
		final=false,
		states={},
		reals={},
		onentrys={},
		onexits={},
		transitions={},
		data={},
		invokes={}
	}
	setmetatable(t,self.STATE.__meta)
	return t
end

function LXSC.STATE:attr(name,value)
	if name=="name" or name=="id" or name=="initial" then
		self[name] = value
	else
		if self[name] then print(string.format("Warning: updating transition %s=%s with %s=%s",name,tostring(self[name]),name,tostring(value))) end
		self[name] = value
	end
end

function LXSC.STATE:addChild(item)
	if item.kind=='transition' then
		item.source = self
		table.insert( self.transitions, item )
	elseif item.kind=='onentry' or item.kind=='onexit' or item.kind=='datamodel' then
		item.state = self
	elseif item.kind=='invoke' then
		item.state = self
		table.insert(self.invokes,item)
	elseif item.kind=='state' or item.kind=='parallel' or item.kind=='final' then
		table.insert(self.states,item)
		table.insert(self.reals,item)
		self.compound = true
		self.atomic   = false
		item.parent   = self
	elseif item.kind=='initial' or item.kind=='history' then
		table.insert(self.states,item)
		item.parent   = self
	end
end

-- *********************************

function LXSC:scxml()
	local t = { kind='scxml', name="(lxsc)", binding="early", datamodel="lua" }
	setmetatable(t,LXSC.SCXML.__meta)
	return t
end

-- *********************************

function LXSC:transition()
	local t = { kind='transition', exec={}, type="external" }
	setmetatable(t,self.TRANSITION.__meta)
	return t
end

function LXSC.TRANSITION:attr(name,value)
	if name=='event' then
		self.events = {}
		for event in string.gmatch(value,'[^%s]+') do
			local tokens = {}
			for token in string.gmatch(event,'[^.*]+') do table.insert(tokens,token) end
			table.insert(self.events,tokens)
		end
	elseif name=='target' then
		self.targets = {}
		for target in string.gmatch(value,'[^%s]+') do table.insert(self.targets,target) end
	elseif name=='code' or name=='type' then
		self[name] = value
	else
		if self[name] then print(string.format("Warning: updating transition %s=%s with %s=%s",name,tostring(self[name]),name,tostring(value))) end
		self[name] = value
	end
end

function LXSC.TRANSITION:addChild(item)
	table.insert(self.exec,item)
end

-- *********************************

function LXSC.GENERIC:addChild(item)
	table.insert(self.kids,item)
end

function LXSC.GENERIC:attr(name,value) end

-- TODO: register attribute handlers for each class and use a common attr() function that uses these.