using Pkg; Pkg.activate("")
using LaMEM, GeophysicalModelGenerator, Random, LaTeXStrings, Plots
import LaMEM: cross_section
Random.seed!(42)
ENV["GKSwstype"]="nul"

include("julia/rocmlm.jl")

# Model setup
model = Model(
    Grid(x=[-2000., 2000.], y=[-2.5, 2.5], z=[-660, 40], nel=(921, 1, 301)),
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
         phase=LithosphericPhases(Layers=[22 95], Phases=[1 2 0], Tlab=1250),
         T=HalfspaceCoolingTemp(Tsurface=Tair, Tmantle=Tmantle, Age=80))

# Add mantle adiabat
model.Grid.Temp = model.Grid.Temp - model.Grid.Grid.Z .* Adiabat;

# Get model grid
data_tuple, _ = cross_section(model, :phase; x=nothing, y=0, z=nothing)
phases = data_tuple.data
data_tuple, _ = cross_section(model, :temperature; x=nothing, y=0, z=nothing)
T, x, z = data_tuple.data, data_tuple.x, data_tuple.z

# Create continuous P gradient from surface to 28 GPa
below_surface_indices = findall(z .<= 0)
gradient = range(28, stop=0, length=length(below_surface_indices))
P_grad = zeros(size(z))
P_grad[below_surface_indices] .= gradient
P = transpose(hcat(fill(P_grad, (1, size(T, 1)))...))

# Uniform mantle composition
X = fill(0.996, size(T, 1), size(T, 2))

# Flatten and combine PTX
input_ft = hcat(vec(X), vec(P), vec(T))

# Load RocMLM and scalers
rocmlm_path = ("/Users/localadmin/Working/geodynamic_models/rocmlm_test/rocmlms/" *
               "perp-synthetic-DT-S129-W129-model-only.pkl")

elapsed_time = @elapsed pred_original = rocmlm_predict(input_ft, rocmlm_path)

elapsed_time_ms = round(elapsed_time * 1e3, digits=4)
nodes = size(pred_original, 1)
elaped_time_per_node = round(elapsed_time_ms / nodes, digits=4)

println("Predicted rho, Vp, Vs at $nodes nodes in $elapsed_time_ms ms")
println("Elapsed time per node: $elaped_time_per_node ms")

above_surface_indices = findall(input_ft[:, 2] .<= 0)
pred_original[above_surface_indices, :] .= NaN

rho = reshape(pred_original[:, 1], size(T))
Vp = reshape(pred_original[:, 2], size(T))
Vs = reshape(pred_original[:, 3], size(T))

# Plot initial setup
plt_dir = joinpath(model.Output.out_dir, "plots"); mkpath(plt_dir);
default(dpi=300, aspect_ratio=:equal, xlims=(-2000, 2000), ylims=(-660, 40),
        xlabel="Distance (km)", ylabel="Depth (km)")
rect = rectangle_from_coords(-1000, -500, 1000, 40)

p1 = Plots.heatmap(x, z, T', title="Initial Temperature", c=cgrad(:thermal),
                   colorbar_title="T (˚C)")
plot!(rect[:, 1], rect[:, 2], color="black", linewidth=3, label=nothing)
p2 = Plots.heatmap(x, z, T', c=cgrad(:thermal), colorbar_title="T (˚C)",
                   xlims=(-1000, 1000), ylims=(-500, 40))
plot(p1, p2, layout=(2, 1))
savefig(joinpath(plt_dir, "init-temp.png"))

p1 = Plots.heatmap(x, z, phases', title="Initial Phases",
                   c=cgrad(:lajolla, 6, categorical=true), colorbar_title="Phase")
plot!(rect[:, 1], rect[:, 2], color="black", linewidth=3, label=nothing)
p2 = Plots.heatmap(x, z, phases', c=cgrad(:lajolla, 6, categorical=true),
                   colorbar_title="Phase", xlims=(-1000, 1000), ylims=(-500, 40))
plot(p1, p2, layout=(2, 1))
savefig(joinpath(plt_dir, "init-phase.png"))

p1 = Plots.heatmap(x, z, rho', title="Initial Density", c=cgrad(:acton, rev=true),
                   colorbar_title=L"rho (g/cm$^3$)")
plot!(rect[:, 1], rect[:, 2], color="black", linewidth=3, label=nothing)
p2 = Plots.heatmap(x, z, rho', c=cgrad(:acton, rev=true), colorbar_title=L"rho (g/cm$^3$)",
                   xlims=(-1000, 1000), ylims=(-500, 40))
plot(p1, p2, layout=(2, 1))
savefig(joinpath(plt_dir, "init-rho-pred.png"))

p1 = Plots.heatmap(x, z, Vp', title="Initial Vp", c=cgrad(:turku, rev=true),
                   colorbar_title="Vp (km/s)")
plot!(rect[:, 1], rect[:, 2], color="black", linewidth=3, label=nothing)
p2 = Plots.heatmap(x, z, Vp', c=cgrad(:turku, rev=true),
                   colorbar_title="Vp (km/s)", xlims=(-1000, 1000), ylims=(-500, 40))
plot(p1, p2, layout=(2, 1))
savefig(joinpath(plt_dir, "init-Vp-pred.png"))

p1 = Plots.heatmap(x, z, Vs', title="Initial Vs", c=cgrad(:oslo, rev=true),
                   colorbar_title="Vs (km/s)")
plot!(rect[:, 1], rect[:, 2], color="black", linewidth=3, label=nothing)
p2 = Plots.heatmap(x, z, Vs', c=cgrad(:oslo, rev=true), colorbar_title="Vs (km/s)",
                   xlims=(-1000, 1000), ylims=(-500, 40))
plot(p1, p2, layout=(2, 1))
savefig(joinpath(plt_dir, "init-Vs-pred.png"))
