local LXSC = require 'lib/lxsc'
LXSC.State={}; LXSC.State.__meta = {__index=LXSC.State}

setmetatable(LXSC.State,{__index=function(s,k) error("Attempt to access "..tostring(k).." on state") end})

LXSC.State.stateKinds = {state=1,parallel=1,final=1,history=1,initial=1}
LXSC.State.realKinds  = {state=1,parallel=1,final=1}
LXSC.State.aggregates = {datamodel=1,donedata=1}
LXSC.State.executes   = {onentry='_onentrys',onexit='_onexits'}

function LXSC:state(kind)
	local t = {
		_kind       = kind or 'state',
		id          = kind.."-"..self.uuid4(),
		isAtomic    = true,
		isCompound  = false,
		isParallel  = kind=='parallel',
		isHistory   = kind=='history',
		isFinal     = kind=='final',
		ancestors   = {},

		states      = {},
		reals       = LXSC.List(), -- <state>, <parallel>, and <final> children only
		transitions = LXSC.List(),
		_eventlessTransitions = {},
		_eventedTransitions   = {},

		_onentrys   = {},
		_onexits    = {},
		_datamodels = {},
		_donedatas  = {},
		_invokes    = {}
	}
	if kind=='history' then t.type='shallow' end -- default value
	t.selfAndAncestors={t}
	return setmetatable(t,self.State.__meta)
end

function LXSC.State:attr(name,value)
	if name=="name" or name=="id" or name=="initial" then
		self[name] = value
	else
		-- if self[name] and self[name]~=value then print(string.format("Warning: updating state %s=%s with %s=%s",name,tostring(self[name]),name,tostring(value))) end
		self[name] = value
	end
end

function LXSC.State:addChild(item)
	if item._kind=='transition' then
		item.source = self
		table.insert( self.transitions, item )

	elseif self.aggregates[item._kind] then
		item.state = self

	elseif self.executes[item._kind] then
		item.state = self
		table.insert( self[self.executes[item._kind]], item )

	elseif self.stateKinds[item._kind] then
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
		if self.realKinds[item._kind] then
			table.insert(self.reals,item)
			self.isCompound = self._kind~='parallel'
			self.isAtomic   = false
		end

	elseif item._kind=='invoke' then
		item.state = self
		table.insert(self._invokes,item)

	else
		-- print("Warning: unhandled child of state: "..item._kind )
	end
end

function LXSC.State:ancestorsUntil(stopNode)
	local i=0
	return function()
		i=i+1
		if self.ancestors[i] ~= stopNode then
			return self.ancestors[i]
		end
	end
end

function LXSC.State:createInitialTo(stateOrId)
	local initial = LXSC:state('initial')
	self:addChild(initial)
	local transition = LXSC:transition()
	initial:addChild(transition)
	transition:addTarget(stateOrId)
	transition._target = type(stateOrId)=='string' and stateOrId or stateOrId.id
	self.initial = initial
end

function LXSC.State:convertInitials()
	local init = rawget(self,'initial')
	if type(init)=='string' then
		-- Convert initial="..." attribute to <initial> state
		self:createInitialTo(self.initial)
	elseif not init then
		local initialElement
		for _,s in ipairs(self.states) do
			if s._kind=='initial' then initialElement=s; break end
		end

		if initialElement then
			self.initial = initialElement
		elseif self.states[1] then
			self:createInitialTo(self.states[1])
		end
	end
	for _,s in ipairs(self.reals) do s:convertInitials() end
end

function LXSC.State:cacheReference(lookup)
	lookup[self.id] = self
	for _,s in ipairs(self.states) do s:cacheReference(lookup) end
end

function LXSC.State:resolveReferences(lookup)
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

function LXSC.State:descendantOf(possibleAncestor)
	return self.ancestors[possibleAncestor]
end

function LXSC.State:inspect()
	return string.format("<%s id=%s>",tostring(rawget(self,'_kind')),tostring(rawget(self,'id')))
end

-- ********************************************************

-- These elements pass their children through to the appropriate collection on the state
for kind,collection in pairs{ datamodel='_datamodels', donedata='_donedatas' } do
	LXSC[kind] = function()
		local t = {_kind=kind}
		function t:addChild(item)
			table.insert(self.state[collection],item)
		end
		return t
	end
end