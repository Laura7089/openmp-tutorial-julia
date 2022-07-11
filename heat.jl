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

import LinearAlgebra: norm

const LENGTH = 1000

function main(n = 1000, nsteps = 10)
    # Set problem definition
    α = 0.1          # heat equation coefficient
    dx = LENGTH / (n + 1)  # physical size of each cell (+1 as don't simulate boundaries as they are given)
    dt = 0.5 / nsteps    # time interval (total time of 0.5s)

    # Print message detailing runtime configuration
    totaltime = dt * nsteps
    @info "MMS heat equation starting..." (n, n) dx (LENGTH, LENGTH) α nsteps totaltime dt

    # Stability requires that dt/(dx^2) <= 0.5
    r = α * dt / dx^2
    if (r > 0.5)
        @warn "Stability: unstable" r
    end

    # Allocate two nxn grids
    u = zeros(n, n)
    u_tmp = zeros(n, n)
    tmp = 0.0

    # Set the initial value of the grid under the MMS scheme
    initial_value!(u, dx)

    # Run through timesteps under the explicit scheme
    @time for t = 2:nsteps
        # Call the solve kernel
        # Computes u_tmp at the next timestep
        # given the value of u at the current timestep
        solve!(u_tmp, α, dx, dt, u)
        u, u_tmp = u_tmp, u
    end

    # Check the L2-norm of the computed solution
    # against the *known* solution from the MMS scheme
    @time begin
        themask = mask(size(u), dt * nsteps, α, dx)
        l2norm = norm(u .- themask)
    end

    # Print results
    @info "Done" l2norm
end


"""
Sets the mesh to an initial value, determined by the MMS scheme
"""
function initial_value!(u, dx)
    for j = 2:size(u)[2]
        for i = 2:size(u)[1]
            u[i, j] = sin(pi * dx * (i - 1) / LENGTH) * sin(pi * dx * (j - 1) / LENGTH)
        end
    end
end


"""
Compute the next timestep, given the current timestep
"""
function solve!(u_tmp, α, dx, dt, u)
    # Finite difference constant multiplier
    r = α * dt / dx^2
    r2 = 1 - 4r

    xmax = size(u_tmp)[1]
    ymax = size(u_tmp)[2]

    # Loop over the nxn grid
    for j = 2:ymax
        for i = 2:xmax
            # Update the 5-point stencil, using boundary conditions on the edges of the domain.
            # Boundaries are zero because the MMS solution is zero there.
            u_tmp[i, j] =
                r2 * u[i, j] +
                r * (
                    (i < xmax ? u[i+1, j] : 0.0) +
                    (i > 1 ? u[i-1, j] : 0.0) +
                    (j < ymax ? u[i, j+1] : 0.0) +
                    (j > 1 ? u[i, j-1] : 0.0)
                )
        end
    end
end


"""
Matrix of true answers given by the manufactured solution
"""
function mask((xₘ, yₘ), t, α, dx)
    modi = pi * dx / LENGTH
    xs = sin.((1:xₘ-1) .* modi)
    ys = sin.((1:yₘ-1) .* modi)
    Mₚ = Iterators.product(xs, ys)
    M₀ = zeros(xₘ, yₘ)

    multiplier = exp(-2α * pi^2 * t / (LENGTH^2))
    gen((x, y)) = multiplier * sin(x) * sin(y)

    M₀[2:xₘ, 2:yₘ] = map(gen, Mₚ)
    return M₀
end
