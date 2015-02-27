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

  ddl/content.lua
  lua-router
  Created by Masatoshi Teruya on 14/10/06.
 
--]]
-- modules
local util = require('util');
local copy = util.table.copy;
local keys = util.table.keys;
local concat = table.concat;
local isSugaredFn = require('router.ddl.helper').isSugaredFn;

-- constants
local METHOD_NAMES = {
    head    = 'HEAD',
    options = 'OPTIONS',
    get     = 'GET',
    post    = 'POST',
    put     = 'PUT',
    delete  = 'DELETE'
};

-- class
local Content = require('halo').class.Content;

Content.inherits {
    'ddl.DDL'
};

function Content:onStart( filter )
    self.filter = filter;
    self.data = {};
    self.index = {};
end

function Content:onComplete()
    local data = self.data;
    
    -- merge handler with filter
    if self.filter then
        for methodName, tbl in pairs( self.filter ) do
            if data[methodName] then
                tbl = copy( tbl );
                tbl[#tbl+1] = data[methodName][1];
                data[methodName] = tbl;
            end
        end
    end
    -- remove unused data
    self.filter = nil;
    self.index = nil;
    
    return data;
end

-- register methods
function Content:Content( iscall, name, fn )
    if iscall then
        self:abort('attempt to call Content');
    else
        local index = self.index;
        local methodName = METHOD_NAMES[name];
        
        if not methodName then
            self:abort( ('method name must be Content:<%s>'):format( 
                concat( keys( METHOD_NAMES ), '|' )
            ));
        elseif type( fn ) ~= 'function' then
            self:abort( ('method %q must be function'):format( name ) );
        elseif index[methodName] then
            self:abort( ('method %q already defined'):format( name ) );
        elseif isSugaredFn( 'Content', fn ) then
            self:abort( ('invalid method declaration'):format( name ) );
        end
        
        self.data[methodName] = { fn };
        index[methodName] = true;
    end
end


return Content.exports;
