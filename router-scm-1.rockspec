package = "router"
version = "scm-1"
source = {
    url = "https://github.com/mah0x211/lua-router.git"
}
description = {
    summary = "URL dispatcher",
    detailed = [[]],
    homepage = "https://github.com/mah0x211/lua-router", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "util"
}
build = {
    type = "builtin",
    modules = {
        router = "router.lua"
    }
}
