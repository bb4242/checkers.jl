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

function state_to_json(s::State)
    d = Dict(
        "turn" => convert(Int, s.turn),
        "moves_without_capture" => s.moves_without_capture,
        "board" => convert(Array{Int, 2}, s.board)
    )
    return JSON.json(d)
end

function do_server()
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
        println(games)
        msg = readline(sock)
        println("Received: ", msg)
        try
            res = JSON.parse(msg)
            println("Parsed: ", res)
            command = res["command"]
            game_id = res["game_id"]
            player = res["player"]

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
                        for pair in game.players
                            write(pair[2], """{"result": "ok", "game_state": $(state_to_json(games[game_id].game_state))}\n""")
                        end
                        continue
                    end
                else
                    newgame = ServerGame(Dict(player => sock), Checkers.State())
                    games[game_id] = newgame
                    println("Creating new game $game_id")
                    write(sock, """{"result": "ok"}\n""")
                    continue
                end

            elseif command == "move"
                if haskey(games, game_id)
                    game = games[game_id]

                    if game.players[player] != sock
                        write(sock, """{"result": "error", "reason": "trying to move for another player"}\n""")
                        continue
                    elseif length(game.players) != 2
                        write(sock, """{"result": "error", "reason": "other player has not joined"}\n""")
                        continue
                    elseif game.game_state.turn != (player == 1 ? Checkers.p1turn : Checkers.p2turn)
                        write(sock, """{"result": "error", "reason": "not your turn"}\n""")
                        continue
                    end

                    move_arr = res["move"]
                    println("Game $game_id: player $player move $move_arr")

                    for i in 1:(length(move_arr) - 1)
                        cm = Checkers.Move(move_arr[i][1], move_arr[i][2], move_arr[i+1][1], move_arr[i+1][2])
                        game.game_state = Checkers.apply_move(game.game_state, cm, Checkers.CheckersMem())
                    end

                    for pair in game.players
                        write(pair[2], """{"result": "ok", "game_state": $(state_to_json(game.game_state))}\n""")
                        if Checkers.is_terminal(game.game_state, Checkers.CheckersMem())[1]
                            close(pair[2])
                        end
                    end
                end
            end

        catch exc
            println("Exception caught: ", exc)
            println(catch_stacktrace())
        end
    end

    println("Client $sock disconnected")
    for game_pair in games
        game = game_pair[2]
        players = game.players
        for player_pair in game.players
            if player_pair[2] == sock
                delete!(game.players, player_pair[1])
                if length(game.players) == 0
                    println("Last player left $(game_pair[1])")
                    delete!(games, game_pair[1])
                end
            end
        end
    end
    println(games)

    # TODO: Remove client from game, delete game if necessary
end




do_server()

end
