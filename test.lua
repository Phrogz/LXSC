require 'io'
require 'lxsc'

xml = io.input('testcases/simple.scxml'):read("*all")
lom = AKLOM.parse(xml)
doc = LXSC:scxml(lom)
print(doc)


