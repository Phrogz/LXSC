(function(S)
S.MAX_ITERATIONS = 1000

local documentOrder = function(a,b) return a._order < b._order end

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
	local statesToExit = self.configuration:toList()
	table.sort( statesToExit, documentOrder )
	for _,s in ipairs(statesToExit) do
		for _,content in ipairs(s.onexits) do self:executeContent(content) end
		-- for _,inv     in ipairs(s.invokes) do self:cancelInvoke(inv)       end
		-- self.configuration:delete(s)
		if self:isFinalState(s) and isScxmlState(s.parent):   
					returnDoneEvent(s.donedata)
	end
end

-- Sensible aliases
S.start = S.interpret
S.step  = S.mainEventLoop	

end)(LXSC.SCXML)
