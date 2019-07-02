
mutable struct Future
    pool::MPIPoolExecutor
    data::Union{Nothing, Some, Exception}
    continuation::Union{Nothing, Function}
    function Future(f::Future)
        f
    end

    function Future(pool::MPIPoolExecutor, data::Any = nothing)
        new(pool, data, nothing)
    end
end

function isfulfilled(f::Future)
    f.data !== nothing
end

function _then!(f::Future, continuation::Function)
    @assert f.continuation === nothing

    f.continuation = continuation
    if isfulfilled(f)
        f.continuation(f.data)
    end
end

function then!(f::Future, continuation::Function)
    f2 = Future(f.pool)
    _then!(f,
      x -> begin
        val = if isa(x, Exception)
          x
        else
          continuation(x)
        end

        fulfill!(f2, val)
      end
    )
    f2
end

function fulfill!(f::Future, value::Any)
    @assert !isfulfilled(f)

    f.data = !isa(value, Exception) ? Some(value) : value
    if f.continuation !== nothing
        f.continuation(value)
    end
    f
end

function get!(f::Future)
    while !isfulfilled(f)
        more_available = run!(f.pool)
    end

    if isa(f.data, Exception)
      throw(f.data)
    end

    something(f.data)
end

function whenall!(futs::Vector{Future}, ::Type{T} = Any) where T
    n = length(futs)
    results = Vector{T}(undef, n)
    r = Future(futs[1].pool)
    function post(i::Int, val::Any)
        if n > 0 && !isa(val, Exception)
          results[i] = val
          n = n - 1

          if n == 0
            fulfill!(r, results)
          end
        else
          fulfill!(r, val)
        end
    end

    for (i,f) in enumerate(futs)
        _then!(f, x -> post(i, x))
    end
    r
end
