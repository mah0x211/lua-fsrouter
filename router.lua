--[[

  Copyright (C) 2013 Masatoshi Teruya
 
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

--]]
local util = require('util');

local function dispatch( self, uri, ... )
    -- get hook table for uri
    local hooks = self.route[uri] and self.route[uri].hooks;
    
    if hooks then
        for i,v in ipairs( hooks ) do
            -- break if return true
            if v.func( ... ) then
                break;
            end
        end
        return true;
    end
    
    return false;
end


local function compile( route )
    local keys = util.keys( route );
    local rootHooks = route['/'] and route['/'].hooks;
    local newRoot = {};
    local newHooks, uri, def, pathz, seg, hooks;
    
    table.sort( keys );
    
    for i = 1, #keys, 1 do
        uri = keys[i];
        def = route[uri];
        newHooks = {};
        newRoot[uri] = { hooks = newHooks };
        
        -- insert root hooks
        if rootHooks then
            util.merge( rootHooks, newHooks );
        end
        
        if uri ~= '/' and route[uri].hooks then
            hooks = route[uri].hooks;
            pathz = util.split( uri, '/' );
            seg = '/';
            
            -- check pathz without last-path(=uri)
            for i = 1, #pathz - 1, 1 do
                seg = seg .. pathz[i] .. '/';
                if route[seg] and route[seg].hooks then
                    util.merge( route[seg].hooks, newHooks );
                end
            end
            util.merge( hooks, newHooks );
        end
    end
    
    return newRoot;
end

local function define( route, sandbox )
    local success,fn;
    
    -- traverse routing definition table
    for uri, def in pairs( route ) do
        -- load server hooks
        for j,hook in ipairs( def.hooks ) do
            success,fn = pcall( require, hook.name );
            if success then
                -- sandboxing
                if sandbox then
                    setfenv( fn, sandbox );
                end
                -- add function
                rawset( hook, 'func', fn );
            else
                def.hooks[j] = nil;
            end
        end
    end
    
    return {
        -- compile
        route = compile( route ),
        dispatch = dispatch
    };
end


return {
    define = define
};

