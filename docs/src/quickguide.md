# Quickguide

## How to run scripts

To run scripts contained in `test/scripts` you need to activate an environment and import all the needed packages.

1. Choose a directory where to create the environment:
   ```julia
   cd("path/to/env/dir")
   ```

2. Activate the environment:

3. ```julia
   ]activate .
   ```

4. `add` or `dev` the FlexPlan repository:
   ```julia
   ]add FlexPlan
   ```
   or
   ```julia
   ]dev https://github.com/Electa-Git/FlexPlan.jl
   ```

5. `add` every package required by the script.
   For example, if the script contains `import Plots`, then execute
   ```julia
   ]add Plots
   ```
