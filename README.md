## Table of contents

- [1 ALGLIB Solver](#alglib_solver_overview)
  - [1.1 What is ALGLIB Solver?](#alglib_solver_what_is_it)
  - [1.2 Supported problem types](#alglib_solver_problem_types)
  - [1.3 ALGLIB Solver vs ALGLIB Library](#alglib_solver_vs_library)
  - [1.4 Downloading and installing](#alglib_solver_download)
  - [1.5 Licensing](#alglib_solver_licensing)
    - [1.5.1 Overview](#alglib_solver_licensing_overview)
    - [1.5.2 Temporary Evaluation License Agreement](#alglib_solver_licensing_evaluation)
    - [1.5.3 Personal, Academic and non-profit research Usage License Agreement](#alglib_solver_licensing_paula)
    - [1.5.4 Commercial licensing](#alglib_solver_licensing_comm)
- [2 Using ALGLIB Solver from JuMP](#alglib_solver_using_jump)
  - [2.1 Installation and activation](#alglib_solver_using_jump_install)
  - [2.2 System-wide license installation](#alglib_solver_using_jump_systemwide)
  - [2.3 Usage and standard MOI parameters](#alglib_solver_using_jump_config)
  - [2.4 Solver-specific parameters](#alglib_solver_using_jump_config_special)

<a id="alglib_solver_overview"></a>

# 1 ALGLIB Solver

<a id="alglib_solver_what_is_it"></a>

## 1.1 What is ALGLIB Solver?

ALGLIB Solver is the optimization-only subset of ALGLIB for users who model problems in environments such as JuMP
instead of calling the full ALGLIB native APIs directly from C++/C#/etc.
It is a binary solver package with all performance features enabled, including SIMD acceleration and robust out-of-the-box parallel execution.

The solver is presently available under x64 Windows and Linux platforms, from JuMP environment or as a part of .nl-based workflow.

<a id="alglib_solver_problem_types"></a>

## 1.2 Supported problem types

**Best fit.** ALGLIB Solver is designed for mixed-integer quadratic and nonlinear optimization:
**MINLP**, **MIQP**, **MIQCQP**, and continuous **QP**/**NLP** as special cases.
It is especially useful for problems with substantial nonlinear structure, where repeated linearization is inefficient.

**Use with caution.** Pure LP/MILP models are also supported,
but specialized LP/MILP solvers are often faster on these cases.
The same applies to nearly linear MINLP models, where linearization-based approaches may work very well.
ALGLIB Solver is strongest when the nonlinear part of the model is large enough to matter.

<a id="alglib_solver_vs_library"></a>

## 1.3 ALGLIB Solver vs ALGLIB Library

Both products are available for free or commercially.
However, these products have distinct, only partially overlapping functions.

Use ALGLIB Solver if:

- you build analytic optimization models in JuMP or another modeling environment
- you need (MI)LP, (MI)QP or (MI)NLP
- you want a pre-compiled high-performance binary solver package
- you do not need direct access to the full ALGLIB numerical API
- you want to evaluate ALGLIB optimization technology with minimal integration work

Use ALGLIB Library if:

- you need linear algebra, interpolation, fitting, DSP, statistics or other non-optimization algorithms
- you perform derivative-free simulation-based optimization (as opposed to analytic models)
- you need direct C++, C#, Java, Python or Delphi APIs
- you want source-code access to the full numerical library
- you embed ALGLIB directly into your own application

<a id="alglib_solver_download"></a>

## 1.4 Downloading and installing

ALGLIB Solver, together with a JuMP wrapper, can be downloaded from [ALGLIB website](https://www.alglib.net/alglib-solver.php).

For JuMP workflow you can just unpack the acrhive into any directory of your choice.
You will tell the JuMP wrapper how to find the solver binary using several methods discussed below in the section "Using ALGLIB Solver".

<a id="alglib_solver_licensing"></a>

## 1.5 Licensing

<a id="alglib_solver_licensing_overview"></a>

### 1.5.1 Overview

You will be able to use ALGLIB Solver under one of three licensing modes, that are discussed in next sections:

- **Temporary evaluation license**. A short 30-day license for initial evaluation. Immediate local activation.
- **Personal/academic license**. A permanent free license with no limitations on problem sizes. Issued online in less than one minute.
- **Commercial license**. A permanent commercial license.

All our licenses do not need internet connection to activations servers.

<a id="alglib_solver_licensing_evaluation"></a>

### 1.5.2 Temporary Evaluation License Agreement

Temporary evaluation license can be activated immediately after downloading and installing the solver.
It does not need internet connection for the activation or functioning, and allows you to use the solver for 30 days.
It means that you can start using solver immediately and without registration.

The temporary license also autorenews when the new version of the solver is released, albeit for a shorter time.
You can evaluate new versions of the solver for 21 days (countdow starts when you re-activate the temporary license).

If you are a free user (personal, academic, non-profit research usage), you will be able to register online at any moment and get your permanent free license token.
Online registration can be performed in less than one minute, with the license token automatically issued and sent to you.
If you are a commercial user, purchasing a commercial license is needed to switch your license to the permanent one.
In both cases you will be able to continue using the solver without reinstalling it.

The complete license terms are [available online](https://www.alglib.net/alglib-solver/tela-1.0.pdf).
The short summary is that the Temporary Evaluation License Agreement allows you to perform any kind of evaluation or integration into your workflows,
without limitation regarding problem size or performance features, but does not allow you to commercially use its results.
You are also allowed to use the solver according to the Personal/Academic/Research license agreement even without asking for a license token,
although time-limited nature of the evaluation license means that you will still need to install the license file to use the solver for more than 30 days.

<a id="alglib_solver_licensing_paula"></a>

### 1.5.3 Personal, Academic and non-profit research Usage License Agreement

If your usage conforms to the terms of our [free license agreement](https://www.alglib.net/paula-v2.1.pdf),
i.e. you use ALGLIB Solver for personal non-commercial projects, in academia for education or research, or for non-profit research,
you can request your permanent license token online at [ALGLIB website](https://www.alglib.net/alglib-solver.php) for free.

We value your time and we trust our users, so your request will be served completely automatically, without lengthy registration procedures,
with the license token being sent to your e-mail in less than one minute.

Presently we offer permanent, non-expiring license tokens that do not need internet connection (activation servers) to function.
It means that your workflow won't break because of malfunctioning internet connection.
Your license token also allows you to use future ALGLIB releases.

<a id="alglib_solver_licensing_comm"></a>

### 1.5.4 Commercial licensing

Commercial edition of ALGLIB Solver is included into our ALGLIB ULTRA licensing plan that combines MINLP-capable ALGLIB Library and ALGLIB Solver in one commercial offer.
We offer a range of license packages, ranging from the minimal single-developer one (DEV1) to the multi-site package (CORPORATE).

Once you procure a commercial license, you get permanent usage rights for the solver version you initially procured, as well as permanent usage rights for all updates released within one year support plan.
If you wish to continue receiving updates after initial support plan expires, you will be able to renew your support plan - right after the expiration or at any later moment.
However, the renewal is completely optional - the license token itself is permanent and never expires, so if you decide to skip renewal, you still will be able to use ALGLIB Solver.

See our website for [more information](https://www.alglib.net/commercial.php) about our commercial licensing programs.

<a id="alglib_solver_using_jump"></a>

# 2 Using ALGLIB Solver from JuMP

<a id="alglib_solver_using_jump_install"></a>

## 2.1 Installation and activation

**Prerequisites**: the downloaded solver archive is unpacked to `/permanent/path/to/alglib-solver` directory.

ALGLIB Solver can be easily installed by downloading solver archive from the website and unpacking it to a permanent directory of your choice.
The archive has several platform-specific binaries which are automatically chosen by the JuMP wrapper.

The [licensing](#alglib_solver_licensing) section mentions that the solver has several operating modes: a temporary license, and a permanent token-based one.
The latter includes free and commercial modes that differ only in usage rights and in how you get your licensing token; installation is the same.
Below we show how to activate a JuMP wrapper, connect it to the solver binary, activate a temporary license, and switch it to the token-based one:

```
#
# First, we need to add JuMP wrapper for ALGLIB to your environment
# We can either add Github repo (internet access is needed) or local copy
#
import Pkg
Pkg.add("JuMP")
Pkg.add(url = "https://github.com/alglib-project/ALGLIB.jl")
using JuMP
using ALGLIB

#
# The next step is to specify where exactly ALGLIB binary is located.
#
# You need to connect ALGLIB binary before activating any kind of license, because the binary is
# used to set up and check license state.
#
# Depending on the situation, you can either:
#
# * specify full name/path of the solver executable with e.g.
#   ALGLIB.set_solver_exec!("/permanent/path/to/alglib-solver/alglib4nl-4080-linux64")
#   (choose name that matches your solver version and OS)
#
# * specify path to directory where multiple executables are located with
#   ALGLIB.set_solver_dir!("/permanent/path/to/alglib-solver")
#   A version appropriate for your platform and license will be chosen.
#
# By default these write to the active Julia project's `LocalPreferences.toml`.
# Use `scope = :global` to write to the user's default Julia environment instead:
# * ALGLIB.set_solver_exec!("/permanent/path/to/alglib-solver/alglib4nl-4080-linux64"; scope = :global)
# * ALGLIB.set_solver_dir!("/permanent/path/to/alglib-solver"; scope = :global)
#
# Below we use local setting for solver directory:
# 
ALGLIB.set_solver_dir!("/permanent/path/to/alglib-solver")

#
# After the wrapper knows about the binary location, we can activate the license.
#
# A temporary 30-days license that allows you to use all functions of the solver can be instantly
# activated locally, without internet connection.
#
# The call below has the following effects:
# * it sets temporary license mode and saves it as a local state file for that specific user
# * you have to perform this call only once on this particular system under this user
# * subsequent calls have no effect aside from spending a little time doing license checks
# * if you already have a license token installed (see below), this call has no effect
#
ALGLIB.register_temporary_license()

#
# If you want to continue using ALGLIB after 30 days, you can easily convert its temporary license to a
# permanent free personal/academic/research one in less than one minute at ALGLIB Solver website, or
# purchase a commercial license.
#
# A free/commercial license token can be installed as follows:
# * perform the call once
# * subsequent calls have no effect aside from spending a little time doing license checks
# * if you have a temporary license, it will be overwritten by this token
#
ALGLIB.install_license("/path/to/license-token.lic")
```

After that, you can use ALGLIB just like any other JuMP solver:

<a id="alglib_solver_using_jump_systemwide"></a>

## 2.2 System-wide license installation

By default, license token (free or commercial) is installed only for current user.
It is stored and looked for in user-local directories, thus other users are generally unable to use the installed token.

Generally, such isolation is considered useful.
However, some headless workflows on Windows or Linux can break because of that.
Furthermore, if ALGLIB Solver is, for some reason, executed under `sudo`, it will be unable to detect the installed token.

To alleviate the problem, ALGLIB Solver comes with a system-wide install option.
This option is not included into ALGLIB.jl wrapper because on POSIX systems it needs `sudo` privileges.
You shall perform it by directly invoking ALGLIB Solver binary:

```
sudo /path/to/alglib4nl-WXYX-linux64 --install-system-wide-license /path/to/alglib-token.lic
```

Above *WXYZ* is a solver version string (e.g. 4080 for 4.08.0, 4081 for 4.08.1 and so on). After calling it once, every user on the machine will be able to use the token.

<a id="alglib_solver_using_jump_config"></a>

## 2.3 Usage and standard MOI parameters

**Prerequisites**: the downloaded solver archive is unpacked to `/permanent/path/to/alglib-solver` directory.
You activated one of licensing modes (temporary license or free/commercial token-based one).
Now you started using ALGLIB Solver, perhaps in a completely new JuMP project.

ALGLIB supports several standard MOI parameters:

- **MOI.Silent** to control optimizer verbosity.
- **MOI.TimeLimitSec** to set timeout.
- **MOI.RelativeGapTolerance** to control termination tolerance.
- **MOI.NumberOfThreads** that controls number of CPU threads used to solve the problem.
  The solver chooses up to `MOI.NumberOfThreads` subproblems to be simultaneously solved.

```
#
# Below we assume that we started in a completely new JuMP project.
#
# It means that we can count on permanent or temporary license being properly activated,
# but still have to tell the ALGLIB for JuMP wrapper about solver location.
#
# If you want to avoid calling set_solver_dir() every time you start a new project,
# call it with an additional `; scope = :global` parameter once.
#
import Pkg
Pkg.add("JuMP")
Pkg.add(url = "https://github.com/alglib-project/ALGLIB.jl")
using JuMP
using ALGLIB
ALGLIB.set_solver_dir!("/permanent/path/to/alglib-solver")

#
# The optimizer is created with these attributes. It is also possible set/clear them later
# with set_optimizer_attribute().
#
optimizer = optimizer_with_attributes(
      ALGLIB.Optimizer,
      MOI.Silent() => true,
      MOI.TimeLimitSec() => 60.0,
      MOI.NumberOfThreads() => 4,
      MOI.RelativeGapTolerance() => 1e-4)
model = Model(optimizer)
@variable(model, x >= 0, Int)
@variable(model, y >= 0)
@objective(model, Min, (x - 1)^2 + (y - 2)^2)
optimize!(model)

println("termination_status = ", termination_status(model))
println("x = ", value(x))
println("y = ", value(y))
```

<a id="alglib_solver_using_jump_config_special"></a>

## 2.4 Solver-specific parameters

ALGLIB optimizer can be created with default parameters, or you can have more detailed control over algorithms running under the hood.
Presently, there are two primary knobs to control: a high-level MINLP algorithm, and a continuous relaxation subsolver.

As of ALGLIB Solver 4.08, the only supported MINLP algorithm is BBSYNC.
It is a synchronous version of the NLP-based branch-and-bound method,
with "synchronous" meaning that it always produces deterministic results, even when running in multithreaded mode.

> Here "deterministic result" does not mean "absolutely always produce the same result".
> Solver outputs may vary due to the different number of threads used
> (BnB may converge to slightly different values depending how many nodes are processed simultaneously),
> or due to the different machine being used (e.g. with different SIMD widht or different versions of system libraries).
> However, when executed with the same number of threads on the same machine and without timeout, it will always produce the same result.

BBSYNC uses continuous NLP subsolver for relaxation subproblems.
Presently, the only subsolver available is quasi-Newton interior point method (`ipm_qn`),
with the only configurable parameter being LBFGS/SR1 memory length.
Recommended values are in *8..64* range, with *0* meaning some default value being chosen.

```
import Pkg
Pkg.add("JuMP")
Pkg.add(url = "https://github.com/alglib-project/ALGLIB.jl")
using JuMP
using ALGLIB
ALGLIB.set_solver_dir!("/permanent/path/to/alglib-solver")

model = Model(() -> ALGLIB.Optimizer(algorithm = :bbsync, subsolver = :ipm_qn, subsolver_memlen = 0))
@variable(model, x >= 0, Int)
@variable(model, y >= 0)
@objective(model, Min, (x - 1)^2 + (y - 2)^2)
optimize!(model)

println("termination_status = ", termination_status(model))
println("x = ", value(x))
println("y = ", value(y))
```
