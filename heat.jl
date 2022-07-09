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

const LINE = "--------------------\n" # A line for fancy output
const LENGTH = 1000

function main(n = 1000, nsteps = 10)
    # Set problem definition
    alpha = 0.1          # heat equation coefficient
    dx = LENGTH / (n + 1)  # physical size of each cell (+1 as don't simulate boundaries as they are given)
    dt = 0.5 / nsteps    # time interval (total time of 0.5s)

    # Print message detailing runtime configuration
    totaltime = dt * nsteps
    @info "MMS heat equation starting..." (n, n) dx (LENGTH, LENGTH) alpha nsteps totaltime dt

    # Stability requires that dt/(dx^2) <= 0.5
    r = alpha * dt / dx^2
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
        solve!(u_tmp, alpha, dx, dt, u)
        u, u_tmp = u_tmp, u
    end

    # Check the L2-norm of the computed solution
    # against the *known* solution from the MMS scheme
    norm = l2norm(u, nsteps, dt, alpha, dx)

    # Print results
    @info "Done" norm
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
function solve!(u_tmp, alpha, dx, dt, u)
    # Finite difference constant multiplier
    r = alpha * dt / dx^2
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
                r * (i < xmax ? u[i+1, j] : 0.0) +
                r * (i > 1 ? u[i-1, j] : 0.0) +
                r * (j < ymax ? u[i, j+1] : 0.0) +
                r * (j > 1 ? u[i, j-1] : 0.0)
        end
    end
end


"""
True answer given by the manufactured solution
"""
solution(t, x, y, alpha) =
    exp(-2alpha * (pi^2) * t / (LENGTH^2)) * sin(pi * x / LENGTH) * sin(pi * y / LENGTH)


"""
Computes the L2-norm of the computed grid and the MMS known solution
The known solution is the same as the boundary function.
"""
function l2norm(u, nsteps, dt, alpha, dx)
    # Final (real) time simulated
    time = dt * nsteps
    # L2-norm error
    l2norm = 0.0

    # Loop over the grid and compute difference of computed and known solutions as an L2-norm
    # xs = (1:size(u)[1]) .* dx
    # ys = (1:size(u)[2]) .* dx
    # test = solution.(time, x, y, alpha)
    test = ((solution(time, x, y, alpha) for x in xs) for y in ys)
    @info size(collect(test))
    for j = 2:size(u)[2]
        for i = 2:size(u)[1]
            answer = solution(time, dx*(i-1), dx*(j-1), alpha)
            l2norm += (u[i, j] - answer)^2
        end
    end

    return sqrt(l2norm)
end
