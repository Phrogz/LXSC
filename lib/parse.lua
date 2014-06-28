local LXSC = require 'lib/lxsc'
local SLAXML = require 'lib/slaxml'
function LXSC:parse(scxml)
	local push, pop = table.insert, table.remove
	local i, stack = 1, {}
	local current, root
	local stateKinds = LXSC.State.stateKinds
	local scxmlNS    = LXSC.scxmlNS
	local parser = SLAXML:parser{
		startElement = function(name,nsURI)
			local item
			if nsURI == scxmlNS then
				if stateKinds[name] then
					item = LXSC:state(name)
				else
					item = LXSC[name](LXSC,name,nsURI)
				end
			else
				item = LXSC:_generic(name,nsURI)
			end
			item._order = i; i=i+1
			if current then current:addChild(item) end
			current = item
			if not root then root = current end
			push(stack,item)
		end,
		attribute = function(name,value)
			current:attr(name,value)
		end,
		closeElement = function(name,nsURI)
			if current._kind ~= name then
				error(string.format("I was working with a '%s' element but got a close notification for '%s'",current._kind,name))
			end
			if name=="transition" and nsURI==scxmlNS then
				push( current.source[rawget(current,'events') and '_eventedTransitions' or '_eventlessTransitions'], current )
			end
			pop(stack)
			current = stack[#stack] or current
		end,
		text = function(text)
			current._text = text
		end
	}
	parser:parse(scxml,{stripWhitespace=true})
	return root
end