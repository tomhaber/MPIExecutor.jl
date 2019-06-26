using MPI

function start()
    if !MPI.Finalized() && !MPI.Initialized()
        MPI.Init()
    end
end

function stop()
    if !MPI.Finalized() && MPI.Initialized()
        MPI.Finalize()
    end
end

registered_stop = false
function prep_stop()
    global registered_stop
    if !registered_stop
        atexit(stop)
        registered_stop = true
    end
end
