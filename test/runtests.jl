using ALGLIB
import MathOptInterface as MOI
import Pkg
using Test

function _optimizer()
    return MOI.Utilities.CachingOptimizer(
        MOI.Utilities.UniversalFallback(MOI.Utilities.Model{Float64}()),
        MOI.Bridges.full_bridge_optimizer(
            MOI.Utilities.CachingOptimizer(
                MOI.Utilities.UniversalFallback(MOI.Utilities.Model{Float64}()),
                ALGLIB.Optimizer(stdin = devnull, stdout = devnull),
            ),
            Float64,
        ),
    )
end

function _moi_test_mode()
    mode = lowercase(get(ENV, "ALGLIB_MOI_TEST_MODE", ""))
    if mode in ("default", "full", "partial")
        return Symbol(mode)
    end
    if lowercase(get(ENV, "ALGLIB_PARTIAL_MOI_TESTS", "false")) in ("1", "true", "yes")
        return :partial
    end
    if lowercase(get(ENV, "ALGLIB_FULL_MOI_TESTS", "false")) in ("1", "true", "yes")
        return :full
    end
    return :full
end

function _run_full_moi_tests()
    return _moi_test_mode() == :full
end

function _run_verbose_moi_tests()
    return _moi_test_mode() in (:full, :partial)
end

function _restore_env!(name::AbstractString, value)
    value === nothing ? delete!(ENV, name) : (ENV[name] = value)
    return
end

function _with_solver_env_cleared(f::Function)
    old_exec = get(ENV, "ALGLIB_EXEC", nothing)
    old_nlpath = get(ENV, "ALGLIB_NLPATH", nothing)
    try
        delete!(ENV, "ALGLIB_EXEC")
        delete!(ENV, "ALGLIB_NLPATH")
        return f()
    finally
        _restore_env!("ALGLIB_EXEC", old_exec)
        _restore_env!("ALGLIB_NLPATH", old_nlpath)
    end
end

function _with_temp_active_project(f::Function)
    old_project = Base.active_project()
    dir = mktempdir()
    try
        Pkg.activate(dir; io = devnull)
        return f()
    finally
        if old_project === nothing
            Pkg.activate(; io = devnull)
        else
            Pkg.activate(dirname(old_project); io = devnull)
        end
    end
end

function _with_temp_depot(f::Function)
    old_depot = copy(DEPOT_PATH)
    dir = mktempdir()
    try
        empty!(DEPOT_PATH)
        push!(DEPOT_PATH, dir)
        append!(DEPOT_PATH, old_depot)
        return f()
    finally
        empty!(DEPOT_PATH)
        append!(DEPOT_PATH, old_depot)
    end
end

function _with_temp_license_home(f::Function)
    dir = mktempdir()
    license_dir = Sys.iswindows() ? joinpath(dir, "ALGLIB") : joinpath(dir, "alglib")
    old_localappdata = get(ENV, "LOCALAPPDATA", nothing)
    old_xdg_state_home = get(ENV, "XDG_STATE_HOME", nothing)
    try
        if Sys.iswindows()
            ENV["LOCALAPPDATA"] = dir
        else
            ENV["XDG_STATE_HOME"] = dir
        end
        return f(license_dir)
    finally
        _restore_env!("LOCALAPPDATA", old_localappdata)
        _restore_env!("XDG_STATE_HOME", old_xdg_state_home)
    end
end

function _write_license_record(dir::AbstractString, name::AbstractString, payload::AbstractString)
    mkpath(dir)
    path = joinpath(dir, name)
    write(path, "not-checked-by-wrapper\n$(payload)\n")
    return path
end

function _write_fake_executable(
    dir::AbstractString,
    name::AbstractString;
    version::Union{Nothing,AbstractString} = nothing,
)
    mkpath(dir)
    path = joinpath(dir, name)
    script = if version === nothing
        "#!/bin/sh\nexit 0\n"
    else
        "#!/bin/sh\nif [ \"\$#\" -eq 1 ] && [ \"\$1\" = \"--version\" ]; then echo \"$(version)\"; exit 0; fi\nexit 0\n"
    end
    write(path, script)
    chmod(path, 0o755)
    return path
end

function _shell_single_quote(value::AbstractString)
    return "'" * replace(value, "'" => "'\\''") * "'"
end

function _write_argument_capture_executable(dir::AbstractString, name::AbstractString)
    mkpath(dir)
    path = joinpath(dir, name)
    output_path = joinpath(dir, "$(name).args")
    script = """
#!/bin/sh
output=$(_shell_single_quote(output_path))
: > "\$output"
for arg in "\$@"; do
    printf '%s\\n' "\$arg" >> "\$output"
done
exit 0
"""
    write(path, script)
    chmod(path, 0o755)
    return path, output_path
end

function _with_temp_workdir(f::Function)
    dir = mktempdir()
    current = pwd()
    try
        cd(dir)
        return f(dir)
    finally
        cd(current)
    end
end

function _discovered_alglib_executables(root::AbstractString)
    candidates = NamedTuple{(:version, :path),Tuple{Int,String}}[]
    seen_paths = Set{String}()
    for (dir, _, _) in walkdir(root)
        for (version, path, _) in ALGLIB._candidate_executables(dir)
            path in seen_paths && continue
            push!(seen_paths, path)
            push!(candidates, (version = version, path = path))
        end
    end
    sort!(candidates; by = candidate -> candidate.version, rev = true)
    return candidates
end

function _moi_test_include()
    mode = _moi_test_mode()
    if mode == :full
        return Union{String,Regex}[]
    elseif mode == :partial
        return Union{String,Regex}[
            r"^test_modification_affine_deletion_edge_cases$",
            r"^test_modification_coef_scalar_objective$",
            r"^test_modification_coef_scalaraffine_lessthan$",
            r"^test_modification_const_scalar_objective$",
            r"^test_modification_func_scalaraffine_lessthan$",
            r"^test_modification_set_scalaraffine_lessthan$",
            r"^test_modification_set_singlevariable_lessthan$",
            r"^test_modification_transform_singlevariable_lessthan$",
        ]
    end
    test = get(ENV, "ALGLIB_MOI_TEST_INCLUDE", "")
    if !isempty(test)
        return Union{String,Regex}[test]
    end
    return Union{String,Regex}[
        # Basic MOI add/support checks for common JuMP scalar
        # constraint families before writing the AMPL .nl file.
        r"^test_basic_VariableIndex_EqualTo$",
        r"^test_basic_VariableIndex_GreaterThan$",
        r"^test_basic_VariableIndex_Integer$",
        r"^test_basic_VariableIndex_Interval$",
        r"^test_basic_VariableIndex_LessThan$",
        r"^test_basic_VariableIndex_ZeroOne$",
        r"^test_basic_ScalarAffineFunction_EqualTo$",
        r"^test_basic_ScalarAffineFunction_GreaterThan$",
        r"^test_basic_ScalarAffineFunction_Integer$",
        r"^test_basic_ScalarAffineFunction_Interval$",
        r"^test_basic_ScalarAffineFunction_LessThan$",
        r"^test_basic_ScalarAffineFunction_ZeroOne$",
        r"^test_basic_ScalarQuadraticFunction_EqualTo$",
        r"^test_basic_ScalarQuadraticFunction_GreaterThan$",
        r"^test_basic_ScalarQuadraticFunction_Integer$",
        r"^test_basic_ScalarQuadraticFunction_Interval$",
        r"^test_basic_ScalarQuadraticFunction_LessThan$",
        r"^test_basic_ScalarQuadraticFunction_ZeroOne$",
        r"^test_basic_ScalarNonlinearFunction_EqualTo$",
        r"^test_basic_ScalarNonlinearFunction_GreaterThan$",
        r"^test_basic_ScalarNonlinearFunction_Integer$",
        r"^test_basic_ScalarNonlinearFunction_Interval$",
        r"^test_basic_ScalarNonlinearFunction_LessThan$",
        r"^test_basic_ScalarNonlinearFunction_ZeroOne$",
        # Attributes supported through AmplNLWriter's file interface.
        r"^test_attribute_RawStatusString$",
        r"^test_attribute_SolveTimeSec$",
        r"^test_attribute_SolverName$",
        # Lightweight constraint checks that do not require duals or
        # unbounded/infeasible certificates from ALGLIB.
        r"^test_constraint_ZeroOne_bounds$",
        r"^test_constraint_ZeroOne_bounds_2$",
        r"^test_constraint_ZeroOne_bounds_3$",
        r"^test_constraint_qcp_duplicate_diagonal$",
        r"^test_constraint_qcp_duplicate_off_diagonal$",
    ]
end

function _moi_test_exclude()
    exclude = Union{String,Regex}[
        # TODO: investigate whether these are limitations in
        # AmplNLWriter's copy_to layer or in ALGLIB's .sol output.
        "test_model_copy_to_",
        # ALGLIB receives models through AMPL .nl files; invalid
        # nonlinear model handling is exercised by AmplNLWriter.
        "test_nonlinear_invalid",
        # File-based AMPL solvers do not support these conic forms
        # directly; they require solver-specific reformulation support.
        "test_conic_NormInfinityCone_INFEASIBLE",
        "test_conic_NormOneCone_INFEASIBLE",
        "test_conic_linear_VectorOfVariables_2",
        # These sets are not supported by the current AMPL .nl wrapper.
        "_Indicator_",
        "_SOS2_",
        # CP-SAT tests are not relevant to this MINLP wrapper.
        "test_cpsat_",
        # Complementarity support has not been established for ALGLIB.
        "_complementarity",
        # AmplNLWriter does not expose MOI.ObjectiveBound, and ALGLIB-specific
        # bound parsing has not been implemented in this wrapper.
        r"^test_linear_Semicontinuous_integration$",
        r"^test_linear_Semiinteger_integration$",
        r"^test_linear_integer_integration$",
        r"^test_solve_ObjectiveBound_",
        # The current ALGLIB .sol output observed in tests does not include
        # NLP block duals, and AmplNLWriter's reader errors on the empty vector.
        r"^test_nonlinear_hs071_NLPBlockDual$",
    ]
    if _moi_test_mode() == :full
        append!(
            exclude,
            [
                # ALGLIB reports these models as unbounded, but the .sol output
                # does not include a usable unbounded-ray certificate.
                r"^test_unbounded_MAX_SENSE$",
                r"^test_unbounded_MAX_SENSE_offset$",
                r"^test_unbounded_MIN_SENSE$",
                r"^test_unbounded_MIN_SENSE_offset$",
            ],
        )
    end
    return exclude
end

@testset "license version bounds" begin
    _with_temp_license_home() do license_dir
        @test ALGLIB.license_version_bounds() == (minver = 1, maxver = 999999)

        _write_license_record(
            license_dir,
            "alglib4jump-eval.jlic",
            """{"serial":"","initial_ver_id":123,"start_at":1,"expire_at":2}""",
        )
        @test ALGLIB.license_version_bounds() == (minver = 123, maxver = 999999)

        _write_license_record(
            license_dir,
            "alglib4jump-license-token.jlic",
            """{"license_id":"debug","checkout_number":1,"web_access_token":"","company_name":"","dev_plan":"corporate","user_names":"","min_ver":7,"max_ver":12,"max_release_date":9999999999,"start_at":1,"expire_at":9999999999}""",
        )
        @test ALGLIB.license_version_bounds() == (minver = 7, maxver = 12)

        _write_license_record(license_dir, "alglib4jump-license-token.jlic", "{")
        @test ALGLIB.license_version_bounds() == (minver = 1, maxver = 999999)

        _write_license_record(
            license_dir,
            "alglib4jump-eval.jlic",
            """{"serial":"","initial_ver_id":456,"start_at":1,"expire_at":2}""",
        )
        _write_license_record(
            license_dir,
            "alglib4jump-license-token.jlic",
            """{"license_id":"debug","min_ver":70}""",
        )
        @test ALGLIB.license_version_bounds() == (minver = 1, maxver = 999999)

        rm(joinpath(license_dir, "alglib4jump-license-token.jlic"))
        _write_license_record(license_dir, "alglib4jump-eval.jlic", """{"serial":""}""")
        @test ALGLIB.license_version_bounds() == (minver = 1, maxver = 999999)
    end
end

@testset "versions" begin
    @test ALGLIB.ALGLIB_JL_VERSION_STRING == "1.0.1"
    @test ALGLIB.ALGLIB_JL_VERSION == VersionNumber(ALGLIB.ALGLIB_JL_VERSION_STRING)
    @test ALGLIB.ALGLIB_SOLVER_BINARY_VERSION_STRING == "0001"
    exe_extension = Sys.iswindows() ? ".exe" : ""
    minimum_solver_version = string(0, ".", lpad(0, 2, '0'), ".", 1)
    @test ALGLIB._regex_escape(".exe") == "\\.exe"
    @test ALGLIB.solver_version_string("alglib4nl-0001-$(ALGLIB.ALGLIB_PLATFORM_SUFFIX)$(exe_extension)") ==
          minimum_solver_version
    @test ALGLIB.solver_version_string("alglib4nl-0010-$(ALGLIB.ALGLIB_PLATFORM_SUFFIX)$(exe_extension)") ==
          "0.01.0"
    @test ALGLIB.solver_version_string("alglib4nl-4071-$(ALGLIB.ALGLIB_PLATFORM_SUFFIX)$(exe_extension)") ==
          "4.07.1"
    @test ALGLIB.executable_name() ==
          "alglib4nl-0001-$(ALGLIB.ALGLIB_PLATFORM_SUFFIX)$(exe_extension)"
end

@testset "ALGLIB_NLPATH binary selection" begin
    _with_temp_license_home() do license_dir
        dir1 = mktempdir()
        dir2 = mktempdir()
        suffix = ALGLIB.ALGLIB_PLATFORM_SUFFIX
        extension = Sys.iswindows() ? ".exe" : ""
        old_exec = get(ENV, "ALGLIB_EXEC", nothing)
        old_nlpath = get(ENV, "ALGLIB_NLPATH", nothing)
        try
            delete!(ENV, "ALGLIB_EXEC")
            ENV["ALGLIB_NLPATH"] = string(dir1, Sys.iswindows() ? ';' : ':', dir2)

            _write_fake_executable(dir1, "alglib4nl-0007-$(suffix)$(extension)")
            _write_fake_executable(dir1, "alglib4nl-0010-$(suffix)$(extension)")
            _write_fake_executable(dir2, "alglib4nl-0009-$(suffix)$(extension)")
            _write_fake_executable(dir2, "alglib4nl-10-$(suffix).ignored")
            _write_fake_executable(dir2, "alglib4nl-010-othersuffix$(extension)")

            @test basename(ALGLIB.executable_path()) == "alglib4nl-0010-$(suffix)$(extension)"

            _write_license_record(
                license_dir,
                "alglib4jump-license-token.jlic",
                """{"license_id":"debug","checkout_number":1,"web_access_token":"","company_name":"","dev_plan":"corporate","user_names":"","min_ver":2,"max_ver":9,"max_release_date":9999999999,"start_at":1,"expire_at":9999999999}""",
            )
            @test basename(ALGLIB.executable_path()) == "alglib4nl-0009-$(suffix)$(extension)"
            @test ALGLIB.binary_info().license_minimum_binary_version == 2
            @test ALGLIB.binary_info().license_maximum_binary_version == 9
            @test ALGLIB.binary_info().selected_binary_version == 9
            @test ALGLIB.binary_info().solver_binary_version_string == "0009"
        finally
            _restore_env!("ALGLIB_EXEC", old_exec)
            _restore_env!("ALGLIB_NLPATH", old_nlpath)
        end
    end
end

@testset "ALGLIB_EXEC" begin
    path = _write_fake_executable(@__DIR__, "fake-alglib4nl"; version = "0042")
    old_exec = get(ENV, "ALGLIB_EXEC", nothing)
    old_nlpath = get(ENV, "ALGLIB_NLPATH", nothing)
    try
        ENV["ALGLIB_EXEC"] = path
        delete!(ENV, "ALGLIB_NLPATH")
        @test ALGLIB.executable_path() == abspath(path)
        @test ALGLIB.binary_info().source == :ALGLIB_EXEC
        @test ALGLIB.binary_info().selected_binary_version == 42
        @test ALGLIB.binary_info().solver_version_string == "0.04.2"
        @test ALGLIB.binary_info().solver_binary_version_string == "0042"
    finally
        old_exec === nothing ? delete!(ENV, "ALGLIB_EXEC") : (ENV["ALGLIB_EXEC"] = old_exec)
        old_nlpath === nothing ? delete!(ENV, "ALGLIB_NLPATH") : (ENV["ALGLIB_NLPATH"] = old_nlpath)
        rm(path; force = true)
    end
end

@testset "solver preferences" begin
    _with_temp_license_home() do _
        _with_solver_env_cleared() do
            _with_temp_depot() do
                _with_temp_active_project() do
                    dir = mktempdir()
                    suffix = ALGLIB.ALGLIB_PLATFORM_SUFFIX
                    extension = Sys.iswindows() ? ".exe" : ""

                    project_exec = _write_fake_executable(dir, "project-alglib"; version = "0043")
                    project_dir = mktempdir()
                    _write_fake_executable(project_dir, "alglib4nl-0007-$(suffix)$(extension)")
                    _write_fake_executable(project_dir, "alglib4nl-0011-$(suffix)$(extension)")

                    @test ALGLIB.set_solver_exec!(project_exec) == abspath(project_exec)
                    @test ALGLIB.executable_path() == abspath(project_exec)
                    @test ALGLIB.binary_info().source == :project_preference_exec
                    @test ALGLIB.binary_info().selected_binary_version == 43

                    @test ALGLIB.set_solver_dir!(project_dir) == abspath(project_dir)
                    @test basename(ALGLIB.executable_path()) == "alglib4nl-0011-$(suffix)$(extension)"
                    @test ALGLIB.binary_info().source == :project_preference_dir
                    @test ALGLIB.binary_info().selected_binary_version == 11

                    env_exec = _write_fake_executable(dir, "env-alglib"; version = "0044")
                    ENV["ALGLIB_EXEC"] = env_exec
                    @test ALGLIB.executable_path() == abspath(env_exec)
                    @test ALGLIB.binary_info().source == :ALGLIB_EXEC
                    @test ALGLIB.binary_info().selected_binary_version == 44
                    delete!(ENV, "ALGLIB_EXEC")

                    env_dir = mktempdir()
                    _write_fake_executable(env_dir, "alglib4nl-0021-$(suffix)$(extension)")
                    ENV["ALGLIB_NLPATH"] = env_dir
                    @test basename(ALGLIB.executable_path()) == "alglib4nl-0021-$(suffix)$(extension)"
                    @test ALGLIB.binary_info().source == :ALGLIB_NLPATH
                    @test ALGLIB.binary_info().selected_binary_version == 21
                    delete!(ENV, "ALGLIB_NLPATH")

                    @test_throws ErrorException ALGLIB.set_solver_exec!(joinpath(dir, "missing"))
                    @test_throws ErrorException ALGLIB.set_solver_dir!(joinpath(dir, "missing-dir"))
                    @test_throws ErrorException ALGLIB.set_solver_dir!(project_dir; scope = :bad)
                end
            end
        end
    end

    _with_temp_license_home() do _
        _with_solver_env_cleared() do
            _with_temp_depot() do
                _with_temp_active_project() do
                    dir = mktempdir()
                    suffix = ALGLIB.ALGLIB_PLATFORM_SUFFIX
                    extension = Sys.iswindows() ? ".exe" : ""

                    global_exec = _write_fake_executable(dir, "global-alglib"; version = "0050")
                    @test ALGLIB.set_solver_exec!(global_exec; scope = :global) == abspath(global_exec)
                    @test ALGLIB.executable_path() == abspath(global_exec)
                    @test ALGLIB.binary_info().source == :global_preference_exec
                    @test ALGLIB.binary_info().selected_binary_version == 50

                    project_preferences = ALGLIB._local_preferences_file(Base.active_project())
                    mkpath(dirname(project_preferences))
                    write(project_preferences, "[ALGLIB]\n__clear__ = [\"solver\"]\n")
                    @test_throws ErrorException ALGLIB.executable_path()

                    project_dir = mktempdir()
                    _write_fake_executable(project_dir, "alglib4nl-0009-$(suffix)$(extension)")
                    @test ALGLIB.set_solver_dir!(project_dir) == abspath(project_dir)
                    @test basename(ALGLIB.executable_path()) == "alglib4nl-0009-$(suffix)$(extension)"
                    @test ALGLIB.binary_info().source == :project_preference_dir
                    @test ALGLIB.binary_info().selected_binary_version == 9
                end
            end
        end
    end
end

@testset "license setup commands" begin
    dir = mktempdir()
    executable, output_path = _write_argument_capture_executable(dir, "fake-alglib4nl")

    ALGLIB.register_evaluation(
        "--dbg-license-dir",
        ".";
        executable = executable,
        options = ["dbg_license_dir=."],
    )
    @test readlines(output_path) == [
        "--just-license-setup",
        "evaluation=true",
        "dbg_license_dir=.",
        "--dbg-license-dir",
        ".",
    ]

    ALGLIB.register_temporary_license(; executable = executable)
    @test readlines(output_path) == [
        "--just-license-setup",
        "evaluation=true",
    ]

    license_path = joinpath(dir, "debug license token.jlic")
    ALGLIB.install_license(
        license_path,
        "dbg_license_dir=.";
        executable = executable,
        options = ["--dbg-license-dir", "."],
    )
    @test readlines(output_path) == [
        "--just-license-setup",
        "install_license=$(license_path)",
        "--dbg-license-dir",
        ".",
        "dbg_license_dir=.",
    ]

    old_exec = get(ENV, "ALGLIB_EXEC", nothing)
    old_nlpath = get(ENV, "ALGLIB_NLPATH", nothing)
    try
        ENV["ALGLIB_EXEC"] = executable
        delete!(ENV, "ALGLIB_NLPATH")
        ALGLIB.register_evaluation()
        @test readlines(output_path) == [
            "--just-license-setup",
            "evaluation=true",
        ]
    finally
        _restore_env!("ALGLIB_EXEC", old_exec)
        _restore_env!("ALGLIB_NLPATH", old_nlpath)
    end
end

@testset "license setup integration" begin
    repository_root = dirname(dirname(@__DIR__))
    executables = _discovered_alglib_executables(repository_root)
    license_token =
        normpath(joinpath(repository_root, "..", "alglib-license-manager", "fetched", "debug-commercial.jlic"))

    if !isempty(executables)
        executable = executables[1].path
        _with_temp_workdir() do dir
            ALGLIB.register_evaluation(
                "--dbg-license-dir",
                ".";
                executable = executable,
            )
            @test isfile(joinpath(dir, "alglib4jump-eval.jlic"))
        end

        _with_temp_workdir() do dir
            ALGLIB.register_temporary_license(
                "dbg_license_dir=.";
                executable = executable,
            )
            @test isfile(joinpath(dir, "alglib4jump-eval.jlic"))
        end

        if isfile(license_token)
            _with_temp_workdir() do dir
                ALGLIB.install_license(
                    license_token,
                    "dbg_license_dir=.";
                    executable = executable,
                )
                @test isfile(joinpath(dir, "alglib4jump-license-token.jlic"))
            end
        end
    end
end

@testset "parameters" begin
    dir = mktempdir()
    fake_executable = _write_fake_executable(dir, "fake-alglib4nl"; version = "0042")
    optimizer = ALGLIB.Optimizer(executable = fake_executable)
    @test sprint(show, optimizer) == "ALGLIB MINLP optimizer"
    @test MOI.get(optimizer, MOI.SolverName()) == "ALGLIB"
    @test MOI.get(optimizer, MOI.SolverVersion()) == "0.04.2"
    @test MOI.supports(optimizer, MOI.RawOptimizerAttribute("custom"))
    @test MOI.supports(optimizer, MOI.Silent())
    @test MOI.supports(optimizer, MOI.TimeLimitSec())
    @test MOI.supports(optimizer, MOI.NumberOfThreads())
    @test MOI.supports(optimizer, MOI.RelativeGapTolerance())
    @test MOI.supports(optimizer, ALGLIB.Algorithm())
    @test MOI.supports(optimizer, ALGLIB.Subsolver())
    @test MOI.supports(optimizer, ALGLIB.SubsolverMemoryLength())

    MOI.set(optimizer, MOI.Silent(), true)
    @test MOI.get(optimizer, MOI.Silent()) == true
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("silent")) == ""
    MOI.set(optimizer, MOI.Silent(), false)
    @test MOI.get(optimizer, MOI.Silent()) == false
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("silent")) === nothing

    MOI.set(optimizer, MOI.TimeLimitSec(), 12.5)
    @test MOI.get(optimizer, MOI.TimeLimitSec()) == 12.5
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("timeout")) == 12.5
    MOI.set(optimizer, MOI.TimeLimitSec(), nothing)
    @test MOI.get(optimizer, MOI.TimeLimitSec()) === nothing
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("timeout")) === nothing

    MOI.set(optimizer, MOI.NumberOfThreads(), 3)
    @test MOI.get(optimizer, MOI.NumberOfThreads()) == 3
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("moi_threads")) == 3
    MOI.set(optimizer, MOI.NumberOfThreads(), nothing)
    @test MOI.get(optimizer, MOI.NumberOfThreads()) === nothing
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("moi_threads")) === nothing

    MOI.set(optimizer, MOI.RelativeGapTolerance(), 1e-3)
    @test MOI.get(optimizer, MOI.RelativeGapTolerance()) == 1e-3
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("pdgap")) == 1e-3
    MOI.set(optimizer, MOI.RelativeGapTolerance(), nothing)
    @test MOI.get(optimizer, MOI.RelativeGapTolerance()) === nothing
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("pdgap")) === nothing

    MOI.set(optimizer, ALGLIB.Algorithm(), :bbsync)
    @test MOI.get(optimizer, ALGLIB.Algorithm()) == :bbsync
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("--bbgd")) == ""
    MOI.set(optimizer, ALGLIB.Algorithm(), nothing)
    @test MOI.get(optimizer, ALGLIB.Algorithm()) === nothing
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("--bbgd")) === nothing

    MOI.set(optimizer, ALGLIB.Subsolver(), "ipm_qn")
    @test MOI.get(optimizer, ALGLIB.Subsolver()) == :ipm_qn
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("--ipm")) == ""
    MOI.set(optimizer, ALGLIB.Subsolver(), nothing)
    @test MOI.get(optimizer, ALGLIB.Subsolver()) === nothing
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("--ipm")) === nothing

    MOI.set(optimizer, ALGLIB.SubsolverMemoryLength(), 20)
    @test MOI.get(optimizer, ALGLIB.SubsolverMemoryLength()) == 20
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("ipm_memlen")) == 20
    MOI.set(optimizer, ALGLIB.SubsolverMemoryLength(), nothing)
    @test MOI.get(optimizer, ALGLIB.SubsolverMemoryLength()) === nothing
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("ipm_memlen")) === nothing

    @test_throws MOI.SetAttributeNotAllowed MOI.set(optimizer, ALGLIB.Algorithm(), :bbgd)
    @test_throws MOI.SetAttributeNotAllowed MOI.set(optimizer, ALGLIB.Subsolver(), :ipm)
    @test_throws MOI.SetAttributeNotAllowed MOI.set(optimizer, ALGLIB.SubsolverMemoryLength(), -1)

    configured = ALGLIB.Optimizer(
        executable = fake_executable,
        algorithm = :bbsync,
        subsolver = :ipm_qn,
        subsolver_memlen = 0,
    )
    @test MOI.get(configured, ALGLIB.Algorithm()) == :bbsync
    @test MOI.get(configured, MOI.RawOptimizerAttribute("--bbgd")) == ""
    @test MOI.get(configured, ALGLIB.Subsolver()) == :ipm_qn
    @test MOI.get(configured, MOI.RawOptimizerAttribute("--ipm")) == ""
    @test MOI.get(configured, ALGLIB.SubsolverMemoryLength()) == 0
    @test MOI.get(configured, MOI.RawOptimizerAttribute("ipm_memlen")) == 0

    MOI.set(optimizer, MOI.RawOptimizerAttribute("custom"), "value")
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("custom")) == "value"
end

@testset "MOI.Test" begin
    repository_root = dirname(dirname(@__DIR__))
    executables = _discovered_alglib_executables(repository_root)
    nlpath_dirs = unique(dirname(candidate.path) for candidate in executables)
    old_exec = get(ENV, "ALGLIB_EXEC", nothing)
    old_nlpath = get(ENV, "ALGLIB_NLPATH", nothing)
    try
        if old_exec === nothing && !isempty(nlpath_dirs)
            delete!(ENV, "ALGLIB_EXEC")
            ENV["ALGLIB_NLPATH"] = join(filter(isdir, nlpath_dirs), Sys.iswindows() ? ';' : ':')
        end
        MOI.Test.runtests(
            _optimizer(),
            MOI.Test.Config(
                atol = 1e-4,
                rtol = 1e-4,
                optimal_status = MOI.LOCALLY_SOLVED,
                infeasible_status = MOI.LOCALLY_INFEASIBLE,
                exclude = Any[
                    # ALGLIB is exposed through the AMPL .nl file format, which
                    # does not return simplex-style basis statuses.
                    MOI.VariableBasisStatus,
                    MOI.ConstraintBasisStatus,
                    # The AMPL .sol result reader does not expose these values.
                    MOI.ObjectiveBound,
                    MOI.DualObjectiveValue,
                    # The current ALGLIB .sol output observed in tests does not
                    # provide constraint duals, so dual checks are excluded.
                    MOI.ConstraintDual,
                ],
            );
            include = _moi_test_include(),
            exclude = _moi_test_exclude(),
            verbose = _run_verbose_moi_tests(),
        )
    finally
        old_exec === nothing ? delete!(ENV, "ALGLIB_EXEC") : (ENV["ALGLIB_EXEC"] = old_exec)
        old_nlpath === nothing ? delete!(ENV, "ALGLIB_NLPATH") : (ENV["ALGLIB_NLPATH"] = old_nlpath)
    end
end

@testset "ALGLIB_NLPATH" begin
    dir = mktempdir()
    bounds = ALGLIB.license_version_bounds()
    binary_version = max(parse(Int, ALGLIB.ALGLIB_SOLVER_BINARY_VERSION_STRING), bounds.minver)
    binary_version_string = lpad(string(binary_version), 4, '0')
    exe_extension = Sys.iswindows() ? ".exe" : ""
    executable_name = "alglib4nl-$(binary_version_string)-$(ALGLIB.ALGLIB_PLATFORM_SUFFIX)$(exe_extension)"
    path = joinpath(dir, executable_name)
    write(path, "#!/bin/sh\nexit 0\n")
    chmod(path, 0o755)
    old_exec = get(ENV, "ALGLIB_EXEC", nothing)
    old_nlpath = get(ENV, "ALGLIB_NLPATH", nothing)
    try
        delete!(ENV, "ALGLIB_EXEC")
        ENV["ALGLIB_NLPATH"] = dir
        @test ALGLIB.executable_path() == abspath(path)
        @test ALGLIB.binary_info().source == :ALGLIB_NLPATH
        @test ALGLIB.binary_info().solver_version_string ==
              ALGLIB.solver_version_string(executable_name)
        @test ALGLIB.binary_info().wrapper_version_string ==
              ALGLIB.ALGLIB_JL_VERSION_STRING
        @test ALGLIB.binary_info().solver_binary_version_string == binary_version_string
    finally
        old_exec === nothing ? delete!(ENV, "ALGLIB_EXEC") : (ENV["ALGLIB_EXEC"] = old_exec)
        old_nlpath === nothing ? delete!(ENV, "ALGLIB_NLPATH") : (ENV["ALGLIB_NLPATH"] = old_nlpath)
    end
end
