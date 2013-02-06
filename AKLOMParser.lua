AKLOM = {
	-- Creates the 'elements' collection and named access to the first child element
	useElementCollectionFlag = true,
	
	-- Creates an 'innertext' property that is the sum of all text objects
	useInnerTextFlag = true,
	
	-- Strips all leading/trailing whitespace between nodes and text
	stripWhitespaceFlag = true
}

function AKLOM.unescape( inString )
	-- Cache function reference for maximum speed
	local gsub = string.gsub
	inString = gsub( inString, '&lt;', '<' )
	inString = gsub( inString, '&gt;', '>' )
	inString = gsub( inString, '&quot;', '"' )
	inString = gsub( inString, '&apos;', "'" )
	return gsub( inString, '&amp;', '&' )
end

-- inXMLString : the XML string to parse
-- Returns: a table representing the LOM node for the root element
function AKLOM.parse( inXMLString )
	-- Cache references for maximum speed
	local sub, gsub, find, push, pop, unescape = string.sub, string.gsub, string.find, table.insert, table.remove, AKLOM.unescape
	local theUseElementCollectionFlag = AKLOM.useElementCollectionFlag
	local theUseInnerTextFlag = AKLOM.useInnerTextFlag
	local theStripWhitespaceFlag = AKLOM.stripWhitespaceFlag
	
	-- Throw out SGML comments and processing directives
	inXMLString = gsub( inXMLString, '<!%-%-.-%-%->', '' )
	inXMLString = gsub( inXMLString, '<%?.-%?>', '' )
	
	if theStripWhitespaceFlag then
		-- Throw out leading and trailing whitespace in text blocks
		inXMLString = gsub( inXMLString, '>%s+', '>' )
		inXMLString = gsub( inXMLString, '%s+<', '<' )
	end
	inXMLString = gsub( inXMLString, '<!%[CDATA%[', '' )
	inXMLString = gsub( inXMLString, '%]%]>', '' )

	
	local theDoc = {
		elements = ( theUseElementCollectionFlag and { } or nil ),
		innertext = ( theUseInnerTextFlag and { } or nil )
	}
	local theCurrentElement = theDoc
	local theStack = { n=0 }
	local thePos = 1
	local theStart, theEnd, theClose, theName, theAttr, theEmpty
	local theLeadingText
	while true do
		theStart, theEnd, theClose, theName, theAttr, theEmpty = find( inXMLString, '<(%/?)(%a%w*)(.-)(%/?)>', thePos )
		-- print(theStart, theEnd, theClose, theName, theAttr, theEmpty)
		if not theStart then break end
		
		local theIsParentFlag = ( theEmpty == '' )
		
		theLeadingText = unescape( sub( inXMLString, thePos + 1, theStart - 1 ) )
		if theLeadingText ~= '' then
			push( theCurrentElement, theLeadingText )
			if theUseInnerTextFlag then
				theCurrentElement.innertext = theCurrentElement.innertext .. theLeadingText
			end
		end

		thePos = theEnd
		
		if theClose ~= '' then
			if theUseInnerTextFlag and theCurrentElement.innertext == '' then
				theCurrentElement.innertext = nil
			end
			theCurrentElement = pop( theStack )
			assert( theName == theCurrentElement.name, "Found close element '"..theName.."', expected '"..theCurrentElement.name.."'" )
			theCurrentElement = theStack[ #theStack ]
			if not theCurrentElement then break end
		else
			local theElement = {
				name      = theName,
				attr      = {},
				elements  = theUseElementCollectionFlag and {} or nil,
				innertext = ( theUseInnerTextFlag and theIsParentFlag ) and '' or nil
			}

			-- Parse the attribute string
			gsub(
				theAttr,
				'([%a_:][%w._:-]*)%s*=%s*([\'"])(.-)%2',
				function( inAttName, _, inAttValue )
					theElement.attr[ inAttName ] = unescape( inAttValue )
				end
			)

			-- Add the element to the parent
			push( theCurrentElement, theElement )
			if theUseElementCollectionFlag then
				if not theCurrentElement[ theName ] then
					theCurrentElement[ theName ] = theElement
				end
				if not theCurrentElement.elements[ theName ] then
					theCurrentElement.elements[ theName ] = {}
				end
				push( theCurrentElement.elements[ theName ], theElement )
			end

			if theIsParentFlag then
				push( theStack, theElement )
				theCurrentElement = theElement
			end
		end
	end

	if #theStack > 0 then
		error( "AKLOM parsing ended early; I was still inside the '"..(theStack[#theStack].name).."' element." )
	end

	return theDoc[ 1 ]
end

function AKLOM.lomstring( inLOM )
	local theOutput = "<" .. inLOM.name .. " (" .. table.getn( inLOM ) .. " children)"
	for k,v in pairs( inLOM.attr ) do
		theOutput = theOutput .. ' ' .. k .. '="' .. v .. '"'
	end
	return theOutput .. '>'
end
