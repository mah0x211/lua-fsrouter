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

  libs/mime.lua
  lua-router
  Created by Masatoshi Teruya on 15/03/18.
 
--]]
-- module
local split = require('util.string').split;
-- default mime
local DEFAULT_MIME = require('router.mime.default');

-- private funcs
local function parseMIME( str, typeMap, extMap )
    local list, ext, mime;
    
    for line in string.gmatch( str, '[^\n\r]+') do
        if not line:find('^%s*#') then
            list = split( line, '%s+' );
            mime = list[1];
            for i = 2, #list do
                ext = '.' .. list[i]:match('[%.%w]+');
                if not extMap[ext] then
                    extMap[ext] = mime;
                    
                    if not typeMap[mime] then
                        typeMap[mime] = { ext };
                    else
                        table.insert( typeMap[mime], ext );
                    end
                end
            end
        end
    end
end

-- class
local MIME = require('halo').class.MIME;


function MIME:init()
    local own = protected( self );
    
    own.typeMap = {};
    own.extMap = {};
    parseMIME( DEFAULT_MIME, own.typeMap, own.extMap );
    return self;
end


function MIME:typeMap()
    return protected( self ).typeMap;
end


function MIME:extMap()
    return protected( self ).extMap;
end


function MIME:readTypes( str )
    local own = protected( self );
    
    parseMIME( str, own.typeMap, own.extMap );
end


return MIME.exports;

