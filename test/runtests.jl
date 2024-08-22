using Valgrind
using Test


function callgrind(cmd)
    `valgrind -q  --tool=callgrind --trace-children=yes --cache-sim=yes --I1=32768,8,64 --D1=32768,8,64 --LL=8388608,16,64 --instr-atstart=no --collect-systime=nsec --compress-strings=no --combine-dumps=yes --dump-line=no $(cmd)`
end

if Valgrind.running_on_valgrind() == 0
    @testset "Outside Valgrind session" begin
    end

    # Restart under Callgrind
    jlcmd = `$(Base.julia_cmd()) $(@__FILE__)`
    @test success(pipeline(callgrind(jlcmd), stdout=stdout, stderr=stderr))
    exit()
end

@noinline function g(a)
    c = 0
    for x in a
        if x > 0
            c += 1
        end
    end
    c
end
const data = zeros(10000)
g(data)

function harness(f::F, name, args...) where F
    Valgrind.Callgrind.zero_stats()
    Valgrind.Callgrind.start_instrumentation()
    @noinline f(args...)
    Valgrind.Callgrind.stop_instrumentation()
    Valgrind.Callgrind.dump_stats_at(name)
end

harness(g, "test_g", data)