--
-- Copyright (C) 2013 Masatoshi Teruya
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
-- fsrouter.lua
-- lua-fsrouter
-- Created by Masatoshi Teruya on 13/03/15.
--
-- modules
local error = error
local format = string.format
local gsub = string.gsub
local setmetatable = setmetatable
local categorizer = require('fsrouter.categorizer')
local default_compiler = require('fsrouter.default').compiler
local default_loadfenv = require('fsrouter.default').loadfenv
local isa = require('isa')
local is_string = isa.string
local is_table = isa.table
local is_function = isa.Function
--- @class BaseDir
--- @field new function
--- @field readdir function
local basedir = require('basedir')
--- @class Plut
--- @field new function
--- @field set function
--- @field lookup function
local plut = require('plut')

--- traverse
--- @param trim_extensions table<string, boolean>
--- @param routes table[]
--- @param rootdir BaseDir
--- @param dirname string
--- @param compiler function
--- @param loadfenv function
--- @param filters table[]
--- @return table[] routes
--- @return string err
local function traverse(trim_extensions, routes, rootdir, dirname, compiler,
                        loadfenv, filters)
    local entries, err = rootdir:readdir(dirname)

    -- failed to readdir
    if err then
        return nil, format('failed to readdir %s: %s', dirname, err)
    end

    -- use segments starting with '$' as parameter segments
    dirname = gsub(dirname, '/%$', {
        ['/$'] = '/:',
    })

    -- read file entries
    local c = categorizer.new(trim_extensions, compiler, loadfenv, filters)
    local ok
    for _, stat in ipairs(entries.reg or {}) do
        ok, err = c:categorize(stat)
        if not ok then
            return nil, err
        end
    end

    -- add the pathname/value pairs to the routes
    for _, route in ipairs(c:finalize()) do
        local rpath = dirname

        if route.name ~= 'index' then
            rpath = gsub(rpath, '/$', '')
            rpath = rpath .. '/' .. route.name
        end
        route.rpath = rpath

        routes[#routes + 1] = {
            rpath = rpath,
            route = route,
        }
    end

    -- traverse directories
    for _, stat in ipairs(entries.dir or {}) do
        _, err = traverse(trim_extensions, routes, rootdir, stat.rpath,
                          compiler, loadfenv, c.filters)
        if err then
            return nil, err
        end
    end

    return routes
end

--- @class FSRouter
--- @field routes Plut
local FSRouter = {}
FSRouter.__index = FSRouter

--- lookup
--- @param pathname string
--- @return table route
--- @return error err
--- @return table glob
function FSRouter:lookup(pathname)
    return self.routes:lookup(pathname)
end

--- new
--- @param pathname string
--- @param opts table
--- @return FSRouter router
--- @return string err
--- @return table[] routes
local function new(pathname, opts)
    opts = opts or {}
    if opts.compiler ~= nil and not is_function(opts.compiler) then
        error('opts.compiler must be function', 2)
    elseif opts.loadfenv ~= nil and not is_function(opts.loadfenv) then
        error('opts.loadfenv must be function', 2)
    elseif opts.trim_extensions == nil then
        opts.trim_extensions = {
            '.html',
            '.htm',
        }
    elseif not is_table(opts.trim_extensions) then
        error('opts.trim_extensions must be table', 2)
    end

    -- convert list to key/value format
    local trim_extentions = {}
    for i, v in ipairs(opts.trim_extentions) do
        if not is_string(v) then
            error(format('opts.trim_extentions#%d must be table', i), 2)
        end
        trim_extentions[v] = true
    end

    local rootdir = basedir.new(pathname, opts)
    local routes, err = traverse(trim_extensions, {}, rootdir, '/',
                                 opts.compiler or default_compiler,
                                 opts.loadfenv or default_loadfenv)
    if err then
        return nil, err
    end

    -- register the url to the router
    local router = plut.new()
    for _, v in ipairs(routes) do
        local ok, serr = router:set(v.rpath, v.route)
        if not ok then
            return nil, format('failed to set route %q: %s', v.rpath, serr)
        end
    end

    return setmetatable({
        routes = router,
    }, FSRouter), nil, routes
end

return {
    new = new,
}
