function LXSC:transition()
	local t = { kind='transition', exec={}, type="external" }
	setmetatable(t,self.TRANSITION.__meta)
	return t
end

function LXSC.TRANSITION:attr(name,value)
	if name=='event' then
		self.events = {}
		self._event = value
		for event in string.gmatch(value,'[^%s]+') do
			local tokens = {}
			for token in string.gmatch(event,'[^.*]+') do table.insert(tokens,token) end
			table.insert(self.events,tokens)
		end

	elseif name=='target' then
		self.targets = nil
		for target in string.gmatch(value,'[^%s]+') do self:addTarget(target) end

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

function LXSC.TRANSITION:addTarget(stateOrId)
	if not self.targets then self.targets = List() end
	table.insert(self.targets,stateOrId)
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
			if matched then
				-- print("Transition",self._event,"matched",event.name)
				return true
			end
		end
	end
	-- print("Transition",self._event,"does not match",event.name)
end

