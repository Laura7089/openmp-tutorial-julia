#!/usr/bin/env julia
#
# PROGRAM: heat equation solve
#
# PURPOSE: This program will explore use of an explicit
#          finite difference method to solve the heat
#          equation under a method of manufactured solution (MMS)
#          scheme. The solution has been set to be a simple
#          function based on exponentials and trig functions.
#
#          A finite difference scheme is used on a 1000x1000 cube.
#          A total of 0.5 units of time are simulated.
#
#          The MMS solution has been adapted from
#          G.W. Recktenwald (2011). Finite difference approximations
#          to the Heat Equation. Portland State University.
#
#
# USAGE:   Run with two arguments:
#          First is the number of cells.
#          Second is the number of timesteps.
#
#          For example, with 100x100 cells and 10 steps:
#
#          ./heat 100 10
#
#
# HISTORY: Written by Tom Deakin, Oct 2018
#          Ported by Laura Demkowicz-Duffy, Jul 2022
#

module Heat

export mask, solve!, initialvalue, main

import LinearAlgebra: norm
product = Iterators.product

# Physical size of domain
const LENGTH = 1000
const ARR_MOD = Base

function main(n = 1000, nsteps = 10, α = 0.1, δx = LENGTH / (n + 1), δt = 1 / 2nsteps)
    # Print message detailing runtime configuration
    totaltime = δt * nsteps
    @info "MMS heat equation starting..." (n, n) δx (LENGTH, LENGTH) α nsteps totaltime δt

    # Stability requires that δt/(dx^2) <= 0.5
    r = α * δt / δx^2
    if (r > 0.5)
        @warn "Stability: unstable" r
    end

    u = initialvalue((n, n), δx)
    u_tmp = Array{Float64}(undef, (n, n))

    # Run through timesteps under the explicit scheme
    B = ARR_MOD.zeros(n, n) # temporary allocation
    @time for t = 2:nsteps
        solve!(u_tmp, B, u, α, δx, δt)
        u, u_tmp = u_tmp, u
    end

    # Check the L2-norm of the computed solution
    # against the *known* solution from the MMS scheme
    @time begin
        themask = mask(size(u), δt * nsteps, α, δx)
        l2norm = norm(u - themask)
    end

    # Print results
    @info "Done" l2norm
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
    B[2:end-1, 2:end-1] .= map(product(2:xₘ-1, 2:yₘ-1)) do (i, j)
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
    Heat.main()
end
