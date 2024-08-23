include("Opcodes.jl")
include("../packet/Auth.jl")
include("Actions.jl")
include("../packet/Chars.jl")

function route(::Type{Val{auth}}, buf)
    println("auth route")

    auth_body = unpack(Auth, buf)
    println(auth_body)

    return pack(CharacterScreen()) |> x -> pack(response_chars, x)
end

function route(::Type{Val{exit}}, buf)
    println("exit route")

    return a_exit
end

route(v::Opcode, data) = route(Val{v}, data)