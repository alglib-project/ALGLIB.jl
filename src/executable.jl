const _EXEC_ENV = "ALGLIB_EXEC"
const _NLPATH_ENV = "ALGLIB_NLPATH"
const _EXECUTABLE_BASENAME = "alglib4nl"
const _LICENSE_TOKEN_FILE = "alglib4jump-license-token.jlic"
const _EVALUATION_LICENSE_FILE = "alglib4jump-eval.jlic"
const _PACKAGE_NAME = "ALGLIB"
const _SOLVER_PREFERENCE_KEY = "solver"
const _SOLVER_PREFERENCE_KIND_EXEC = "exec"
const _SOLVER_PREFERENCE_KIND_DIR = "dir"

struct _PreferenceAbsent end
struct _PreferenceCleared end

const _PREFERENCE_ABSENT = _PreferenceAbsent()
const _PREFERENCE_CLEARED = _PreferenceCleared()

function _platform_suffix(kernel::Symbol, arch::Symbol, word_size::Integer)
    if kernel == :Linux
        if arch == :aarch64
            return "linuxarm64"
        end
        return word_size == 64 ? "linux64" : "linux32"
    elseif kernel == :Windows
        return word_size == 64 ? "win64" : "win32"
    elseif kernel == :Darwin
        return arch == :aarch64 ? "osxarm64" : "osx64"
    end
    return string(kernel, word_size)
end

_platform_suffix() = _platform_suffix(Sys.KERNEL, Sys.ARCH, Sys.WORD_SIZE)

const ALGLIB_PLATFORM_SUFFIX = _platform_suffix()

function _exe_extension()
    return Sys.iswindows() ? ".exe" : ""
end

function _default_license_dir()
    if Sys.iswindows()
        base = get(ENV, "LOCALAPPDATA", joinpath(homedir(), "AppData", "Local"))
        return joinpath(base, "ALGLIB")
    end
    base = get(ENV, "XDG_STATE_HOME", joinpath(homedir(), ".local", "state"))
    return joinpath(base, "alglib")
end

function _signed_payload(path::AbstractString)
    text = read(path, String)
    line_end = findfirst('\n', text)
    return line_end === nothing ? nothing : text[nextind(text, line_end):end]
end

function _integer_field(record, name::AbstractString)
    value = get(record, name, nothing)
    return value isa Integer ? Int(value) : nothing
end

function _parse_json_payload(path::AbstractString)
    payload = _signed_payload(path)
    return payload === nothing ? nothing : JSON.parse(payload)
end

function _license_token_bounds(license_dir::AbstractString)
    path = joinpath(license_dir, _LICENSE_TOKEN_FILE)
    isfile(path) || return nothing
    record = _parse_json_payload(path)
    record isa AbstractDict || return _default_license_bounds()
    minver = _integer_field(record, "min_ver")
    maxver = _integer_field(record, "max_ver")
    if minver === nothing || maxver === nothing || minver > maxver
        return _default_license_bounds()
    end
    return (minver = minver, maxver = maxver)
end

function _evaluation_license_bounds(license_dir::AbstractString)
    path = joinpath(license_dir, _EVALUATION_LICENSE_FILE)
    isfile(path) || return nothing
    record = _parse_json_payload(path)
    record isa AbstractDict || return _default_license_bounds()
    minver = _integer_field(record, "initial_ver_id")
    minver === nothing && return _default_license_bounds()
    return (minver = minver, maxver = ALGLIB_SOLVER_MAXIMUM_BINARY_VERSION)
end

function _default_license_bounds()
    return (
        minver = ALGLIB_SOLVER_MINIMUM_BINARY_VERSION,
        maxver = ALGLIB_SOLVER_MAXIMUM_BINARY_VERSION,
    )
end

function _binary_version_to_string(version::Integer)
    if version < 0
        error("ALGLIB binary version must be non-negative, got `$(version)`.")
    end
    major = version ÷ 1000
    minor = (version % 1000) ÷ 10
    patch = version % 10
    return string(major, ".", lpad(minor, 2, '0'), ".", patch)
end

function _binary_version_token(version::Integer)
    if version < 0
        error("ALGLIB binary version must be non-negative, got `$(version)`.")
    end
    return lpad(string(version), 4, '0')
end

"""
    license_version_bounds()

Return the ALGLIB binary-version interval supported by the current license.

The wrapper reads the same license-state files as the ALGLIB license manager,
but it does not verify signatures. Invalid signatures and malformed or missing
license files are left to the solver and default to `1:999999` here.
"""
function license_version_bounds(; license_dir::AbstractString = _default_license_dir())
    try
        bounds = _license_token_bounds(license_dir)
        bounds !== nothing && return bounds
        bounds = _evaluation_license_bounds(license_dir)
        bounds !== nothing && return bounds
    catch
        return _default_license_bounds()
    end
    return _default_license_bounds()
end

"""
    executable_name()

Return the minimum ALGLIB executable filename for the current platform.
"""
function executable_name()
    return "$(_EXECUTABLE_BASENAME)-$(ALGLIB_SOLVER_BINARY_VERSION_STRING)-$(ALGLIB_PLATFORM_SUFFIX)$(_exe_extension())"
end

function _path_entries(value::AbstractString)
    return filter!(!isempty, split(value, Sys.iswindows() ? ';' : ':'))
end

function _check_executable(path::AbstractString)
    if !isfile(path)
        return nothing
    end
    if !Sys.iswindows() && stat(path).mode & 0o111 == 0
        return nothing
    end
    return abspath(path)
end

function _regex_escape(value::AbstractString)
    return replace(value, r"([\\\^\$\.\|\?\*\+\(\)\[\]\{\}])" => s -> "\\" * String(s))
end

function _candidate_executable_regex()
    suffix = _regex_escape(ALGLIB_PLATFORM_SUFFIX)
    extension = _regex_escape(_exe_extension())
    return Regex("^$(_EXECUTABLE_BASENAME)-([0-9]+)-$(suffix)$(extension)\$")
end

function _executable_binary_version(path::AbstractString)
    match_result = match(_candidate_executable_regex(), basename(path))
    if match_result === nothing
        error(
            "Unable to determine ALGLIB solver version from executable name `$(basename(path))`; expected `$(_EXECUTABLE_BASENAME)-DIGITS-$(ALGLIB_PLATFORM_SUFFIX)$(_exe_extension())`.",
        )
    end
    return parse(Int, match_result.captures[1]; base = 10)
end

function _parse_binary_version_token(token::AbstractString)
    stripped = strip(token)
    if isempty(stripped) || !all(isdigit, stripped)
        error("Invalid ALGLIB `--version` output `$(token)`.")
    end
    return parse(Int, stripped; base = 10)
end

function _query_executable_binary_version(path::AbstractString)
    output = try
        read(Cmd([path, "--version"]), String)
    catch err
        error("Unable to query ALGLIB solver version from `$(path) --version`: $(err)")
    end
    return _parse_binary_version_token(output)
end

"""
    solver_version_string(executable)

Return the ALGLIB solver version derived from a versioned executable name.
"""
function solver_version_string(executable::AbstractString)
    return _binary_version_to_string(_executable_binary_version(executable))
end

function _solver_version_string_from_binary_version(binary_version::Integer)
    return _binary_version_to_string(binary_version)
end

function _candidate_executables(dir::AbstractString)
    isdir(dir) || return Tuple{Int,String,String}[]
    pattern = _candidate_executable_regex()
    candidates = Tuple{Int,String,String}[]
    for name in readdir(dir)
        match_result = match(pattern, name)
        match_result === nothing && continue
        version = try
            parse(Int, match_result.captures[1]; base = 10)
        catch
            continue
        end
        path = _check_executable(joinpath(dir, name))
        path === nothing && continue
        push!(candidates, (version, path, name))
    end
    return candidates
end

function _select_nlpath_executable(value::AbstractString)
    bounds = license_version_bounds()
    best = nothing
    for dir in _path_entries(value)
        for candidate in _candidate_executables(dir)
            version, path, name = candidate
            if bounds.minver <= version <= bounds.maxver &&
               (best === nothing || version > best.version)
                best = (version = version, path = path, name = name)
            end
        end
    end
    return best
end

_select_nlpath_executable() = _select_nlpath_executable(ENV[_NLPATH_ENV])

function _global_preferences_project_file()
    if isempty(DEPOT_PATH)
        error("Unable to locate the default Julia environment because `DEPOT_PATH` is empty.")
    end
    return joinpath(
        DEPOT_PATH[1],
        "environments",
        "v$(VERSION.major).$(VERSION.minor)",
        "Project.toml",
    )
end

function _preference_project_file(scope::Symbol; for_write::Bool = false)
    if scope == :project
        project = Base.active_project()
        if project === nothing
            for_write && error("Unable to set ALGLIB project preferences because no Julia project is active.")
            return nothing
        end
        return project
    elseif scope == :global
        return _global_preferences_project_file()
    end
    error("Invalid ALGLIB preference scope `$(scope)`. Expected `:project` or `:global`.")
end

function _local_preferences_file(project_toml::AbstractString)
    project_dir = dirname(project_toml)
    for name in Base.preferences_names
        path = joinpath(project_dir, name)
        if isfile(path)
            return path
        end
    end
    return joinpath(project_dir, "LocalPreferences.toml")
end

function _read_toml_file(path::AbstractString)
    isfile(path) || return Dict{String,Any}()
    try
        return TOML.parsefile(path)
    catch err
        error("Unable to read ALGLIB preferences from `$(path)`: $(err)")
    end
end

function _solver_preference_from_table(table)
    table isa AbstractDict || return _PREFERENCE_ABSENT
    package_table = get(table, _PACKAGE_NAME, nothing)
    package_table isa AbstractDict || return _PREFERENCE_ABSENT
    clear = get(package_table, "__clear__", String[])
    if clear isa AbstractVector && _SOLVER_PREFERENCE_KEY in clear
        return _PREFERENCE_CLEARED
    end
    return get(package_table, _SOLVER_PREFERENCE_KEY, _PREFERENCE_ABSENT)
end

function _load_solver_preference(scope::Symbol)
    project_toml = _preference_project_file(scope)
    project_toml === nothing && return _PREFERENCE_ABSENT

    local_preference = _solver_preference_from_table(
        _read_toml_file(_local_preferences_file(project_toml)),
    )
    local_preference !== _PREFERENCE_ABSENT && return local_preference

    project = _read_toml_file(project_toml)
    project_preferences = get(project, "preferences", nothing)
    return _solver_preference_from_table(project_preferences)
end

function _package_preference_table!(preferences::Dict{String,Any})
    package_table = get(preferences, _PACKAGE_NAME, nothing)
    if !(package_table isa Dict{String,Any})
        package_table = Dict{String,Any}()
        preferences[_PACKAGE_NAME] = package_table
    end
    return package_table
end

function _remove_solver_clear!(package_table::Dict{String,Any})
    clear = get(package_table, "__clear__", nothing)
    clear isa AbstractVector || return
    remaining = Any[value for value in clear if value != _SOLVER_PREFERENCE_KEY]
    if isempty(remaining)
        delete!(package_table, "__clear__")
    else
        package_table["__clear__"] = remaining
    end
    return
end

function _set_solver_preference!(
    kind::AbstractString,
    path::AbstractString;
    scope::Symbol,
)
    project_toml = _preference_project_file(scope; for_write = true)
    preferences_file = _local_preferences_file(project_toml)
    mkpath(dirname(preferences_file))
    preferences = _read_toml_file(preferences_file)
    package_table = _package_preference_table!(preferences)
    _remove_solver_clear!(package_table)
    package_table[_SOLVER_PREFERENCE_KEY] = Dict{String,Any}(
        "kind" => String(kind),
        "path" => String(path),
    )
    open(preferences_file, "w") do io
        TOML.print(io, preferences; sorted = true)
    end
    return
end

"""
    set_solver_exec!(path; scope = :project)

Store an exact ALGLIB executable path in Julia package preferences.

`scope = :project` writes to the active project's local preferences.
`scope = :global` writes to the user's default Julia environment preferences.
"""
function set_solver_exec!(path::AbstractString; scope::Symbol = :project)
    executable = _check_executable(path)
    if executable === nothing
        error("ALGLIB solver executable `$(path)` is not an executable file.")
    end
    _set_solver_preference!(_SOLVER_PREFERENCE_KIND_EXEC, executable; scope = scope)
    return executable
end

"""
    set_solver_dir!(path; scope = :project)

Store a directory containing ALGLIB executables in Julia package preferences.

The directory is scanned for platform-specific executable names like
`alglib4nl-DIGITS-$(ALGLIB_PLATFORM_SUFFIX)$(_exe_extension())`.
"""
function set_solver_dir!(path::AbstractString; scope::Symbol = :project)
    dir = abspath(path)
    isdir(dir) || error("ALGLIB solver directory `$(path)` is not a directory.")
    _set_solver_preference!(_SOLVER_PREFERENCE_KIND_DIR, dir; scope = scope)
    return dir
end

function _preference_source(scope::Symbol, kind::AbstractString)
    if scope == :project
        return kind == _SOLVER_PREFERENCE_KIND_EXEC ? :project_preference_exec :
               :project_preference_dir
    elseif scope == :global
        return kind == _SOLVER_PREFERENCE_KIND_EXEC ? :global_preference_exec :
               :global_preference_dir
    end
    error("Invalid ALGLIB preference scope `$(scope)`. Expected `:project` or `:global`.")
end

function _resolve_exact_executable(value::AbstractString, source::Symbol, description::AbstractString)
    path = _check_executable(value)
    if path !== nothing
        return (path = path, source = source, query_solver_version = true)
    end
    error("`$(description)` is set to `$(value)`, but this is not an executable file.")
end

function _resolve_executable_dir(value::AbstractString, source::Symbol, description::AbstractString)
    selection = _select_nlpath_executable(value)
    if selection !== nothing
        return (path = selection.path, source = source, query_solver_version = false)
    end
    bounds = license_version_bounds()
    error(
        "Unable to locate an executable matching `$(_EXECUTABLE_BASENAME)-DIGITS-$(ALGLIB_PLATFORM_SUFFIX)$(_exe_extension())` with decimal version in [$(bounds.minver), $(bounds.maxver)] in `$(description)=$(value)`.",
    )
end

function _resolve_solver_preference(record, scope::Symbol)
    if !(record isa AbstractDict)
        error("Invalid ALGLIB solver preference for scope `$(scope)`: expected a table.")
    end
    kind = get(record, "kind", nothing)
    path = get(record, "path", nothing)
    if !(kind isa AbstractString) || !(path isa AbstractString)
        error(
            "Invalid ALGLIB solver preference for scope `$(scope)`: expected string fields `kind` and `path`.",
        )
    end
    if kind == _SOLVER_PREFERENCE_KIND_EXEC
        return _resolve_exact_executable(
            path,
            _preference_source(scope, kind),
            "$(scope) solver executable preference",
        )
    elseif kind == _SOLVER_PREFERENCE_KIND_DIR
        return _resolve_executable_dir(
            path,
            _preference_source(scope, kind),
            "$(scope) solver directory preference",
        )
    end
    error(
        "Invalid ALGLIB solver preference for scope `$(scope)`: expected `kind` to be `exec` or `dir`, got `$(kind)`.",
    )
end

function _resolve_executable()
    if haskey(ENV, _EXEC_ENV)
        return _resolve_exact_executable(ENV[_EXEC_ENV], :ALGLIB_EXEC, _EXEC_ENV)
    end
    if haskey(ENV, _NLPATH_ENV)
        return _resolve_executable_dir(ENV[_NLPATH_ENV], :ALGLIB_NLPATH, _NLPATH_ENV)
    end
    for scope in (:project, :global)
        preference = _load_solver_preference(scope)
        preference === _PREFERENCE_ABSENT && continue
        preference === _PREFERENCE_CLEARED && break
        return _resolve_solver_preference(preference, scope)
    end
    error(
        """
        Unable to locate the ALGLIB executable.

        Set `$(_EXEC_ENV)` to the exact executable path, set `$(_NLPATH_ENV)`
        to a path-list of directories containing a compatible ALGLIB executable,
        or call `ALGLIB.set_solver_exec!` or `ALGLIB.set_solver_dir!`.
        """,
    )
end

"""
    executable_path()

Return the ALGLIB `alglib4nl` executable path.

`Optimizer(executable = ...)` bypasses this function. Otherwise, resolution
order is:

1. `ALGLIB_EXEC`, interpreted as an exact executable path.
2. `ALGLIB_NLPATH`, interpreted as a path-list of directories scanned for the
   highest compatible platform-specific ALGLIB executable.
3. The active project's `ALGLIB.set_solver_exec!` preference.
4. The active project's `ALGLIB.set_solver_dir!` preference.
5. The default Julia environment's `ALGLIB.set_solver_exec!` preference.
6. The default Julia environment's `ALGLIB.set_solver_dir!` preference.
"""
function executable_path()
    return _resolve_executable().path
end

function _license_setup_executable(executable::Union{Nothing,AbstractString})
    return executable === nothing ? executable_path() : String(executable)
end

function _license_setup_command(
    action::AbstractString,
    extra_args;
    executable::Union{Nothing,AbstractString} = nothing,
    options::AbstractVector{<:AbstractString} = String[],
)
    solver = _license_setup_executable(executable)
    return Cmd([
        solver,
        "--just-license-setup",
        String(action),
        String.(options)...,
        String.(extra_args)...,
    ])
end

function _run_license_setup(
    action::AbstractString,
    extra_args;
    executable::Union{Nothing,AbstractString} = nothing,
    options::AbstractVector{<:AbstractString} = String[],
)
    return run(
        _license_setup_command(
            action,
            extra_args;
            executable = executable,
            options = options,
        ),
    )
end

"""
    binary_info()

Return basic information about the configured ALGLIB binary.
"""
function binary_info()
    resolved = _resolve_executable()
    path = resolved.path
    bounds = license_version_bounds()
    binary_version = if resolved.query_solver_version
        _query_executable_binary_version(path)
    else
        _executable_binary_version(path)
    end
    return (
        source = resolved.source,
        path = path,
        executable_name = basename(path),
        selected_binary_version = binary_version,
        license_minimum_binary_version = bounds.minver,
        license_maximum_binary_version = bounds.maxver,
        solver_version_string = _solver_version_string_from_binary_version(binary_version),
        solver_version = VersionNumber(_solver_version_string_from_binary_version(binary_version)),
        solver_binary_version_string = _binary_version_token(binary_version),
        wrapper_version_string = ALGLIB_JL_VERSION_STRING,
        wrapper_version = ALGLIB_JL_VERSION,
    )
end
