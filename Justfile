#!/usr/bin/env -S just --justfile
set positional-arguments
set dotenv-load

DEMOS := "heat.jl pi.jl heat.cuda.jl jacsolv.jl"

# Viking-related folders and files
VIKING_TEMPLATE := "./viking_run.sh.j2"
VIKING_UPSTREAM_NAME := `mktemp -p /tmp -du juliaXXX`
VIKING_BENCH_DIR := "~/scratch/julia_benches"
VIKING_BENCH_RESULTS_DIR := `mktemp -p /tmp -du juliabenchXXX`

# Default viking run configuration
VIKING_MODULE := "lang/Julia/1.7.1-linux-x86_64"
VIKING_PARTITION := "teach"
VIKING_SLURM_ARGS := ""
VIKING_JOB_TIME := "00:10:00"
VIKING_MEMORY := "4gb"
VIKING_NUM_TASKS := "1"
VIKING_CPUS_PT := "20"

LAB_MACHINE_ADDR := env_var("LAB_MACHINE_ADDR")
LAB_DEST := "julia_source"

YORK_USER := env_var("YORK_USER")
export SSHPASS := env_var("YORK_PASS")

# Get an interactive shell with the package imported
interactive:
    julia -i <( echo '\
        using Revise, JuliaFormatter, Pkg; \
        fa() = format("."); \
    ')

# Run a default entrypoint, then again to avoid compilation time
run demo="heat.jl":
    julia <(echo 'include("{{ absolute_path(demo) }}"); main(); main()')

# Run JuliaFormatter on the project, or a path
format path=".":
    julia <(echo 'using JuliaFormatter; format("{{ path }}")')

# Clean up run and build artefacts
clean:
    make clean

# Call `rsync` on a lab machine
_lab_rsync src dest *args="-r":
    sshpass -e rsync {{ args }} "{{ src }}" "{{ YORK_USER }}@{{ LAB_MACHINE_ADDR }}:{{ dest }}"

# Call `ssh` for a lab machine
lab_ssh *cmd="":
    sshpass -e ssh "{{ YORK_USER }}@{{ LAB_MACHINE_ADDR }}" '{{ cmd }}'

# Upload a demo to a lab machine
lab_upload demo: (_lab_rsync demo LAB_DEST "-I")

# Run a demo on a lab machine
lab_run demo *args="": (lab_upload demo)
    just lab_ssh \
        'cd "{{ join(LAB_DEST, demo) }}" \
        && make clean \
        && make \
        && just {{ demo }} {{ args }}'

lab_script *args="":
    #!/bin/bash
    set -euxo pipefail

    SCRIPT=$(mktemp /tmp/julia_XXXXXX.sh)
    chmod +x $SCRIPT

    echo "cd {{ LAB_DEST }}" >> $SCRIPT
    just --dry-run --no-highlight {{ args }} 2>> $SCRIPT
    cat $SCRIPT
    just _lab_rsync $SCRIPT $SCRIPT
    just lab_ssh "bash -c $SCRIPT"

# Upload a file to viking, defaults to recursive
_viking_rsync_to src dest args="-r":
    rsync {{ args }} "{{ src }}" "{{ YORK_USER }}@viking.york.ac.uk:{{ dest }}"

# Download a file from viking
_viking_rsync_from src dest args="":
    rsync {{ args }} "{{ YORK_USER }}@viking.york.ac.uk:{{ src }}" "{{ dest }}"

# Call `ssh` for viking
viking_ssh cmd="":
    sshpass -e ssh "{{ YORK_USER }}@viking.york.ac.uk" '{{ cmd }}'
alias vs := viking_ssh

# Run a demo as a batch job on viking
viking_run demo *args="":
    mkdir -p "{{ VIKING_UPSTREAM_NAME }}"
    cd "{{ VIKING_UPSTREAM_NAME }}" && rm -rf "*" ".*"
    cp -rv "{{ demo }}" "{{ VIKING_UPSTREAM_NAME }}"
    echo 'include("/users/{{ YORK_USER }}/scratch/{{ file_name(VIKING_UPSTREAM_NAME) }}/{{ file_name(demo) }}"); main(); main()' \
        > "{{ VIKING_UPSTREAM_NAME }}/run.jl"
    jinja2 \
        -o "{{ VIKING_UPSTREAM_NAME }}/run_{{ file_name(demo) }}.job" \
        "{{ VIKING_TEMPLATE }}" \
        -D 'ntasks={{ VIKING_NUM_TASKS }}' \
        -D 'module={{ VIKING_MODULE }}' \
        -D 'partition={{ VIKING_PARTITION }}' \
        -D 'time_allot={{ VIKING_JOB_TIME }}' \
        -D 'cpus_pt={{ VIKING_CPUS_PT }}' \
        -D 'extra_opts={{ VIKING_SLURM_ARGS }}' \
        -D 'mem={{ VIKING_MEMORY }}'
    # cat "{{ VIKING_UPSTREAM_NAME }}/run_{{ demo }}.job"
    chmod +x "{{ VIKING_UPSTREAM_NAME }}/run_{{ file_name(demo) }}.job"
    just _viking_rsync_to "{{ VIKING_UPSTREAM_NAME }}" "scratch"
    just viking_ssh \
        'cd ~/scratch/$(basename {{ VIKING_UPSTREAM_NAME }}) && \
        sbatch ./run_{{ file_name(demo) }}.job'
    @printf "\n==================================================\nViking job run in directory $(basename {{ VIKING_UPSTREAM_NAME }})\n\n"

# TODO: adapt me
# Helper for viking_run for openmp
# viking_run_openmp cpus="20" *args="":
#     just \
#         'VIKING_UPSTREAM_NAME={{ VIKING_UPSTREAM_NAME }}' \
#         VIKING_JOB_TIME={{ VIKING_JOB_TIME }} \
#         VIKING_CPUS_PT={{ cpus }} \
#         MAXWELL_CMD="OMP_NUM_THREADS={{ cpus }} {{ MAXWELL_CMD }}" \
#         viking_run "openmp" {{ args }}

# Helper for viking_run for cuda
viking_run_cuda *args="":
    just \
        'VIKING_UPSTREAM_NAME={{ VIKING_UPSTREAM_NAME }}' \
        VIKING_PARTITION=gpu \
        VIKING_SLURM_ARGS='#SBATCH --gres=gpu:1' \
        VIKING_JOB_TIME={{ VIKING_JOB_TIME }} \
        VIKING_MODULE=system/CUDA/11.1.1-GCC-10.2.0 \
        VIKING_CPUS_PT=1 \
        viking_run "cuda" {{ args }}

# Helper for viking_run for mpi
# viking_run_mpi tasks="9" *args="":
#     just \
#         'VIKING_UPSTREAM_NAME={{ VIKING_UPSTREAM_NAME }}' \
#         MAXWELL_CMD="mpirun -n {{ tasks }}" \
#         VIKING_JOB_TIME={{ VIKING_JOB_TIME }} \
#         VIKING_MODULE=mpi/OpenMPI/4.1.1-GCC-11.2.0 \
#         viking_run "mpi" {{ tasks }} "1" {{ args }}

# View the viking job queue
viking_queue: (viking_ssh "squeue -u " + YORK_USER)
alias vq := viking_queue

# TODO: adapt for Julia
# Run all benches
viking_bench_run jump="500" max="5000" demos=DEMOS omp_cpus="20" mpi_tasks="9" mpi_dims="-X 3 -Y 3":
    #!/bin/env hush
    let demo = std.split("{{ demos }}", " ")
    for size in std.range({{ jump }}, {{ max }}, {{ jump }}) do
        if std.contains(demos, "original") then
            { just VIKING_UPSTREAM_NAME=/tmp/julia_original_${size}
                    VIKING_JOB_TIME={{ VIKING_JOB_TIME }}
                    viking_run original -x $size -y $size --noio }
        end
    end

# Cancel all viking jobs
viking_cancel: && (viking_ssh "scancel -u " + YORK_USER)
    #!/bin/bash
    set -euo pipefail

    read -p "Are you sure you want to cancel all viking jobs for {{ YORK_USER }}? [y/N]" -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        echo
        echo "No confirmation from user, exiting..."
        exit 1
    fi
    echo
    echo "Cancelling all viking jobs for {{ YORK_USER }}..."

# Cancel viking jobs and clean up
viking_clean: (viking_cancel) (viking_ssh "rm -rfv ~/scratch/hipc*")
