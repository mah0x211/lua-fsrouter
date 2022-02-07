--
-- Copyright (C) 2022 Masatoshi Fukunaga
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
-- modules
local error = error
local ipairs = ipairs
local pairs = pairs
local next = next
local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring
local type = type
local format = string.format
local find = string.find
local gsub = string.gsub
local match = string.match
local sub = string.sub
local sort = table.sort
local isa = require('isa')
local is_table = isa.table
local is_function = isa.Function
-- constants
local METHODS = require('fsrouter.default').METHODS

-- extract name without extension
local function basename(filename)
    return match(filename, '([^/.]+)%.-[^/]*$')
end

--- @class Categorizer
--- @field trim_extentions table<string, boolean>
--- @field compiler function
--- @field loadfenv function
--- @field upfilters table[]
--- @field files table<string, table>
--- @field filters table[]
--- @field filter_order table<string, string>
--- @field filter_disabled table<string, any>
--- @field handlers table<string, table>
local Categorizer = {}
Categorizer.__index = Categorizer

--- commpile
--- @param pathname string
--- @return table methods
--- @return string err
function Categorizer:compile(pathname)
    local methods, err = self.compiler(pathname, self.loadfenv())
    if err then
        return nil, format('failed to compile %q: %s', pathname, err)
    end
    return methods
end

--- as_handler
--- @param stat table
--- @return boolean ok
--- @return string err
function Categorizer:as_handler(stat)
    -- extract basename wihtout extension and remove '@' prefix
    local entry = sub(basename(stat.entry), 2)

    -- '$' prefixed name must be used as parameter segment
    entry = gsub(entry, '^%$', {
        ['$'] = ':',
    })

    if self.handlers[entry] then
        return false,
               format('invalid handler file %q: route %q already exists by %s',
                      stat.rpath, entry, self.handlers[entry].rpath)
    end

    -- compile handler
    local methods, err = self:compile(stat.pathname)
    if err then
        return false, format('invalid handler file %q: %s', stat.rpath, err)
    elseif not is_table(methods) then
        return false,
               format(
                   'invalid handler file %q: method list (%q) is not a table',
                   stat.rpath, type(methods))
    elseif methods.all then
        return false,
               format('invalid handler file %q: the method %q cannot be used',
                      stat.rpath, 'all')
    end

    -- verify method/function pairs
    for method, fn in pairs(methods) do
        if not METHODS[method] then
            return false,
                   format(
                       'invalid handler file %q: method name (%q) must be string',
                       stat.rpath, tostring(method))
        elseif not is_function(fn) then
            return false,
                   format(
                       'invalid handler file %q: method (%q) must be function',
                       stat.rpath, type(fn))
        end
    end

    -- ignore empty-handler
    if not next(methods) then
        return true
    end
    stat.methods = methods

    -- categorize into the method list of the handler table

    self.handlers[entry] = stat

    return true
end

--- as_filter
--- @param stat table
--- @return boolean ok
--- @return string err
function Categorizer:as_filter(stat)
    local entry = stat.entry
    local order = match(entry, '^#(%d+)%.')

    if not order then
        -- same name filter will be disabled
        if find(entry, '^#%-%.') then
            self.filter_disabled[sub(entry, 4)] = stat.rpath
            return true
        end

        return false,
               format(
                   'invalid filter file %q: the filename prefix must begin with %q',
                   stat.rpath, "'#%d+%.' or '#-%.'")
    end
    entry = sub(entry, 3 + #order)

    if self.filter_order[order] then
        return false,
               format(
                   'invalid filter file %q: the order #%s is already used by %q',
                   stat.rpath, order, self.filter_order[order])
    end
    self.filter_order[order] = stat.rpath
    stat.order = tonumber(order, 10)

    -- compile handler
    local methods, err = self:compile(stat.pathname)
    if err then
        return false, format('invalid filter file %q: %s', stat.rpath, err)
    elseif not is_table(methods) then
        return false,
               format('invalid filter file %q: method list (%q) is not a table',
                      stat.rpath, type(methods))
    end
    stat.methods = methods

    -- categorize into the method list of the filter table
    for method, fn in pairs(methods) do
        if not METHODS[method] then
            return false,
                   format(
                       'invalid filter file %q: method name (%q) must be string',
                       stat.rpath, tostring(method))
        elseif not is_function(fn) then
            return false,
                   format(
                       'invalid filter file %q: method (%q) must be function',
                       stat.rpath, type(fn))
        end

        local list = self.filters[method]
        if not list then
            list = {}
            self.filters[method] = list
        end
        list[#list + 1] = {
            name = entry,
            order = stat.order,
            fn = fn,
            stat = stat,
        }
    end

    return true
end

--- as_file
--- @param stat table
--- @return boolean ok
--- @return string err
function Categorizer:as_file(stat)
    local entry = stat.entry

    -- remove extension from a resource file
    if self.trim_extentions[stat.ext] then
        entry = basename(entry)
    end

    -- '$' prefixed name must be used as parameter segment
    entry = gsub(entry, '^%$', {
        ['$'] = ':',
    })

    -- file
    stat.type = 'file'
    self.files[entry] = stat
    return true
end

--- categorize
--- @param stat table
--- @return boolean ok
--- @return string err
function Categorizer:categorize(stat)
    local prefix = sub(stat.entry, 1, 1)
    local is_handler = prefix == '@'
    local is_filter = prefix == '#'

    if not is_handler and not is_filter then
        return self:as_file(stat)
    elseif is_filter then
        return self:as_filter(stat)
    end

    return self:as_handler(stat)
end

--- sort_by_order
--- @param a table
--- @param b table
--- @return boolean lt
local function sort_by_order(a, b)
    return a.order < b.order
end

--- sort_by_name
--- @param a table
--- @param b table
--- @return boolean lt
local function sort_by_name(a, b)
    return a.name < b.name
end

--- shallow_copy
--- @param tbl table|nil
--- @param filterfn function|nil
--- @return table|nil
local function shallow_copy(tbl, filterfn)
    if tbl ~= nil then
        local newtbl = {}

        filterfn = filterfn or function(k, v)
            return v
        end
        for k, v in pairs(tbl) do
            newtbl[k] = filterfn(k, v)
        end

        return newtbl
    end
end

--- append_method_list
---@param dst table[]
---@param src table[]
---@param mtype string
---@param method string
local function append_method_list(dst, src, mtype, method)
    for i, v in ipairs(src or {}) do
        dst[#dst + 1] = {
            type = mtype,
            method = method,
            name = v.stat.rpath,
            fn = v.fn,
            idx = i,
        }
    end
end

--- categorize
--- @return boolean ok
--- @return string err
function Categorizer:finalize()
    local routes = {}

    -- sort all filter handlers by order
    for _, list in pairs(self.filters) do
        sort(list, sort_by_order)
    end

    -- marge filters with parent filters
    local filter_disabled = self.filter_disabled
    for method, uplist in pairs(self.upfilters) do
        local merged_list = shallow_copy(uplist, function(k, v)
            -- ignore disabled filters
            if not filter_disabled[v.name] then
                return v
            end
        end)

        for _, v in ipairs(self.filters[method] or {}) do
            -- ignore disabled filters
            if not filter_disabled[v.name] then
                merged_list[#merged_list + 1] = v
            end
        end

        if next(merged_list) then
            self.filters[method] = merged_list
        else
            self.filters[method] = nil
        end
    end

    -- create file route
    for name, stat in pairs(self.files) do
        local methods = {}
        local route = {
            name = name,
            file = stat,
            methods = methods,
            filters = {
                all = shallow_copy(self.filters.all),
            },
        }
        local handler = self.handlers[name]

        -- same name handler is used as a content handler
        if handler then
            route.handler = handler
            self.handlers[name] = nil
            -- attach filters for each method
            for method, fn in pairs(handler.methods) do
                local flist = shallow_copy(self.filters[method])
                route.filters[method] = flist

                local mlist = {}
                append_method_list(mlist, route.filters.all, 'filter', 'all')
                append_method_list(mlist, flist, 'filter', method)
                mlist[#mlist + 1] = {
                    type = 'handler',
                    name = handler.rpath,
                    method = method,
                    fn = fn,
                }
                methods[method] = mlist
            end
        end

        -- attach only get filters
        if not methods.get then
            local flist = shallow_copy(self.filters.get)
            route.filters.get = flist

            local mlist = {}
            append_method_list(mlist, route.filters.all, 'filter', 'all')
            append_method_list(mlist, flist, 'filter', 'get')
            if next(mlist) then
                methods.get = mlist
            end
        end

        routes[#routes + 1] = route
    end

    -- create handler route
    for name, stat in pairs(self.handlers) do
        local methods = {}
        local route = {
            name = name,
            methods = methods,
            filters = {
                all = shallow_copy(self.filters.all),
            },
            handler = stat,
        }

        -- attach filters for each method
        for method, fn in pairs(stat.methods) do
            local flist = shallow_copy(self.filters[method])
            route.filters[method] = flist

            local mlist = {}
            append_method_list(mlist, route.filters.all, 'filter', 'all')
            append_method_list(mlist, flist, 'filter', method)
            mlist[#mlist + 1] = {
                type = 'handler',
                name = stat.rpath,
                method = method,
                fn = fn,
            }
            methods[method] = mlist
        end

        routes[#routes + 1] = route
    end

    sort(routes, sort_by_name)

    return routes
end

--- new
--- @param trim_extentions table<string, boolean>
--- @param compiler function
--- @param loadfenv function
--- @param upfilters table[]
--- @return Categorizer
local function new(trim_extentions, compiler, loadfenv, upfilters)
    if not is_table(trim_extentions) then
        error('trim_extentions must be table', 2)
    elseif not is_function(compiler) then
        error('compiler must be function', 2)
    elseif not is_function(loadfenv) then
        error('loadfenv must be function', 2)
    end

    return setmetatable({
        trim_extentions = trim_extentions,
        compiler = compiler,
        loadfenv = loadfenv,
        files = {},
        handlers = {},
        filters = {},
        filter_order = {},
        filter_disabled = {},
        upfilters = upfilters or {},
    }, Categorizer)
end

return {
    new = new,
}
