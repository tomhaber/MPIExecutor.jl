using Serialization
import MPI

funcs = Union{Function, Nothing}[]
function run_slave()
    global funcs
    comm = MPI.Comm_get_parent()
    while true
        s = MPI.Probe(0, MPI.ANY_TAG, comm)
        count = MPI.Get_count(s, UInt8)
        recv_mesg = Array{UInt8}(undef, count)
        status = MPI.Recv!(recv_mesg, 0, MPI.ANY_TAG, comm)
        tag = MPI.Get_tag(status)
        io = IOBuffer(recv_mesg)
        if tag == 1
            id = deserialize(io)
            while size(funcs, 1) < id
                push!(funcs, nothing)
            end
            ex = deserialize(io)
            funcs[id] = eval(ex)
            return true
        elseif tag == 2
            return false
        else
            id = tag - 4
            tracker_id = deserialize(io)
            args = deserialize(io)

            r = funcs[id](args...)
            io = IOBuffer()
            serialize(io, tracker_id)
            serialize(io, r)
            MPI.Send(io.data[1:io.size], 0, 0, comm)
        end
    end
end

function main()
    MPI.Init()
    ret = true
    while ret
        ret = Base.invokelatest(run_slave)
    end

    MPI.Finalize()
end

main()
