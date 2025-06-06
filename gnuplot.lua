local path = require 'ext.path'
local table = require 'ext.table'
local class = require 'ext.class'
local range = require 'ext.range'

--[[
local function findfile(prefix, suffix)
	-- if you have more than 100 plots running in tandem then you are out of luck.
	for i=1,100 do
		local fn = prefix..'.'..i..'.'..suffix
		local f = io.open(fn,  ... TODO how to create if not exists and fail if exists? to prevent race conditions ...
	end
end
--]]

-- default serialization for gnuplot "data" and "griddata"
local function defaultdatatostring(x)
	if type(x) == 'string' then
		return ('%q'):format(x)
	else
		return tostring(x)
	end
end

local GNUPlot = class()

function GNUPlot:__call(args)
	local persist = args.persist

	--[[
	use this for custom serialization
	especially for serializing numbers at higher-than-default precision
	right now this is used for serializing "data" and "griddata"
	--]]
	local datatostring = args.tostring or defaultdatatostring

	local cmds = table()
	if not persist then
		local terminal = args.terminal or 'png size 800,600'
		cmds:insert('set terminal '..terminal)
		cmds:insert("set output '"..assert(args.output).."'")
	end
	if args.log then cmds:insert('set log '..args.log) end

	-- for these fields, 
	-- if it's a string then quote it
	-- if it's a table then concat and append 
	-- ... hmm ...  this is to preserve old behavior of quoting the arg, while supporting non-quoted values ... 
	-- overall seems dumb.
	for _,k in ipairs{'key', 'title', 'label', 'xlabel', 'ylabel', 'zlabel', 'cblabel'} do
		local v = args[k]
		local tv = type(v)
		if tv == 'nil' then
		elseif tv == 'string' then
			cmds:insert(('set %s %q'):format(k, v))
		elseif tv == 'table' then
			cmds:insert('set '..k..' '..table.concat(v, ' '))
		else
			error("idk how to handle type "..tv..' for key '..k)
		end
	end
	
	if args.border then cmds:insert('set border '..args.border) end
	if args.style then
		if type(args.style) == 'table' then
			for _,style in ipairs(args.style) do
				cmds:insert('set style '..style)
			end
		else
			cmds:insert('set style '..args.style)
		end
	end
	if args.parametric then cmds:insert('set parametric') end
	if args.samples then cmds:insert('set samples '..args.samples) end
	if args.view then cmds:insert('set view '..args.view) end
	if args.contour then cmds:insert('set contour'..(args.contour == true and '' or ' '..args.contour)) end
	if args.isosamples then cmds:insert('set isosamples'..(args.isosamples == true and '' or ' '..args.isosamples)) end
	if args.cntrparam then cmds:insert('set cntrparam '..args.cntrparam) end
	if args.pm3d then cmds:insert('set pm3d'..(args.pm3d == true and '' or ' '..args.pm3d)) end
	if args.dgrid3d then cmds:insert('set dgrid3d'..(args.dgrid3d == true and '' or ' '..args.dgrid3d)) end
	if args.palette then cmds:insert('set palette '..args.palette) end
	if args.datafile then cmds:insert('set datafile '..args.datafile) end
	if args.grid then cmds:insert('set grid '..args.grid) end
	if args.tics then cmds:insert('set tics '..args.tics) end
	if args.xtics then cmds:insert('set xtics '..args.xtics) end
	if args.ytics then cmds:insert('set ytics '..args.ytics) end
	if args.ztics then cmds:insert('set ztics '..args.ztics) end
	if args.x2tics then cmds:insert('set x2tics '..args.x2tics) end
	if args.y2tics then cmds:insert('set y2tics '..args.y2tics) end
	if args.mxtics then cmds:insert('set mxtics '..args.mxtics) end
	if args.mytics then cmds:insert('set mytics '..args.mytics) end
	if args.cbtics then cmds:insert('set cbtics '..args.cbtics) end
	if args.boxwidth then cmds:insert('set boxwidth '..args.boxwidth) end
	if args.xdata then cmds:insert('set xdata '..args.xdata) end
	if args.ydata then cmds:insert('set ydata '..args.ydata) end
	if args.timefmt then cmds:insert('set timefmt '..('%q'):format(args.timefmt)) end
	if args.format then
		for k,v in pairs(args.format) do
			cmds:insert('set format '..k..' '..('%q'):format(v))
		end
	end
	if args.nokey then cmds:insert'set nokey' end
	if args.notitle then cmds:insert'set notitle' end

	for _,letter in ipairs{'x', 'y', 'z', 't', 'u', 'v', 'cb'} do
		local field = letter..'range'
		local value = args[field]
		if value then
			local cmd = 'set '..field .. ' [' .. (value[1] or '') .. ':' .. (value[2] or '') .. ']'
			if value[3] then
				cmd = cmd .. ' ' .. value[3]
			end
			cmds:insert(cmd)
		end
	end

	if args.unset then
		for _,cmd in ipairs(args.unset) do
			cmds:insert('unset '..cmd)
		end
	end
	for i=1,#args do
		if type(args[i]) == 'string' then
			cmds:insert(args[i])
		end
	end
	local plotcmds = table()
	local splotcmds = table()
	--local datafilename = '___tmp.gnuplot.data.txt'	-- has collisions ...
	--local datafilename = findfile('___tmp.gnuplot.data', 'txt') -- Lua has no function for create-only-if-not-present ... like python's open"wx" ... so this will have collisions too.
	--local datafilename = os.tmpfile()	-- has no filename, and by design, so other processes cannot see it: https://en.cppreference.com/w/c/io/tmpfile
	local datafilename = os.tmpname() -- is buggy on Windows.
	for i=1,#args do
		if type(args[i]) == 'table' then
			local plot = args[i]
			local plotdatafile
			if plot.datafile then
				plotdatafile = plot.datafile
			elseif plot.using then
				plotdatafile = datafilename
			end
			local j=1
			local plotcmd
			if plotdatafile then
				if type(plotdatafile) == 'table' then
					plotcmd =  table.concat(plotdatafile, ' ')
				else
					plotcmd =  "'"..plotdatafile.."'"
				end
				if plot.using then plotcmd = plotcmd .. " using "..plot.using end
			else
				plotcmd = plot[j] j=j+1
			end

			for k,v in pairs(plot) do
				if type(k) == 'string'
				and k ~= 'using'
				and k ~= 'splot'
				and k ~= 'datafile'
				and k ~= 'palette'
				then
					if k == 'title' then
						if type(v) == 'string' then
							v = ('%q'):format(v)
						elseif type(v) == 'table' then
							v = table.concat(v, ' ')
						end
					end
					if v == true then
						plotcmd = plotcmd..' '..k
					else
						plotcmd = plotcmd..' '..k..' '..v
					end
				end
			end
			if plot.palette then
				plotcmd = plotcmd .. ' palette'
			end
			if plot.splot then
				splotcmds:insert(plotcmd)
			else
				plotcmds:insert(plotcmd)
			end
			-- add the rest last
			for k=j,#plot do
				plotcmds:insert(plot[j])
			end
		end
	end

	if #plotcmds > 0 then cmds:insert('plot '..plotcmds:concat(', ')) end
	if #splotcmds > 0 then cmds:insert('splot '..splotcmds:concat(', ')) end
	if persist then
		cmds:insert'pause -1'
	end

	-- without this there's a memory leak bug in later gnuplot versions
	-- https://stackoverflow.com/questions/18654966/how-can-i-prevent-gnuplot-from-eating-my-memory
	cmds:insert'set output'

	local cmdsfilename = self:getCmdTmpName()
	path(cmdsfilename):write(cmds:concat('\n'))

	if args.data then
		local data = table()
		local numcols = range(#args.data):map(function(i) return #args.data[i] end):sup() or 0
		for i=1,numcols do
			local sep = ''
			for j=1,#args.data do
				data:insert(sep..datatostring(args.data[j][i]))
				sep = '\t'
			end
			data:insert('\n')
		end
		path(datafilename):write(data:concat())
	end

	if args.griddata then
		local data = table()
		for i,x in ipairs(args.griddata.x) do
			for j,y in ipairs(args.griddata.y) do
				data:insert(x..'\t'..y)
				for k=1,#args.griddata do
					data:insert('\t'..datatostring(args.griddata[k][i][j]))
				end
				data:insert('\n')
			end
			data:insert('\n')
		end
		path(datafilename):write(data:concat())
	end

	-- some gnuplot errors are errors, some are just warnings ...
	local cmdlineargs = table{'gnuplot'}
	if persist then
		cmdlineargs:insert'-p'
	end
	cmdlineargs:insert(cmdsfilename)
	local cmd = cmdlineargs:concat' '

	local results = table.pack(self:exec(cmd))
	if args.warnOnErrors then
		if results[1] then
			io.stderr:write('cmds:\n'
				..require 'template.showcode'(path(cmdsfilename):read())..'\n'
				..'failed with error:\n'
				..tostring(results[1])..'\n'
				..tostring(results[2])..'\n')
		end
	end

	if args.savecmds then path(args.savecmds):write(path(cmdsfilename):read()) end
	if args.savedata then path(args.savedata):write(path(datafilename):read()) end

	-- TODO xpcall to ensure these are deleted?
	path(cmdsfilename):remove()
	path(datafilename):remove()

	return results:unpack()
end

function GNUPlot:getCmdTmpName()
	--return '___tmp.gnuplot.cmds.txt'
	return os.tmpname()
end

function GNUPlot:exec(cmd)
	return os.execute(cmd)
end

return GNUPlot()
