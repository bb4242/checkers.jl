using Revise

include("checkers.jl")

module GameServer

using Checkers
import JSON

mutable struct ServerGame
    players::Dict{Int, TCPSocket}
    game_state::Checkers.State
end

# Map from game_id to state data about that game
games = Dict{Any, ServerGame}()

# http = HttpHandler() do req::Request, res::Response
#     global next_id
#     global game_states
#     println(req.resource)
#     m = match(r"^/games/new/?$", req.resource)
#     if m != nothing
#         game_states[next_id] = State()
#         next_id += 1
#         return Response(string(next_id-1))
#     end

#     m = match(r"^/games/(\d+)/?$", req.resource)
#     if m != nothing
#         game_id = parse(Int, m.captures[1])
#         return Response(200, Dict{AbstractString,AbstractString}([("Content-Type","application/json")]), JSON.json(game_states[game_id], 2))
#     end



#     #m = match(r"^/games/(\d+)/?$", req.resource)
#     #if m == nothing return Response(404) end
#     #println(m.captures)
#     #number = parse(BigInt, m.captures[1])
#     #if number < 1 || number > 100_000 return Response(500) end
#     #return Response(string(fibonacci(number)))
# end

# http.events["error"]  = (client, err) -> println(err)
# http.events["listen"] = (port)        -> println("Listening on $port...")

# server = Server( http )
# run( server, 8000 )

function do_server()
    println("Hello")
    while true
        server = listen(4242)
        while true
            sock = accept(server)
            @async handle_client(sock)
        end
    end
end

function handle_client(sock)
    while isopen(sock)
        println("Waiting...")
        msg = readline(sock)
        println("Received: ", msg)
        try
            res = JSON.parse(msg)
            println("Parsed: ", res)
            command = res["command"]
            game_id = res["game_id"]
            player = res["player"]
            println("Command: ", command)
            println("Games ", games)

            if command == "join"
                println("PLAYER ", player)
                if !(player in [1, 2])
                    write(sock, """{"result": "error", "reason": "invalid player (must be 1 or 2)"}\n""")
                    continue
                end
                if haskey(games, game_id)
                    game = games[game_id]
                    if haskey(game.players, player)
                        write(sock, """{"result": "error", "reason": "invalid player (already taken)"}\n""")
                        continue
                    else
                        println("Client $sock joining $game_id as $player")
                        game.players[player] = sock
                        write(sock, """{"result": "ok", "game_state": $(JSON.json(games[game_id].game_state))}\n""")
                        continue
                    end
                else
                    newgame = ServerGame(Dict(player => sock), Checkers.State())
                    games[game_id] = newgame
                    println("Creating new game $game_id")
                    write(sock, """{"result": "ok", "game_state": $(JSON.json(games[game_id].game_state))}\n""")
                    continue
                end

            elseif command == "move"
                if haskey(games, game_id) && games[game_id].players[player] == sock
                    move = res["move"]
                    println("Game $game_id: player $player move $move")

                    # TODO: Make sure game has 2 players
                    # TODO: Validate it's your turn
                    # TODO: Apply move
                    # TODO: Check for game that has ended & remove it from games dict

                    for pair in games[game_id].players
                        write(pair[2], """{"result": "ok", "game_state": $(JSON.json(games[game_id].game_state))}\n""")
                    end

                    continue
                end
            end

        catch exc
            println("EXC ", exc)
        end
    end


    # TODO: Remove client from game, delete game if necessary
end




do_server()

end
