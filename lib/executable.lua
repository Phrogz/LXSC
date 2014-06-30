local LXSC = require 'lib/lxsc'
LXSC.Exec = {}

function LXSC.Exec:log(scxml)
	local message = {self.label}
	if self.expr and self.expr~="" then
		local value = scxml:eval(self.expr)
		if value==LXSC.Datamodel.EVALERROR then return end
		table.insert(message,tostring(value))
	end
	print(table.concat(message,": "))
	return true
end

function LXSC.Exec:assign(scxml)
	-- TODO: support child executable content in place of expr
	if self.location=="" then
		scxml:fireEvent("error.execution.invalid-location","Unsupported <assign> location '"..tostring(self.location).."'")
	else
		local value = scxml:eval(self.expr)
		if value~=LXSC.Datamodel.EVALERROR then
			scxml:set( self.location, value )
			return true
		end
	end
end

function LXSC.Exec:raise(scxml)
	scxml:fireEvent(self.event,nil,{type='internal',origintype=''})
	return true
end

function LXSC.Exec:script(scxml)
	local result = scxml:run(self._text)
	return result ~= LXSC.Datamodel.EVALERROR
end

function LXSC.Exec:send(scxml)
	-- TODO: support type/typeexpr/target/targetexpr
	local type = self.type or self.typeexpr and scxml:eval(self.typeexpr)
	if type == LXSC.Datamodel.EVALERROR then return end

	local id = self.id
	if self.idlocation and not id then
		local loc = scxml:eval(self.idlocation)
		if loc == LXSC.Datamodel.EVALERROR then return end
		id = LXSC.uuid4()
		scxml:set( loc, id )
	end

	if not type then type = 'http://www.w3.org/TR/scxml/#SCXMLEventProcessor' end
	if type ~= 'http://www.w3.org/TR/scxml/#SCXMLEventProcessor' then
		scxml:fireEvent("error.execution.invalid-send-type","Unsupported <send> type '"..tostring(type).."'",{sendid=id})
		return
	end	

	local target = self.target or self.targetexpr and scxml:eval(self.targetexpr)
	if target == LXSC.Datamodel.EVALERROR then return end
	if target and target ~= '#_internal' and target ~= '#_scxml_' .. scxml:get('_sessionid') then
		scxml:fireEvent("error.execution.invalid-send-target","Unsupported <send> target '"..tostring(target).."'",{sendid=id})
		return
	end

	local name = self.event or scxml:eval(self.eventexpr)
	if name == LXSC.Datamodel.EVALERROR then return end
	local data
	if self.namelist then
		data = {}
		for name in string.gmatch(self.namelist,'[^%s]+') do data[name] = scxml:get(name) end
		if not next(data) then
			scxml:fireEvent("error.execution.invalid-send-namelist","<send> namelist must include one or more locations",{sendid=id})
			return
		end
	end
	for _,child in ipairs(self._kids) do
		if child._kind=='param' then
			if not data then data = {} end
			if not scxml:executeSingle(child,data) then return end
		elseif child._kind=='content' then
			if data then error("<send> may not have both <param> and <content> child elements.") end
			data = {}
			if not scxml:executeSingle(child,data) then return end
			data = data.content -- unwrap the content
		end
	end

	if self.delay or self.delayexpr then
		local delay = self.delay or scxml:eval(self.delayexpr)
		if delay == LXSC.Datamodel.EVALERROR then return end
		local delaySeconds, units = string.match(delay,'^(.-)(m?s)')
		delaySeconds = tonumber(delaySeconds)
		if units=="ms" then delaySeconds = delaySeconds/1000 end
		local delayedEvent = { expires=scxml:elapsed()+delaySeconds, name=name, data=data, sendid=id }
		local i=1
		for _,delayed2 in ipairs(scxml._delayedSend) do
			if delayed2.expires>delayedEvent.expires then break else i=i+1 end
		end
		table.insert(scxml._delayedSend,i,delayedEvent)
	else
		local fields = {type=target=='#_internal' and 'internal' or 'external'}
		if fields.type=='external' then
			fields.origin = '#_scxml_' .. scxml:get('_sessionid')
		else
			fields.origintype = ''
		end
		fields.sendid = self.id
		scxml:fireEvent(name,data,fields)
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
		if val == LXSC.Datamodel.INVALIDLOCATION then return end
	elseif self.expr then
		val = scxml:eval(self.expr)
		if val == LXSC.Datamodel.EVALERROR then return end
	end
	context[self.name] = val
	return true
end

function LXSC.Exec:content(scxml,context)
	if not context then error("<content> only supported as child of <send> or <donedata>") end
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
				if not scxml:executeSingle(child) then return end
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
				if not scxml:executeSingle(child) then return end
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
				if not scxml:executeSingle(child) then return end
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
			self:fireEvent(delayedEvent.name,delayedEvent.data,{type='external'})
			last = last-1
		else
			i=i+1
		end
	end
end

function LXSC.SCXML:cancelDelayedSend(sendId)
	for i=#self._delayedSend,1,-1 do
		if self._delayedSend[i].sendid==sendId then table.remove(self._delayedSend,i) end
	end
end

-- ******************************************************************

function LXSC.SCXML:executeContent(parent)
	for _,executable in ipairs(parent._kids) do
		if not self:executeSingle(executable) then break end
	end
end

function LXSC.SCXML:executeSingle(item,...)
	local handler = LXSC.Exec[item._kind]
	if handler then
		return handler(item,self,...)
	else
		self:fireEvent('error.execution.unhandled',"unhandled executable type "..item._kind)
		return true -- Just because we didn't understand it doesn't mean we should stop processing executable
	end
end

