#==============================================================================
    Code for solving the Hamiltonian Jacboi Bellman for
	   an RBC model with a Diffusion process

	Translated Julia code from Matlab code by Ben Moll:
        http://www.princeton.edu/~moll/HACTproject.htm
==============================================================================#

using Parameters, Distributions, Plots

@with_kw type RBC_Model_parameters
    γ= 2.0 #gamma parameter for CRRA utility
    ρ = 0.05 #the discount rate
    α = 0.3 # the curvature of the production function (cobb-douglas)
    δ = 0.05 # the depreciation rate
end


# Z our state variable follows this process
@with_kw type Ornstein_Uhlenbeck_parameters
	#= for this process:
	 		dlog(z) = -θ⋅log(z)dt + σ^2⋅dw
		and
			log(z)∼N(0,var) where var = σ^2/(2⋅θ) =#
    var = 0.07
	μ_z = exp(var/2)
	corr = 0.9
	θ = -log(corr)
	σ_sq = 2*θ*var

end

RBC_param = RBC_Model_parameters()
OU_param = Ornstein_Uhlenbeck_parameters()

@unpack_RBC_Model_parameters(RBC_param)
@unpack_Ornstein_Uhlenbeck_parameters(OU_param)

#=============================================================================
 	k our capital follows a process that depends on z,

	using the regular formulan for capital accumulation
	we would have:
		(1+ρ)k_{t+1} = k_{t}⋅f'(k_{t}) + (1-δ)k_{t}
	where:
		f(k_{t}) = z⋅k^{α} so f'(k_{t}) = (α)⋅z⋅k^{α-1}
	so in steady state where k_{t+1} = k_{t}
		(1+ρ)k = α⋅z⋅k^{α} + (1-δ)k
		k = [(α⋅z)/(ρ+δ)]^{1/(1-α)}

=============================================================================#
#K_starting point, for mean of z process

k_st = ((α⋅μ_z)/(ρ+δ))^(1/(1-α))

# create the grid for k
I = 100 #number of points on grid
k_min = 0.3*k_st # min value
k_max = 3*k_st # max value
k = linspace(k_min, k_max, I)
dk = (k_max-k_min)/(I-1)

# create the grid for z
J = 40
z_min = μ_z*0.8
z_max = μ_z*1.2
z = linspace(z_min, z_max, J)
dz = (z_max-z_min)/(J-1)
dz_sq = dz^2


# Check the pdf to make sure our grid isn't cutting off the tails of
	# our distribution
y = pdf.(LogNormal(0, var), z)
plot(z,y, grid=false,
		xlabel="z", ylabel="Probability",
		legend=false, color="purple", title="PDF of z")

#create matrices for k and z
kk = k*ones(1,J)
zz = ones(I,1)*z'

# use Ito's lemma to find the drift and variance of our optimization equation

μ = (-θ*log(z)+σ_sq/2).*z # the drift from Ito's lemma
Σ_sq = σ_sq.*z.^2 #the variance from Ito's lemma

max_it = 100
ε = 0.1^(6)
Δ = 1000

# set up all of these empty matrices
Vaf, Vab, Vzf, Vzb, Vzz, c = [zeros(I,J) for i in 1:6]

#==============================================================================

    Now we are going to construct a matrix summarizing the evolution of z

    We will do this using our Kolomogorov Forward Equation (KFE)
        of the general form:

        g(⋅)dt = -[s(k)g(⋅)]dk - [μ(⋅)g(⋅)]dz + 1/2 *(σ^2⋅g(⋅))dz^z



==============================================================================#

 yy = (-Σ_sq/dz_sq - μ/dz)
 χ = Σ_sq/(2*dz_sq) # Last term of KFE
 ζ = μ/dz + Σ_sq/(2*dz_sq)


 # Define the diagonals of this matrix
 updiag = zeros(I,1)
 	for j = 1:J
		updiag =[updiag; repmat([ζ[j]], I, 1)]
	end
 updiag =(updiag[:])


 centerdiag=repmat([χ[1]+yy[1]],I,1)
	for j = 2:J-1
		centerdiag = [centerdiag; repmat([yy[j]], I, 1)]
	end
 centerdiag=[centerdiag; repmat([yy[J]+ζ[J]], I, 1)]
 centerdiag = centerdiag[:]

lowdiag = repmat([χ[2]], I, 1)
	for j=3:J
		lowdiag = [lowdiag; repmat([χ[j]],I,1)]
	end
lowdiag=lowdiag[:]

# spdiags in Matlab allows for automatic trimming
    # spdiagm does not do this

B_switch = spdiagm(centerdiag)
    + [spdiagm(lowdiag) zeros(I*(J-1), I); zeros(I,I*J)]
    + spdiagm(updiag)[(I+1):end,(I+1):end]
