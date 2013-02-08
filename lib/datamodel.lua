Datamodel = {}
Datamodel.__meta = {__index=Datamodel}
setmetatable(Datamodel,{__call=function(o)
	local dm = { data={} }
	setmetatable(dm,o.__meta)
	return dm
end})
