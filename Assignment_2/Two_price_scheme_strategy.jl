using Random
using JuMP
using Gurobi
using Printf
using Clustering
using Distances
using Plots

include("Scenario generation.jl")

prob = 1/NSS

model_1= Model(Gurobi.Optimizer)

#declare Variables
@variable(model_1, p_DA[1:T]>=0)
@variable(model_1, Delta[1:T,1:NSS])
@variable(model_1, Delta_up[1:T,1:NSS]>=0)
@variable(model_1, Delta_down[1:T,1:NSS]>=0)


#Objective function
@objective(model_1,Max,sum(prob*(Selected_scenarios[w][2][t]*p_DA[t]+(0.9 + 0.1*(Selected_scenarios[w][3][t]))*Selected_scenarios[w][2][t]*Delta_up[t,w]-(1.2+0.2*(Selected_scenarios[w][3][t]-1))*Selected_scenarios[w][2][t]*Delta_down[t,w]) for w in 1:NSS,t in 1:T))

#Constraints
@constraint(model_1,DA_production[t in 1:T],p_DA[t]<= Capacity)
@constraint(model_1,production_uncertainty[t in 1:T,w in 1:NSS],Delta[t,w]==Selected_scenarios[w][1][t]-p_DA[t])
@constraint(model_1,production_inbalanced[t in 1:T,w in 1:NSS],Delta[t,w]==Delta_up[t,w]-Delta_down[t,w])

filepath = joinpath(@__DIR__, "model.lp")
f = open(filepath, "w")
print(f, model_1)
close(f)

# Solving the model
optimize!(model_1)

# Printing the termination status
println("Status: ", JuMP.termination_status(model_1))

# Printing the objective value
println("Objective value: ", JuMP.objective_value(model_1))

#displaying the wanted results
if termination_status(model_1) == MOI.OPTIMAL
    println("Optimal solution found")
    # Generate x values from -π to π
    x = collect(Int,1:T)

    # Calculate y values (sine of x)
    y = [value.(p_DA[t]) for t in 1:T ]

    # Plot the sine function
    plot(x, y, label="Day ahead production (MW)", xlabel="t (h)", ylabel="power (MW)", title="Day ahead production (MW)", linewidth=2)
    filepath = joinpath(@__DIR__, "Two_price_scheme_strategy.png")
    savefig(filepath)
    println("Expected profit: $(JuMP.objective_value(model_1))")

    scenarios_profit=zeros(NSS)
    for w in 1:NSS
        scenarios_profit[w]=sum(Selected_scenarios[w][2][t]*value.(p_DA[t])+(0.9 + 0.1*(Selected_scenarios[w][3][t]))*Selected_scenarios[w][2][t]*value.(Delta_up[t,w])-(0.9*Selected_scenarios[w][3][t] - 1.2*(Selected_scenarios[w][3][t]-1))*Selected_scenarios[w][2][t]*value.(Delta_down[t,w]) for t in 1:T)/1000000#/expected_profit
    end

    x_w = collect(Int, 1:NSS)
    plot(x_w, scenarios_profit, label="profit distribution scenarios", xlabel="scenarios", ylabel="Profit (MDKK)", title="profit distribution scenarios (DKK)", linewidth=2)
    filepath = joinpath(@__DIR__, "Two_price_scheme_profit.png")
    savefig(filepath)

end
