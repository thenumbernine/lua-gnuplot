local file = require 'ext.file'
local table = require 'ext.table'

local function gnuplot(args)
	local cmds = table()
	cmds:insert('set terminal png size 800,600')
	cmds:insert("set output '"..args.output.."'")
	if args.log then cmds:insert('set log '..args.log) end
	if args.xlabel then cmds:insert(('set xlabel %q'):format(args.xlabel)) end
	if args.ylabel then cmds:insert(('set ylabel %q'):format(args.ylabel)) end
	if args.zlabel then cmds:insert(('set zlabel %q'):format(args.zlabel)) end
	if args.cblabel then cmds:insert(('set cblabel %q'):format(args.cblabel)) end
	if args.title then cmds:insert(('set title %q'):format(args.title)) end
	if args.style then cmds:insert('set style '..args.style) end
	if args.samples then cmds:insert('set samples '..args.samples) end
	if args.view then cmds:insert('set view '..args.view) end
	if args.contour then cmds:insert('set contour') end
	if args.datafile then cmds:insert('set datafile '..args.datafile) end
	for i=1,#args do
		if type(args[i]) == 'string' then
			cmds:insert(args[i])
		end
	end
	local plotcmds = table()
	local splotcmds = table()
	local datafilename = 'data.txt'
	local griddatafilename = 'griddata.txt'
	for i=1,#args do
		if type(args[i]) == 'table' then
			local plot = args[i]
			local plotdatafile
			if plot.datafile then
				plotdatafile = plot.datafile
			elseif plot.using then
				plotdatafile = plot.splot and griddatafilename or datafilename
			end
			local plotcmd
			if plotdatafile then
				plotcmd =  "'"..plotdatafile.."'"
				if plot.using then plotcmd = plotcmd .. " using "..plot.using end
			else
				plotcmd = plot[1]
			end
			
			for k,v in pairs(plot) do
				if type(k) == 'string'
				and k ~= 'using'
				and k ~= 'splot'
				and k ~= 'datafile'
				and k ~= 'palette'
				then
					if k == 'title' then v = ('%q'):format(v) end
					plotcmd = plotcmd..' '..k..' '..v
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
		end
	end
	if #plotcmds > 0 then cmds:insert('plot '..plotcmds:concat(', ')) end
	if #splotcmds > 0 then cmds:insert('splot '..splotcmds:concat(', ')) end
	local cmdsfilename = 'cmds.txt'
	file[cmdsfilename] = cmds:concat('\n')

	if args.data then
		local data = table()
		local numcols = range(#args.data):map(function(i) return #args.data[i] end):sup() or 0
		for i=1,numcols do
			local sep = ''
			for j=1,#args.data do
				data:insert(sep..(args.data[j][i] or '-'))
				sep = '\t'
			end
			data:insert('\n')
		end
		file[datafilename] = data:concat()
	end

	if args.griddata then
		local data = table()
		for i,x in ipairs(args.griddata.x) do
			for j,y in ipairs(args.griddata.y) do
				data:insert(x..'\t'..y)
				for k=1,#args.griddata do
					data:insert('\t'..args.griddata[k][i][j])
				end
				data:insert('\n')
			end
			data:insert('\n')
		end
		file[griddatafilename] = data:concat()
	end

	-- some gnuplot errors are errors, some are just warnings ...
	--if not 
	os.execute('gnuplot '..cmdsfilename) 
	--then
	--	error('cmds:\n'..file[cmdsfilename]:trim():split'\n':map(function(l,i) return i..':\t'..l end):concat'\n')
	--end

	file[cmdsfilename] = nil
	file[datafilename] = nil
	file[griddatafilename] = nil
end

return gnuplot
