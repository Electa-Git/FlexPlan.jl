# Documentation for FlexPlan.jl

You can read this documentation online at <https://electa-git.github.io/FlexPlan.jl/dev/>.

## Preview the documentation (for developers)

While developing FlexPlan you can also preview the documentation locally in your browser
with live-reload capability, i.e. when modifying a file, every browser (tab) currently
displaying the corresponding page is automatically refreshed.

### Instructions for *nix

1. Copy the following zsh/Julia code snippet:

   ```julia
   #!/bin/zsh
   #= # Following line is zsh code
   julia -i $0:a # The string `$0:a` represents this file in zsh
   =# # Following lines are Julia code
   import Pkg
   Pkg.activate(; temp=true)
   Pkg.develop("FlexPlan")
   Pkg.add("Documenter")
   Pkg.add("LiveServer")
   using FlexPlan, LiveServer
   cd(dirname(dirname(pathof(FlexPlan))))
   servedocs()
   exit()
   ```

2. Save it as a zsh script (name it like `preview_flexplan_docs.sh`).
3. Assign execute permission to the script: `chmod u+x preview_flexplan_docs.sh`.
4. Run the script.
5. Open your favorite web browser and navigate to `http://localhost:8000`.
