using Jive
@If VERSION >= v"1.11" module test_jive_ext_daemon_mode_ext

using Test
using Jive
using DaemonMode

DaemonModeExt = Base.get_extension(Jive, :DaemonModeExt)
@test DaemonModeExt.serverRun isa Function

end # module test_jive_ext_daemon_mode_ext
