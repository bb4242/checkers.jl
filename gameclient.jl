include("mcts.jl")

module GameClient

using MCTS
using Checkers
import JSON

function parse_json(j)
    s = Checkers.State()
    s.turn = convert(Checkers.TURN, j["turn"])
    s.moves_without_capture = j["moves_without_capture"]
    s.board = convert(Array{Checkers.BOARD, 2}, hcat(j["board"]...))
    return s
end


function do_client(mcts_iterations, game_id, player)
    sock = connect(4242)
    mem = Checkers.CheckersMem()

    # Join game
    cmd = Dict("command" => "join", "game_id" => game_id, "player" => player)
    write(sock, JSON.json(cmd) * "\n")

    while isopen(sock)
        resp = JSON.parse(readline(sock))
        @assert resp["result"] == "ok"

        if haskey(resp, "game_state")
            state = parse_json(resp["game_state"])
            println("\n", state)

            # Compute move
            if convert(Int, state.turn) == player
                move = Checkers.Move()
                move_arr = Array{Int, 2}(0, 2)
                while convert(Int, state.turn) == player
                    est_minimax, node = MCTS.mcts(state, mem, mcts_iterations)
                    move = get(MCTS.best_child(node, 0.0).move)
                    move_arr = [move_arr; [move.sx move.sy]]

                    state = Checkers.apply_move(state, move, mem)

                    @printf("Computer minimax estimate: %.3f\n", est_minimax)
                    println("Computer nodes: ", node.total_visits)
                    println("Computer move: ", move)
                end
                move_arr = [move_arr; [move.ex move.ey]]

                # Send move to server
                cmd = Dict("command" => "move", "game_id" => game_id, "player" => player, "move" => move_arr')
                write(sock, JSON.json(cmd) * "\n")

            end
        end
    end
end


end

GameClient.do_client(parse(Int, ARGS[1]), ARGS[2], parse(Int, ARGS[3]))
