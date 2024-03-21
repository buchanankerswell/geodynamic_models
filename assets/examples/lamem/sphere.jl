using LaMEM, GeophysicalModelGenerator, Plots

model = Model(Grid(nel=(16,16,16), x=[-1,1], y=[-1,1], z=[-1,1]),
              Time(nstep_max=20, dt_min=1e-3, dt=1, dt_max=10, time_end=100),
              Solver(SolverType="multigrid", MGLevels=2), Output(out_dir="example_1"))

rm_phase!(model)
matrix = Phase(ID=0, Name="matrix", eta=1e20, rho=3000)
sphere = Phase(ID=1, Name="sphere", eta=1e23, rho=3200)
add_phase!(model, sphere, matrix)
add_sphere!(model,cen=(0.0,0.0,0.0), radius=(0.5, ))

run_lamem(model,1)