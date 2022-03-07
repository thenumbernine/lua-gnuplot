package = "gnuplot"
version = "dev-1"
source = {
   url = "git+https://github.com/thenumbernine/lua-gnuplot"
}
description = {
   summary = "gnuplot wrapper",
   detailed = "gnuplot wrapper",
   homepage = "https://github.com/thenumbernine/lua-gnuplot",
   license = "MIT"
}
dependencies = {
	'lua >= 5.1',
}
build = {
   type = "builtin",
   modules = {
      gnuplot = "gnuplot.lua"
   }
}
