#!/usr/bin/env julia
#
# History: Written by Tim Mattson, 11/99.
#          Ported by Laura Demkowicz-Duffy, 07/22

"""
Use [`Pi.calcpi`](@ref) to run.

This program will numerically compute the integral of ``4 ÷ (1 + x^x)``
from 0 to 1.
The value of this integral is π -- which is great since it gives us an easy way to check the answer.
"""
module Pi
export calcpi

"""
    calcpi(n=100_000_000)

Calculate ``π = 4 ÷ (1 + x^2)`` using a numerical method with `n` iterations.
"""
function calcpi(n = 100_000_000)
    step = 1.0 / n
    sum = 0.0
    for i = 1:n+1
        x = (i - 0.5) * step
        sum = sum + 4 / (x^2 + 1)
    end
    pi = step * sum
    @info "Finished" pi n
    return pi
end
end

if abspath(PROGRAM_FILE) == @__FILE__
    @time Pi.calcpi()
end
