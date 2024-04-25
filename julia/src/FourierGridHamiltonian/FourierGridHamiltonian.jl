module FourierGridHamiltonian

import FFTW
import LinearAlgebra: LAPACK, BLAS, chkstride1, checksquare, libblastrampoline

include("./eigen.jl")

end # module FourierGridHamiltonian
