function receive_msg!(io::IOBuffer, comm::MPI.Comm)
    s = MPI.Probe(0, MPI.MPI_ANY_TAG, comm)
    count = MPI.Get_count(s, UInt8)
    Base.ensureroom(io, count)

    tag = MPI.Get_tag(s)
    received_from = MPI.Get_source(s)
 
    buf = MPI.Buffer(io.data, count, MPI.Datatype(UInt8))
    MPI.Recv!(buf, received_from, tag, comm)
    io.size = count
    seek(io, 0)

    tag
end

function run_worker(comm::MPI.Comm, funcs::Vector{Union{Function, Nothing}})
    io = IOBuffer()

    while true
        tag = receive_msg!(io, comm)

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
              showerror(stdout, e, catch_backtrace())
              e
            end

            seek(io, 0)
            serialize(io, tracker_id)
            serialize(io, r)

            buf = MPI.Buffer(io.data, io.size, MPI.Datatype(UInt8))
            MPI.Send(buf, 0, 0, comm)
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

     # free the merged intercomm https://github.com/open-mpi/ompi/issues/8426
    if MPI.Comm_get_parent() != MPI.COMM_NULL
        MPI.free(comm)
    end

    nothing
end
