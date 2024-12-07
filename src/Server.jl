import Dates
import CSV
import JLD2

using Base.Threads
using DataFrames
using UUIDs
using Sockets
using Lazy
using Dates
using Printf

# OPCODES

@enum Opcode auth = 431 exit = 432 response_chars = 931 first_date = 940 create_pincode = 346 create_pincode_reply = 941 create_character = 435 create_character_reply = 935 remove_character = 436 remove_character_reply = 936 update_pincode = 347 update_pincode_reply = 942

@enum Action a_exit = 1

# MACROS

include("Packer.jl")

# PACKETS

include("Packet.jl")

# REPOSITORY

include("Repository.jl")

# HANDLERS

include("Route.jl")

# SERVER

function handle_client(client::TCPSocket)
    println("accept client")

    try
        @>> getFirstDate() pack(first_date) write(client)
    catch e
        showerror(stdout, e, catch_backtrace())
    end

    # Read data from the client
    while isopen(client)
        try
            data = readavailable(client)
            if length(data) == 2
                write(client, data)
                continue
            end

            buf = IOBuffer(data)

            header = unpack(Header, buf)
            println("Received from client: ", header.opcode)

            @async begin
                try
                    res = Opcode(header.opcode) |> x -> route(x, buf)
                    if res == a_exit
                        close(client)
                        return
                    end

                    write(client, res)
                catch e
                    showerror(stdout, e, catch_backtrace())
                    close(client)
                end
            end
        catch e
            if e isa EOFError
                return
            end

            showerror(stdout, e, catch_backtrace())
            break  # Exit the loop if an error occurs (like client disconnection)
        end
    end

    println("Client disconnected")
end

# Create and run the TCP server
function start_server(port::Int)
    load_database()
    @async save_database()

    server = listen(IPv4(0), port)
    println("Server is listening on port $port")

    try
        while true
            client = accept(server) # Accept a new client
            @async handle_client(client) # Handle the client asynchronously
        end
    catch err
        println("can't accept client")
        println(err)
    end
end