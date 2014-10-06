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
local clone = util.table.clone;
local keys = util.table.keys;
local typeof = util.typeof;
local concat = table.concat;
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

function Content:onStart( data )
    self.data = {};
    self.index = {};
end

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
        end
        
        self.data[methodName] = fn;
        index[methodName] = true;
    end
end


return Content.exports;
