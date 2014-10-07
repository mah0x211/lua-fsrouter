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
local typeof = util.typeof;
local SATISFY = {
    all = true,
    any = true
};
local RESTRICT_VALID_USER = 1;
local RESTRICT_ROLE = 2
local RESTRICT = {
    ['valid-user']  = RESTRICT_VALID_USER,
    role            = RESTRICT_ROLE,
};


local function setaddr( self, field, val )
    if not typeof.string( val ) then
        self:abort('value must be string');
    else
        local addr = self.data.addr;
        local addrIdx = self.index[field];
        local idx = addrIdx[val];
        
        if not idx then
            idx = #addr + 1;
            addr[idx] = { field, val };
            addrIdx[val] = idx;
        else
            val = table.remove( self.data.addr, idx );
            addr[#addr] = val;
        end
    end
end


-- class
local Access = require('halo').class.Access;

Access.inherits {
    'ddl.DDL'
};

function Access:onStart( data )
    self.data = data and util.table.clone( data ) or {
        addr = {},
        restrict = {}
    };
    self.index = {
        allow = {},
        deny = {}
    };
end


function Access:allow( iscall, val )
    if not iscall then
        self:abort('attempt to add new index');
    end
    setaddr( self, 'allow', val );
end

function Access:deny( iscall, val )
    if not iscall then
        self:abort('attempt to add new index');
    end
    setaddr( self, 'deny', val );
end


function Access:satisfy( iscall, val )
    if not iscall then
        self:abort('attempt to add new index');
    elseif not SATISFY[val] then
        self:abort('value must be "all" or "any"');
    end
    
    self.data.satisfy = val;
end


function Access:restrict( iscall, val )
    local restrict = self.data.restrict;
    
    if not iscall then
        self:abort('attempt to add new index');
    elseif not RESTRICT[val] then
        self:abort('value must be "valid-user" or "role"');
    elseif val == 'valid-user' then
        restrict[val] = true;
    else
        return function( role )
            local i = 1;
            
            if type( role ) ~= 'table' then
                self:abort('role must be table');
            end
            -- check fields
            for _, v in pairs( role ) do
                if _ ~= i then
                    self:abort( ('invalid role field %q = %q'):format( _, tostring( v ) ) );
                end
                i = i + 1;
            end
            restrict.role = role;
        end
    end
end


return Access.exports;
