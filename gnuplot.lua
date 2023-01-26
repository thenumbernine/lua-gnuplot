local file = require 'ext.file'
local table = require 'ext.table'
local range = require 'ext.range'

-- default serialization for gnuplot "data" and "griddata"
local function defaultdatatostring(x)
	if type(x) == 'string' then
		return ('%q'):format(x)
	else
		return tostring(x)
	end
end

local function gnuplot(args)
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
	if args.xlabel then cmds:insert(('set xlabel %q'):format(args.xlabel)) end
	if args.ylabel then cmds:insert(('set ylabel %q'):format(args.ylabel)) end
	if args.zlabel then cmds:insert(('set zlabel %q'):format(args.zlabel)) end
	if args.cblabel then cmds:insert(('set cblabel %q'):format(args.cblabel)) end
	if args.title then cmds:insert(('set title %q'):format(args.title)) end
	if args.key then cmds:insert(('set key %s'):format(args.key)) end
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
	if args.palette then cmds:insert('set palette '..args.palette) end
	if args.datafile then cmds:insert('set datafile '..args.datafile) end
	if args.tics then cmds:insert('set tics '..args.tics) end
	if args.xtics then cmds:insert('set xtics '..args.xtics) end
	if args.ytics then cmds:insert('set ytics '..args.ytics) end
	if args.ztics then cmds:insert('set ztics '..args.ztics) end
	if args.x2tics then cmds:insert('set x2tics '..args.x2tics) end
	if args.y2tics then cmds:insert('set y2tics '..args.y2tics) end
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
	local datafilename = '___tmp.gnuplot.data.txt'
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
				plotcmd =  "'"..plotdatafile.."'"
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
					if k == 'title' then v = ('%q'):format(v) end
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

	local cmdsfilename = '___tmp.gnuplot.cmds.txt'
	file(cmdsfilename):write(cmds:concat('\n'))

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
		file(datafilename):write(data:concat())
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
		file(datafilename):write(data:concat())
	end

	-- some gnuplot errors are errors, some are just warnings ...
	local cmdlineargs = table{'gnuplot'}
	if persist then
		cmdlineargs:insert'-p'
	end
	cmdlineargs:insert(cmdsfilename)
	local cmd = cmdlineargs:concat' '

	local results = {os.execute(cmd)}
	if args.warnOnErrors and results[1] then
		io.stderr:write('cmds:\n'
			..require 'template.showcode'(file(cmdsfilename):read())..'\n'
			..'failed with error:\n'
			..tostring(results[1])..'\n'
			..tostring(results[2])..'\n')
	end

	if args.savecmds then file(args.savecmds):write(file(cmdsfilename):read()) end
	if args.savedata then file(args.savedata):write(file(datafilename):read()) end

	file(cmdsfilename):remove()
	file(datafilename):remove()
end

return gnuplot
