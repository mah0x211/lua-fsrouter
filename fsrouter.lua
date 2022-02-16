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
local concat = table.concat
local error = error
local format = string.format
local gsub = string.gsub
local setmetatable = setmetatable
local new_categorizer = require('fsrouter.categorizer').new
local default_compiler = require('fsrouter.default').compiler
local default_loadfenv = require('fsrouter.default').loadfenv
local new_mediatypes = require('mediatypes').new
local new_plut = require('plut').new
local new_regex = require('regex').new
local basedir = require('basedir')
local extname = require('extname')
local isa = require('isa')
local is_boolean = isa.boolean
local is_string = isa.string
local is_table = isa.table
local is_function = isa.Function

-- init for libmagic
local Magic
do
    local libmagic = require('libmagic')
    Magic = libmagic.open(libmagic.MIME_ENCODING, libmagic.NO_CHECK_COMPRESS,
                          libmagic.SYMLINK)
    Magic:load()
end

--- get_charset
---@param pathname string
---@return string charset
local function get_charset(pathname)
    return Magic:file(pathname)
end

--- traverse
--- @param ctx table<string, boolean>
--- @param routes table[]
--- @param dirname string
--- @param filters table[]
--- @return table[] routes
--- @return string err
local function traverse(ctx, routes, dirname, filters)
    local dir, oerr = ctx.rootdir:opendir(dirname)

    -- failed to readdir
    if oerr then
        return nil, format('failed to traverse %s: %s', dirname, oerr)
    elseif not dir then
        return routes
    end

    local dentries = {}
    local c = new_categorizer(ctx.trim_extensions, ctx.compiler, ctx.loadfenv,
                              filters)
    -- read file entries
    local entry, rerr = dir:readdir()
    while entry do
        if not ctx.re_ignore:test(entry) then
            local stat, serr = ctx.rootdir:stat(dirname .. '/' .. entry)

            if serr then
                return nil, format('failed to traverse %s: %s', dirname, serr)
            elseif stat then
                local ext = extname(stat.rpath)

                stat.entry = entry
                stat.ext = ext
                stat.mime = ext and ctx.mime:getmime(gsub(ext, '^.', ''))
                stat.charset = get_charset(stat.pathname)
                if stat.type == 'directory' then
                    dentries[#dentries + 1] = stat
                else
                    local ok, cerr = c:categorize(stat)
                    if not ok then
                        return nil, cerr
                    end
                end
            end
        end

        entry, rerr = dir:readdir()
    end
    if rerr then
        return nil, format('failed to traverse %s: %s', dirname, rerr)
    end

    -- use segments starting with '$' as parameter segments
    dirname = gsub(dirname, '/%$', {
        ['/$'] = '/:',
    })
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
    for _, stat in ipairs(dentries) do
        local _, err = traverse(ctx, routes, stat.rpath, c.filters)
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
    if not is_string(pathname) then
        error('pathname must be string', 2)
    elseif not is_table(opts) then
        error('opts must be table', 2)
    elseif opts.follow_symlink ~= nil and not is_boolean(opts.follow_symlink) then
        error('opts.follow_symlink must be boolean', 2)
    elseif opts.trim_extensions ~= nil and not is_table(opts.trim_extensions) then
        error('opts.trim_extensions must be table', 2)
    elseif opts.mimetypes ~= nil and not is_string(opts.mimetypes) then
        error('opts.mimetypes must be string')
    elseif opts.ignore ~= nil and not is_table(opts.ignore) then
        error('opts.ignore must be table', 2)
    elseif opts.loadfenv ~= nil and not is_function(opts.loadfenv) then
        error('opts.loadfenv must be function', 2)
    elseif opts.compiler ~= nil and not is_function(opts.compiler) then
        error('opts.compiler must be function', 2)
    end

    local ctx = {
        rootdir = basedir.new(pathname, opts.follow_symlink == true),
        mime = new_mediatypes(opts.mimetypes),
        trim_extensions = {},
        compiler = opts.compiler or default_compiler,
        loadfenv = opts.loadfenv or default_loadfenv,
    }
    -- convert list to key/value format
    for i, v in ipairs(opts.trim_extensions or {
        '.html',
        '.htm',
    }) do
        if not is_string(v) then
            error(format('opts.trim_extensions#%d must be table', i), 2)
        end
        ctx.trim_extensions[v] = true
    end

    -- set ignoreRegex list
    local ignore = {
        -- default ignore pattern
        '^[.].*$',
    }
    for i, pattern in ipairs(opts.ignore or {}) do
        if not is_string(pattern) then
            error(format('opts.ignore#%d must be string', i), 2)
        end
        -- evalulate
        local _, err = new_regex(pattern, 'i')
        if err then
            error(format('opts.ignore#%d cannot be compiled: %s', i, err), 2)
        end

        ignore[#ignore + 1] = pattern
    end
    -- compile patterns
    local pattern = '(?:' .. concat(ignore, '|') .. ')'
    local err
    ctx.re_ignore, err = new_regex(pattern, 'i')
    if err then
        error(format('opts.ignore: %q: %s', pattern, err), 2)
    end

    -- traverse the directories under the base directory
    local routes
    routes, err = traverse(ctx, {}, '/')
    if err then
        return nil, err
    end

    -- register the url to the router
    local router = new_plut()
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
