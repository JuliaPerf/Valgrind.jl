module ValgrindBenchmarkTools

using Valgrind, Reexport
@reexport using BenchmarkTools

@inline function prehook()
    Valgrind.Callgrind.zero_stats()
    Valgrind.Callgrind.start_instrumentation()
end

@inline function posthook(id)
    Valgrind.Callgrind.stop_instrumentation()
    Valgrind.Callgrind.dump_stats_at(id)
end

function __init__()
    BenchmarkTools.DEFAULT_PARAMETERS = BenchmarkTools.Parameters(;
        prehook = prehook,
        posthook = posthook,
        enable_customizable_func = :ALL,
    )

    # Serialization
    BenchmarkTools.VERSIONS["Valgrind"] = pkgversion(Valgrind)
    BenchmarkTools.VERSIONS["ValgrindBenchmarkTools.jl"] =
        pkgversion(ValgrindBenchmarkTools)
end


end # module ValgrindBenchmarkTools
