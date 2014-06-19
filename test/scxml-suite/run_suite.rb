#!/usr/bin/env ruby
#encoding: utf-8
BASE  = 'http://www.w3.org/Voice/2013/SCXML-irp/'
CACHE = 'spec-cache'

require 'uri'
require 'fileutils'
require 'nokogiri' # gem install nokogiri

def run!
	Dir.chdir(File.dirname(__FILE__)) do
		FileUtils.mkdir_p CACHE
		@manifest = Nokogiri.XML( get_file('manifest.xml'), &:noblanks )
		@mod = Nokogiri.XML(IO.read('manifest-mod.xml'))
		run_tests
	end
end

def run_tests
	tests = @manifest.xpath('//test')
	required = tests.reject{ |t| t['conformance']=='optional' }
	auto,manual = required.partition{ |t| t['manual']=='false' }
	Dir['*.scxml'].each{ |f| File.delete(f) }
	auto.sort_by{ |test| test['id'] }.each do |test|
		if mod = @mod.at_xpath("//assert[@id='#{test['id']}']")
			if mod['status']=='failed'
				puts "Skipping known-failed test #{test['id']} because #{mod.text}"
				next
			end
		end
		exit unless run_test(test.at('start')['uri'])
	end
end

def run_test(uri)
	doc = Nokogiri.XML( get_file(uri), &:noblanks )
	convert_to_scxml!(doc)
	file = File.basename(uri).sub('txml','scxml')
	File.open(file,'w:utf-8'){ |f| f.puts doc }
	# puts "lua autotest.lua #{file}"
	system("lua autotest.lua #{file}").tap do |successFlag|
		if successFlag
			File.delete(file) 
		else
			`subl #{file}`
		end
	end
end

def convert_to_scxml!(doc)
	doc.at_xpath('//conf:pass').replace '<final id="pass" />' if doc.at_xpath('//conf:pass')
	doc.at_xpath('//conf:fail').replace '<final id="fail" />' if doc.at_xpath('//conf:fail')
	{
		arrayVar:             ->(a){ ['array',  "testvar#{a}"                         ]},
		arrayTextVar:         ->(a){ ['array',  "testvar#{a}"                         ]},
		eventdataVal:         ->(a){ ['cond',   "_event.data == #{a}"                 ]},
		eventNameVal:         ->(a){ ['cond',   "_event.name == '#{a}'"               ]},
		originTypeEq:         ->(a){ ['cond',   "_event.origintype == '#{a}'"         ]},
		emptyEventData:       ->(a){ ['cond',   "_event.data == nil"                  ]},
		eventFieldHasNoValue: ->(a){ ['cond',   "_event.#{a} == ''"                   ]},
		isBound:              ->(a){ ['cond',   "testvar#{a} ~= nil"                  ]},
		inState:              ->(a){ ['cond',   "In('#{a}')"                          ]},
		true:                 ->(a){ ['cond',   'true'                                ]},
		false:                ->(a){ ['cond',   'false'                               ]},
		unboundVar:           ->(a){ ['cond',   "testvar#{a}==nil"                    ]},
		noValue:              ->(a){ ['cond',   "testvar#{a}==nil or testvar#{a}==''" ]},
		nameVarVal:           ->(a){ ['cond',   "_name == '#{a}'"                     ]},
		nonBoolean:           ->(a){ ['cond',   "@@@@@@@@@@@@@@@@"                    ]},
		systemVarIsBound:     ->(a){ ['cond',   "#{a} ~= nil"                         ]},
		varPrefix:     ->(a){
      x,y = a.split /\s+/
			['cond',"string.sub(testvar#{y},1,string.len(testvar#{x}))==testvar#{x}"]
		},
		VarEqVar:      ->(a){
      x,y = a.split /\s+/
			['cond',"testvar#{x}==testvar#{y}"]
		},
		idQuoteVal:    ->(a){
			x,op,y = a.split(/([=<>]=?)/)
			['cond',"testvar#{x} #{op=='=' ? '==' : op} '#{y}'"]
		},
		idVal:         ->(a){
      x,op,y = a.split /([=<>]+)/
			['cond',"testvar#{x} #{op == '=' ? '==' : op} #{y}"]
		},
		namelistIdVal: ->(a){
			x,op,y = a.split /([=<>]+)/
			['cond',"testvar#{x} #{op == '=' ? '==' : op} #{y}"]
		},
		idSystemVarVal: ->(a){
			x,op,y = a.split /([=<>]+)/
			['cond',"testvar#{x} #{op == '=' ? '==' : op} #{y}"]
		},
		compareIDVal:  ->(a){
			x,op,y = a.split /([=<>]+)/
			['cond',"testvar#{x} #{op == '=' ? '==' : op} testvar#{y}"]
		},
		eventvarVal: ->(a){
			x,op,y = a.split /([=<>]+)/
			['cond',"_event.data['testvar#{x}'] #{op == '=' ? '==' : op} #{y}"]
		},
		VarEqVarStruct: ->(a){
			x,y = a.split /\D+/
			['cond',"testvar#{x} == testvar#{y}"]
		},
		eventFieldsAreBound: ->(a){
			['cond', "_event.name~=nil and _event.type~=nil and _event.sendid~=nil and _event.origin~=nil and _event.invokeid~=nil"]
		},
		datamodel:                ->(a){ ['datamodel', 'lua'               ]},
		delayExpr:                ->(a){ ['delayexpr', "testvar#{a}"       ]},
		eventExpr:                ->(a){ ['eventexpr',  "testvar#{a}"      ]},
		eventDataFieldValue:      ->(a){ ['expr',       "_event.data.#{a}" ]},
		eventDataNamelistValue:   ->(a){ ['expr',       "_event.data.#{a}" ]},
		eventDataParamValue:      ->(a){ ['expr',       "_event.data.#{a}" ]},
		eventField:               ->(a){ ['expr',       "_event.#{a}"      ]},
		eventName:                ->(a){ ['expr',       "_event.name"      ]},
		eventSendid:              ->(a){ ['expr',       "_event.sendid"    ]},
		eventType:                ->(a){ ['expr',       "_event.type"      ]},
		expr:                     ->(a){ ['expr',       a                  ]},
		illegalArray:             ->(a){ ['expr',       "7"                ]},
		illegalExpr:              ->(a){ ['expr',       "!"                ]},
		invalidSendTypeExpr:      ->(a){ ['expr',       '27'               ]},
		invalidSessionID:         ->(a){ ['expr',       "-1"               ]},
		invalidName:              ->(a){ ['name',       ""                 ]},
		varExpr:                  ->(a){ ['expr',       "testvar#{a}"      ]},
		varChildExpr:             ->(a){ ['expr',       "testvar#{a}"      ]},
		quoteExpr:                ->(a){ ['expr',       "'#{a}'"           ]},
		systemVarExpr:            ->(a){ ['expr',       a                  ]},
		scxmlEventIOLocation:     ->(a){ ['expr',       "FIXME"            ]},
		id:                       ->(a){ ['id',         "testvar#{a}"      ]},
		idlocation:               ->(a){ ['idlocation', "'testvar#{a}'"    ]},
		index:                    ->(a){ ['index',      "testvar#{a}"      ]},
		item:                     ->(a){ ['item',       "testvar#{a}"      ]},
		illegalItem:              ->(a){ ['item',       "_no"              ]},
		location:                 ->(a){ ['location',   "testvar#{a}"      ]},
		invalidLocation:          ->(a){ ['location',   "_no"              ]},
		invalidParamLocation:     ->(a){ ['location',   ""                 ]},
		systemVarLocation:        ->(a){ ['location',   a                  ]},
		name:                     ->(a){ ['name',       "testvar#{a}"      ]},
		namelist:                 ->(a){ ['namelist',   "testvar#{a}"      ]},
		sendIDExpr:               ->(a){ ['sendidexpr', "testvar#{a}"      ]},
		srcExpr:                  ->(a){ ['srcexpr',    "testvar#{a}"      ]},
		targetpass:               ->(a){ ['target',     'pass'             ]},
		targetfail:               ->(a){ ['target',     'fail'             ]},
		illegalTarget:            ->(a){ ['target',     'xxxxxxxxx'        ]},
		unreachableTarget:        ->(a){ ['target',     'FIXME'            ]},
		targetVar:                ->(a){ ['targetexpr', "testvar#{a}"      ]},
		targetExpr:               ->(a){ ['targetexpr', "testvar#{a}"      ]},
		basicHTTPAccessURITarget: ->(a){ ['targetexpr', "FIXME"            ]},
		invalidSendType:          ->(a){ ['type',       '27'               ]},
		typeExpr:                 ->(a){ ['typeexpr',   "testvar#{a}"      ]},
	}.each do |a1,proc|
		doc.xpath("//@conf:#{a1}").each{ |a| a2,v=proc[a.value]; a.parent[a2]=v; a.remove }
	end

	doc.xpath('//conf:incrementID').each{ |e|
		e.replace "<assign location='testvar#{e['id']}' expr='testvar#{e['id']}+1' />"
	}
	doc.xpath('//conf:array123').each{ |e| e.replace "{1,2,3}" }
	doc.xpath('//conf:extendArray').each{ |e| e.replace "<assign location='testvar#{e['id']}' expr='(function() local t2={}; for i,v in ipairs(testvar#{e['id']}) do t2[i]=v end t2[#t2+1]=4 return t2 end)()' />" }
	doc.xpath('//conf:sumVars').each{ |e|
		e.replace "<assign location='testvar#{e['id1']}' expr='testvar#{e['id1']}+testvar#{e['id2']}' />"
	}
	doc.xpath('//conf:concatVars').each{ |e|
		e.replace "<assign location='testvar#{e['id1']}' expr='testvar#{e['id1']}..testvar#{e['id2']}' />"
	}
	doc.xpath('//conf:contentFoo').each{ |e| e.replace %Q{<content expr="'foo'"/>} }
	doc.xpath('//conf:script').each{ |e| e.replace %Q{<script>testvar1 = 1</script>} }
	doc.xpath('//conf:sendToSender').each{ |e|
		e.replace %Q{<send event="#{e['name']}" targetexpr="_event.origin" typeexpr="_event.origintype"/>}
	}

	if a = doc.at_xpath('//@*[namespace-uri()="http://www.w3.org/2005/scxml-conformance"]')
		puts a.parent
		exit
	end
	if a = doc.at_xpath('//conf:*')
		puts a
		exit
	end
end

def get_file(uri)
	Dir.chdir(CACHE) do
		unless File.exist?(uri)
			subdir = File.dirname(uri)
			FileUtils.mkdir_p subdir			
			Dir.chdir(subdir){ `curl -s -L -O #{URI.join BASE, uri}` }
		end
		File.open( uri, 'r:UTF-8', &:read )
	end
end

run! if __FILE__==$0