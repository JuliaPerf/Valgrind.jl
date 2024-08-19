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
