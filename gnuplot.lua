local file = require 'ext.file'
local table = require 'ext.table'

local function gnuplot(args)
	local cmds = table()
	cmds:insert('set terminal png size 800,600')
	cmds:insert("set output '"..args.output.."'")
	if args.logx then cmds:insert('set log x') end
	if args.logy then cmds:insert('set log y') end
	if args.logxy then cmds:insert('set log xy') end
	if args.xlabel then cmds:insert(('set xlabel %q'):format(args.xlabel)) end
	if args.ylabel then cmds:insert(('set ylabel %q'):format(args.ylabel)) end
	if args.title then cmds:insert(('set title %q'):format(args.title)) end
	if args.style then cmds:insert('set style '..args.style) end
	if args.samples then cmds:insert('set samples '..args.samples) end
	for i=1,#args do
		if type(args[i]) == 'string' then
			cmds:insert(args[i])
		end
	end
	local plotcmds = table()
	local datafilename = 'data.txt'
	for i=1,#args do
		if type(args[i]) == 'table' then
			local plot = args[i]
			local plotcmd = plot.using and ("'"..datafilename.."' using "..plot.using)
				or plot[1]
			for k,v in pairs(plot) do
				if type(k) == 'string'
				and k ~= 'using'
				then
					if k == 'title' then v = ('%q'):format(v) end
					plotcmd = plotcmd..' '..k..' '..v
				end
			end
			plotcmds:insert(plotcmd)
		end
	end
	cmds:insert('plot '..plotcmds:concat(', '))
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

	local cmdsfilename = 'cmds.txt'
	file[cmdsfilename] = cmds:concat('\n')
	file[datafilename] = data:concat()
	
	os.execute('gnuplot '..cmdsfilename)

	file[cmdsfilename] = nil
	file[datafilename] = nil
end

return gnuplot
