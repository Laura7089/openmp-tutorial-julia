#!/usr/bin/env -S just --justfile
set positional-arguments
set dotenv-load

DEMOS := "heat.jl pi.jl heat.cuda.jl jacsolv.jl"

# Viking-related folders and files
VIKING_TEMPLATE := "./viking_run.sh.j2"
VIKING_UPSTREAM_NAME := `mktemp -du juliaXXX`

# Default viking run configuration
VIKING_MODULE := "lang/Julia/1.7.1-linux-x86_64"
VIKING_PARTITION := "gpu"
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
    ssh "{{ YORK_USER }}@viking.york.ac.uk" -t '{{ cmd }}'
alias vs := viking_ssh

# Upload a demo and supporting files to viking
viking_upload demo *args="":
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
        -D 'extra_opts=#SBATCH --gres=gpu:1' \
        -D 'mem={{ VIKING_MEMORY }}'
    # cat "{{ VIKING_UPSTREAM_NAME }}/run_{{ demo }}.job"
    chmod +x "{{ VIKING_UPSTREAM_NAME }}/run_{{ file_name(demo) }}.job"
    just _viking_rsync_to "{{ VIKING_UPSTREAM_NAME }}" "scratch"

# Run a demo as a batch job on viking
viking_run demo *args="":
    just "VIKING_UPSTREAM_NAME={{ VIKING_UPSTREAM_NAME}}" viking_upload {{ demo }} {{ args }}
    just viking_ssh \
        'cd ~/scratch/$(basename {{ VIKING_UPSTREAM_NAME }}) && \
        sbatch ./run_{{ file_name(demo) }}.job'
    @printf "\n==================================================\nViking job run in directory $(basename {{ VIKING_UPSTREAM_NAME }})\n\n"
alias vr := viking_run

# Get an interactive `srun` shell on viking
viking_interactive bin="/bin/bash" *args="":
    just viking_ssh 'srun \
        --ntasks={{ VIKING_NUM_TASKS }} \
        --time={{ VIKING_JOB_TIME }} \
        --pty \
        {{ bin }} {{ args }}'
alias vi := viking_interactive

# View the viking job queue
viking_queue: (viking_ssh "squeue -u " + YORK_USER)
alias vq := viking_queue

# Cancel all viking jobs
viking_cancel: && (viking_ssh "scancel -u " + YORK_USER)
    #!/bin/bash
    set -euo pipefail

    read -p "Are you sure you want to cancel all viking jobs for {{ YORK_USER }}? [y/N]" -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo
        echo "No confirmation from user, exiting..."
        exit 1
    fi
    echo
    echo "Cancelling all viking jobs for {{ YORK_USER }}..."

# Cancel viking jobs and clean up
viking_clean: (viking_cancel) (viking_ssh "rm -rfv ~/scratch/julia*")
