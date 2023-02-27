-- extract id from *id parameter
return {
    all = function(req, res)
        -- use first segment as an post-id
        -- req.param.id = string.match(req.param.id, '^([^/]+)/-')
    end,
}
