const REGEX_DATE            = r"X //Created Date \(UTC\): (?P<date>[\s\S]*)$";
const REGEX_ITX_VERSION     = r"X //Igor Text File Exporter Version: (?P<version>[\d.]*)$";
const REGEX_PRODIGY_VERSION = r"X //Created by: SpecsLab Prodigy,\s*(?:\S+)\s*(?P<version>\S+)\s*$";
const REGEX_ACQ_PARAMS      = r"X //(?P<name>.*)\b\s* = (?P<value>.*)$";
const REGEX_WAVES           = r"\S*=\((?P<S>\d+),(?P<N>\d+)\)\s*'(?P<ID>\S*)'.*$";
const REGEX_XSCALE          = r"X SetScale\s?/\S x,\s*(?P<xval1>[\+\-\.\d]+)\s*,\s*(?P<xval2>[\+\-\.\d]+)\s*,\s*\"(?P<xinfo>.*)\"\s*,\s*'(?P<ID>\S*)'.*$";
const REGEX_YSCALE          = r"X SetScale\s?/\S y,\s*(?P<yval1>[\+\-\.\d]+)\s*,\s*(?P<yval2>[\+\-\.\d]+)\s*,\s*\"(?P<yinfo>.*)\"\s*,\s*'(?P<ID>\S*)'.*$";
const REGEX_DSCALE          = r"X SetScale\s?/\S d,\s*(?P<dval1>[\+\-\.\d]+)\s*,\s*(?P<dval2>[\+\-\.\d]+)\s*,\s*\"(?P<dinfo>.*)\"\s*,\s*'(?P<ID>\S*)'.*$";
const REGEX_DELAY           = r"position:(?P<stage_delay>[\+\-\.\d]+);beta:(?P<stage_beta>[\+\-\.\d]+);X:(?P<stage_X>[\+\-\.\d]+);Y:(?P<stage_Y>[\+\-\.\d]+);A:(?P<stage_A>[\+\-\.\d]+);B:(?P<stage_B>[\+\-\.\d]+);\s*$";

struct ProdigyITX
	id          ::String # Exp. Data ID
	date        ::String # Creation Date
	itx_ver     ::String # Igor Text File Version
	software_ver::String # Software Version
	params      ::Dict{String, String}
	data        ::Matrix{Float64}
	xarr        ::Vector{Float64}
	yarr        ::Vector{Float64}
end

function ProdigyITX(itx_pth::String; ifshow::Bool=false)
    itx_eachline = eachline(itx_pth)

    str = first(iterate(itx_eachline))
    if str ≠ "IGOR"
        error("ITX file does not start with a header 'IGOR'.")
    end
    ifshow && println("check: header = 'IGOR'")

    str = first(iterate(itx_eachline))
    ifshow && println("match: date with [ $str ]")
    date = match(REGEX_DATE, str)["date"]

    str = first(iterate(itx_eachline))
    ifshow && println("match: itx-version with [ $str ]")

    regex_match = match(REGEX_ITX_VERSION, str)
    itx_ver = if regex_match ≡ nothing
        regex_match = match(REGEX_PRODIGY_VERSION, str)
        ""
    else
        str = first(iterate(itx_eachline))
        regex_match["version"]
    end

    ifshow && println("match: software-version with [ $str ]")
    software_ver = if regex_match ≡ nothing
        regex_match = match(REGEX_PRODIGY_VERSION, str)
        ""
    else
        str = first(iterate(itx_eachline))
        regex_match["version"]
    end

    params = Dict{String, String}()

    if regex_match ≡ nothing
        str = first(iterate(itx_eachline))
    end
    ifshow && println("match: Acquisition Parameters with [ $str ]")
    if str ≠ "X //Acquisition Parameters:"
        error("Cannot find the position of 'Acquisition Parameters'.")
    end
    ifshow && println("check: acquisition parameters found")

    str = first(iterate(itx_eachline))
    while true
        ifshow && println("match: try $str")
        view(str, 1:4) ≠ "X //" && break
        regex_match = match(REGEX_ACQ_PARAMS, str)
        ifshow && println("match: try here: $regex_match")
        ifshow && println("match: get regex_match[\"name\"]  = $(regex_match["name"])")
        ifshow && println("match: get regex_match[\"value\"] = $(regex_match["value"])")
        params[regex_match["name"]] = regex_match["value"]

        str = first(iterate(itx_eachline))
    end

    ifshow && println("match: try $str")
    waves = match(REGEX_WAVES, str)
    id, nrow, ncol = waves["ID"], parse(Int, waves["S"]), parse(Int, waves["N"])

    str = first(iterate(itx_eachline))
    if str ≠ "BEGIN"
        error("Cannot find the position of 'BEGIN'.")
    end

    data = Matrix{Float64}(undef, nrow, ncol)

    for i in axes(data, 1)
        str_split = eachsplit(first(iterate(itx_eachline)), ' ')
        for (j, s) in enumerate(str_split)
            @inbounds data[i,j] = parse(Float64, s)
        end
    end

    str = first(iterate(itx_eachline))
    if str ≠ "END"
        error("Cannot find the position of 'END'.")
    end

    str = first(iterate(itx_eachline))
    let regex_match = match(REGEX_XSCALE, str)
        id ≠ regex_match["ID"] && error("")
        params["xval1"] = regex_match["xval1"]
        params["xval2"] = regex_match["xval2"]
        params["xinfo"] = regex_match["xinfo"]
    end

    xarr = collect(
        range(
            parse(Float64, params["xval1"]),
            parse(Float64, params["xval2"]);
            length=nrow
        )
    )

    str = first(iterate(itx_eachline))
    let regex_match = match(REGEX_YSCALE, str)
        id ≠ regex_match["ID"] && error("")
        params["yval1"] = regex_match["yval1"]
        params["yval2"] = regex_match["yval2"]
        params["yinfo"] = regex_match["yinfo"]
    end

    yval1 = parse(Float64, params["yval1"])
    yval2 = parse(Float64, params["yval2"])
    yarr = if yval1 ≤ yval2
        collect(range(; start = yval1, stop = yval2, length = ncol))
    else
        collect(range(; start = yval1, step = yval2, length = ncol))
    end

    str = first(iterate(itx_eachline))
    let regex_match = match(REGEX_DSCALE, str)
        id ≠ regex_match["ID"] && error("")
        params["dval1"] = regex_match["dval1"]
        params["dval2"] = regex_match["dval2"]
        params["dinfo"] = regex_match["dinfo"]
    end

    close(itx_eachline.stream)

    return ProdigyITX(id, date, itx_ver, software_ver, params, data, xarr, yarr)
end
