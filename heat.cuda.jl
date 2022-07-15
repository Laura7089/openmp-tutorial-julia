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
import Pkg; Pkg.add("CUDA")

import LinearAlgebra: norm
using CUDA

const LENGTH = 1000

function main(n = 1000, nsteps = 10, α = 0.1, δx = LENGTH / (n + 1), δt = 0.5 / nsteps)
    # Print message detailing runtime configuration
    totaltime = δt * nsteps
    @info "MMS heat equation starting..." (n, n) δx (LENGTH, LENGTH) α nsteps totaltime δt

    # Stability requires that δt/(dx^2) <= 0.5
    r = α * δt / δx^2
    if (r > 0.5)
        @warn "Stability: unstable" r
    end

    u = initial_value((n, n), δx) |> CuArray
    u_tmp = CuArray{Float64}(undef, (n, n))

    # Run through timesteps under the explicit scheme
    B = CUDA.zeros(n, n) # temporary allocation
    @time for t = 2:nsteps
        solve!(u_tmp, B, u, α, δx, δt)
        u, u_tmp = u_tmp, u
    end

    # Check the L2-norm of the computed solution
    # against the *known* solution from the MMS scheme
    @time begin
        themask = mask(size(u), δt * nsteps, α, δx)
        l2norm = norm(u .- themask)
    end

    # Print results
    @info "Done" l2norm
end


"""
Sets the mesh to an initial value, determined by the MMS scheme
"""
function initial_value((x, y), δx)
    u = zeros((x, y))
    for (i, j) in Iterators.product(axes(u[1:end-1, 1:end-1])...)
        u[i+1, j+1] = sin(pi * δx * i / LENGTH) * sin(pi * δx * j / LENGTH)
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
    B[2:end-1, 2:end-1] .= (
        u[i+1, j] + u[i, j-1] + u[i-1, j] + u[i, j+1] for
        (i, j) in Iterators.product(2:xₘ-1, 2:yₘ-1)
    )

    @. uₜ[:, :] = r₂ * u + r * B
end


"""
Matrix of true answers given by the manufactured solution
"""
function mask((xₘ, yₘ), t, α, δx)
    modi = pi * δx / LENGTH
    xs = (1:xₘ-1) .* modi
    ys = (1:yₘ-1) .* modi
    Mₚ = Iterators.product(xs, ys)
    M₀ = CUDA.zeros(xₘ, yₘ)

    multiplier = exp(-2α * pi^2 * t * LENGTH^-2)
    gen((x, y)) = multiplier * sin(x) * sin(y)

    M₀[2:xₘ, 2:yₘ] = map(gen, Mₚ)
    return M₀
end
