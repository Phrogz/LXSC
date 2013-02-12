function LXSC:state(kind)
	local t = {
		kind=kind or 'state',
		id=LXSC.uuid4(),
		isAtomic   = true,
		isCompound = false,
		isParallel = kind=='parallel',
		isHistory  = kind=='history',
		isFinal    = kind=='final',
		ancestors  = {},

		states     = {},
		reals      = {},

		onentrys   = {},
		onexits    = {},

		transitions= {},

		data={},
		invokes={}
	}
	t.selfAndAncestors={t}
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
		item.ancestors[self] = true
		item.selfAndAncestors[2] = self
		for i,anc in ipairs(self.ancestors) do
			item.ancestors[i+1]        = anc
			item.ancestors[anc]        = true
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

function LXSC.STATE:ancestorsUntil(stopNode)
	local i=0
	return function()
		i=i+1
		if self.ancestors[i] ~= stopNode then
			return self.ancestors[i]
		end
	end
end

function LXSC.STATE:convertInitials()
	if type(self.initial)=='string' then
		local initial = LXSC:state('initial')
		self:addChild(initial)
		local transition = LXSC:transition()
		initial:addChild(transition)
		transition.targets = List( self.initial )
		self.initial = initial
		for _,s in ipairs(self.reals) do s:convertInitials() end
	end
end

function LXSC.STATE:cacheReference(lookup)
	lookup[self.id] = self
	for _,s in ipairs(self.states) do s:cacheReference(lookup) end
end

function LXSC.STATE:resolveReferences(lookup)
	for _,t in ipairs(self.transitions) do
		if t.targets then
			for i,target in ipairs(t.targets) do
				if type(target)=="string" then
					if lookup[target] then
						t.targets[i] = lookup[target]
					else
						error(string.format("Cannot find start with id '%s' for target",tostring(target)))
					end
				end
			end
		end
	end
	for _,s in ipairs(self.states) do s:resolveReferences(lookup) end
end

function LXSC.STATE:descendantOf(possibleAncestor)
	return self.ancestors[possibleAncestor]
end
