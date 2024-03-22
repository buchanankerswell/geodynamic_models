using LaMEM, GeophysicalModelGenerator, Plots
ENV["GKSwstype"]="nul"

# Model setup
model = Model(
    Grid(x=[-2000., 2000.], y=[-2.5, 2.5], z=[-660, 40], nel=(512, 1, 128)),
    BoundaryConditions(temp_bot=1565.0, temp_top=20.0, open_top_bound=1),
    Scaling(GEO_units(temperature=1000, stress=1e9Pa, length=1km, viscosity=1e20Pa*s)),
    Time(time_end=2e3, dt=1e-3, dt_min=1e-6, dt_max=0.1, nstep_max=400, nstep_out=10),
    SolutionParams(shear_heat_eff=1.0, Adiabatic_Heat=1.0, act_temp_diff=1, eta_min=5e18,
                   eta_ref=1e21, eta_max=1e25, min_cohes=1e3),
    FreeSurface(surf_use=1, surf_corr_phase=1, surf_level=0.0, surf_air_phase=5,
                surf_max_angle=40.0),
    Output(out_density=1, out_j2_strain_rate=1, out_surf=1, out_surf_pvd=1,
           out_surf_topography=1, out_j2_dev_stress=1, out_pressure=1, out_temperature=1,
           out_dir="subduction_2d_lamem"),
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
# Material ID's
# 0: asthenosphere
# 1: oceanic crust
# 2: oceanic lithosphere
# 3: continental crust
# 4: continental lithosphere
# 5: air layer
Tair, Tmantle, Adiabat = 20.0, 1280.0, 0.4;

# Add asthenosphere
model.Grid.Temp .= Tmantle .+ 1.0;
model.Grid.Phases .= 0;

# Add sticky air
model.Grid.Temp[model.Grid.Grid.Z .> 0] .= Tair;
model.Grid.Phases[model.Grid.Grid.Z .> 0.0 ] .= 5;

# Add left oceanic plate
add_box!(model; xlim=(-2000.0, 0.0), ylim=(model.Grid.coord_y...,), zlim=(-660.0, 0.0),
         Origin=nothing, StrikeAngle=0, DipAngle=0,
         phase=LithosphericPhases(Layers=[20 80], Phases=[1 2 0], Tlab=1250),
         T=SpreadingRateTemp(Tsurface=Tair, Tmantle=Tmantle, MORside="left", SpreadingVel=0.5,
                             AgeRidge=0.01; maxAge=80.0))

# Add right oceanic plate
add_box!(model; xlim=(1500, 2000), ylim=(model.Grid.coord_y...,), zlim=(-660.0, 0.0),
         Origin=nothing, StrikeAngle=0, DipAngle=0,
         phase=LithosphericPhases(Layers=[20 80], Phases=[1 2 0], Tlab=1250),
         T=SpreadingRateTemp(Tsurface=Tair, Tmantle=Tmantle, MORside="right", SpreadingVel=0.5,
                             AgeRidge=0.01; maxAge=80.0))

# Add overriding plate margin
add_box!(model; xlim=(0.0, 400.0), ylim=(model.Grid.coord_y[1], model.Grid.coord_y[2]), 
         zlim=(-660.0, 0.0), Origin=nothing, StrikeAngle=0, DipAngle=0,
         phase=LithosphericPhases(Layers=[25 90], Phases=[3 4 0], Tlab=1250),
         T=HalfspaceCoolingTemp(Tsurface=Tair, Tmantle=Tmantle, Age=80))

# Add overriding plate craton
add_box!(model; xlim=(400.0, 1500.0), ylim=(model.Grid.coord_y...,), zlim=(-660.0, 0.0),
         Origin=nothing, StrikeAngle=0, DipAngle=0,
         phase=LithosphericPhases(Layers=[35 100], Phases=[3 4 0], Tlab=1250),
         T=HalfspaceCoolingTemp(Tsurface=Tair, Tmantle=Tmantle, Age=120))

# Change dip angle of subducting oceanic plate at margin
add_box!(model; xlim=(0.0, 300), ylim=(model.Grid.coord_y...,), zlim=(-660.0, 0.0),
         Origin=nothing, StrikeAngle=0, DipAngle=30,
         phase=LithosphericPhases(Layers=[30 80], Phases=[1 2 0], Tlab=1250),
         T=HalfspaceCoolingTemp(Tsurface=Tair, Tmantle=Tmantle, Age=80))

# Add mantle adiabat
model.Grid.Temp = model.Grid.Temp - model.Grid.Grid.Z .* Adiabat;

# Plot initial setup
plt_dir = joinpath(model.Output.out_dir, "plots"); mkpath(plt_dir);
plot_cross_section(model, y=0, field=:temperature); savefig(joinpath(plt_dir, "init-temp.png"))
plot_cross_section(model, y=0, field=:phase); savefig(joinpath(plt_dir, "init-phase.png"))

# Define material properties
softening = Softening(ID=0, APS1=0.1, APS2=0.5, A=0.95)
dryPeridotite = Phase(Name="dryPeridotite", ID=0, rho=3300.0, alpha=3e-5,
                      disl_prof="Dry_Olivine_disl_creep-Hirth_Kohlstedt_2003", Vn=14.5e-6,
                      diff_prof="Dry_Olivine_diff_creep-Hirth_Kohlstedt_2003", Vd=14.5e-6,
                      G=5e10, k=3, Cp=1000.0, ch=30e6, fr=20.0, A=6.6667e-12, chSoftID=0,
                      frSoftID=0)
oceanicCrust = Phase(Name="oceanCrust", ID=1, rho=3300.0, alpha=3e-5,
                     disl_prof="Plagioclase_An75-Ranalli_1995", G=5e10, k=3, Cp=1000.0,
                     ch=5e6, fr=0.0, A=2.333e-10)
oceanicLithosphere = copy_phase(dryPeridotite, Name="oceanicLithosphere", ID=2)
continentalCrust = copy_phase(oceanicCrust, Name="continentalCrust", ID=3,
                              disl_prof="Quarzite-Ranalli_1995", rho=2700.0,  ch=30e6, fr=20.0,
                              A=5.3571e-10, chSoftID=0, frSoftID=0)
continentalLithosphere = copy_phase(dryPeridotite, Name="continentalLithosphere", ID=4)
air = Phase(Name="air", ID=5, rho=50.0, eta=1e19, G=5e10, k=100, Cp=1e6, ch=10e6, fr=0.0)

# Add materials
rm_phase!(model)
add_phase!(model, dryPeridotite, oceanicCrust, oceanicLithosphere, continentalCrust,
           continentalLithosphere, air)

# Add softening law
add_softening!(model, softening)

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
save_cross_section_plots(model, plt_dir; field=:phase)
save_cross_section_plots(model, plt_dir; field=:density)
save_cross_section_plots(model, plt_dir; field=:temperature)