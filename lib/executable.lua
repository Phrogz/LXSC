local LXSC = require 'lib/lxsc'
LXSC.Exec = {}

function LXSC.Exec:log(scxml)
	local message = {self.label}
	if self.expr then table.insert(message,scxml:eval(self.expr)) end
	print(table.concat(message,": "))
end

function LXSC.Exec:assign(scxml)
	-- TODO: support child executable content in place of expr
	scxml:set( self.location, scxml:eval(self.expr) )
end

function LXSC.Exec:raise(scxml)
	scxml:fireEvent(self.event,nil,true)
end

function LXSC.Exec:script(scxml)
	scxml:run(self._text)
end

function LXSC.Exec:send(scxml)
	-- TODO: warn about delay/delayexpr no support
	-- TODO: support type/typeexpr/target/targetexpr
	local name = self.event or scxml:eval(self.eventexpr)
	local data
	if self.namelist then
		data = {}
		for name in string.gmatch(self.namelist,'[^%s]+') do data[name] = scxml:get(name) end
	end
	if self.idlocation and not self.id then scxml:set( scxml:eval(self.idlocation), LXSC.uuid4() ) end

	if self.delay or self.delayexpr then
		local delay = self.delay or scxml:eval(self.delayexpr)
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
end

function LXSC.SCXML:executeContent(item)
	local handler = LXSC.Exec[item._kind]
	if handler then
		handler(item,self)
	else
		self:fireEvent('error.execution.unhandled',"unhandled executable type "..item._kind,true)
	end
end

