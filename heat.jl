#!/usr/bin/env julia
#
# PROGRAM: heat equation solve
#
#
# HISTORY: Written by Tom Deakin, Oct 2018
#          Ported by Laura Demkowicz-Duffy, Jul 2022

"""
Run with [`Heat.heat()`](@ref).
See the documentation for that function for more details.

This module supports running with [CUDA.jl](https://cuda.juliagpu.org/stable).
To enable it, set [`Heat.ARR_MOD`](@ref) to `CUDA`.
To enable CPU threads, set [`Heat.CPU_THREADS`](@ref) to `true`.

This program will explore use of an explicit finite difference method to solve the heat equation under a method of manufactured solution (MMS)
scheme.
The solution has been set to be a simple function based on exponentials and trig functions.

A finite difference scheme is used on a `LENGTHxLENGTH` cube.
A total of `0.5` units of time are simulated.

The MMS solution has been adapted from:
G.W. Recktenwald (2011).
Finite difference approximations to the Heat Equation.
Portland State University.
"""
module Heat
export heat

"""
Physical size of domain in units.
"""
const LENGTH = 1000
"""
Julia module used to create arrays with `ARR_MOD.zeros`.
Intended for use with CUDA.

Defaults to `Base`.
"""
const ARR_MOD = Base
"""
Whether or not to enable CPU multithreading.
Defaults to `false`.
"""
const CPU_THREADS = false

import LinearAlgebra: norm
const product = Iterators.product
const parmap = if CPU_THREADS
        import Distributed: pmap
        pmap
    else
        map
    end

import .ARR_MOD

"""
    heat([n=1000, ][steps=10, ][α=0.1]; [δx=LENGTH÷(n+1), ][δt=1/2steps, ])

Run the MMS heat equation on a grid of size `n` with `steps` iterations.
"""
function heat(n = 1000, steps = 10, α = 0.1; δx = LENGTH / (n + 1), δt = 1 / 2steps)
    # Print message detailing runtime configuration
    totaltime = δt * steps
    @info "MMS heat equation starting with params:" (n, n) δx (LENGTH, LENGTH) α steps totaltime δt

    # Stability requires that δt/(dx^2) <= 0.5
    r = α * δt / δx^2
    if r > 0.5
        @warn "Stability: unstable" r
    end

    u = initialvalue((n, n), δx)
    u_tmp = Array{Float64}(undef, (n, n))

    # Run through timesteps under the explicit scheme
    B = ARR_MOD.zeros(n, n) # temporary allocation
    stats = @timed for t = 2:steps
        solve!(u_tmp, B, u, α, δx, δt)
        u, u_tmp = u_tmp, u
    end
    @info "Main loop finished" stats.time stats.bytes stats.gctime

    # Check the L2-norm of the computed solution
    # against the *known* solution from the MMS scheme
    stats = @timed begin
        themask = mask(size(u), δt * steps, α, δx)
        l2norm = norm(u - themask)
    end

    # Print results
    @info "L2-Norm calculation finished" l2norm stats.time stats.bytes stats.gctime
end


"""
Sets the mesh to an initial value, determined by the MMS scheme
"""
function initialvalue(size, δx)
    u = ARR_MOD.zeros(size)
    mult = pi * δx / LENGTH
    u[2:end, 2:end] = map(product(1:size[1]-1, 1:size[2]-1)) do (i, j)
        sin(mult * i) * sin(mult * j)
    end
    return u
end


"""
Compute the next timestep, given the current timestep
"""
function solve!(uₜ::AbstractArray, B::AbstractArray, u::AbstractArray, α, δx, δt)
    # Finite difference constant multiplier
    r = α * δt / δx^2
    r₂ = 1 - 4r

    (xₘ, yₘ) = size(u)
    B[2:end-1, 2:end-1] .= parmap(product(2:xₘ-1, 2:yₘ-1)) do (i, j)
        u[i+1, j] + u[i, j-1] + u[i-1, j] + u[i, j+1]
    end

    @. uₜ = r₂ * u + r * B
end


"""
Matrix of true answers given by the manufactured solution
"""
function mask((xₘ, yₘ), t, α, δx)
    modi = pi * δx / LENGTH
    xs = (1:xₘ-1) .* modi
    ys = (1:yₘ-1) .* modi
    M = ARR_MOD.zeros(xₘ, yₘ)

    M[2:end, 2:end] .= map(product(xs, ys)) do (x, y)
        exp(-2α * pi^2 * t / LENGTH^2) * sin(x) * sin(y)
    end
    return M
end

end

if abspath(PROGRAM_FILE) == @__FILE__
    Heat.heat()
end
