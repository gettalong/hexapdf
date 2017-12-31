# Benchmarking

This directory contains various benchmarks involving HexaPDF, and common files used by all
benchmarks. Each directory represents one type of benchmark and contains all its necessary files -
see the respective README files for more information.

The scripts have been written with a Linux environment in mind. They may work on macOS or with the
Linux subsystem on Windows 10.


## Running a Benchmark

To run a benchmark just execute the `script.sh` file in the benchmark direcctory, for example:

    optimization/script.sh

The script may take arguments to control the execution of the benchmark, use `script.sh -h` to show
some help.


## Generating Graphs

There is also support for generating graphs from the output of the `script.sh` files using Gnuplot.
Use the provided `plot.sh` script with a benchmark directory name, all additional arguments are
passed on the `script.sh` file.

For example:

    ./plot.sh raw_text "1x 5x"
