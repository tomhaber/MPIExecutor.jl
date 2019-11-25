function receive_msg(comm::MPI.Comm)
    s = MPI.Probe(0, MPI.MPI_ANY_TAG, comm)
    count = MPI.Get_count(s, UInt8)
    recv_mesg = Array{UInt8}(undef, count)
    status = MPI.Recv!(recv_mesg, 0, MPI.Get_tag(s), comm)
    tag = MPI.Get_tag(status)
    io = IOBuffer(recv_mesg)
    tag, io
end

function run_worker(comm::MPI.Comm, funcs::Vector{Union{Function, Nothing}})
    while true
        tag, io = receive_msg(comm)

        if tag == 0
            ex = deserialize(io)::Expr
            Main.eval(ex)
            return true
        elseif tag == 1
            id = deserialize(io)::Int64
            f = deserialize(io)::Function

            while size(funcs, 1) < id
                push!(funcs, nothing)
            end
            funcs[id] = f
            return true
        elseif tag == 2
            return false
        else tag == 3
            id = deserialize(io)::Union{Function, Int64}
            tracker_id = deserialize(io)::Int64
            args = deserialize(io)

            f = if isa(id, Function)
              id
            else
              funcs[id]
            end

            r = try
              f(args...)
            catch e
              e
            end

            io = IOBuffer()
            serialize(io, tracker_id)
            serialize(io, r)
            MPI.Send(io.data[1:io.size], 0, 0, comm)
        end
    end
end

function main_worker(comm::MPI.Comm=MPI.COMM_WORLD)
    if !MPI.Initialized()
        MPI.Init()
    end

    @assert !MPI.Finalized()

    comm = if MPI.Comm_get_parent() == MPI.COMM_NULL
        comm
    else
        MPI.Intercomm_merge(MPI.Comm_get_parent(), true)
    end

    funcs = Union{Function, Nothing}[]

    ret = true
    while ret
      ret = Base.invokelatest(run_worker, comm, funcs)
    end
end
