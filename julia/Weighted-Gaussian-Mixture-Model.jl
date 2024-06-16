### A Pluto.jl notebook ###
# v0.19.42

using Markdown
using InteractiveUtils

# ╔═╡ 810e0bea-2b22-11ef-1124-dd6e2a3eba7d
begin
	import Pkg
	Pkg.activate()

	import Libdl
	import CairoMakie as cm
end

# ╔═╡ 1762d51b-f2ec-4cd4-8a07-d52e286afe42
gauss(x::Real, μ::Real, σ::Real) =
	0.3989422804014327 * exp(-0.5 * abs2((x - μ)/σ)) / σ

# ╔═╡ 2cbbabd3-5c1a-4cc2-88a1-590d14358d58
md"---"

# ╔═╡ 8c13a60c-80d9-47a1-8b5b-13554e983f3b
p_ans = begin
	temp = [rand() for n in 1:6]
	temp_sum = sum(temp)
	@inbounds for i in eachindex(temp)
		temp[i] /= temp_sum
	end
	temp
end

# ╔═╡ 9893f1fa-9969-487f-bb16-f089c27e06f6
μ_ans = [30.0 * rand() for n in 1:length(p_ans)]

# ╔═╡ afbdf97f-30a8-42cc-9868-bbc02fda3a5d
σ_ans = [0.1 + 0.9 * rand() for n in 1:length(p_ans)]

# ╔═╡ b3773db0-78a6-437f-9ac1-32142cc405dc
md"---"

# ╔═╡ f6da663f-750d-46b9-94b0-c1cb7fae24bb
function demo(
	xdat::AbstractVector,
	wdat::AbstractVector,
	μans::AbstractVector,
	σans::AbstractVector,
	pans::AbstractVector,
	# = = = = = = = = = =
	μsol::AbstractVector,
	σsol::AbstractVector,
	psol::AbstractVector,
)
	ytmp = similar(xdat)
	ytot = similar(xdat)

	fig = cm.Figure()
	axs = [
		cm.Axis(fig[1,1]; limits = (xdat[1], xdat[end], 0.0, nothing)),
		cm.Axis(fig[2,1]; limits = (xdat[1], xdat[end], 0.0, nothing))
	]

	for ax in axs
		cm.scatter!(ax, xdat, wdat;
			color = (:steelblue, 0.5),
			markersize = 5.0
		)
	end

	# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

	@simd for i in eachindex(ytot)
		@inbounds ytot[i] = 0.0
	end

	@inbounds for n in eachindex(pans)
		p_n = pans[n]
		μ_n = μans[n]
		σ_n = σans[n]
		@inbounds for i in eachindex(ytmp)
			ytmp[i] = p_n * gauss(xdat[i], μ_n, σ_n)
			ytot[i] += ytmp[i]
		end

		for ax in axs
			cm.lines!(ax, xdat, ytmp; color = (:gray25, 0.5),)
		end
	end

	for ax in axs
		cm.lines!(ax, xdat, ytot; color = (:gray25, 1.0),)
	end

	# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

	@simd for i in eachindex(ytot)
		@inbounds ytot[i] = 0.0
	end

	@inbounds for n in eachindex(psol)
		p_n = psol[n]
		μ_n = μsol[n]
		σ_n = σsol[n]
		@inbounds for i in eachindex(ytmp)
			ytmp[i] = p_n * gauss(xdat[i], μ_n, σ_n)
			ytot[i] += ytmp[i]
		end

		cm.lines!(axs[1], xdat, ytmp; color = (:chocolate2, 0.5),)
	end

	cm.lines!(axs[1], xdat, ytot; color = (:chocolate2, 1.0),)

	# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

	lib = Libdl.dlopen("../lib/lib-pespack.dylib")
	cSolveWGMM = Libdl.dlsym(lib, :cSolveWGMM)
	ccall(
		cSolveWGMM, Nothing,
		(
			Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble},
			Csize_t, Csize_t, Csize_t
		),
		xdat, wdat, μsol, σsol, psol, length(xdat), length(psol), 8192
	)
	Libdl.dlclose(lib)

	@simd for i in eachindex(ytot)
		@inbounds ytot[i] = 0.0
	end

	@inbounds for n in eachindex(psol)
		p_n = psol[n]
		μ_n = μsol[n]
		σ_n = σsol[n]
		@inbounds for i in eachindex(ytmp)
			ytmp[i] = p_n * gauss(xdat[i], μ_n, σ_n)
			ytot[i] += ytmp[i]
		end

		cm.lines!(axs[2], xdat, ytmp; color = (:chocolate2, 0.5),)
	end

	cm.lines!(axs[2], xdat, ytot; color = (:chocolate2, 1.0),)

	# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

	println("sum(wdat) / sum(ytot) = $(sum(wdat) / sum(ytot))")

	return fig
end

# ╔═╡ 3c9927f0-9ac1-42c2-9ec1-cd07b7431d2a
x_dat, w_dat = begin
	_μmin_, _μmin_index_ = findmin(μ_ans)
	_μmax_, _μmax_index_ = findmax(μ_ans)
	_xdat_ = collect(range(
		_μmin_ - 5.0 * σ_ans[_μmin_index_];
		stop = _μmax_ + 5.0 * σ_ans[_μmax_index_],
		step = 0.05
	))

	_wdat_ = similar(_xdat_)
	@simd for i in eachindex(_wdat_)
		@inbounds _wdat_[i] = 0.0
	end

	signal_amplitude = 1.37
	noise_amplitude = 0.001 * signal_amplitude

	for n in eachindex(p_ans)
		p_n = @inbounds p_ans[n] * 1.37
		μ_n = @inbounds μ_ans[n]
		σ_n = @inbounds σ_ans[n]
		@inbounds for i in eachindex(_wdat_)
			_wdat_[i] += max(0.0,
				p_n * gauss(_xdat_[i], μ_n, σ_n) + noise_amplitude * randn()
			)
		end
	end

	_xdat_, _wdat_
end

# ╔═╡ f395b8c7-649b-468c-a392-a6e68134df4d
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
		w_dat,
		μ_ans,
		σ_ans,
		p_ans,
		# = =
		μ_sol,
		σ_sol,
		p_sol,
	)
end

# ╔═╡ 0350e518-48c1-46ce-a70f-48bf6ec2f588
p_sol, p_ans

# ╔═╡ 1d7599ff-afd2-4618-bd40-858c91a728fa
μ_sol, μ_ans

# ╔═╡ d46e2e56-1a45-40d9-9bd3-13cbaca42c1b
σ_sol, σ_ans

# ╔═╡ Cell order:
# ╠═810e0bea-2b22-11ef-1124-dd6e2a3eba7d
# ╟─1762d51b-f2ec-4cd4-8a07-d52e286afe42
# ╟─2cbbabd3-5c1a-4cc2-88a1-590d14358d58
# ╠═8c13a60c-80d9-47a1-8b5b-13554e983f3b
# ╠═9893f1fa-9969-487f-bb16-f089c27e06f6
# ╠═afbdf97f-30a8-42cc-9868-bbc02fda3a5d
# ╟─b3773db0-78a6-437f-9ac1-32142cc405dc
# ╠═f6da663f-750d-46b9-94b0-c1cb7fae24bb
# ╠═3c9927f0-9ac1-42c2-9ec1-cd07b7431d2a
# ╠═f395b8c7-649b-468c-a392-a6e68134df4d
# ╠═0350e518-48c1-46ce-a70f-48bf6ec2f588
# ╠═1d7599ff-afd2-4618-bd40-858c91a728fa
# ╠═d46e2e56-1a45-40d9-9bd3-13cbaca42c1b
