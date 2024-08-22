module Valgrind

using LLVM.Interop, StaticArrays, CEnum

# TODO: Allow @asmcall to take a expr that is static_eval 

# https://godbolt.org/z/WTnn8MnbG
# Clang:   %0 = call i64 asm sideeffect "rolq $$3,  %rdi ; rolq $$13, %rdi\0A\09rolq $$61, %rdi ; rolq $$51, %rdi\0A\09xchgq %rbx,%rbx", "={dx},{ax},0,~{cc},~{memory},~{dirflag},~{fpsr},~{flags}"(ptr nonnull %_zzq_args, i64 0) #4

@inline function client_request_expr(default::Int, request::Int, arg1::Int, arg2::Int, arg3::Int, arg4::Int, arg5::Int)
    args = @MVector [request, arg1, arg2, arg3, arg4, arg5]
    # Valgrind uses volatile stores to the alloca
    GC.@preserve args begin
        @asmcall("""
                rolq \$\$3, %rdi; rolq \$\$13, %rdi
                rolq \$\$61, %rdi ; rolq \$\$51, %rdi
                xchgq %rbx,%rbx
                """,
                "={dx},{ax},0,~{cc},~{memory},~{dirflag},~{fpsr},~{flags}", true,
                Int64, Tuple{Ptr{Cvoid}, Int64}, pointer(args), default)
    end
end


@inline function client_request_stmt(request, arg1, arg2, arg3, arg4, arg5)
    client_request_expr(0, Int(request), arg1, arg2, arg3, arg4, arg5)
    nothing
end

VG_USERREQ_TOOL_BASE(a::Char,b::Char) = (UInt(a) & 0xff) << 24 | (UInt(b) & 0xff) << 16

# typedef
#    enum { VG_USERREQ__RUNNING_ON_VALGRIND  = 0x1001,
#           VG_USERREQ__DISCARD_TRANSLATIONS = 0x1002,
#           /* These allow any function to be called from the simulated
#              CPU but run on the real CPU.  Nb: the first arg passed to
#              the function is always the ThreadId of the running
#              thread!  So CLIENT_CALL0 actually requires a 1 arg
#              function, etc. */
#           VG_USERREQ__CLIENT_CALL0 = 0x1101,
#           VG_USERREQ__CLIENT_CALL1 = 0x1102,
#           VG_USERREQ__CLIENT_CALL2 = 0x1103,
#           VG_USERREQ__CLIENT_CALL3 = 0x1104,
#           /* Can be useful in regression testing suites -- eg. can
#              send Valgrind's output to /dev/null and still count
#              errors. */
#           VG_USERREQ__COUNT_ERRORS = 0x1201,
#           /* Allows the client program and/or gdbserver to execute a monitor
#              command. */
#           VG_USERREQ__GDB_MONITOR_COMMAND = 0x1202,
#           /* Allows the client program to change a dynamic command line
#              option.  */
#           VG_USERREQ__CLO_CHANGE = 0x1203,
#           /* These are useful and can be interpreted by any tool that
#              tracks malloc() et al, by using vg_replace_malloc.c. */
#           VG_USERREQ__MALLOCLIKE_BLOCK = 0x1301,
#           VG_USERREQ__RESIZEINPLACE_BLOCK = 0x130b,
#           VG_USERREQ__FREELIKE_BLOCK   = 0x1302,
#           /* Memory pool support. */
#           VG_USERREQ__CREATE_MEMPOOL   = 0x1303,
#           VG_USERREQ__DESTROY_MEMPOOL  = 0x1304,
#           VG_USERREQ__MEMPOOL_ALLOC    = 0x1305,
#           VG_USERREQ__MEMPOOL_FREE     = 0x1306,
#           VG_USERREQ__MEMPOOL_TRIM     = 0x1307,
#           VG_USERREQ__MOVE_MEMPOOL     = 0x1308,
#           VG_USERREQ__MEMPOOL_CHANGE   = 0x1309,
#           VG_USERREQ__MEMPOOL_EXISTS   = 0x130a,
#           /* Allow printfs to valgrind log. */
#           /* The first two pass the va_list argument by value, which
#              assumes it is the same size as or smaller than a UWord,
#              which generally isn't the case.  Hence are deprecated.
#              The second two pass the vargs by reference and so are
#              immune to this problem. */
#           /* both :: char* fmt, va_list vargs (DEPRECATED) */
#           VG_USERREQ__PRINTF           = 0x1401,
#           VG_USERREQ__PRINTF_BACKTRACE = 0x1402,
#           /* both :: char* fmt, va_list* vargs */
#           VG_USERREQ__PRINTF_VALIST_BY_REF = 0x1403,
#           VG_USERREQ__PRINTF_BACKTRACE_VALIST_BY_REF = 0x1404,
#           /* Stack support. */
#           VG_USERREQ__STACK_REGISTER   = 0x1501,
#           VG_USERREQ__STACK_DEREGISTER = 0x1502,
#           VG_USERREQ__STACK_CHANGE     = 0x1503,
#           /* Wine support */
#           VG_USERREQ__LOAD_PDB_DEBUGINFO = 0x1601,
#           /* Querying of debug info. */
#           VG_USERREQ__MAP_IP_TO_SRCLOC = 0x1701,
#           /* Disable/enable error reporting level.  Takes a single
#              Word arg which is the delta to this thread's error
#              disablement indicator.  Hence 1 disables or further
#              disables errors, and -1 moves back towards enablement.
#              Other values are not allowed. */
#           VG_USERREQ__CHANGE_ERR_DISABLEMENT = 0x1801,
#           /* Some requests used for Valgrind internal, such as
#              self-test or self-hosting. */
#           /* Initialise IR injection */
#           VG_USERREQ__VEX_INIT_FOR_IRI = 0x1901,
#           /* Used by Inner Valgrind to inform Outer Valgrind where to
#              find the list of inner guest threads */
#           VG_USERREQ__INNER_THREADS    = 0x1902
#    } Vg_ClientRequest;

running_on_valgrind() = client_request_expr(0, Int(0x1001), 0, 0, 0, 0, 0)

module Callgrind
    using CEnum
    import ..Valgrind: VG_USERREQ_TOOL_BASE, client_request_stmt
    @cenum(Vg_CallgrindClientRequest::Int,
        VG_USERREQ__DUMP_STATS = VG_USERREQ_TOOL_BASE('C','T'),
        VG_USERREQ__ZERO_STATS,
        VG_USERREQ__TOGGLE_COLLECT,
        VG_USERREQ__DUMP_STATS_AT,
        VG_USERREQ__START_INSTRUMENTATION,
        VG_USERREQ__STOP_INSTRUMENTATION
    )

    function dump_stats()
        client_request_stmt(VG_USERREQ__DUMP_STATS, 0, 0, 0, 0, 0)
    end

    function dump_stats_at(pos_str)
        c_pos_str = Base.cconvert(Ptr{Cchar}, pos_str)
        GC.@preserve c_pos_str begin
            ptr = Base.unsafe_convert(Ptr{Cchar}, c_pos_str)
            client_request_stmt(VG_USERREQ__DUMP_STATS_AT, reinterpret(Int, ptr), 0, 0, 0, 0)
        end
    end
    
    function zero_stats()
        client_request_stmt(VG_USERREQ__ZERO_STATS, 0, 0, 0, 0, 0)
    end

    function toggle_collect()
        client_request_stmt(VG_USERREQ__TOGGLE_COLLECT, 0, 0, 0, 0, 0)
    end
    
    function start_instrumentation()
        client_request_stmt(VG_USERREQ__START_INSTRUMENTATION, 0, 0, 0, 0, 0)
    end

    function stop_instrumentation()
        client_request_stmt(VG_USERREQ__STOP_INSTRUMENTATION, 0, 0, 0, 0, 0)
    end
end


end # module Valgrind
