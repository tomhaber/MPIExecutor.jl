struct RemoteFunction <: Function
    remote_identifier::Int64
    local_function::Function

    function RemoteFunction(remote_identifier::Int64, func::Function)
        new(remote_identifier, func)
    end
end

(r::RemoteFunction)(args...) = r.local_function(args...)

macro remote(pool, ex)
    quote
        register!($(esc(pool)), $(esc(ex)))
    end
end

Serialization.serialize(s::AbstractSerializer, rf::RemoteFunction) = serialize(s, rf.remote_identifier)
