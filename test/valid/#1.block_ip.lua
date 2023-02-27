-- blocks requests from hosts with listed IP addresses on all method
return {
    all = function(req, res)
        -- if request-ip-is-listed-in-the-ip-list then
        --     return 418 I'm a teapot
        -- end
    end,
}
