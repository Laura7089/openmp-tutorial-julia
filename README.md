# Julia Ports

All the problems in this repo have been ported to [Julia](https://julialang.org/).
To run one, either:

- execute it with `julia ./filename.jl` to get a quick run; note that this will likely include compilation time in the speed data
- start the REPL: `julia`, use `include("./filename.jl")` to import the problem then `?ProblemName` to view documentation; precompilation should be enabled this way

# Programming Your GPU with OpenMP

This is a hands-on tutorial that introduces the basics of targetting GPUs with OpenMP 4.5 through a series of worked examples.

Starting with serial code, the tutorial takes you thorugh parallellising, exploring the performance characteristics, and optimising the following small programs:

* `vadd` – A simple vector addition program, often considered the "hello world" of GPU programming.
* `pi` – A numerical integration program that calculates and approximate value of π.
* `jac_solv` – A Jacobi solver.
* `heat` - An explicit finite difference 5-point stencil code.

## Usage

To build all the examples:

```bash
make
```

To run, submit jobs using your training account:

```bash
qsub submit_vadd     # For vector add
qsub submit_pi       # For pi
qsub submit_jac_solv # For Jacobi
qsub submit_heat     # For heat
```

## Publication history
Versions of this tutorial have been presented at [SC'17](https://sc17.supercomputing.org/presentation/?id=tut127&sess=sess217), [SC'18](https://sc18.supercomputing.org/presentation/?id=tut138&sess=sess245), [SC'19](https://sc19.supercomputing.org/presentation/?id=tut110&sess=sess183), and virtually at [SC'20](https://sc20.supercomputing.org/presentation/?id=tut155&sess=sess237) and [SC'21](https://sc21.supercomputing.org/presentation/?id=tut116&sess=sess189).
A version of this tutorial was presented [UK OpenMP Users' Conference](https://ukopenmpusers.co.uk) in 2018 and 2019.
