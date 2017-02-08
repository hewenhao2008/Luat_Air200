module(...,package.seeall)
local link = require"link"
local misc = require"misc"

local FREQ,prot,addr,port,lid = 1800000
local DBG_FILE,resinf,inf,luaerr,d1,d2 = "/dbg.txt",""

local function readtxt(f)
	local file,rt = io.open(f,"r")
	if file == nil then
		print("dbg can not open file",f)
		return ""
	end
	rt = file:read("*a")
	file:close()
	return rt
end

local function writetxt(f,v)
	local file = io.open(f,"w")
	if file == nil then
		print("dbg open file to write err",f)
		return
	end
	file:write(v)
	file:close()
end

local function writepara()
	if resinf then
		print("dbg_w",resinf)
		writetxt(DBG_FILE,resinf)
	end
end

local function initpara()
	inf = readtxt(DBG_FILE) or ""
	print("dbg inf",inf)
end

local function getlasterr()
	luaerr = readtxt("/luaerrinfo.txt") or ""
end

local function valid()
	return ((string.len(luaerr) > 0) or (string.len(inf) > 0)) and _G.PROJECT
end

local function rcvtimeout()
	endntfy()
	link.close(lid)
end

local function snd()
	local data = (luaerr or "") .. (inf or "")
	if string.len(data) > 0 then
		link.send(lid,_G.PROJECT .. "," .. (_G.VERSION and (_G.VERSION .. ",") or "") .. misc.getimei() .. "," .. data)
		sys.timer_start(snd,FREQ)
		sys.timer_start(rcvtimeout,20000)
	end
end

local rests = ""

local reconntimes = 0
local function reconn()
	if reconntimes < 3 then
		reconntimes = reconntimes+1
		link.connect(lid,prot,addr,port)
	else
		endntfy()
	end
end

function endntfy()
	sys.dispatch("DBG_END_IND")
	sys.timer_stop(sys.dispatch,"DBG_END_IND")
end

local function notify(id,evt,val)
	print("dbg notify",id,evt,val)
	if id ~= lid then return end
	if evt == "CONNECT" then
		if val == "CONNECT OK" then
			sys.timer_stop(reconn)
			reconntimes = 0
			rests = ""
			snd()
		else
			sys.timer_start(reconn,5000)
		end
	elseif evt == "STATE" and val == "CLOSED" then
		link.close(lid)
	end
end

local function recv(id,data)
	if string.upper(data) == "OK" then
		sys.timer_stop(snd)
		link.close(lid)
		resinf = ""
		inf = ""
		writepara()
		luaerr = ""
		os.remove("/luaerrinfo.txt")
		endntfy()
		sys.timer_stop(rcvtimeout)
	end
end

local function init()
	initpara()
	getlasterr()
	if valid() then
		lid = link.open(notify,recv,"dbg")
		link.connect(lid,prot,addr,port)
		sys.dispatch("DBG_BEGIN_IND")
		sys.timer_start(sys.dispatch,120000,"DBG_END_IND")
	end
end

function restart(r)
	resinf = "RST:" .. r .. ";"
	writepara()
	rtos.restart()
end

function setup(inProt,inAddr,inPort)
	if inProt and inAddr and inPort then
		prot,addr,port = inProt,inAddr,inPort
		init()
	end
end
