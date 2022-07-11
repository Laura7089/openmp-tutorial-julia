#!/usr/bin/env -S just --justfile

# Get an interactive shell with the package imported
interactive:
    julia -i <( echo '\
        using Revise, JuliaFormatter, Pkg; \
        fa() = format("."); \
    ')

# Run a default entrypoint
run demo="heat.jl":
    julia <(echo 'import Pkg; include("{{ demo }}"); main()')

# Run JuliaFormatter on the project, or a path
format path=".":
    julia <(echo 'using JuliaFormatter; format("{{ path }}")')

# Clean up run and build artefacts
clean:
    make clean
