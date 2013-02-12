require 'io'
require 'lxsc'

xml = io.input('testcases/simple.scxml'):read("*all")
machine = LXSC:parse(xml)
machine:start()
print("active: "..table.concat(machine:activeStateIds(),  ", ") ) 
print("atomic: "..table.concat(machine:activeAtomicIds(), ", ") ) 
machine:fireEvent("e")
machine:step()
print("active: "..table.concat(machine:activeStateIds(),  ", ") ) 
print("atomic: "..table.concat(machine:activeAtomicIds(), ", ") ) 
