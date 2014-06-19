local LXSC = require 'lib/lxsc'
LXSC.Transition={}; LXSC.Transition.__meta = {__index=LXSC.Transition}

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
			tokens.name = table.concat(tokens,'.')
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
	if not self.targets then self.targets = LXSC.List() end
	if type(stateOrId)=='string' then
		for id in string.gmatch(stateOrId,'[^%s]+') do
			table.insert(self.targets,id)
		end
	else
		table.insert(self.targets,stateOrId)
	end
end

function LXSC.Transition:conditionMatched(datamodel)
	if self.cond then
		local result = datamodel:eval(self.cond)
		return result and (result ~= LXSC.Datamodel.EVALERROR)
	end
	return true
end

function LXSC.Transition:matchesEvent(event)
	for _,tokens in ipairs(self.events) do
		if event.name==tokens.name or tokens.name=="*" then
			return true
		elseif #tokens <= #event._tokens then
			local matched = true
			for i,token in ipairs(tokens) do
				if event._tokens[i]~=token then
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
