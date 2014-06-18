local LXSC = require 'lib/lxsc'
LXSC.Exec = {}

function LXSC.Exec:log(scxml)
	local message = {self.label}
	if self.expr then
		local value = scxml:eval(self.expr)
		if value==LXSC.Datamodel.EVALERROR then return end
		table.insert(message,value)
	end
	print(table.concat(message,": "))
	return true
end

function LXSC.Exec:assign(scxml)
	-- TODO: support child executable content in place of expr
	local value = scxml:eval(self.expr)
	if value~=LXSC.Datamodel.EVALERROR then
		scxml:set( self.location, value )
		return true
	end
end

function LXSC.Exec:raise(scxml)
	scxml:fireEvent(self.event,nil,'internal')
	return true
end

function LXSC.Exec:script(scxml)
	scxml:run(self._text)
	return true
end

function LXSC.Exec:send(scxml)
	-- TODO: support type/typeexpr/target/targetexpr
	local type = self.type or self.typeexpr and scxml:eval(self.typeexpr)
	if type == LXSC.Datamodel.EVALERROR then return end
	if not type then type = 'http://www.w3.org/TR/scxml/#SCXMLEventProcessor' end
	if type ~= 'http://www.w3.org/TR/scxml/#SCXMLEventProcessor' then
		scxml:fireEvent("error.execution.invalid-send-type","Unsupported <send> type '"..tostring(type).."'")
		return
	end	

	local target = self.target or self.targetexpr and scxml:eval(self.targetexpr)
	if target == LXSC.Datamodel.EVALERROR then return end
	if target and target ~= '#_internal' and target ~= '#_scxml_' .. scxml:get('_sessionid') then
		scxml:fireEvent("error.execution.invalid-send-target","Unsupported <send> target '"..tostring(target).."'")
		return
	end

	local name = self.event or scxml:eval(self.eventexpr)
	if name == LXSC.Datamodel.EVALERROR then return end
	local data
	if self.namelist then
		data = {}
		for name in string.gmatch(self.namelist,'[^%s]+') do data[name] = scxml:get(name) end
	end
	for _,child in ipairs(self._kids) do
		if child._kind=='param' then
			if not data then data = {} end
			if not scxml:executeContent(child,data) then return end
		elseif child._kind=='content' then
			if data then error("<send> may not have both <param> and <content> child elements.") end
			data = {}
			if not scxml:executeContent(child,data) then return end
			data = data.content -- unwrap the content
		end
	end

	if self.idlocation and not self.id then
		local loc = scxml:eval(self.idlocation)
		if loc == LXSC.Datamodel.EVALERROR then return end
		scxml:set( loc, LXSC.uuid4() )
	end

	if self.delay or self.delayexpr then
		local delay = self.delay or scxml:eval(self.delayexpr)
		if delay == LXSC.Datamodel.EVALERROR then return end
		local delaySeconds, units = string.match(delay,'^(.-)(m?s)')
		delaySeconds = tonumber(delaySeconds)
		if units=="ms" then delaySeconds = delaySeconds/1000 end
		local delayedEvent = { expires=scxml:elapsed()+delaySeconds, name=name, data=data, id=self.id }
		local i=1
		for _,delayed2 in ipairs(scxml._delayedSend) do
			if delayed2.expires>delayedEvent.expires then break else i=i+1 end
		end
		table.insert(scxml._delayedSend,i,delayedEvent)
	else
		scxml:fireEvent(name,data,target=='#_internal' and 'internal' or 'external')
	end
	return true
end

function LXSC.Exec:param(scxml,context)
	if not context   then error("<param name='"..self.name.."' /> only supported as child of <send>") end
	if not self.name then error("<param> element missing 'name' attribute") end
	if not (self.location or self.expr) then error("<param> element requires either 'expr' or 'location' attribute") end
	local val
	if self.location then
		val = scxml:get(self.location)
	elseif self.expr then
		val = scxml:eval(self.expr)
		if val == LXSC.Datamodel.EVALERROR then return end
	end
	context[self.name] = val
	return true
end

function LXSC.Exec:content(scxml,context)
	if not context   then error("<content> only supported as child of <send>") end
	if self.expr and self._text then error("<content> element must have either 'expr' attribute or child content, but not both") end
	if not (self.expr or self._text) then error("<content> element requires either 'expr' attribute or child content") end
	local val = scxml:eval(self.expr or self._text)
	if val == LXSC.Datamodel.EVALERROR then return end
	context.content = val
	return true
end

function LXSC.Exec:cancel(scxml)
	local sendid = self.sendid or scxml:eval(self.sendidexpr)
	if sendid == LXSC.Datamodel.EVALERROR then return end
	scxml:cancelDelayedSend(sendid)
	return true
end

LXSC.Exec['if'] = function (self,scxml)
	local result = scxml:eval(self.cond)
	if result == LXSC.Datamodel.EVALERROR then return end
	if result then
		for _,child in ipairs(self._kids) do
			if child._kind=='else' or child._kind=='elseif' then
				break
			else
				if not scxml:executeContent(child) then return end
			end
		end
	else
		local executeFlag = false
		for _,child in ipairs(self._kids) do
			if child._kind=='else' then
				if executeFlag then break else executeFlag = true end
			elseif child._kind=='elseif' then
				if executeFlag then
					break
				else
					result = scxml:eval(child.cond)
					if result == LXSC.Datamodel.EVALERROR then return end
					if result then executeFlag = true end
				end
			elseif executeFlag then
				if not scxml:executeContent(child) then return end
			end
		end
	end
	return true
end

function LXSC.Exec:foreach(scxml)
	local array = scxml:get(self.array)
	if type(array) ~= 'table' then
		scxml:fireEvent('error.execution',"foreach array '"..self.array.."' is not a table")
	else
		local list = {}
		for i,v in ipairs(array) do list[i]=v end
		for i,v in ipairs(list) do
			if not scxml:set(self.item,v) then return end
			if self.index and not scxml:set(self.index,i) then return end
			for _,child in ipairs(self._kids) do
				if not scxml:executeContent(child) then return end
			end
		end
		return true
	end
end

function LXSC.SCXML:processDelayedSends() -- automatically called by :step()
	local i,last=1,#self._delayedSend
	while i<=last do
		local delayedEvent = self._delayedSend[i]
		if delayedEvent.expires <= self:elapsed() then
			table.remove(self._delayedSend,i)
			self:fireEvent(delayedEvent.name,delayedEvent.data,'external')
			last = last-1
		else
			i=i+1
		end
	end
end

function LXSC.SCXML:cancelDelayedSend(sendId)
	for i=#self._delayedSend,1,-1 do
		if self._delayedSend[i].id==sendId then table.remove(self._delayedSend,i) end
	end
end

-- ******************************************************************

function LXSC.SCXML:executeContent(item,...)
	local handler = LXSC.Exec[item._kind]
	if handler then
		return handler(item,self,...)
	else
		-- print("UNHANDLED EXECUTABLE: "..item._kind)
		self:fireEvent('error.execution.unhandled',"unhandled executable type "..item._kind)
		return true -- Just because we didn't understand it doesn't mean we should stop processing executable
	end
end

