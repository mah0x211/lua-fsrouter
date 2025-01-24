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
local type = type
local pcall = pcall
local errorf = require('error').format
local default_precheck = require('fsrouter.default').precheck
local readdir = require('fsrouter.readdir')

--- @class plut
--- @field set fun(self, pathname:string, data:any):(ok:boolean, err:any)
--- @field lookup fun(self, pathname:string):(data:any, err:any, glob:table)

local plut = require('plut')
local new_plut = plut.new --- @type fun():plut

--- @class fsrouter
--- @field router plut
local FSRouter = {}

--- new
--- @param pathname string
--- @param opts table?
--- @return fsrouter? router
--- @return any err
--- @return table[]? routes
function FSRouter:init(pathname, opts)
    opts = opts or {}
    if type(pathname) ~= 'string' then
        error('pathname must be string', 2)
    elseif type(opts) ~= 'table' then
        error('opts must be table', 2)
    elseif opts.precheck ~= nil and not pcall(function()
        assert(type(opts.precheck) == 'function')
    end) then
        error('opts.precheck must be function', 2)
    elseif opts.router ~= nil and not pcall(function()
        -- check the router methods
        assert(type(opts.router.set) == 'function')
        assert(type(opts.router.lookup) == 'function')
    end) then
        error('opt.router must has set() and lookup() methods', 2)
    end

    local router = opts.router or new_plut()
    local user_precheck = opts.precheck or default_precheck
    opts.precheck = function(route)
        -- register the url to the router
        local ok, err = router:set(route.rpath, route)
        if not ok then
            return false, errorf('failed to set route %q', route.rpath, err)
        end

        -- user precheck
        ok, err = user_precheck(route)
        if not ok then
            return false, errorf('failed to precheck %q', route.rpath, err)
        end
        return true
    end

    -- read a pathname directory and create a routing table
    local routes, err = readdir(pathname, opts)
    opts.precheck = user_precheck
    if err then
        return nil, err
    end

    self.routes = router
    return self, nil, routes
end

local IGNORE_PLUT_ERROR = {
    [plut.EPATHNAME] = true,
    [plut.ERESERVED] = true,
}

--- lookup
--- @param pathname string
--- @return table route
--- @return any err
--- @return table? glob
function FSRouter:lookup(pathname)
    local route, err, glob = self.routes:lookup(pathname)

    if err then
        if IGNORE_PLUT_ERROR[err.type] then
            return nil
        end
        return nil, errorf('failed to lookup()', err)
    end

    return route, nil, glob
end

return {
    new = require('metamodule').new(FSRouter),
}
