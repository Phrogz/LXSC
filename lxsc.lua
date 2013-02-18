local LXSC = { VERSION="0.4" }
local real = getfenv(0)

setfenv(0,setmetatable({LXSC=LXSC},{__index=real}))
require 'lib/state'
require 'lib/scxml'
require 'lib/transition'
require 'lib/datamodel'
require 'lib/event'
require 'lib/generic'
require 'lib/executable'
require 'lib/datatypes'
require 'lib/runtime'
require 'lib/parse'
setfenv(0,real)

return LXSC