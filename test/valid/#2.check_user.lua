-- check user session on all method
return {
    all = function(req, res)
        -- if no-session-cookie or
        --    session-has-been-expired
        -- then
        --     -- redirect to /signin
        --     return 303 see other
        -- end

        -- set user
        -- res.user = session.usern
    end,
}
