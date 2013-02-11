(function(S)
S.MAX_ITERATIONS = 1000

local documentOrder = function(a,b) return a._order < b._order end
local isAtomicState = function(s)   return s.isAtomic          end
local LCPA          = function(first,rest) -- least common parallel ancestor
	for _,anc in ipairs(first.ancestors) do
		if anc.isParallel then
			local allDescend = true
			for _,s in ipairs(rest) do
				if not s:descendantOf(anc) then
					allDescend = false
					break
				end
			end
			if allDescend then
				return anc
			end
		end
	end
end

function S:interpret()
	if not self:validate() then self:failWithError() end
	self:expandScxmlSource()
	self.configuration  = OrderedSet()
	-- self.statesToInvoke = OrderedSet()
	self.datamodel      = Datamodel()

	self:executeGlobalScriptElements()
	self.internalQueue = Queue()
	self.externalQueue = Queue()
	self.running = true
	if self.binding == "early" then
		self:initializeDatamodel()
	end
	self:executeTransitionContent(self.initial.transitions)
	self:enterStates(self.initial.transitions)
	self:mainEventLoop()
end

function S:mainEventLoop()
	local anyChange, enabledTransitions, stable, iterations
	while self.running do
		anyChange = false
		stable = false
		iterations = 0
		while self.running and not stable and iterations<self.MAX_ITERATIONS do
			enabledTransitions = self:selectEventlessTransitions()
			if enabledTransitions:isEmpty() then
				if internalQueue:isEmpty() then
					stable = true
				else
					local internalEvent = internalQueue:dequeue()
					self.datamodel:set("_event",internalEvent)
					enabledTransitions = self:selectTransitions(internalEvent)
				end
			end
			if not enabledTransitions:isEmpty() then
				anyChange = true
				self:microstep(enabledTransitions:toList()) -- TODO: (optimization) can remove toList() call
			end
			iterations = iterations + 1
		end

		if iterations>=S.MAX_ITERATIONS then print(string.format("Warning: stopped unstable system after %d internal iterations",S.MAX_ITERATIONS)) end

		-- for _,state in ipairs(self.statesToInvoke) do
		-- 	for _,inv in ipairs(state.invokes) do
		-- 		self:invoke(inv)
		-- 	end
		-- end
		-- self.statesToInvoke:clear()

		if self.internalQueue:isEmpty() then
			local externalEvent = externalQueue:dequeue()
			if externalEvent then
				if externalEvent:isCancelEvent() then
					self.running = false
				else
					datamodel:set("_event",externalEvent)
					-- for _,state in ipairs(self.configuration) do
					-- 	for _,inv in ipairs(state.invokes) do
					-- 		if inv.invokeid == externalEvent.invokeid then
					-- 			self:applyFinalize(inv, externalEvent)
					-- 		end
					-- 		if inv.autoforward then
					-- 			self:send(inv.id, externalEvent)
					-- 		end
					-- 	end
					-- end
					enabledTransitions = self:selectTransitions(externalEvent)
					if not enabledTransitions:isEmpty() then
						anyChange = true
						self:microstep(enabledTransitions:toList()) -- TODO: (optimization) can remove toList() call
					end
				end
			end
		end

		if not anyChange then break end
	end

	if not self.running then self:exitInterpreter() end
end

function S:exitInterpreter()
	local statesToExit = self.configuration:toList():sort(documentOrder)
	for _,s in ipairs(statesToExit) do
		for _,content in ipairs(s.onexits) do self:executeContent(content) end
		-- for _,inv     in ipairs(s.invokes) do self:cancelInvoke(inv)       end
		-- self.configuration:delete(s)
		-- if self:isFinalState(s) and s.parent.kind=='scxml' then   
		-- 	self:returnDoneEvent(s:donedata())
		-- end
	end
end

function S:selectEventlessTransitions()
	local enabledTransitions = OrderedSet()
	local atomicStates = self.configuration:toList():filter(isAtomicState):sort(documentOrder)
	for _,state in ipairs(atomicStates) do
		self:addEventlessTransition(state,enabledTransitions)
	end
	return self:filterPreempted(enabledTransitions)
end
-- TODO: store sets of evented vs. eventless transitions
function S:addEventlessTransition(state,enabledTransitions)
	for _,s in ipairs(state.selfAndAncestors) do
		for _,t in ipairs(s.transitions) do
			if not t.events and t:conditionMatched(self.datamodel) then
				enabledTransitions:add(t)
				return
			end
		end
	end
end

function S:selectTransitions(event)
	local enabledTransitions = OrderedSet()
	local atomicStates = self.configuration:toList():filter(isAtomicState):sort(documentOrder)
	for _,state in ipairs(atomicStates) do
		self:addTransitionForEvent(state,event,enabledTransitions)
	end
	return self:filterPreempted(enabledTransitions)
end
-- TODO: store sets of evented vs. eventless transitions
function S:addTransitionForEvent(state,event,enabledTransitions)
	for _,s in ipairs(state.selfAndAncestors) do
		for _,t in ipairs(s.transitions) do
			if t.events and t:matchesEvent(event) and t:conditionMatched(self.datamodel) then
				enabledTransitions:add(t)
				return
			end
		end
	end
end

function S:filterPreempted(enabledTransitions)
	local filteredTransitions = OrderedSet()
	for _,t1 in ipairs(enabledTransitions) do
		if not filteredTransitions:some(function(t2)
			local t2Cat = self:preemptionCategory(t2)
			return t2Cat==3 or (t2Cat==2 and self:preemptionCategory(t1)==3)
		end) then
			filteredTransitions:add(t)
		end
	end
	return filteredTransitions
end
function S:preemptionCategory(t)
	if not t.preemptionCategory then
		if not t.targets then
			t.preemptionCategory = 1
		elseif LCPA( t.type=="internal" and t.parent or t.parent.parent, t.targets ) then
			t.preemptionCategory = 2
		else
			t.preemptionCategory = 3
		end
	end
	return t.preemptionCategory
end

function S:microstep(enabledTransitions)
	self:exitStates(enabledTransitions)
	self:executeTransitionContent(enabledTransitions)
	self:enterStates(enabledTransitions)
end

function S:executeTransitionContent(transitions)
	for _,t in ipairs(transitions) do
		for _,executable in ipairs(t.exec) do
			if executable.run then
				executable:run()
			else
				print("Warning: unsupported executable "..executable.kind)
			end
		end
	end
end

function S:exitStates(enabledTransitions)
	local statesToExit = OrderedSet()
	for _,t in ipairs(enabledTransitions) do
		if t.targets then
			tstates = getTargetStates(t.target)
			if t.type == "internal" and isCompoundState(t.source) and tstates.every(lambda s: isDescendant(s,t.source))::
				ancestor = t.source
			else:
				ancestor = findLCCA([t.source].append(getTargetStates(t.target)))
			for s in configuration:
				if isDescendant(s,ancestor):
					statesToExit.add(s)
		end
	end
	for s in statesToExit:
		statesToInvoke.delete(s)
	statesToExit = statesToExit.toList().sort(exitOrder)
	for s in statesToExit:
		for h in s.history:
			if h.type == "deep":
				f = lambda s0: isAtomicState(s0) and isDescendant(s0,s)
			else:
				f = lambda s0: s0.parent == s
			historyValue[h.id] = configuration.toList().filter(f)
	for s in statesToExit:
		for content in s.onexit:
			executeContent(content)
		for inv in s.invoke:
			cancelInvoke(inv)
		configuration.delete(s)


-- Sensible aliases
S.start = S.interpret
S.step  = S.mainEventLoop	

end)(LXSC.SCXML)
