--[[

  Copyright (C) 2014 Masatoshi Teruya
 
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
 
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
 
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.

  ddl/filter.lua
  lua-router
  Created by Masatoshi Teruya on 14/10/06.
 
--]]
-- modules
local util = require('util');
local keys = util.table.keys;
local concat = table.concat;
local isSugaredFn = require('router.ddl.helper').isSugaredFn;

-- constants
local METHOD_NAMES = {
    any     = 'ANY',
    head    = 'HEAD',
    options = 'OPTIONS',
    get     = 'GET',
    post    = 'POST',
    put     = 'PUT',
    delete  = 'DELETE'
};

-- class
local Filter = require('halo').class.Filter;

Filter.inherits {
    'ddl.DDL'
};

function Filter:onStart( filter )
    self.filter = filter;
    self.data = {};
    self.index = {};
end

-- merge filter with previous filter
function Filter:onComplete()
    local filter = self.filter or {};
    local tbl;
    
    for method, fn in pairs( self.data ) do
        tbl = filter[method];
        if tbl then
            tbl[#tbl+1] = fn;
        else
            filter[method] = { fn };
        end
    end
    -- remove unused data
    self.filter = nil;
    self.index = nil;
    
    return filter;
end

-- register methods
function Filter:Filter( iscall, name, fn )
    if iscall then
        self:abort('attempt to call Filter');
    else
        local index = self.index;
        local methodName = METHOD_NAMES[name];
        local methodTbl = self.data[methodName];
        
        if not methodName then
            self:abort( ('method name must be Filter:<%s>'):format( 
                concat( keys( METHOD_NAMES ), '|' )
            ));
        elseif type( fn ) ~= 'function' then
            self:abort( ('method %q must be function'):format( name ) );
        elseif index[methodName] then
            self:abort( ('method %q already defined'):format( name ) );
        elseif isSugaredFn( 'Filter', fn ) then
            self:abort( ('invalid method declaration'):format( name ) );
        end
        
        index[methodName] = true;
        -- to set ANY filter to other method filter
        if methodName == 'ANY' then
            for _, methodName in pairs( METHOD_NAMES ) do
                -- set filter if method does not exists
                if methodName ~= 'ANY' and not self.data[methodName] then
                    self.data[methodName] = fn;
                end 
            end
        else
            self.data[methodName] = fn;
        end
    end
end


return Filter.exports;
