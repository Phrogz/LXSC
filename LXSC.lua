LXSC = {
	SCXML = {}
}
for k,t in pairs(LXSC) do t.__meta={__index=t} end

function LXSC:convert(el)
	return self[el.name](self,el)
end
function LXSC:scxml(el)
	for k,v in pairs(el.elements) do
		print(k,v)
	end
	local t = {
		name=el.attr.name or "(lxsc)",
		states={}
	}

	setmetatable(t,self.SCXML.__meta)
	return t
end
