using BenchmarkTools
using ValgrindBenchmarkTools

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

@show @benchmark g($data)