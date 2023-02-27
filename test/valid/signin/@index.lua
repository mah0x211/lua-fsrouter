-- handle post request for /signin
return {
    post = function(req, res)
        -- oauth signin
        -- check query
        -- create state
        -- redirect to the provider url with the required parameters
        -- return 303 see other
    end,

    -- handle get request for /signin
    get = function(req, res)
        -- oauth callback
        -- check query
        -- exchange code for token
        -- if exchange-failure then
        --     -- display error page
        --     -- return 200
        -- end

        -- create session
        -- set a session-cookie
        -- redirect to '/'
        -- return 303 see other
    end,
}
