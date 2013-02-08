function LXSC:parse(scxml)
	local push, pop = table.insert, table.remove
	local stack = {}
	local current, root, i
	local parser = SLAXML:parser{
		startElement = function(name)
			local item = LXSC[name](LXSC,name)
			item._order = i; i=i+1
			if current then current:addChild(item) end
			current = item
			if not root then root = current end
			push(stack,item)
		end,
		attribute = function(name,value) current:attr(name,value) end,
		closeElement = function(name)
			if current.kind ~= name then
				error(string.format("I was working with a '%s' element but got a close notification for '%s'",current.kind,name))
			end
			pop(stack)
			current = stack[#stack] or current
		end,
		text = function(text)
			print(string.format("Text: %s",text))
		end
	}
	i=1
	parser:parse(scxml)
	return root
end