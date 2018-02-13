@everywhere include("mcts.jl")

module Game

using MCTS
using Checkers


function play_game(think_time)
    state = State()

    wc = MCTS.start_workers()

    computer_player = rand([p1turn, p2turn])
    println("Computer is ", computer_player)

    while !is_terminal(state)[1]
        println("\nTURN: ", state.turn)
        println(state)
        println()
        moves = valid_moves(state)
        selected_move = nothing

        if state.turn == computer_player
            if length(moves) > 1
                sleep(think_time)
            end
            selected_move, n_nodes, est_minimax = MCTS.get_best_move(wc)
            println("Computer minimax estimate: ", est_minimax)
            println("Computer nodes: ", n_nodes)
            println("Computer move: ", selected_move)

        else
            for i=1:length(moves)
                println(i, ". ", moves[i])
            end
                line = parse(Int, readline())
            selected_move = moves[line]
        end

        state = apply_move(state, selected_move)
        MCTS.do_apply_move(wc, selected_move)

    end
    println("Game over, winner: ", is_terminal(state))
    println(state.board)
end


end

Game.play_game(parse(Float64, ARGS[1]))
