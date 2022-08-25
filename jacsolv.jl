#!/usr/bin/env julia
#
#  PROGRAM: jacobi Solver
#
#  PURPOSE: This program will explore use of a jacobi iterative
#           method to solve a system of linear equations (Ax= b).
#
#           Here is the basic idea behind the method.   Rewrite
#           the matrix A as a Lower Triangular (L), upper triangular
#           (U) and diagonal matrix (D)
#
#                Ax = (L + D + U)x = b
#
#            Carry out the multiplication and rearrange:
#
#                Dx = b - (L+U)x  -->   x = (b-(L+U)x)/D
#
#           We can do this iteratively
#
#                x_new = (b-(L+U)x_old)/D
#
#  USAGE:   Run wtihout arguments to use default SIZE.
#
#              julia ./jac_solv.jl
#
#           Run with a single argument for the order of the A
#           matrix ... for example
#
#              julia ./jac_solv.jl 2500
#
#  HISTORY: Written by Tim Mattson, Oct 2015
#           Ported to Julia by Laura Demkowicz-Duffy, July 2022
#

using Dates
import LinearAlgebra: diagind, I

# Maximum allowable non-diag values
const MAX_VAR = 0.25
const TOLERANCE = 0.001

"""
Create a random, diagonally dominant matrix.  For
a diagonally dominant matrix, the diagonal element
of each row is great than the sum of the other
elements in the row.  Then scale the matrix so the
result is near the identiy matrix.
"""
nearident(n = 5) = (rand(Float64, (n, n)) .* MAX_VAR) + I

"""
Jacobi iterative solver

Mutates `xnew` and `xold`
"""
function jacobisolve!(xnew, xold, A, b)
    conv = typemax(Int)
    iters = 0
    while (conv > TOLERANCE) && (iters < 100_000)
        iters += 1
        for i = 1:length(xnew)
            @inbounds xnew[i] = 0.0
            for j = 1:length(xnew)
                if i != j
                    @inbounds xnew[i] += A[j, i] * xold[j]
                end
            end
            # xnew[i] = sum(A[i,j] * xold[i] for j in 1:ndim if j != i)
        end
        @inbounds xnew[:] = (b .- xnew) ./ A[diagind(A)]

        # test convergence
        conv = sqrt(sum((xnew .- xold) .^ 2))
        @debug "" iters conv
        xold, xnew = xnew, xold
    end
    @info "Jacobi solve done" conv iters
end

function jacsolv(ndim = 1000)
    A = nearident(ndim)
    @debug A

    # Initialize x and just give b some non-zero random values
    xnew = zeros(ndim)
    xold = zeros(ndim)
    b = rand(Float64, ndim) .* 0.51

    @time jacobisolve!(xnew, xold, A, b)

    # test answer by multiplying my computed value of x by
    # the input A matrix and comparing the result with the
    # input b vector.
    xold[:] = map(sum, eachcol(A) .* xnew)
    err = sqrt(sum((xold - b) .^ 2))

    checksum = sum(xnew)
    @info "Tests done" err checksum
    if err > TOLERANCE
        @warn "final solution error > $(TOLERANCE)" err
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    jacsolv()
end
