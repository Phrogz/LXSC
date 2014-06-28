local LXSC = require 'lib/lxsc';
(function(S)
S.MAX_ITERATIONS = 1000
local OrderedSet,Queue,List = LXSC.OrderedSet, LXSC.Queue, LXSC.List

-- ****************************************************************************

local function entryOrder(a,b)    return a._order < b._order end
local function exitOrder(a,b)     return b._order < a._order end
local function isDescendant(a,b)  return a:descendantOf(b)   end
local function isCancelEvent(e)   return e.name=='quit.lxsc' end
local function isFinalState(s)    return s._kind=='final'    end
local function isScxmlState(s)    return s._kind=='scxml'    end
local function isHistoryState(s)  return s._kind=='history'  end
local function isParallelState(s) return s._kind=='parallel' end
local function isCompoundState(s) return s.isCompound        end
local function isAtomicState(s)   return s.isAtomic		       end
local function getChildStates(s)  return s.reals             end
local function findLCCA(first,rest) -- least common compound ancestor
	for _,anc in ipairs(first.ancestors) do
		if isCompoundState(anc) or isScxmlState(anc) then
			if rest:every(function(s) return isDescendant(s,anc) end) then
				return anc
			end
		end
	end
end

local emptyList = List()

local depth=0
local function logloglog(s)
	-- print(string.rep('   ',depth)..tostring(s))
end
local function startfunc(s) logloglog(s) depth=depth+1 end
local function closefunc(s) if s then logloglog(s) end depth=depth-1 end

-- ****************************************************************************

function S:interpret(options)
	self._delayedSend = { extraTime=0 }

	-- if not self:validate() then self:failWithError() end
	if not rawget(self,'_stateById') then self:expandScxmlSource() end
	self._configuration:clear()
	self._statesToInvoke = OrderedSet() -- TODO: implement <invoke>
	self._internalQueue  = Queue()
	self._externalQueue  = Queue()
	self._historyValue   = {}

	self._data = LXSC.Datamodel(self,options and options.data)
	self._data:_setSystem('_sessionid',LXSC.uuid4())
	self._data:_setSystem('_name',self.name or LXSC.uuid4())
	self._data:_setSystem('_ioprocessors',{})
	if self.binding == "early" then self._data:initAll() end
	self.running = true
	self:executeGlobalScriptElement()
	self:enterStates(self.initial.transitions)
	self:mainEventLoop()
end

-- ******************************************************************************************************
-- ******************************************************************************************************
-- ******************************************************************************************************

function S:mainEventLoop()
	local anyTransition, enabledTransitions, macrostepDone, iterations
	while self.running do
		anyTransition = false -- (LXSC specific)
		iterations    = 0     -- (LXSC specific)
		macrostepDone = false

		-- Here we handle eventless transitions and transitions
		-- triggered by internal events until macrostep is complete
		while self.running and not macrostepDone and iterations<S.MAX_ITERATIONS do
			enabledTransitions = self:selectEventlessTransitions()
			if enabledTransitions:isEmpty() then
				if self._internalQueue:isEmpty() then
					macrostepDone = true
				else
					logloglog("-- Internal Queue: "..self._internalQueue:inspect())
					local internalEvent = self._internalQueue:dequeue()
					self._data:_setSystem('_event',internalEvent)
					enabledTransitions = self:selectTransitions(internalEvent)
				end
			end
			if not enabledTransitions:isEmpty() then
				anyTransition = true
				self:microstep(enabledTransitions)
			end
			iterations = iterations + 1
		end

		if iterations>=S.MAX_ITERATIONS then print(string.format("Warning: stopped unstable system after %d internal iterations",S.MAX_ITERATIONS)) end

		-- Either we're in a final state, and we break out of the loop…
		if not self.running then break end
		-- …or we've completed a macrostep, so we start a new macrostep by waiting for an external event

		-- Here we invoke whatever needs to be invoked. The implementation of 'invoke' is platform-specific
		for _,state in ipairs(self._statesToInvoke) do for _,inv in ipairs(state._invokes) do self:invoke(inv) end end
		self._statesToInvoke:clear()

		-- Invoking may have raised internal error events; if so, we skip and iterate to handle them
		if self._internalQueue:isEmpty() then
			logloglog("-- External Queue: "..self._externalQueue:inspect())
			local externalEvent = self._externalQueue:dequeue()
			if externalEvent then -- (LXSC specific) The queue might be empty.
				if isCancelEvent(externalEvent) then
					self.running = false
				else
					self._data:_setSystem('_event',externalEvent)
						for _,state in ipairs(self._configuration) do
							for _,inv in ipairs(state._invokes) do
								if inv.invokeid == externalEvent.invokeid then self:applyFinalize(inv, externalEvent) end
								if inv.autoforward then self:send(inv.id, externalEvent) end
							end
						end
						enabledTransitions = self:selectTransitions(externalEvent)
						if not enabledTransitions:isEmpty() then
							anyTransition = true
							self:microstep(enabledTransitions)
						end
					end
				end

			-- (LXSC specific) we stop iterating as soon as no transitions occur
			if not anyTransition then break end
		end
	end

	-- We re-check if we're running here because we use step-based processing;
	-- we may have exited the 'running' loop if there were no more events to process.
	if not self.running then self:exitInterpreter() end
end

-- ******************************************************************************************************
-- ******************************************************************************************************
-- ******************************************************************************************************

function S:executeGlobalScriptElement()
	if rawget(self,'_script') then self:executeSingle(self._script) end
end

function S:exitInterpreter()
	local statesToExit = self._configuration:toList():sort(exitOrder)
	for _,s in ipairs(statesToExit) do
		for _,content in ipairs(s._onexits) do self:executeContent(content) end
		for _,inv	    in ipairs(s._invokes) do self:cancelInvoke(inv)       end

		-- (LXSC specific) We do not delete the configuration on exit so that it may be examined later.
		-- self._configuration:delete(s)

		if isFinalState(s) and isScxmlState(s.parent) then
			self:returnDoneEvent(self:donedata(s))
		end
	end
end

function S:selectEventlessTransitions()
	startfunc('selectEventlessTransitions()')
	local enabledTransitions = OrderedSet()
	local atomicStates = self._configuration:toList():filter(isAtomicState):sort(entryOrder)
	for _,state in ipairs(atomicStates) do
		self:addEventlessTransition(state,enabledTransitions)
	end
	enabledTransitions = self:removeConflictingTransitions(enabledTransitions)
	closefunc('-- selectEventlessTransitions result: '..enabledTransitions:inspect())
	return enabledTransitions
end
-- (LXSC specific) we use this function since Lua cannot break out of a nested loop
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
	startfunc('selectTransitions( '..event:inspect()..' )')
	local enabledTransitions = OrderedSet()
	local atomicStates = self._configuration:toList():filter(isAtomicState):sort(entryOrder)
	for _,state in ipairs(atomicStates) do
		self:addTransitionForEvent(state,event,enabledTransitions)
	end
	enabledTransitions = self:removeConflictingTransitions(enabledTransitions)
	closefunc('-- selectTransitions result: '..enabledTransitions:inspect())
	return enabledTransitions
end
-- (LXSC specific) we use this function since Lua cannot break out of a nested loop
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

function S:removeConflictingTransitions(enabledTransitions)
	startfunc('removeConflictingTransitions( enabledTransitions:'..enabledTransitions:inspect()..' )')
	local filteredTransitions = OrderedSet()
	for _,t1 in ipairs(enabledTransitions) do
		local t1Preempted = false
		local transitionsToRemove = OrderedSet()
		for _,t2 in ipairs(filteredTransitions) do
			if self:computeExitSet(List(t1)):hasIntersection(self:computeExitSet(List(t2))) then
				if isDescendant(t1.source,t2.source) then
					transitionsToRemove:add(t2)
				else
					t1Preempted = true
					break
				end
			end
		end

		if not t1Preempted then
			for _,t3 in ipairs(transitionsToRemove) do
				filteredTransitions:delete(t3)
			end
			filteredTransitions:add(t1)
		end
	end

	closefunc('-- removeConflictingTransitions result: '..filteredTransitions:inspect())
	return filteredTransitions
end

function S:microstep(enabledTransitions)
	startfunc('microstep( enabledTransitions:'..enabledTransitions:inspect()..' )')

	self:exitStates(enabledTransitions)
	self:executeTransitionContent(enabledTransitions)
	self:enterStates(enabledTransitions)

	if rawget(self,'onEnteredAll') then self.onEnteredAll() end

	closefunc()
end

function S:exitStates(enabledTransitions)
	startfunc('exitStates( enabledTransitions:'..enabledTransitions:inspect()..' )')

	local statesToExit = self:computeExitSet(enabledTransitions)
	for _,s in ipairs(statesToExit) do self._statesToInvoke:delete(s) end
	statesToExit = statesToExit:toList():sort(exitOrder)

	-- Record history for states being exited
	for _,s in ipairs(statesToExit) do
		for _,h in ipairs(s.states) do
			if h._kind=='history' then
				self._historyValue[h.id] = self._configuration:toList():filter(function(s0)
					if h.type=='deep' then
						return isAtomicState(s0) and isDescendant(s0,s)
					else
						return s0.parent==s
					end
				end)
			end
		end
	end

	-- Exit the states
	for _,s in ipairs(statesToExit) do
		if self.onBeforeExit then self.onBeforeExit(s.id,s._kind,s.isAtomic) end
		for _,content in ipairs(s._onexits) do
			self:executeContent(content)
		end
		for _,inv in ipairs(s._invokes) do self:cancelInvoke(inv) end
		self._configuration:delete(s)
		logloglog(string.format("-- removed %s from the configuration; config is now {%s}",s:inspect(),table.concat(self:activeStateIds(),', ')))
	end

	closefunc()
end

function S:computeExitSet(transitions)
	startfunc('computeExitSet( transitions:'..transitions:inspect()..' )')
	local statesToExit = OrderedSet()
	for _,t in ipairs(transitions) do
		if t.targets then
			local domain = self:getTransitionDomain(t)
			for _,s in ipairs(self._configuration) do
				if isDescendant(s,domain) then
					statesToExit:add(s)
				end
			end
		end
	end
	closefunc('-- computeExitSet result '..statesToExit:inspect())
	return statesToExit   	
end

function S:executeTransitionContent(enabledTransitions)
	startfunc('executeTransitionContent( enabledTransitions:'..enabledTransitions:inspect()..' )')
	for _,t in ipairs(enabledTransitions) do
		if self.onTransition then self.onTransition(t) end
		for _,executable in ipairs(t._exec) do
			if not self:executeSingle(executable) then break end
		end
	end
	closefunc()
end

function S:enterStates(enabledTransitions)
	startfunc('enterStates( enabledTransitions:'..enabledTransitions:inspect()..' )')

	local statesToEnter         = OrderedSet()
	local statesForDefaultEntry = OrderedSet()
  local defaultHistoryContent = {}           -- temporary table for default content in history states
	self:computeEntrySet(enabledTransitions,statesToEnter,statesForDefaultEntry,defaultHistoryContent)

	for _,s in ipairs(statesToEnter:toList():sort(entryOrder)) do
		self._configuration:add(s)
		logloglog(string.format("-- added %s '%s' to the configuration; config is now <%s>",s._kind,s.id,table.concat(self:activeStateIds(),', ')))
		if isScxmlState(s) then error("Added SCXML to configuration.") end
		self._statesToInvoke:add(s)

		if self.binding=="late" then
			-- The LXSC datamodel ensures this happens only once per state
			self._data:initState(s)
		end 

		for _,content in ipairs(s._onentrys) do
			self:executeContent(content)
		end
		if self.onAfterEnter then self.onAfterEnter(s.id,s._kind,s.isAtomic) end

		if statesForDefaultEntry:isMember(s) then
			for _,t in ipairs(s.initial.transitions) do
				for _,executable in ipairs(t._exec) do
					if not self:executeSingle(executable) then break end
				end
			end
		end

		if defaultHistoryContent[s.id] then
			for _,executable in ipairs(defaultHistoryContent[s.id]) do
				if not self:executeSingle(executable) then break end
			end
		end

		if isFinalState(s) then
			local parent = s.parent
			if isScxmlState(parent) then
				self.running = false
			else
				local grandparent = parent.parent
				self:fireEvent( "done.state."..parent.id, self:donedata(s), {type='internal'} )
				if isParallelState(grandparent) then					
					local allAreInFinal = true
					for _,child in ipairs(grandparent.reals) do
						if not self:isInFinalState(child) then
							allAreInFinal = false
							break
						end
					end
					if allAreInFinal then
						self:fireEvent( "done.state."..grandparent.id, nil, {type='internal'} )
					end
				end
			end
		end

	end

	closefunc()
end

function S:computeEntrySet(transitions,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
	startfunc('computeEntrySet( transitions:'..transitions:inspect()..', ... )')

	for _,t in ipairs(transitions) do
		if t.targets then
			for _,s in ipairs(t.targets) do
				self:addDescendantStatesToEnter(s,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
			end
		end
		-- logloglog('-- after adding descendants statesToEnter is: '..statesToEnter:inspect())

		local ancestor = self:getTransitionDomain(t)
		for _,s in ipairs(self:getEffectiveTargetStates(t)) do
			self:addAncestorStatesToEnter(s,ancestor,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
		end
	end
	logloglog('-- computeEntrySet result statesToEnter: '..statesToEnter:inspect())
	logloglog('-- computeEntrySet result statesForDefaultEntry: '..statesForDefaultEntry:inspect())
	closefunc()
end

function S:addDescendantStatesToEnter(state,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
	startfunc("addDescendantStatesToEnter( state:"..state:inspect()..", ... )")
	if isHistoryState(state) then

		if self._historyValue[state.id] then
			for _,s in ipairs(self._historyValue[state.id]) do
				self:addDescendantStatesToEnter(s,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
				self:addAncestorStatesToEnter(s,state.parent,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
			end
		else
			defaultHistoryContent[state.parent.id] = state.transitions[1]._exec
			for _,t in ipairs(state.transitions) do
				if t.targets then
					for _,s in ipairs(t.targets) do
						self:addDescendantStatesToEnter(s,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
						self:addAncestorStatesToEnter(s,state.parent,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
					end
				end
			end
		end

	else

		statesToEnter:add(state)
		logloglog("statesToEnter:add( "..state:inspect().." )")

		if isCompoundState(state) then
			statesForDefaultEntry:add(state)
			for _,t in ipairs(state.initial.transitions) do
				for _,s in ipairs(self:getEffectiveTargetStates(t)) do
					self:addDescendantStatesToEnter(s,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
					self:addAncestorStatesToEnter(s,state,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
				end
			end
		elseif isParallelState(state) then
			for _,child in ipairs(getChildStates(state)) do
				if not statesToEnter:some(function(s) return isDescendant(s,child) end) then
					self:addDescendantStatesToEnter(child,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
				end
			end
		end

	end

	closefunc()
end

function S:addAncestorStatesToEnter(state,ancestor,statesToEnter,statesForDefaultEntry,defaultHistoryContent)
	startfunc("addAncestorStatesToEnter( state:"..state:inspect()..", ancestor:"..ancestor:inspect()..", ... )")
	
	for anc in state:ancestorsUntil(ancestor) do
		statesToEnter:add(anc)
		logloglog("statesToEnter:add( "..anc:inspect().." )")
		if isParallelState(anc) then
			for _,child in ipairs(getChildStates(anc)) do
				if not statesToEnter:some(function(s) return isDescendant(s,child) end) then
					self:addDescendantStatesToEnter(child,statesToEnter,statesForDefaultEntry,defaultHistoryContent) 
				end
			end
		end
	end

	closefunc()
end

function S:isInFinalState(s)
	if isCompoundState(s) then
		return getChildStates(s):some(function(s) return isFinalState(s) and self._configuration:isMember(s)	end)
	elseif isParallelState(s) then
		return getChildStates(s):every(function(s) self:isInFinalState(s) end)
	else
		return false
	end
end

function S:getTransitionDomain(t)
	startfunc('getTransitionDomain( t:'..t:inspect()..' )' )
	local result
	local tstates = self:getEffectiveTargetStates(t)
	if not tstates then
		result = nil
	elseif t.type=='internal' and isCompoundState(t.source) and tstates:every(function(s) return isDescendant(s,t.source) end) then
		result = t.source
	else
		result = findLCCA(t.source,t.targets or emptyList)
	end
	closefunc('-- getTransitionDomain result: '..tostring(result and result.id))
	return result
end

function S:getEffectiveTargetStates(transition)
	startfunc('getEffectiveTargetStates( transition:'..transition:inspect()..' )')
	local targets = OrderedSet()
	if transition.targets then
		for _,s in ipairs(transition.targets) do
			if isHistoryState(s) then
				if self._historyValue[s.id] then
					targets:union(self._historyValue[s.id])
				else
					-- History states can only have one transition, so we hard-code that here.
					targets:union(self:getEffectiveTargetStates(s.transitions[1]))
				end
			else
				targets:add(s)
			end
		end
	end
	closefunc('-- getEffectiveTargetStates result: '..targets:inspect())
	return targets
end

function S:expandScxmlSource()
	self:convertInitials()
	self._stateById = {}
	for _,s in ipairs(self.states) do s:cacheReference(self._stateById) end
	self:resolveReferences(self._stateById)
end

function S:returnDoneEvent(donedata)
	-- TODO: implement
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
				if val == LXSC.Datamodel.INVALIDLOCATION then
					self:fireEvent("error.execution.invalid-param-value","There was an error determining the value for a <param> inside a <donedata>")
				elseif val ~= LXSC.Datamodel.EVALERROR then
					if p.name==nil or p.name=="" then
						self:fireEvent("error.execution.invalid-param-name","Unsupported <param> name '"..tostring(p.name).."'")
					else
						map[p.name] = val
					end
				end
			end
			return next(map) and map
		end
	end
end

function S:fireEvent(name,data,eventValues)
	eventValues = eventValues or {}
	eventValues.type = eventValues.type or 'platform'
	local event = LXSC.Event(name,data,eventValues)
	logloglog(string.format("-- queued %s event '%s'",event.type,event.name))
	if rawget(self,'onEventFired') then self.onEventFired(event) end
	self[eventValues.type=='external' and "_externalQueue" or "_internalQueue"]:enqueue(event)
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
