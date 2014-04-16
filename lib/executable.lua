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
	scxml:fireEvent(self.event,nil,true)
	return true
end

function LXSC.Exec:script(scxml)
	scxml:run(self._text)
	return true
end

function LXSC.Exec:send(scxml)
	-- TODO: support type/typeexpr/target/targetexpr
	local name = self.event or scxml:eval(self.eventexpr)
	if name == LXSC.Datamodel.EVALERROR then return end
	local data
	if self.namelist then
		data = {}
		for name in string.gmatch(self.namelist,'[^%s]+') do data[name] = scxml:get(name) end
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
		local delayedEvent = { expires=os.clock()+delaySeconds, name=name, data=data, id=self.id }
		local i=1
		for _,delayed2 in ipairs(scxml._delayedSend) do
			if delayed2.expires>delayedEvent.expires then break else i=i+1 end
		end
		table.insert(scxml._delayedSend,i,delayedEvent)
	else
		scxml:fireEvent(name,data,false)
	end
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
		scxml:fireEvent('error.execution',"foreach array '"..self.array.."' is not a table",true)
	else
		local list = {}
		for i,v in ipairs(array) do list[i]=v end
		for i,v in ipairs(list) do
			scxml:set(self.item,v)
			if self.index then scxml:set(self.index,i) end
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
		if delayedEvent.expires <= os.clock() then
			table.remove(self._delayedSend,i)
			self:fireEvent(delayedEvent.name,delayedEvent.data,false)
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

function LXSC.SCXML:executeContent(item)
	local handler = LXSC.Exec[item._kind]
	if handler then
		return handler(item,self)
	else
		-- print("UNHANDLED EXECUTABLE: "..item._kind)
		self:fireEvent('error.execution.unhandled',"unhandled executable type "..item._kind,true)
		return true -- Just because we didn't understand it doesn't mean we should stop processing executable
	end
end

