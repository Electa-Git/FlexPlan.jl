# Quickguide

## How to run scripts

Some scripts have been provided in `FlexPlan/test/scripts` to test the package functionality. To run those scripts, you need to activate an environment and import all the needed packages.

1. In a Julia REPL, choose a directory where to create the environment:
   ```
   julia> cd("path/to/env/dir")
   ```
2. Enter the Pkg REPL by pressing `]` from the Julia REPL:
   ```
   julia> ]
   ```

3. Activate the environment:
   ```
   pkg> activate .
   ```

4. `add` the FlexPlan package:
   ```
   pkg> add FlexPlan
   ```

5. `add` every package required by the script.
   For example, if the script contains `import Plots`, then execute
   ```
   pkg> add Plots
   ```
