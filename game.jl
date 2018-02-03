include("minimax.jl")

module Game

using MCTS
using TTT


function play_game()
    state = State()

    computer_player = rand([p1turn, p2turn])
    println("Computer is ", computer_player)

    while !is_terminal(state)[1]
        println("It's the turn of ", state.turn)
        display(state.board)
        println()

        if state.turn == computer_player
            r, n = MCTS.mcts(state, 100000)
            state = MCTS.best_child(n, 0.0).board_state
        else
            println("\nEnter your move like (1, 3): ")
            input = map(x->parse(Int, x), split(readline(), ","))
            move = Move(input[1], input[2])
            state = apply_move(state, move)
        end
    end
    println("Game over, winner: ", is_terminal(state))
    display(state.board)
end


end

Game.play_game()
