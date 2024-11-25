using Sockets
using Lazy

includet("Repository.jl")
includet("Packet.jl")
includet("Packer.jl")
includet("Handler.jl")

import .Repository
import .Packet: getFirstDate, Opcode, pack
import .Handler: first_date
import .Packer: pack

function test()
    println("test 2 2 2")
end

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
    Repository.load_database()
    @async Repository.save_database()

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