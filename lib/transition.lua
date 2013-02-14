function LXSC:transition()
	local t = { _kind='transition', _exec={}, type="external" }
	setmetatable(t,self.Transition.__meta)
	return t
end

function LXSC.Transition:attr(name,value)
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
		self._target = value
		for target in string.gmatch(value,'[^%s]+') do self:addTarget(target) end

	elseif name=='cond' or name=='type' then
		self[name] = value

	else
		if self[name] then print(string.format("Warning: updating transition %s=%s with %s=%s",name,tostring(self[name]),name,tostring(value))) end
		self[name] = value

	end
end

function LXSC.Transition:addChild(item)
	table.insert(self._exec,item)
end

function LXSC.Transition:addTarget(stateOrId)
	if not self.targets then self.targets = List() end
	table.insert(self.targets,stateOrId)
end

function LXSC.Transition:conditionMatched(datamodel)
	return not self.cond or datamodel:eval(self.cond)
end

function LXSC.Transition:matchesEvent(event)
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

function LXSC.Transition:inspect()
	return string.format(
		"<transition in '%s'%s%s%s>",
		self.source.id or self.source.name,
		self._event and (" on '"..self._event.."'") or "",
		self.cond and (" if '"..self.cond.."'") or "",
		self._target and (" to '"..self._target.."'") or ""
	)
end
