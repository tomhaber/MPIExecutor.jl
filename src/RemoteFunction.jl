struct RemoteFunction
    remote_identifier::Int64
    local_function::Function

    function RemoteFunction(remote_identifier::Int64, func::Function)
        new(remote_identifier, func)
    end
end

(r::RemoteFunction)(args...) = r.local_function(args...)

macro remote(pool, ex)
    quote
        remote_identifier = register!($(esc(pool)), $(QuoteNode(ex)))
        RemoteFunction(remote_identifier, $(esc(ex)))
    end
end
