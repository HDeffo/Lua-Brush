--[[
first letter denotes variable type

f = function
t = table
i = number
s = string
b = boolean
v = changing or unknown variable

"next, var" is the same as "pairs(var)" but faster
]]

--localization--
local fInsert = table.insert
local fRemove = table.remove
local fConcat = table.concat
local fFloor = math.floor
local fChar = string.char
local fSort = table.sort
local fMax = math.max


--variables--
local tHex = {[0]="0",[1]="1",[2]="2",[3]="3",[4]="4",[5]="5",[6]="6",[7]="7",[8]="8",[9]="9",[10]="a",[11]="b",[12]="c",[13]="d",[14]="e",[15]="f",[16]=" "}
local tDec = {["0"]=0,["1"]=1,["2"]=2,["3"]=3,["4"]=4,["5"]=5,["6"]=6,["7"]=7,["8"]=8,["9"]=9,["a"]=10,["b"]=11,["c"]=12,["d"]=13,["e"]=14,["f"]=15,[" "]=16}
local tMTFTable = {} --this will be a table of all bytes 0-255


--basic functions--

local function fSetBits(tData, sCurrBit, sThisBit, bInternal)--converts frequency tree to bits for huffman
	local tSet

	sCurrBit = sCurrBit or ""
	sThisBit = sThisBit or "0"
	
	local tSolution = {}
	if type(tData.contains)=="table"	then
		tSet = fSetBits(tData.contains[1],sCurrBit..(bInternal and sThisBit or ""),1,true)
		for k,v in next,tSet  do
			tSolution[k] = v
		end
		tSet = fSetBits(tData.contains[2],sCurrBit..(bInternal and sThisBit or ""),0,true)
		for k,v in next,tSet  do
			tSolution[k] = v
		end
	else
		tSolution[tData.contains]=sCurrBit..sThisBit
	end
	return tSolution
end

local function fTblHexToDec(tData) --converts all hex characters to decimal numbers
	for k,v in ipairs(tData) do
		tData[k] = tDec[v]
	end
	return tData
end

local function fTblCharToDec(tData) --converts all text to decimal in a table
	for k,v in next, tData do
		tData[k] = v:byte()
	end
	return tData
end

--next two reverse the above two
local function fTblDecToHex(tData)
	for k,v in next, tData do
		tData[k] = tHex[v]
	end
	return tData
end

local function fTblDecToChar(tData)
	for k,v in ipairs(tData) do
		tData[k] = fChar(v)
	end
	return tData
end

local function fShallowCopy(tData) --makes a shallow copy of a table changing pointers
	local tOutput = {}
	for k,v in ipairs(tData) do
		tOutput[k] = v
	end
	return tOutput
end

local function fIsEqual(tA,tB) --checks if tables contain the same data
	for i=1,#tA do
		if tA[i]~=tB[i] then
			return false
		end
	end
	return #tA==#tB
end

local function fLexTblSort(tA,tB) --sorter for tables
	for i=1,#tA do 
		if tA[i]~=tB[i] then 
			return tA[i]<tB[i]
		end
	end 
	return false 
end

local function fDecToBin(iNum)--convert base 10 to base 2
	if iNum==0 then
		return "00000000" --0 needs a special handle
	end
	local tBinary = {}
	while iNum > 0 do
		fInsert(tBinary,1,iNum%2)
		iNum=fFloor(iNum/2)
	end
	return (#tBinary%8>0 and ("0"):rep(8-#tBinary%8) or "")..fConcat(tBinary)
end


--BWT functions--
local function fBWT(tData)

	--setup--
	local iSize = #tData
	local tSolution = {}
	local tSolved = {}
	
	
	--key table--
	for n=1,iSize do 
		tData[iSize] = fRemove(tData,1)
		tSolution[n] = fShallowCopy(tData)
	end
	table.sort(tSolution,fLexTblSort)
	
	
	--encode output--
	for i=1,iSize do
		tSolved[i] = tSolution[i][iSize]
	end
	
	
	--finalize--
	for i=1,iSize do
		if fIsEqual(tSolution[i],tData) then
			return i,tSolved
		end
	end
	return false
end

local function fUnBWT(iPointer,tData)

	--setup--
	local tSolution = {}
	local iLen = #tData
	
	
	--decode--
	for _=1,iLen do
		for i=1,iLen do
			if not tSolution[i] then
				tSolution[i] = {} --prevent an error
			end
			fInsert(tSolution[i],1,tData[i]) --insert each entry into each column
		end
		table.sort(tSolution,fLexTblSort) --sort after each set of adds
	end
	
	
	--finalize--
	return tSolution[iPointer]
end


--MTF functions--
local function fFlushMTF() --reset the MTF table for handling
	for i=0,255 do
		tMTFTable[i+1] = i
	end
end

local function fMTF(tData)

	--setup--
	local tSolution = {}
	fFlushMTF()
	
	
	--encode--
	for _,iNum in next,tData do
		for i=1,256 do
			if tMTFTable[i]==iNum then --if bits are the same
				fInsert(tMTFTable,1,fRemove(tMTFTable,i)) --move bit to front
				fInsert(tSolution,i) --insert bit position
				break --next entry
			end
		end
	end
	
	
	--finalize--
	return tSolution
end

local function fUnMTF(tData)

	--setup--
	local tSolution = {}
	fFlushMTF()
	
	
	--decode--
	for _,iNum in next,tData do
		fInsert(tMTFTable,1,fRemove(tMTFTable,iNum)) --move bit to front
		fInsert(tSolution,tMTFTable[1]) --record bit
	end
	
	
	--finalize--
	return tSolution
end


--String RLE functions--
local function fSRLE(tData)
	
	--setup--
	local tSolution = {}
	
	--encode--
	while #tData>0 do
		fInsert(tSolution,tData[1])
		if fRemove(tData,1) == tData[1] then--if theres a run
			local iEnc = tData[1]
			local iCount = 1
			while tData[1]==iEnc and iCount<255 do --count how long the run is
				fRemove(tData,1)
				iCount = iCount + 1
			end
			fInsert(tSolution,#tSolution,iCount)
			fInsert(tSolution,#tSolution,iCount) --insert count identifier
			print(textutils.serialize(tSolution):gsub("\n",""))
		end
	end
	
	
	--finalize--
	return tSolution
end

local function fUnSRLE(tData)

	--setup--
	local tSolution = {}
	
	
	--decode--
	while #tData>0 do
		if tData[1]==tData[2] then --we found a counter so now add it
			fRemove(tData,1)
			local iCount = fRemove(tData,1)
			local iChar = fRemove(tData,1)
			for _=1,iCount do
				fInsert(tSolution,iChar)
			end
		else
			fInsert(tSolution,fRemove(tData,1))
		end
	end
	
	
	--finalize--
	return tSolution
end


--Color RLE functions--
local function fCRLE(tData)

	--setup--
	local tSolution = {}
	local sInter = ""
	local iLast = -1
	
	--encode--
	for _,iNum in next, tData do
		if iNum==iLast then
			sInter=sInter.."0"
		else
			if iNum==16 then
				sInter = sInter.."11"
			else
				sInter=sInter.."1"..fDecToBin(iNum):sub(4,8)
			end
		end
		iLast = iNum
	end
	sInter = sInter:sub(2,#sInter)
	if #sInter%8~=0 then
		sInter = sInter..("1"):rep(8-#sInter%8)
	end
	while #sInter>=8 do
		fInsert(tSolution,tonumber(sInter:sub(1,8),2))
		sInter = sInter:sub(9,#sInter)
	end
	
	
	--finalize--
	return tSolution
end

local function fUnCRLE(iLength, tData)
	
	--setup--
	local sInter = ""
	local tSolution = {}
	
	for _,v in next,tData do
		sInter = sInter..fDecToBin(v)
	end
	tSolution[1] = tonumber(sInter:sub(1,5),2)
	iLength = iLength - 1
	sInter = sInter:sub(6,#sInter)
	
	--decode--
	while iLength>0 do
		iLength = iLength - 1
		if sInter:sub(1,1)=="0" then
			fInsert(tSolution,tSolution[#tSolution])
			sInter = sInter:sub(2,#sInter)
		else
			if sInter:sub(2,2)=="1" then
				fInsert(tSolution,16)
				sInter = sInter:sub(3,#sInter)
			else
				fInsert(tSolution,tonumber(sInter:sub(2,6),2))
				sInter = sInter:sub(7,#sInter)
			end
		end
	end
	
	--finalize--
	return tSolution
end

--Huffman functions--
local function fHuffman(tData)

	--setup--
	local tFreq = {}
	local tTree = {}
	local tKey = {}
	local sInter = ""
	local tSolution = {}
	local iMaxSize, iCount = 0, 0
	
	
	--key table--
	for _,v in next, tData do
		tFreq[v] = tFreq[v] and tFreq[v]+1 or 1
	end
	for k,v in next,tFreq do
		iCount = iCount + 1
		fInsert(tTree,{freq=v,contains=k,depth=0})
	end
	while #tTree>1 do
		fSort(tTree, function(a,b)
			return a.freq==b.freq and a.depth<b.depth or a.freq<b.freq
		end)
		fInsert(tTree,{depth=fMax(tTree[1].depth,tTree[2].depth)+1,freq=tTree[1].freq+tTree[2].freq,contains={tTree[1],tTree[2]}})
		fRemove(tTree,1)
		fRemove(tTree,1)
	end
	tKey = fSetBits(tTree[1])
	
	
	--encode--
	sInter = fDecToBin(iCount)
	for k,v in next, tKey do
		sInter = sInter..fDecToBin(#v)
	end
	for k,v in next, tKey do
		sInter = sInter..fDecToBin(k)..v
	end
	for _,v in next, tData do
		sInter = sInter..tKey[v]
	end
	sInter = ("0"):rep(8 - ((#sInter%8)+1)).."1"..sInter
	while #sInter>=8 do
		fInsert(tSolution,tonumber(sInter:sub(1,8),2))
		sInter = sInter:sub(9,#sInter)
	end
	
	--finalize--
	return tSolution
end

local function fUnHuffman(tData)
	
	--setup--
	local sInter = ""
	local sBuild = ""
	local tSolution = {}
	local tKeys = {}
	local iCount
	
	
	--key table--
	for k,v in next, tData do
		sInter = sInter..fDecToBin(v)
	end
	while sInter:sub(1,1)=="0" do
		sInter = sInter:sub(2,#sInter)
	end
	iCount = tonumber(sInter:sub(2,9),2)
	sInter = sInter:sub(10,#sInter)
	for i=1,iCount do
		tKeys[i] = tonumber(sInter:sub(1,8),2)
		sInter = sInter:sub(9,#sInter)
	end
	for i=1,iCount do
		tKeys[sInter:sub(9,8+tKeys[i])] = tonumber(sInter:sub(1,8),2)
		sInter = sInter:sub(tKeys[i]+9,#sInter)
		tKeys[i] = nil
	end
	
	
	--decode--
	while #sInter>0 do
		sBuild = sBuild..sInter:sub(1,1)
		if tKeys[sBuild] then
			fInsert(tSolution,tKeys[sBuild])
			sBuild = ""
		end
		sInter = sInter:sub(2,#sInter)
	end
	
	
	--finalize--
	return tSolution
end

--paintcan header functions--
function fSetHeader(tData,iLength,bAnim,tCutPoints,iFrames)
	
	--setup--
	local sInter
	local sHeader = fDecToBin(iLength)
	
	
	--encode--
	sHeader = (bAnim and "1" or "0")..fDecToBin(#sHeader/8):sub(2,8)..sHeader
	if bAnim then
		sInter = fDecToBin(iFrames)
		sHeader = sHeader..fDecToBin(#sInter/8)..sInter
	end
	for _,v in next,tCutPoints do
		sInter = fDecToBin(v[1])
		sHeader = sHeader..fDecToBin(#sInter/8)..sInter
		sInter = fDecToBin(v[2])
		sHeader = sHeader..(iLength>255 and fDecToBin(#sInter/8) or "")..sInter
	end
	for i=#sHeader,8,-8 do
		fInsert(tData,1,tonumber(sHeader:sub(i-7,i),2))
	end
	
	
	--finalize--
	return tData
end

function fGetHeader(tData)

	--setup--
	local sBytes
	local tCutPoints = {}
	local iLength,bAnim,iFrames
	
	
	--decode--
	sBytes = fDecToBin(fRemove(tData,1))
	bAnim = sBytes:sub(1,1)=="1"
	iLength = tonumber(sBytes:sub(2,8),2)
	sBytes = ""
	for i=1,iLength do
		sBytes = sBytes..fDecToBin(fRemove(tData,1))
	end
	iLength = tonumber(sBytes,2)
	if bAnim then
		local cut = fDecToBin(fRemove(tData,1))
		iFrames = tonumber(cut,2)
		sBytes = ""
		for i=1,iFrames do
			sBytes = sBytes..fDecToBin(fRemove(tData,1))
		end
		iFrames = tonumber(sBytes,2)
	end
	for i=1,3+(bAnim and (iFrames-1)*3 or 0) do
		fInsert(tCutPoints,{})
		local cut=fDecToBin(fRemove(tData,1))
		tCutPoints[#tCutPoints][1] = tonumber(cut,2)
		sBytes = ""
		for i=1,tCutPoints[#tCutPoints][1] do
			sBytes = sBytes..fDecToBin(fRemove(tData,1))
		end
		tCutPoints[#tCutPoints][1] = tonumber(sBytes,2)
		
		if iLength>255 then
			tCutPoints[#tCutPoints][2] = tonumber(fDecToBin(fRemove(tData,1)),2)
			sBytes = ""
			for i=1,tCutPoints[#tCutPoints][2] do
				sBytes = sBytes..fDecToBin(fRemove(tData,1))
			end
			tCutPoints[#tCutPoints][2] = tonumber(sBytes,2)
		else
			local cut=fDecToBin(fRemove(tData,1))
			tCutPoints[#tCutPoints][2] = tonumber(cut,2)
		end
	end
	
	--finalize--
	return tData,iLength,bAnim,tCutPoints,iFrames
end


--API functions--
function encode(bAnim,...)

	--setup--
	local tInter = {}
	local tHuff = {}
	local tArg = {}
	local tCutPoints = {}
	local iLength, iCut
	local sOutput = ""
	
	
	--encode--
	if not bAnim then
		tArg = {...}
	else
		for _,v in next,{...} do
			fInsert(tArg,v[1])
			fInsert(tArg,v[2])
			fInsert(tArg,v[3])
		end
	end
	iLength = #tArg[1]
	for k,v in next, tArg do
		fInsert(tCutPoints,{})
		v = fShallowCopy(v)
		if k%3==0 then
			v = fTblCharToDec(v)
			v = fMTF(v)
			iCut, v = fBWT(v)
			tCutPoints[k][2] = iCut
			v = fSRLE(v)
		else
			v = fTblHexToDec(v)
			iCut, v = fBWT(v)
			tCutPoints[k][2] = iCut
			v = fCRLE(v)
		end
		for x,y in next, v do
			fInsert(tInter,y)
		end
		tCutPoints[k][1] = #tInter
	end
	tInter = fSetHeader(tInter,iLength,bAnim,tCutPoints,#({...}))
	tInter = fSRLE(tInter)
	tInter = fMTF(tInter)
	tHuff = fHuffman(tInter)
	if #tHuff<#tInter then
		tInter = tHuff
		fInsert(tInter,1)
	else
		fInsert(tInter,0)
	end
	tInter = fTblDecToChar(tInter)
	
	for k,v in next, tInter do
		sOutput = sOutput..v
	end
	
	
	--finalize--
	return sOutput
end

function decode(sData)
	
	--setup--
	local tOutput = {}
	local tFrames = {}
	local iLength,bAnim,tCutPoints,iFrames
	
	
	--decode--
	for i=1,#sData do
		tOutput[i] = sData:sub(1,1)
	end
	tOutput = fTblCharToDec(tOutput)
	tOutput = fRemove(tOutput,1)==1 and tOutput or fUnHuffman(tOutput)
	tOutput = fUnMTF(tOutput)
	tOutput = fUnSRLE(tOutput)
	tOutput,iLength,bAnim,tCutPoints,iFrames = fGetHeader(tOutput)
	
end









