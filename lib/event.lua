LXSC.Event = function(name,data)
	local e = {name=name,data=data,tokens={}}
	for token in string.gmatch(name,'[^.*]+') do table.insert(e.tokens,token) end
	return e
end
