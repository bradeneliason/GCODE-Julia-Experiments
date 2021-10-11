using GcodeParser
using GLMakie
using Parameters

##
# Load Command Types
# TODO: M43 T seems to break with the other rule patterns
commandtype = Dict(pair[1]=>strip(pair[2]) for pair = split.(readlines("marlin_codes.txt"), ":"))

# Prusa-specific G-codes
commandtype["M862.1"] = "Print checking - nozzle diameter ";
commandtype["M862.2"] = "Print checking - model code";
commandtype["M862.3"] = "Print checking - model name";
commandtype["M862.4"] = "Print checking - firmware version";
commandtype["M862.5"] = "Print checking - gcode level";

## TODO: create a struct for printer position and state
# Vector of abstract commands. 
# subtype movement commands
# https://marlinfw.org/docs/gcode/G000-G001.html
abstract type GCommand end

const Option{T} = Union{T, Missing}
@with_kw struct GMovement{T<:Real} <: GCommand
    x::Option{T}   = missing # position
    y::Option{T}   = missing # position
    z::Option{T}   = missing # position
    e::Option{T}   = missing # extrusion
    f::Option{T}   = missing # feedrate
    s::Option{T}   = missing # laser power (not used)
    absolute::Bool = true    # Absolute position
end


##
# GcodeParser.stripComments didn't work well for all comments
function stripComments(line::String)::String
    re1 = r"\(.*\)";    # Remove anything inside the outer parentheses
    re2 = r"[^:]\;.*";  # Remove anything after a semi-colon to the end of the line, including preceding spaces
    re3 = r"^\;.*$";  # Remove anything after a semi-colon to the end of the line, including preceding spaces

    line = replace(line,  re1 => s"");
    line = replace(line,  re2 => s"");
    line = replace(line,  re3 => s"");
    line = filter(x -> !isspace(x), line) # Remove whitespace

    return line;
end

# Extract Movements from gcode G1/G0 commandss
function movement(cmds, absolute=true)
    xval = yval = zval = eval = fval = sval = missing
    if haskey(cmds, "X")
        xval = parse(Float64, cmds["X"]);
    end
    if haskey(cmds, "Y")
        yval = parse(Float64, cmds["Y"]);
    end
    if haskey(cmds, "Z")
        zval = parse(Float64, cmds["Z"]);
    end
    if haskey(cmds, "E")
        eval = parse(Float64, cmds["E"]);
    end
    GMovement{Float64}(x=xval, y=yval, z=zval, e=eval, f=fval, s=sval)
end
# c =  Dict("Y" => "117.050", "X" => "112.950", "G" => "1", "E" => "1.63151") 
# movement(c)



##
# path = "gcode/test.gcode"
# path = "gcode/clip.gcode"
# path = "gcode/towers.gcode"
# TODO: moar performance
path = "gcode/lamp.gcode"
glines = readlines(path)
glines = stripComments.(glines)
filter!(l -> length(l)>0, glines);

gcmds = parseLine.(glines); #TODO: are there ever gcodes with two identical arguments?
gcmds = [Dict("cmd" => "$(c[1][1]c[1][2])", c[2:end]...) for c in gcmds];

@info "Length of GCODE: " length(gcmds)

##

printpath = []
for line in gcmds
    command = line["cmd"]

    if command == "G91"
        # TODO: Implement switches between relative and absolute positioning
        @warn "Relative positioning not implemented\n$line"
    end

    if command == "G1"
        push!(printpath, movement(line));
    end
end;

##
fillmissing(val, lastval=0.0) = ismissing(val) ? lastval : val

function getxyz(movelist, default=zeros(1,4))
    x,y,z,e, = default
    N = length(movelist)
    positions = Matrix{Option{Float64}}(undef, N,4)
    @inbounds for (i,mov) in enumerate(movelist)
        x = fillmissing(mov.x, x)
        y = fillmissing(mov.y, y)
        z = fillmissing(mov.z, z)
        e = mov.e
        positions[i,:] = [x y z e]
    end
    positions
end

@time positions = getxyz(printpath);
x = positions[:, 1]
y = positions[:, 2]
z = positions[:, 3]
e = positions[:, 4]

nothing
##
# https://makie.juliaplots.org/stable/examples/plotting_functions/lines/#example_11610848752349455524
lws = ifelse.(ismissing.(e), 0.5, 2.0)
cs = ifelse.(ismissing.(e), 1.0, 0.0)
fig, _ = lines(x,y,z, overdraw = true, color=cs) # try overdraw = true
fig


