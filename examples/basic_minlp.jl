using JuMP
using ALGLIB

model = Model(ALGLIB.Optimizer)
@variable(model, x >= 0, Int)
@variable(model, y >= 0)
@objective(model, Min, (x - 1)^2 + (y - 2)^2)
optimize!(model)

println("termination_status = ", termination_status(model))
println("x = ", value(x))
println("y = ", value(y))
