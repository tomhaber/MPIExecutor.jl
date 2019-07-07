module MPIExecutorTest

using MPIExecutor
using Test

@testset "Start and shutdown" begin
    pool = MPIPoolExecutor(1)

    @test size(pool) == 1
    shutdown!(pool)
end

@testset "Empty pool" begin
    pool = MPIPoolExecutor(0)

    @test size(pool) == 1 # master behaves as slave
    shutdown!(pool)
end

@testset "Simple remote once" begin
    pool = MPIPoolExecutor(1)

    test = @remote pool function()
        123
    end

    x = submit!(pool, test)

    @test get!(x) == 123

    run!(pool)

    shutdown!(pool)
end

@testset "Run everywhere" begin
    worker_count = 2
    pool = MPIPoolExecutor(worker_count)

    test = @remote pool function()
        123
    end

    x = run_broadcast!(pool, test)

    @test get!(x) == [123, 123]

    shutdown!(pool)
end

@testset "Futures: whenall" begin
    MPIPoolExecutor(0) do pool
        func = @remote pool (x) -> x^2
        Future = MPIExecutor.Future
        futs = [then!(f, func) for f in [Future(pool, Some(1)), Future(pool, Some(2))]]
        f = then!(whenall!(futs), identity)
        @test get!(f) == [1,4]
    end
end

@testset "Futures: whenall throws" begin
    MPIPoolExecutor(0) do pool
        func = @remote pool (x) -> x^2
        Future = MPIExecutor.Future
        futs = [then!(f, func) for f in [Future(pool, InterruptException()), Future(pool, Some(2))]]
        f = then!(whenall!(futs), identity)
        @test_throws InterruptException get!(f)
    end
end

@testset "Futures: then remote" begin
    MPIPoolExecutor(0) do pool
        f = @remote pool () -> 2
        g = @remote pool (x) -> x^2

        fut = submit!(pool, f)
        fut = then!(fut, g)
        @test get!(fut) == 4
    end
end

@testset "Futures: then remote throws" begin
    MPIPoolExecutor(0) do pool
        f = @remote pool () -> error("bla")
        g = @remote pool (x) -> x^2

        fut = submit!(pool, f)
        fut = then!(fut, g)
        @test_throws ErrorException get!(fut)
    end
end

end
