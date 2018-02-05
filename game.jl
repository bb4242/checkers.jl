include("minimax.jl")

module Game

using MCTS
using Checkers


function play_game()
    state = State()

    computer_player = rand([p1turn, p2turn])
    println("Computer is ", computer_player)

    while !is_terminal(state)[1]
        println("It's the turn of ", state.turn)
        println(state.board)
        println()

        if state.turn == computer_player
            r, n = MCTS.mcts(state, 10000)
            state = MCTS.best_child(n, 0.0).board_state
            println("Computer minimax estimate: ", n.total_reward / n.total_visits)
        else
            moves = valid_moves(state)
            for i=1:length(moves)
                println(i, ". ", moves[i])
            end
            line = parse(Int, readline())
            state = apply_move(state, moves[line])

            # println("\nEnter your move like (1, 3): ")
            # input = map(x->parse(Int, x), split(readline(), ","))
            # move = Move(input[1], input[2])
            # state = apply_move(state, move)
        end
    end
    println("Game over, winner: ", is_terminal(state))
    println(state.board)
end


end

Game.play_game()
