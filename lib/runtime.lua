local LXSC = require 'lib/lxsc';
(function(S)
S.MAX_ITERATIONS = 1000
local OrderedSet,Queue = LXSC.OrderedSet, LXSC.Queue

-- ****************************************************************************

local function documentOrder(a,b) return a._order < b._order end
local function exitOrder(a,b)     return b._order < a._order end
local function isAtomicState(s)   return s.isAtomic          end
local function findLCPA(first,rest) -- least common parallel ancestor
	for _,anc in ipairs(first.ancestors) do
		if anc._kind=='parallel' then
			if rest:every(function(s) return s:descendantOf(anc) end) then
				return anc
			end
		end
	end
end
local function findLCCA(first,rest) -- least common compound ancestor
	for _,anc in ipairs(first.ancestors) do
		if anc.isCompound then
			if rest:every(function(s) return s:descendantOf(anc) end) then
				return anc
			end
		end
	end
end

-- ****************************************************************************

function S:interpret(options)
	-- if not self:validate() then self:failWithError() end
	if not self._stateById then self:expandScxmlSource() end
	self._config:clear()
	self._delayedSend = { extraTime=0 }
	-- self.statesToInvoke = OrderedSet()
	self._data = LXSC.Datamodel(self,options and options.data)
	self._data:_setSystem('_sessionid',LXSC.uuid4())
	self.historyValue   = {}

	self._internalQueue = Queue()
	self._externalQueue = Queue()
	self.running = true
	if self.binding == "early" then self._data:initAll() end
	if self._script then self:executeContent(self._script) end
	self:enterStates(self.initial.transitions)
	self:mainEventLoop()
end

-- ******************************************************************************************************
-- ******************************************************************************************************
-- ******************************************************************************************************

function S:mainEventLoop()
	local anyChange, enabledTransitions, stable, iterations
	while self.running do
		anyChange = false
		stable = false
		iterations = 0
		while self.running and not stable and iterations<self.MAX_ITERATIONS do
			enabledTransitions = self:selectEventlessTransitions()
			if enabledTransitions:isEmpty() then
				if self._internalQueue:isEmpty() then
					stable = true
				else
					local internalEvent = self._internalQueue:dequeue()
					self._data:_setSystem('_event',internalEvent)
					enabledTransitions = self:selectTransitions(internalEvent)
				end
			end
			if not enabledTransitions:isEmpty() then
				anyChange = true
				self:microstep(enabledTransitions)
			end
			iterations = iterations + 1
		end

		if iterations>=S.MAX_ITERATIONS then print(string.format("Warning: stopped unstable system after %d internal iterations",S.MAX_ITERATIONS)) end

		-- for _,state in ipairs(self.statesToInvoke) do for _,inv in ipairs(state._invokes) do self:invoke(inv) end end
		-- self.statesToInvoke:clear()

		if self._internalQueue:isEmpty() then
			local externalEvent = self._externalQueue:dequeue()
			if externalEvent then
				anyChange = true
				if externalEvent.name=='quit.lxsc' then
					self.running = false
				else
					self._data:_setSystem('_event',externalEvent)
					-- for _,state in ipairs(self._config) do
					-- 	for _,inv in ipairs(state._invokes) do
					-- 		if inv.invokeid == externalEvent.invokeid then self:applyFinalize(inv, externalEvent) end
					-- 		if inv.autoforward then self:send(inv.id, externalEvent) end
					-- 	end
					-- end
					enabledTransitions = self:selectTransitions(externalEvent)
					if not enabledTransitions:isEmpty() then
						self:microstep(enabledTransitions)
					end
				end
			end
		end

		if not anyChange then break end
	end

	if not self.running then self:exitInterpreter() end
end

-- ******************************************************************************************************
-- ******************************************************************************************************
-- ******************************************************************************************************

function S:exitInterpreter()
	local statesToExit = self._config:toList():sort(documentOrder)
	for _,s in ipairs(statesToExit) do
		for _,content in ipairs(s._onexits) do
			if not self:executeContent(content) then
				break
			end
		end
		-- for _,inv     in ipairs(s._invokes) do self:cancelInvoke(inv)       end
		-- self._config:delete(s)
		-- if self:isFinalState(s) and s.parent._kind=='scxml' then self:returnDoneEvent(self:donedata(s)) end
	end
end

function S:selectEventlessTransitions()
	local enabledTransitions = OrderedSet()
	local atomicStates = self._config:toList():filter(isAtomicState):sort(documentOrder)
	for _,state in ipairs(atomicStates) do
		self:addEventlessTransition(state,enabledTransitions)
	end
	return self:filterPreempted(enabledTransitions)
end
-- TODO: store sets of evented vs. eventless transitions
function S:addEventlessTransition(state,enabledTransitions)
	for _,s in ipairs(state.selfAndAncestors) do
		for _,t in ipairs(s._eventlessTransitions) do
			if t:conditionMatched(self._data) then
				enabledTransitions:add(t)
				return
			end
		end
	end
end

function S:selectTransitions(event)
	local enabledTransitions = OrderedSet()
	local atomicStates = self._config:toList():filter(isAtomicState):sort(documentOrder)
	for _,state in ipairs(atomicStates) do
		self:addTransitionForEvent(state,event,enabledTransitions)
	end
	return self:filterPreempted(enabledTransitions)
end
-- TODO: store sets of evented vs. eventless transitions
function S:addTransitionForEvent(state,event,enabledTransitions)
	for _,s in ipairs(state.selfAndAncestors) do
		for _,t in ipairs(s._eventedTransitions) do
			if t:matchesEvent(event) and t:conditionMatched(self._data) then
				enabledTransitions:add(t)
				return
			end
		end
	end
end

function S:filterPreempted(enabledTransitions)
	local filteredTransitions = OrderedSet()
	for _,t1 in ipairs(enabledTransitions) do
		local anyPreemption = false
		for _,t2 in ipairs(filteredTransitions) do
			local t2Cat = self:preemptionCategory(t2)
			if t2Cat==3 or (t2Cat==2 and self:preemptionCategory(t1)==3) then
				anyPreemption = true
				break
			end
		end
		if not anyPreemption then filteredTransitions:add(t1) end
	end
	return filteredTransitions
end
function S:preemptionCategory(t)
	if not t.preemptionCategory then
		if not t.targets then
			t.preemptionCategory = 1
		elseif findLCPA( t.type=="internal" and t.source or t.source.parent, t.targets ) then
			t.preemptionCategory = 2
		else
			t.preemptionCategory = 3
		end
	end
	return t.preemptionCategory
end

function S:microstep(enabledTransitions)
	self:exitStates(enabledTransitions)
	for _,t in ipairs(enabledTransitions) do
		if self.onTransition then self.onTransition(t) end
		for _,executable in ipairs(t._exec) do
			if not self:executeContent(executable) then
				break
			end
		end
	end
	self:enterStates(enabledTransitions)
	if self.onEnteredAll then self.onEnteredAll() end
end

function S:exitStates(enabledTransitions)
	local statesToExit = OrderedSet()
	for _,t in ipairs(enabledTransitions) do
		if t.targets then
			local ancestor
			if t.type == "internal" and t.source.isCompound and t.targets:every(function(s) return s:descendantOf(t.source) end) then
				ancestor = t.source
			else
				ancestor = findLCCA(t.source, t.targets)
			end
			for _,s in ipairs(self._config) do
				if s:descendantOf(ancestor) then statesToExit:add(s) end
			end
		end
	end

	-- for _,s in ipairs(statesToExit) do self.statesToInvoke:delete(s) end

	statesToExit = statesToExit:toList():sort(exitOrder)

	for _,s in ipairs(statesToExit) do
		-- TODO: create special history collection for speed
		for _,h in ipairs(s.states) do
			if h._kind=='history' then
				if self.historyValue[h.id] then
					self.historyValue[h.id]:clear()
				else
					self.historyValue[h.id] = OrderedSet()
				end
				for _,s0 in ipairs(self._config) do
					if h.type=='deep' then
						if s0.isAtomic and s0:descendantOf(s) then self.historyValue[h.id]:add(s0) end
					else
						if s0.parent==s then self.historyValue[h.id]:add(s0) end
					end
				end
			end
		end
	end

	for _,s in ipairs(statesToExit) do
		if self.onBeforeExit then self.onBeforeExit(s.id,s._kind,s.isAtomic) end
		for _,content in ipairs(s._onexits) do
			if not self:executeContent(content) then
				break
			end
		end
		-- for _,inv in ipairs(s._invokes)     do self:cancelInvoke(inv) end
		self._config:delete(s)
	end
end

function S:enterStates(enabledTransitions)
	local statesToEnter = OrderedSet()
	local statesForDefaultEntry = OrderedSet()

	local function addStatesToEnter(state)	
		if state._kind=='history' then
			if self.historyValue[state.id] then
				for _,s in ipairs(self.historyValue[state.id]) do
					addStatesToEnter(s)
					for anc in s:ancestorsUntil(state.parent) do
						statesToEnter:add(anc)
					end
				end
			else
				for _,t in ipairs(state.transitions) do
					for _,s in ipairs(t.targets) do addStatesToEnter(s) end
				end
			end
		else
			statesToEnter:add(state)
			if state.isCompound then
				statesForDefaultEntry:add(state)
				for _,s in ipairs(state.initial.transitions[1].targets) do addStatesToEnter(s) end
			elseif state._kind=='parallel' then
				for _,s in ipairs(state.reals) do addStatesToEnter(s) end
			end
		end
	end

	for _,t in ipairs(enabledTransitions) do		
		if t.targets then
			local ancestor
			if t.type=="internal" and t.source.isCompound and t.targets:every(function(s) return s:descendantOf(t.source) end) then
				ancestor = t.source
			else
				ancestor = findLCCA(t.source, t.targets)
			end
			for _,s in ipairs(t.targets) do addStatesToEnter(s) end
			for _,s in ipairs(t.targets) do
				for anc in s:ancestorsUntil(ancestor) do
					statesToEnter:add(anc)
					if anc._kind=='parallel' then
						for _,child in ipairs(anc.reals) do
							local descendsFlag = false
							for _,s in ipairs(statesToEnter) do
								if s:descendantOf(child) then
									descendsFlag = true
									break
								end
							end
							if not descendsFlag then addStatesToEnter(child) end
						end
					end
				end
			end
		end
	end

	statesToEnter = statesToEnter:toList():sort(documentOrder)
	for _,s in ipairs(statesToEnter) do
		if s._kind=='scxml' then
			print("WARNING: tried to add scxml to the configuration!")
		else
			self._config:add(s)
			-- self.statesToInvoke:add(s)
			if self.binding=="late" then self._data:initState(s) end -- The datamodel ensures this happens only once per state
			for _,content in ipairs(s._onentrys) do
				if not self:executeContent(content) then
					break
				end
			end
			if self.onAfterEnter then self.onAfterEnter(s.id,s._kind,s.isAtomic) end
			if statesForDefaultEntry:member(s) then
				for _,t in ipairs(s.initial.transitions) do
					for _,executable in ipairs(t._exec) do
						if not self:executeContent(executable) then
							break
						end
					end
				end
			end
			if s._kind=='final' then
				local parent = s.parent
				if parent._kind=='scxml' then
					self.running = false
				else
					local grandparent = parent.parent
					self:fireEvent( "done.state."..parent.id, self:donedata(s), true )
					if grandparent and grandparent._kind=='parallel' then
						local allAreInFinal = true
						for _,child in ipairs(grandparent.reals) do
							if not self:isInFinalState(child) then
								allAreInFinal = false
								break
							end
						end
						if allAreInFinal then self:fireEvent( "done.state."..grandparent.id ) end
					end
				end
			end
		end
	end

	for _,s in ipairs(self._config) do
		if s._kind=='final' and s.parent._kind=='scxml' then self.running = false end
	end
end

function S:isInFinalState(s)
	if s.isCompound then
		for _,s in ipairs(s.reals) do
			if s._kind=='final' and self._config:member(s) then
				return true
			end
		end
	elseif s._kind=='parallel' then
		for _,s in ipairs(s.reals) do
			if not self:isInFinalState(s) then
				return false
			end
		end
		return true
	end
end

function S:expandScxmlSource()
	self:convertInitials()
	self._stateById = {}
	for _,s in ipairs(self.states) do s:cacheReference(self._stateById) end
	self:resolveReferences(self._stateById)
end


function S:donedata(state)
	local c = state._donedatas[1]
	if c then
		if c._kind=='content' then
			return c.expr and self._data:eval(c.expr) or c._text
		else
			local map = {}
			for _,p in ipairs(state._donedatas) do
				local val = p.location and self._data:get(p.location) or p.expr and self._data:eval(p.expr)
				if val == LXSC.Datamodel.EVALERROR then val=nil end
				map[p.name] = val
			end
			return map
		end
	end
end

function S:fireEvent(name,data,internalFlag)
	-- print("fireEvent(",name,data,internalFlag,")")
	local event = LXSC.Event(name,data,{origintype='http://www.w3.org/TR/scxml/#SCXMLEventProcessor'})
	if self.onEventFired then self.onEventFired(event) end
	self[internalFlag and "_internalQueue" or "_externalQueue"]:enqueue(event)
	return event
end

-- Sensible aliases
S.start   = S.interpret
S.restart = S.interpret

function S:step()
	self:processDelayedSends()
	self:mainEventLoop()
end

end)(LXSC.SCXML)
