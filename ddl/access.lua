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

  ddl/access.lua
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
    authorize   = 'authorize'
};

-- class
local Access = require('halo').class.Access;

Access.inherits {
    'ddl.DDL'
};

function Access:onStart()
    self.data = {};
    self.index = {};
end

function Access:onComplete()
    -- remove unused data
    self.filter = nil;
    self.index = nil;
    
    return self.data;
end

-- register methods
function Access:Access( iscall, name, fn )
    if iscall then
        self:abort('attempt to call Access');
    else
        local index = self.index;
        local methodName = METHOD_NAMES[name];
        
        if not methodName then
            self:abort( ('method name must be Access:<%s>'):format( 
                concat( keys( METHOD_NAMES ), '|' )
            ));
        elseif type( fn ) ~= 'function' then
            self:abort( ('method %q must be function'):format( name ) );
        elseif index[methodName] then
            self:abort( ('method %q already defined'):format( name ) );
        elseif isSugaredFn( 'Access', fn ) then
            self:abort( ('invalid method declaration'):format( name ) );
        end
        
        self.data[methodName] = fn;
        index[methodName] = true;
    end
end


return Access.exports;
