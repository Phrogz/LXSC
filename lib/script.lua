local LXSC = require 'lib/lxsc'
LXSC.Script={}; LXSC.Script.__meta = {__index=LXSC.Script,}
function LXSC:script()
	local t = { _kind = 'script' }
	return setmetatable(t,self.Script.__meta)
end

function LXSC.Script:attr(name,value)
	if name=="src" then
		local scheme, hierarchy
		local colon = value:find(':')
		if colon then scheme,hierarchy = value:sub(1,colon-1), value:sub(colon+1) end
		if scheme=='file' then
			local f = assert(io.open(hierarchy,"r"))
			self._text = f:read("*all")
			f:close()
		else
			error("Cannot load <script src='"..value.."'>")
		end
	else
		print("Unexpected <script> attribute "..name.."='"..tostring(value).."'")
	end
end

function LXSC.Script:onFinishedParsing()
	if not self._text then
		error("<script> elements must have either a src attribute or text contents.")
	end
end
