#==============================================================================
    Code for solving the Hamiltonian Jacboi Bellman for
	   an basic model: a neoclassical growth model: ρV(k) = max_{c} U(c) + V'(k)[F(k)-δk - c]
	   Where s(k) = F(k) - δk - c(k) and c(k) = U'^{-1}(V'(k))

	Translated Julia code from Matlab code by Ben Moll:
        http://www.princeton.edu/~moll/HACTproject.htm

    Updated to Julia 1.0.0
==============================================================================#

using Distributions, Plots, SparseArrays, LinearAlgebra


σ= 2.0 #
ρ = 0.05 #the discount rate
δ = 0.05 # the depreciation rate
A = 1.0
α= 0.3


k_ss = (α*A/(ρ+δ))^(1/(1-α))

H = 10000
k_min = 0.001*k_ss
k_max = 2.0*k_ss

k = LinRange(k_min, k_max, H)
k = convert(Array, k) # create grid for a values
dk = (k_max-k_min)/(H-1)

Δ = 1000

maxit = 10
ε = 10e-6

dVf, dVb = [zeros(H,1) for i in 1:6]

#initial guess for V
v0 = (A.*k.^α).^(1-σ)/(1-σ)/ρ
v= v0

dist=[]

for n=1:maxit
	V=v

    # forward difference
	dVf[1:H-1] = (V[2:H]-V[1:H-1])/dk
	dVf[H] = (A.*k_max.^α - δ.*k_max)^(-σ)

	# backward difference
	dVb[2:H] = (V[2:H]-V[1:H-1])/dk
	dVb[1] = (A.*k_min.^α - δ.*k_min)^(-σ) # the boundary condition

	I_concave = dVb .> dVf

    # consumption and savings with forward difference
    cf = dVf.^(-1/σ)
    μ_f = A.*k.^α - δ.*k -cf

    # consumption and savings with backward difference
    cb = dVb.^(-1/σ)
    μ_b = A.*k.^α - δ.*k -cb

	c0 = A.*k.^α - δ.*k
    dV0 = c0.^(-σ)

    # Now to make a choice between forward and backward difference
    If = μ_f .> 0
    Ib = μ_b .< 0
    I0 = (1.0.-If-Ib)

    global dV_Upwind= dVf.*If + dVb.*Ib + dV0.*I0

    global c = dV_Upwind.^(-1/σ)
    u = c.^(1-σ)/(1-σ)

    # create the transition matrix
    X = -min.(μ_b,0)/dk
    Y = -max.(μ_f,0)/dk + min.(μ_b,0)/dk
    Z = max.(μ_f,0)/dk


    AA = sparse(Diagonal((Y[:]))) + [zeros(1,H); sparse(Diagonal((X[2:H]))) zeros(H-1,1)] + [zeros(H-1,1) sparse(Diagonal((Z[1:H-1]))); zeros(1,H)]
    B = (ρ + 1/Δ)*sparse(I,H,H) - AA
    b = u + V./Δ

    V = B\b
    V_change = V-v
    global v= V

	push!(dist,findmax(abs.(V_change))[1])
	if dist[n] .< ε
		println("Value Function Converged Iteration=")
		println(n)
		break
	end
end

plot(dist, grid=false,
		xlabel="Iteration", ylabel="||V^{n+1} - V^n||",
		ylims=(-0.001,0.030),
		legend=false, title="")
png("Convergence")


v_err = c.^(1-σ)/(1-σ) + dV_Upwind.*(A.*k.^α - δ.*k -c) - ρ.*v

plot(k, v_err, grid=false,
		xlabel="k", ylabel="Error in the HJB equation",
		xlims=(k_min,k_max),
		legend=false, title="")
png("HJB_error")


plot(k, v, grid=false,
		xlabel="k", ylabel="V(k)",
		xlims=(k_min,k_max),
		legend=false, title="")
png("Value_function_vs_k")

plot(k, c, grid=false,
		xlabel="k", ylabel="c(k)",
		xlims=(k_min,k_max),
		legend=false, title="")
png("c(k)_vs_k")

# approximation at the borrowing constraint
k_dot = (A.*k.^α - δ.*k -c)

plot(k, k_dot, grid=false,
		xlabel="k", ylabel="s(k)",
		xlims=(k_min,k_max), title="", label="s(k)", legend=false)
plot!(k, zeros(H,1), label="", line=:dash)
png("stateconstraint")
