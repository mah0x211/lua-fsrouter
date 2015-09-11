package = "router"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-router.git"
}
description = {
    summary = "url router",
    homepage = "https://github.com/mah0x211/lua-router",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "halo >= 1.1.7",
    "rootdir >= 1.0.2",
    "usher"
}
build = {
    type = "builtin",
    modules = {
        router = "router.lua"
    }
}
