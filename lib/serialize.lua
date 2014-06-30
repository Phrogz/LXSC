local function serialize(v,opts)
	if not opts then opts = {} end
	if not opts.notype then opts.notype = {} end
	if not opts.nokey  then opts.nokey  = {} end
	if not opts.lv     then opts.lv=0        end
	if opts.sort and type(opts.sort)~='function' then opts.sort = function(a,b) if type(a[1])==type(b[1]) then return a[1]<b[1] end end end
	local t = type(v)
	if t=='string' then
		return string.format('%q',v)
	elseif t=='number' or t=='boolean' then
		return tostring(v)
	elseif t=='table' then
		local vals = {}
		local function serializeKV(k,v)
			local tk,tv = type(k),type(v)
			if not (opts.notype[tk] or opts.notype[tv] or opts.nokey[k]) then
				local indent=""
				if opts.indent then
					opts.lv = opts.lv + 1
					indent = opts.indent:rep(opts.lv)
				end
				if tk=='string' and string.find(k,'^[%a_][%a%d_]*$') then
					table.insert(vals,indent..k..'='..serialize(v,opts))
				else
					table.insert(vals,indent..'['..serialize(k,opts)..']='..serialize(v,opts))
				end
				if opts.indent then opts.lv = opts.lv-1 end
			end
		end
		if opts.sort then
			local numberKeys = {}
			local otherKeys  = {}
			for k,v in pairs(v) do
				if type(k)=='number' then
					table.insert(numberKeys,k)
				else
					table.insert(otherKeys,{k,v})
				end
			end
			table.sort(numberKeys)
			table.sort(otherKeys,opts.sort)
			for _,n in ipairs(numberKeys) do serializeKV(n,v[n])    end
			for _,o in ipairs(otherKeys)  do serializeKV(o[1],o[2]) end
		else
			for k,v in pairs(v) do serializeKV(k,v) end
		end
		if opts.indent then
			return #vals==0 and '{}' or '{\n'..table.concat(vals,',\n')..'\n'..opts.indent:rep(opts.lv)..'}'
		else
			return '{'..table.concat(vals,', ')..'}'
		end
	elseif t=='function' then
		return 'nil --[[ '..tostring(v)..' ]]'
	else
		error("Cannot serialize "..tostring(t))
	end
end

local function deserialize(str)
	local f,err = loadstring("return "..str)
	if not f then error(string.format('Error parsing %q: %s',str,err)) end
	local successFlag,resultOrError = pcall(f)
	if successFlag then
		return resultOrError
	else
		error(string.format("Error evaluating %q: %s",str,resultOrError))
	end
end

local LXSC = require 'lib/lxsc'
LXSC.serializeLua   = serialize
LXSC.deserializeLua = deserialize
