### A Pluto.jl notebook ###
# v0.19.42

using Markdown
using InteractiveUtils

# ╔═╡ 5ed84a1e-2af9-11ef-3805-01e3d9316a71
begin
	import Pkg
	Pkg.activate()

	import Libdl
	import CairoMakie as cm
end

# ╔═╡ 309d3141-0a7e-4134-ba5a-1a36969f475f
gauss(x::Real, μ::Real, σ::Real) =
	0.3989422804014327 * exp(-0.5 * abs2((x - μ)/σ)) / σ

# ╔═╡ e28976fa-8f61-40c1-a1b2-66cb0428da19
md"---"

# ╔═╡ 56f4b3f4-6e37-41dc-bbd7-ab87019f4657
p_ans = begin
	temp = [rand() for n in 1:6]
	temp_sum = sum(temp)
	@inbounds for i in eachindex(temp)
		temp[i] /= temp_sum
	end
	temp
end

# ╔═╡ 76fd39ed-01b8-4cd2-92be-c0d9a2e044bd
μ_ans = [30.0 * rand() for n in 1:length(p_ans)]

# ╔═╡ d066a659-c1ac-4c8d-a29f-41c91a0d0ab3
σ_ans = [0.1 + 0.9 * rand() for n in 1:length(p_ans)]

# ╔═╡ fb189e95-6c77-4e4e-8d19-7bff9656caf7
md"---"

# ╔═╡ 3a1225d5-0605-42e9-b498-b1760c8f7474
function demo(
	xdat::AbstractVector,
	μans::AbstractVector,
	σans::AbstractVector,
	pans::AbstractVector,
	# = = = = = = = = = =
	μsol::AbstractVector,
	σsol::AbstractVector,
	psol::AbstractVector,
)
	xlim = extrema(xdat)
	xarr = collect(range(xlim[1]; stop = xlim[2], length = 1024))
	yarr = similar(xarr)
	ytot = similar(xarr)
	@simd for i in eachindex(ytot)
		@inbounds ytot[i] = 0.0
	end

	fig = cm.Figure()
	axs = [
		cm.Axis(fig[1,1]; limits = (xlim..., 0.0, nothing)),
		cm.Axis(fig[2,1]; limits = (xlim..., 0.0, nothing))
	]

	for ax in axs
		cm.hist!(ax, xdat;
			bins = 128,
			color = (:steelblue, 0.5),
			normalization = :pdf,
		)
	end

	@inbounds for n in eachindex(pans)
		p_n = pans[n]
		μ_n = μans[n]
		σ_n = σans[n]
		@inbounds for i in eachindex(yarr)
			yarr[i] = p_n * gauss(xarr[i], μ_n, σ_n)
			ytot[i] += yarr[i]
		end

		for ax in axs
			cm.lines!(ax, xarr, yarr; color = (:gray25, 0.5),)
		end
	end

	for ax in axs
		cm.lines!(ax, xarr, ytot; color = (:gray25, 1.0),)
	end

	# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

	@simd for i in eachindex(ytot)
		@inbounds ytot[i] = 0.0
	end

	@inbounds for n in eachindex(psol)
		p_n = psol[n]
		μ_n = μsol[n]
		σ_n = σsol[n]
		@inbounds for i in eachindex(yarr)
			yarr[i] = p_n * gauss(xarr[i], μ_n, σ_n)
			ytot[i] += yarr[i]
		end

		cm.lines!(axs[1], xarr, yarr; color = (:chocolate2, 0.5),)
	end

	cm.lines!(axs[1], xarr, ytot; color = (:chocolate2, 1.0),)

	# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

	lib = Libdl.dlopen("../lib/lib-pespack.dylib")
	cSolveGMM = Libdl.dlsym(lib, :cSolveGMM)
	ccall(
		cSolveGMM, Nothing,
		(
			Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble},
			Csize_t, Csize_t, Csize_t
		),
		xdat, μsol, σsol, psol, length(xdat), length(psol), 8192
	)
	Libdl.dlclose(lib)

	@simd for i in eachindex(ytot)
		@inbounds ytot[i] = 0.0
	end

	@inbounds for n in eachindex(psol)
		p_n = psol[n]
		μ_n = μsol[n]
		σ_n = σsol[n]
		@inbounds for i in eachindex(yarr)
			yarr[i] = p_n * gauss(xarr[i], μ_n, σ_n)
			ytot[i] += yarr[i]
		end

		cm.lines!(axs[2], xarr, yarr; color = (:chocolate2, 0.5),)
	end

	cm.lines!(axs[2], xarr, ytot; color = (:chocolate2, 1.0),)

	# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

	return fig
end

# ╔═╡ e1dfc92f-5f88-4ce9-83f6-fa7a0dd994d9
x_dat = begin
	data = Vector{Float64}(undef, 1 << 11)
	for i in eachindex(data)
		ptmp = rand()
		seed = randn()
		@inbounds data[i] = if ptmp < 0.1
			μ_ans[1] + σ_ans[1] * seed
		elseif ptmp < 0.3
			μ_ans[2] + σ_ans[2] * seed
		elseif ptmp < 0.6
			μ_ans[3] + σ_ans[3] * seed
		else
			μ_ans[4] + σ_ans[4] * seed
		end
	end
	data
end

# ╔═╡ cb89d06f-3c35-4705-97e5-01d9384fa77d
begin
	p_sol = [inv(length(p_ans)) for n in 1:length(p_ans)]
	μ_sol = let xlim = extrema(x_dat), xsep = xlim[2] - xlim[1]
		[xlim[1] + xsep * (0.8 * rand() + 0.1) for n in 1:length(p_ans)]
	end
	σ_sol = let tmp = 1e0
		[tmp for n in 1:length(p_ans)]
	end

	demo(
		x_dat,
		μ_ans,
		σ_ans,
		p_ans,
		# = =
		μ_sol,
		σ_sol,
		p_sol,
	)
end

# ╔═╡ edb00adc-8654-4e9c-9279-fd30f4dde274
p_sol

# ╔═╡ 155d7832-08e3-4c08-ba0f-069e05efbc06
μ_sol

# ╔═╡ ded55b57-aff0-4154-9875-e3149d5cb899
σ_sol

# ╔═╡ Cell order:
# ╠═5ed84a1e-2af9-11ef-3805-01e3d9316a71
# ╟─309d3141-0a7e-4134-ba5a-1a36969f475f
# ╟─e28976fa-8f61-40c1-a1b2-66cb0428da19
# ╠═56f4b3f4-6e37-41dc-bbd7-ab87019f4657
# ╠═76fd39ed-01b8-4cd2-92be-c0d9a2e044bd
# ╠═d066a659-c1ac-4c8d-a29f-41c91a0d0ab3
# ╟─fb189e95-6c77-4e4e-8d19-7bff9656caf7
# ╠═3a1225d5-0605-42e9-b498-b1760c8f7474
# ╠═e1dfc92f-5f88-4ce9-83f6-fa7a0dd994d9
# ╠═cb89d06f-3c35-4705-97e5-01d9384fa77d
# ╠═edb00adc-8654-4e9c-9279-fd30f4dde274
# ╠═155d7832-08e3-4c08-ba0f-069e05efbc06
# ╠═ded55b57-aff0-4154-9875-e3149d5cb899
