function run_worker(comm::MPI.Comm, funcs::Vector{Union{Function, Nothing}})
    while true
        s = MPI.Probe(0, MPI.MPI_ANY_TAG, comm)
        count = MPI.Get_count(s, UInt8)
        recv_mesg = Array{UInt8}(undef, count)
        status = MPI.Recv!(recv_mesg, 0, MPI.Get_tag(s), comm)
        tag = MPI.Get_tag(status)
        io = IOBuffer(recv_mesg)
        if tag == 1
            id = deserialize(io)
            while size(funcs, 1) < id
                push!(funcs, nothing)
            end
            ex = deserialize(io)
            funcs[id] = Main.eval(ex)
            return true
        elseif tag == 2
            return false
        else
            id = tag - 4
            tracker_id = deserialize(io)
            args = deserialize(io)

            r = try
              funcs[id](args...)
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
