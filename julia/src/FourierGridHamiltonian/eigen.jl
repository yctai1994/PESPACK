if Base.USE_BLAS64
    const BlasInt = Int64
else
    const BlasInt = Int32
end

struct ZHEEVR
    isuppz::Vector{Int64}
    work  ::Vector{ComplexF64}
    rwork ::Vector{Float64}
    iwork ::Vector{Int64}
end

function ZHEEVR(n::Int; nb::Int = 32)
    isuppz = Vector{BlasInt}(undef, 2n)
    work   = Vector{ComplexF64}(undef, max(1, (nb + 1) * n))
    rwork  = Vector{Float64}(undef, max(1, 24n))
    iwork  = Vector{BlasInt}(undef, max(1, 10n))
    return ZHEEVR(isuppz, work, rwork, iwork)
end

# Hermitian eigensolvers using LAPACK zheevr subroutine
function eigen!(
        values ::AbstractVector{Float64},
        vectors::AbstractMatrix{ComplexF64},
        matrix ::AbstractMatrix{ComplexF64},
        zheevr ::ZHEEVR,
    )
    Base.require_one_based_indexing(matrix)

    jobz   = 'V'
    range  = 'A'
    uplo   = 'U'
    vl, vu, il, iu, abstol = 0.0, 0.0, 0, 0, -1.0

    chkstride1(matrix)
    LAPACK.chkuplofinite(matrix, uplo)

    n      = checksquare(matrix) # The order of the matrix A.
    lda    = max(1, stride(matrix, 2)) # The leading dimension of the array A.
    m      = Ref{BlasInt}() # The total number of eigenvalues found.
    ldz    = max(1, n) # The leading dimension of the array Z.
    lwork  = BlasInt(-1)
    lrwork = BlasInt(-1)
    liwork = BlasInt(-1)
    info   = Ref{BlasInt}()

    for i = 1:2
        ccall(
            (
                BLAS.@blasfunc(zheevr_),
                libblastrampoline
            ), Cvoid,
            (
                Ref{UInt8}, Ref{UInt8}, Ref{UInt8}, Ref{BlasInt},
                Ptr{ComplexF64}, Ref{BlasInt}, Ref{ComplexF64}, Ref{ComplexF64},
                Ref{BlasInt}, Ref{BlasInt}, Ref{ComplexF64}, Ptr{BlasInt},
                Ptr{Float64}, Ptr{ComplexF64}, Ref{BlasInt}, Ptr{BlasInt},
                Ptr{ComplexF64}, Ref{BlasInt}, Ptr{Float64}, Ref{BlasInt},
                Ptr{BlasInt}, Ref{BlasInt}, Ptr{BlasInt},
                Clong, Clong, Clong
            ),
            jobz, range, uplo, n,
            matrix, lda, vl, vu,
            il, iu, abstol, m,
            values, vectors,
            ldz, zheevr.isuppz,
            zheevr.work, lwork,
            zheevr.rwork, lrwork,
            zheevr.iwork, liwork,
            info, 1, 1, 1
        )

        LAPACK.chklapackerror(info[])

        if isone(i)
            lwork = BlasInt(real(zheevr.work[1]))
            @assert lwork ≤ length(zheevr.work) "lwork > length(zheevr.work)"
            lrwork = BlasInt(zheevr.rwork[1])
            @assert lrwork ≤ length(zheevr.rwork) "lrwork > length(zheevr.rwork)"
            liwork = zheevr.iwork[1]
            @assert liwork ≤ length(zheevr.iwork) "liwork > length(zheevr.iwork)"
        end
    end

    return nothing
end

function permuteval!(v::AbstractVector, i::Int, j::Int)
    @inbounds temp = v[i]
    @inbounds v[i] = v[j]
    @inbounds v[j] = temp
    return nothing
end

function permutecol!(m::AbstractMatrix, col1::Int, col2::Int)
	@inbounds for i in axes(m, 1)
		temp = m[i,col1]
    	m[i,col1] = m[i,col2]
    	m[i,col2] = temp
	end
	return nothing
end

function binarySearch(
	arr::AbstractVector,
	val::ComplexF64,
	lx::Int,
	rx::Int;
	sortby::Function = real,
)
    lx ≥ rx && return lx
    ub = rx # upper bound
    while lx < rx
		# midpoint (binary search)
        mx = (lx + rx) >> 1
		# arr[mx].f == val in this case
        if @inbounds isless(sortby(val), sortby(arr[mx]))
			rx = mx
		else
			lx = mx + 1
		end
    end

	# lx = upper bound && arr[lx] ≤ val
    if @inbounds lx ≡ ub && !isless(sortby(val), sortby(arr[lx]))
		lx += 1
	end

    return lx
end

struct GEEVX
    scale ::Vector{Float64}
    rconde::Vector{Float64}
    rcondv::Vector{Float64}
    work  ::Vector{ComplexF64}
    rwork ::Vector{Float64}
end

function GEEVX(n::Int; nb::Int = 128)
    scale  = Vector{Float64}(undef, n)
    rconde = Vector{Float64}(undef, n)
    rcondv = Vector{Float64}(undef, n)
    work   = Vector{ComplexF64}(undef, max(1, (nb + 1) * n))
    rwork  = Vector{Float64}(undef, max(1, 2n))
    return GEEVX(scale, rconde, rcondv, work, rwork)
end

# non-hermitian eigen decomposition
function eigen!(
	values::AbstractVector{ComplexF64},
	vectors::AbstractMatrix{ComplexF64},
	matrix::AbstractMatrix{ComplexF64},
	geevx::GEEVX;
	sortby::Function = real,
)
	Base.require_one_based_indexing(matrix)

	balanc = 'B'
	sense  = 'N'

	n = checksquare(matrix)

	jobvl = 'N'
	ldvl  = 0 # @assert ldvl == 0

	jobvr = 'V'
	ldvr  = n # @assert ldvr == n

	LAPACK.chkfinite(matrix) # balancing routines don't support NaNs and Infs

	lda = max(1, stride(matrix, 2))
	ilo = Ref{BlasInt}()
	ihi = Ref{BlasInt}()

	abnrm = Ref{Float64}()	
	lwork = BlasInt(-1)
	info  = Ref{BlasInt}()

	for ix in 1:2  # first call returns lwork as work[1]
		ccall(
			(
				BLAS.@blasfunc(zgeevx_),
				libblastrampoline
			),
			Cvoid,
			(
				Ref{UInt8}, Ref{UInt8}, Ref{UInt8}, Ref{UInt8},
				Ref{BlasInt}, Ptr{ComplexF64}, Ref{BlasInt}, Ptr{ComplexF64},
				Ptr{ComplexF64}, Ref{BlasInt},
				Ptr{ComplexF64}, Ref{BlasInt},
				Ptr{BlasInt}, Ptr{BlasInt}, Ptr{Float64}, Ptr{Float64},
				Ptr{Float64}, Ptr{Float64},
				Ptr{ComplexF64}, Ref{BlasInt},
				Ptr{Float64}, Ref{BlasInt},
				Clong, Clong, Clong, Clong
			),
			balanc, jobvl, jobvr, sense,
			n, matrix, lda, values,
			Ptr{ComplexF64}(), max(1, ldvl),
			vectors, max(1, ldvr),
			ilo, ihi, geevx.scale, abnrm,
			geevx.rconde, geevx.rcondv,
			geevx.work, lwork,
			geevx.rwork, info,
			1, 1, 1, 1
		)

		LAPACK.chklapackerror(info[])

		if isone(ix)
			lwork = BlasInt(geevx.work[1])
			@assert lwork ≤ length(geevx.work) "lwork > length(geevx.work)"
		end
	end

	for ix in 2:n
        @inbounds val = values[ix]
        jx = ix
        lc = binarySearch(values, val, 1, ix; sortby = sortby) # location
        while jx > lc
            permuteval!(values,  jx, jx-1)
			permutecol!(vectors, jx, jx-1)
            jx -= 1
        end
    end

	return nothing
end
