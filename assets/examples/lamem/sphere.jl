using LaMEM, GeophysicalModelGenerator, Plots
ENV["GKSwstype"]="nul"

# Model setup
model = Model(
    Grid(nel=(256, 1, 256), x=[-1, 1], y=[-1e-2, 1e-2], z=[-1, 1]),
    Time(nstep_max=20, dt_min=1e-3, dt=1, dt_max=10, time_end=100),
    Output(out_dir="falling_sphere_2d_lamem"),
    Solver(SolverType="multigrid", MGLevels=3,
           PETSc_options=["-snes_ksp_ew",
                          "-snes_ksp_ew_rtolmax 1e-4",
                          "-snes_rtol 5e-3",
                          "-snes_atol 1e-4",
                          "-snes_max_it 200",
                          "-snes_PicardSwitchToNewton_rtol 1e-3",
                          "-snes_NewtonSwitchToPicard_it 20",
                          "-js_ksp_type fgmres",
                          "-js_ksp_max_it 20",
                          "-js_ksp_atol 1e-8",
                          "-js_ksp_rtol 1e-4",
                          "-snes_linesearch_type l2",
                          "-snes_linesearch_maxstep 10",
                          "-da_refine_y 1"])
)

# Adding materials and temperature fields
rm_phase!(model)
matrix = Phase(ID=0, Name="matrix", eta=1e20, rho=3000)
sphere = Phase(ID=1, Name="sphere", eta=1e23, rho=3200)
add_phase!(model, sphere, matrix)
add_sphere!(model, cen=(0.0,0.0,0.0), radius=(0.5, ))

# Run model
run_lamem(model, 4)

# Plotting function
function save_cross_section_plots(model, plt_dir; field=:phase, y=0)
    timesteps, _, _ = read_LaMEM_simulation(model)

    for tstep in timesteps
        tstep_padded = lpad(tstep, 4, "0")
        filename = joinpath(plt_dir, "$field-$tstep_padded.png")
        plot_cross_section(model; field=field, y=y, timestep=tstep); savefig(filename)
    end
end

# Save plots
plt_dir = joinpath(model.Output.out_dir, "plots"); mkpath(plt_dir);
save_cross_section_plots(model, plt_dir; field=:phase)
save_cross_section_plots(model, plt_dir; field=:density)