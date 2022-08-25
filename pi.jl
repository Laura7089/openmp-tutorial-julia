#
# This program will numerically compute the integral of
#
#                   4/(1+x*x)
#
# from 0 to 1.  The value of this integral is pi -- which
# is great since it gives us an easy way to check the answer.
#
# The is the original sequential program.  It uses the timer
# from the OpenMP runtime library
#
# History: Written by Tim Mattson, 11/99.
#          Ported by Laura Demkowicz-Duffy, 07/22
#

function calcpi(n=100000000)
    step = 1.0 / n
    sum = 0.0
    for i in 1:n+1
        x = (i - 0.5) * step
        sum = sum + 4 / (x^2 + 1)
    end
    pi = step * sum
    @info "Finished" pi n
    return pi
end

if abspath(PROGRAM_FILE) == @__FILE__
    calcpi()
end
