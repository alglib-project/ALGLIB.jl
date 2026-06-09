module ALGLIB

import AmplNLWriter
import JSON
import MathOptInterface as MOI
import TOML

export ALGLIB_JL_VERSION
export ALGLIB_JL_VERSION_STRING
export ALGLIB_SOLVER_BINARY_VERSION_STRING
export Optimizer
export ALGLIB_PLATFORM_SUFFIX
export Algorithm
export binary_info
export executable_name
export executable_path
export install_license
export license_version_bounds
export register_evaluation
export register_temporary_license
export set_solver_dir!
export set_solver_exec!
export Subsolver
export SubsolverMemoryLength

const ALGLIB_JL_VERSION_STRING = "1.0.1"
const ALGLIB_JL_VERSION = VersionNumber(ALGLIB_JL_VERSION_STRING)

const ALGLIB_SOLVER_BINARY_VERSION_STRING = "0001"
const ALGLIB_SOLVER_MINIMUM_BINARY_VERSION = 1
const ALGLIB_SOLVER_MAXIMUM_BINARY_VERSION = 999999

include("executable.jl")

"""
    register_evaluation(args...; executable = nothing, options = String[])

Start or check an ALGLIB evaluation license by running the executable in
license-setup mode.
"""
function register_evaluation(
    args::AbstractString...;
    executable::Union{Nothing,AbstractString} = nothing,
    options::AbstractVector{<:AbstractString} = String[],
)
    return _run_license_setup(
        "evaluation=true",
        args;
        executable = executable,
        options = options,
    )
end

"""
    register_temporary_license(args...; executable = nothing, options = String[])

Alias for [`register_evaluation`](@ref). The same solver mode is used for
evaluation and temporary licenses.
"""
function register_temporary_license(
    args::AbstractString...;
    executable::Union{Nothing,AbstractString} = nothing,
    options::AbstractVector{<:AbstractString} = String[],
)
    return register_evaluation(
        args...;
        executable = executable,
        options = options,
    )
end

"""
    install_license(path, args...; executable = nothing, options = String[])

Install an ALGLIB license token file by running the executable in license-setup
mode.
"""
function install_license(
    path::AbstractString,
    args::AbstractString...;
    executable::Union{Nothing,AbstractString} = nothing,
    options::AbstractVector{<:AbstractString} = String[],
)
    return _run_license_setup(
        "install_license=$(String(path))",
        args;
        executable = executable,
        options = options,
    )
end

"""
    Optimizer(;
        executable = nothing,
        options = String[],
        algorithm = nothing,
        subsolver = nothing,
        subsolver_memlen = nothing,
        kwargs...,
    )

Create an AMPL `.nl` optimizer for ALGLIB's `alglib4nl` executable.

An explicit `executable` path overrides all configured defaults. Otherwise, the
executable is resolved from `ALGLIB_EXEC`, `ALGLIB_NLPATH`, or ALGLIB package
preferences set by [`set_solver_exec!`](@ref) and [`set_solver_dir!`](@ref).
Use `options` for solver command-line options passed through AmplNLWriter.
Use `algorithm = :bbsync`, `subsolver = :ipm_qn`, and `subsolver_memlen = N`
for the corresponding ALGLIB solver controls.
Additional keyword arguments are forwarded to `AmplNLWriter.Optimizer`.
"""
struct Algorithm <: MOI.AbstractOptimizerAttribute end

struct Subsolver <: MOI.AbstractOptimizerAttribute end

struct SubsolverMemoryLength <: MOI.AbstractOptimizerAttribute end

const _ALGORITHM_BBSYNC_FLAG = "--bbgd"
const _SUBSOLVER_IPM_QN_FLAG = "--ipm"
const _SUBSOLVER_IPM_QN_MEMLEN_OPTION = "ipm_memlen"

mutable struct Optimizer <: MOI.AbstractOptimizer
    inner::AmplNLWriter.Optimizer
    executable::String
    query_solver_version::Bool
end

function Optimizer(;
    executable::Union{Nothing,AbstractString} = nothing,
    options::Vector{String} = String[],
    algorithm = nothing,
    subsolver = nothing,
    subsolver_memlen = nothing,
    kwargs...,
)
    resolved = if executable === nothing
        _resolve_executable()
    else
        (path = String(executable), source = :argument, query_solver_version = true)
    end
    solver = resolved.path
    model = Optimizer(
        AmplNLWriter.Optimizer(solver, options; kwargs...),
        solver,
        resolved.query_solver_version,
    )
    if algorithm !== nothing
        MOI.set(model, Algorithm(), algorithm)
    end
    if subsolver !== nothing
        MOI.set(model, Subsolver(), subsolver)
    end
    if subsolver_memlen !== nothing
        MOI.set(model, SubsolverMemoryLength(), subsolver_memlen)
    end
    return model
end

Base.show(io::IO, ::Optimizer) = print(io, "ALGLIB MINLP optimizer")

MOI.empty!(model::Optimizer) = MOI.empty!(model.inner)
MOI.is_empty(model::Optimizer) = MOI.is_empty(model.inner)
MOI.supports_incremental_interface(model::Optimizer) =
    MOI.supports_incremental_interface(model.inner)
MOI.optimize!(model::Optimizer) = MOI.optimize!(model.inner)

const _MOI_ATTRIBUTE = Union{
    MOI.AbstractConstraintAttribute,
    MOI.AbstractModelAttribute,
    MOI.AbstractOptimizerAttribute,
    MOI.AbstractVariableAttribute,
}

MOI.get(model::Optimizer, attr::_MOI_ATTRIBUTE, args...) =
    MOI.get(model.inner, attr, args...)
MOI.get(model::Optimizer, attr::_MOI_ATTRIBUTE, idxs::Vector) =
    MOI.get(model.inner, attr, idxs)
MOI.set(model::Optimizer, attr::_MOI_ATTRIBUTE, args...) =
    MOI.set(model.inner, attr, args...)
MOI.set(
    model::Optimizer,
    attr::Union{MOI.AbstractVariableAttribute,MOI.AbstractConstraintAttribute},
    idxs::Vector,
    values::Vector,
) = MOI.set(model.inner, attr, idxs, values)
MOI.supports(model::Optimizer, attr::_MOI_ATTRIBUTE, args...) =
    MOI.supports(model.inner, attr, args...)
MOI.supports_constraint(
    model::Optimizer,
    F::Type{<:MOI.AbstractFunction},
    S::Type{<:MOI.AbstractSet},
) = MOI.supports_constraint(model.inner, F, S)
MOI.add_variable(model::Optimizer) = MOI.add_variable(model.inner)
MOI.add_variables(model::Optimizer, n::Int) = MOI.add_variables(model.inner, n)
MOI.add_constraint(
    model::Optimizer,
    func::MOI.AbstractFunction,
    set::MOI.AbstractSet,
) = MOI.add_constraint(model.inner, func, set)
MOI.add_constraint(
    model::Optimizer,
    variables::Vector{MOI.VariableIndex},
    set::MOI.AbstractVectorSet,
) = MOI.add_constraint(model.inner, variables, set)
MOI.add_constrained_variable(model::Optimizer, set::MOI.AbstractScalarSet) =
    MOI.add_constrained_variable(model.inner, set)
MOI.add_constrained_variables(model::Optimizer, set::MOI.AbstractVectorSet) =
    MOI.add_constrained_variables(model.inner, set)
MOI.delete(model::Optimizer, index::MOI.Index) = MOI.delete(model.inner, index)
MOI.delete(model::Optimizer, indices::Vector{<:MOI.Index}) =
    MOI.delete(model.inner, indices)
MOI.is_valid(model::Optimizer, index::MOI.Index) = MOI.is_valid(model.inner, index)
MOI.modify(
    model::Optimizer,
    ci::MOI.ConstraintIndex,
    change::MOI.AbstractFunctionModification,
) = MOI.modify(model.inner, ci, change)
MOI.modify(
    model::Optimizer,
    cis::AbstractVector{<:MOI.ConstraintIndex},
    changes::AbstractVector{<:MOI.AbstractFunctionModification},
) = MOI.modify(model.inner, cis, changes)
MOI.modify(
    model::Optimizer,
    attr::MOI.ObjectiveFunction,
    change::MOI.AbstractFunctionModification,
) = MOI.modify(model.inner, attr, change)
MOI.modify(
    model::Optimizer,
    attr::MOI.ObjectiveFunction,
    changes::AbstractVector{<:MOI.AbstractFunctionModification},
) = MOI.modify(model.inner, attr, changes)
MOI.copy_to(model::Optimizer, src) = MOI.copy_to(model.inner, src)

MOI.supports(::Optimizer, ::MOI.RawOptimizerAttribute) = true
MOI.get(model::Optimizer, attr::MOI.RawOptimizerAttribute) = MOI.get(model.inner, attr)
MOI.set(model::Optimizer, attr::MOI.RawOptimizerAttribute, value) =
    MOI.set(model.inner, attr, value)

MOI.get(::Optimizer, ::MOI.SolverName) = "ALGLIB"
function MOI.get(model::Optimizer, ::MOI.SolverVersion)
    binary_version = if model.query_solver_version
        _query_executable_binary_version(model.executable)
    else
        _executable_binary_version(model.executable)
    end
    return _solver_version_string_from_binary_version(binary_version)
end

function MOI.supports(
    ::Optimizer,
    ::Union{
        MOI.Silent,
        MOI.TimeLimitSec,
        MOI.NumberOfThreads,
        MOI.RelativeGapTolerance,
        Algorithm,
        Subsolver,
        SubsolverMemoryLength,
    },
)
    return true
end

function _normalized_symbol(attr::MOI.AbstractOptimizerAttribute, value, allowed)
    if value === nothing
        return nothing
    elseif value isa Symbol || value isa AbstractString
        normalized = Symbol(lowercase(String(value)))
        if normalized in allowed
            return normalized
        end
    end
    expected = join(string.(allowed), ", ")
    throw(
        MOI.SetAttributeNotAllowed(
            attr,
            "Invalid value $(repr(value)); expected one of $expected.",
        ),
    )
end

function MOI.get(model::Optimizer, ::Algorithm)
    return haskey(model.inner.options, _ALGORITHM_BBSYNC_FLAG) ? :bbsync : nothing
end

function MOI.set(model::Optimizer, attr::Algorithm, value)
    normalized = _normalized_symbol(attr, value, (:bbsync,))
    if normalized === nothing
        delete!(model.inner.options, _ALGORITHM_BBSYNC_FLAG)
    elseif normalized == :bbsync
        model.inner.options[_ALGORITHM_BBSYNC_FLAG] = ""
    end
    return
end

function MOI.get(model::Optimizer, ::Subsolver)
    return haskey(model.inner.options, _SUBSOLVER_IPM_QN_FLAG) ? :ipm_qn : nothing
end

function MOI.set(model::Optimizer, attr::Subsolver, value)
    normalized = _normalized_symbol(attr, value, (:ipm_qn,))
    if normalized === nothing
        delete!(model.inner.options, _SUBSOLVER_IPM_QN_FLAG)
    elseif normalized == :ipm_qn
        model.inner.options[_SUBSOLVER_IPM_QN_FLAG] = ""
    end
    return
end

function MOI.get(model::Optimizer, ::SubsolverMemoryLength)
    value = get(model.inner.options, _SUBSOLVER_IPM_QN_MEMLEN_OPTION, nothing)
    return value === nothing ? nothing : Int(value)
end

function MOI.set(model::Optimizer, attr::SubsolverMemoryLength, value)
    if value === nothing
        delete!(model.inner.options, _SUBSOLVER_IPM_QN_MEMLEN_OPTION)
        return
    elseif !(value isa Integer) || value isa Bool || value < 0
        throw(
            MOI.SetAttributeNotAllowed(
                attr,
                "Invalid value $(repr(value)); expected a nonnegative integer.",
            ),
        )
    end
    model.inner.options[_SUBSOLVER_IPM_QN_MEMLEN_OPTION] = Int(value)
    return
end

function MOI.get(model::Optimizer, ::MOI.Silent)
    return haskey(model.inner.options, "silent")
end

function MOI.set(model::Optimizer, ::MOI.Silent, value::Bool)
    if value
        model.inner.options["silent"] = ""
    else
        delete!(model.inner.options, "silent")
    end
    return
end

function MOI.get(model::Optimizer, ::MOI.TimeLimitSec)
    value = get(model.inner.options, "timeout", nothing)
    return value === nothing ? nothing : Float64(value)
end

function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, value)
    if value === nothing
        delete!(model.inner.options, "timeout")
        return
    end
    model.inner.options["timeout"] = Float64(value)
    return
end

function MOI.get(model::Optimizer, ::MOI.NumberOfThreads)
    value = get(model.inner.options, "moi_threads", nothing)
    return value === nothing ? nothing : Int(value)
end

function MOI.set(model::Optimizer, ::MOI.NumberOfThreads, value::Union{Nothing,Integer})
    if value === nothing
        delete!(model.inner.options, "moi_threads")
        return
    end
    model.inner.options["moi_threads"] = Int(value)
    return
end

function MOI.get(model::Optimizer, ::MOI.RelativeGapTolerance)
    value = get(model.inner.options, "pdgap", nothing)
    return value === nothing ? nothing : Float64(value)
end

function MOI.set(model::Optimizer, ::MOI.RelativeGapTolerance, value)
    if value === nothing
        delete!(model.inner.options, "pdgap")
        return
    end
    model.inner.options["pdgap"] = Float64(value)
    return
end

end
