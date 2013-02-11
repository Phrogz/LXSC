LXSC = { SCXML={}, STATE={}, TRANSITION={}, GENERIC={} }
for k,t in pairs(LXSC) do t.__meta={__index=t} end
setmetatable(LXSC.SCXML,{__index=LXSC.STATE})
setmetatable(LXSC,{__index=function(kind)
	return function(self,kind)
		local t = {kind=kind,kids={}}
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

function LXSC:state(kind)
	local t = {
		kind=kind or 'state',
		id=LXSC.uuid4(),
		isAtomic   = true,
		isCompound = false,
		isParallel = kind=='parallel',
		isHistory  = kind=='history',
		isFinal    = kind=='final',
		ancestors={},
		selfAndAncestors={self},
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
		if self[name] then print(string.format("Warning: updating state %s=%s with %s=%s",name,tostring(self[name]),name,tostring(value))) end
		self[name] = value
	end
end

local stateKinds = 
function LXSC.STATE:addChild(item)
	if item.kind=='transition' then
		item.source = self
		table.insert( self.transitions, item )
	elseif item.kind=='onentry' or item.kind=='onexit' or item.kind=='datamodel' then
		item.state = self
	elseif item.kind=='invoke' then
		item.state = self
		table.insert(self.invokes,item)
	elseif LXSC.stateKinds[item.kind] then
		table.insert(self.states,item)
		item.parent = self
		item.ancestors[1] = self
		item.selfAndAncestors[2] = self
		for i,anc in ipairs(self.ancestors) do
			item.ancestors[i+1] = anc
			item.selfAndAncestors[i+2] = anc
		end
		if LXSC.realKinds[item.kind] then
			table.insert(self.states,item)
			self.isCompound = true
			self.isAtomic   = false
		end
	else
		print("Warning: unhandled child of state: "..item.kind )
	end
end

function LXSC.STATE:convertInitials()
	if self.initial then
		local initial = LXSC:state('initial')
		self:addChild(initial)
	end
end

function LXSC.STATE:cacheReference(lookup)
	lookup[self.id] = self
	for _,s in ipairs(self.states) do s:resolveReferences(lookup) end
end

function LXSC.STATE:resolveReferences(lookup)
	lookup[self.id] = self
	for _,s in ipairs(self.states) do s:resolveReferences(lookup) end
end

-- *********************************

function LXSC:scxml()
	local t = { kind='scxml', name="(lxsc)", binding="early", datamodel="lua" }
	setmetatable(t,LXSC.SCXML.__meta)
	return t
end

function LXSC.SCXML:cacheAndResolveReferences()
	self.stateById = {}
	for _,s in ipairs(self.states) do s:cacheReference(self.stateById) end
	self:resolveReferences(self.stateById)
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

function LXSC.TRANSITION:conditionMatched(datamodel)
	return not self.cond or datamodel:run(self.cond)
end

function LXSC.TRANSITION:matchesEvent(event)
	for _,tokens in ipairs(self.events) do
		if #tokens <= #event.tokens then
			local matched = true
			for i,token in ipairs(tokens) do
				if event.tokens[i]~=token then
					matched = false
					break
				end
			end
			if matched then return true end
		end
	end
end

-- *********************************

function LXSC.GENERIC:addChild(item)
	table.insert(self.kids,item)
end

function LXSC.GENERIC:attr(name,value) end

-- TODO: register attribute handlers for each class and use a common attr() function that uses these.