import CairoMakie as cm

function log10Ticks(max_val::Real, basis::NTuple{N,Int} = (1, 2, 5)) where N
    temp = log10(max_val)
    exponent = 0
    while temp ≥ 1.0
        exponent += 1
        temp -= 1.0
    end
    mantissa = 0
    for n in 1:N
        if temp ≥ log10(basis[n])
            mantissa = n
        end
    end

    total = N * exponent + mantissa
    ticks = Vector{Int}(undef, total)

    for n in 1:N
        temp = basis[n]
        for i in n:N:total
            ticks[i] = temp
            temp *= 10
        end
    end

    return ticks
end

function log10TicksLables(max_val::Real, basis::NTuple{N,Int} = (1, 2, 5)) where N
    temp = log10(max_val)
    exponent = 0
    while temp ≥ 1.0
        exponent += 1
        temp -= 1.0
    end
    mantissa = 0
    for n in 1:N
        if temp ≥ log10(basis[n])
            mantissa = n
        end
    end

    total = N * exponent + mantissa
    ticks = Vector{cm.Makie.RichText}(undef, total)

    if isone(N) && isone(first(basis))
        expo = 0
        for i in 1:total
            ticks[i] = cm.rich("10", cm.superscript("$expo"))
            expo += 1
        end
    else
        for n in 1:N
            mant = basis[n]
            expo = 0
            for i in n:N:total
                ticks[i] = cm.rich("$mant×10", cm.superscript("$expo"))
                expo += 1
            end
        end
    end

    return ticks
end
