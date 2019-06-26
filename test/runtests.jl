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

end
