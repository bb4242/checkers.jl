include("ttt.jl")

module Minimax

using TTT
using Base.Test


function minimax(s::State)
    t, v = is_terminal(s)
    if t
        return v, Move()
    else

        mult = s.turn == p1turn ? 1.0 : -1.0
        bestval::Float64 = -Inf * mult
        bestmove = Move()
        for m=valid_moves(s)
            new_s = apply_move(s, m)
            val, _wm = minimax(new_s)
            if val*mult > bestval*mult
                bestval = val
                bestmove = m
            end
        end
        return bestval, bestmove
    end
end

function test()
    # Test code
    s = State(p1turn, [q q q; O X q; q q q])
    #s = State()

    r = minimax(s)
    println("\nRESULT ", r)
    #display(r[2].board)
    #@code_warntype minimax(s)

    println("PLAYING GAME")
    while !is_terminal(s)[1]
        val, m = minimax(s)
        println("\n", val, ": ", m)
        s = apply_move(s, m)
        display(s.board)
    end

    @test minimax(s)[1] == 1
    @test minimax(State())[1] == 0

    @time minimax(State())
end


end


module MCTS

using TTT
using Minimax

mutable struct MoveData
    move::Move
    n_tries::Int
end

MoveData(move::Move) = MoveData(move, 0)

mutable struct Node
    board_state::State

    parent::Nullable{Node}
    depth::Int

    total_reward::Float64
    total_visits::Int

    children::Vector{Node}
    available_moves::Vector{MoveData}
end

function Node(node::Node, move::Move)
    new_state = apply_move(node.board_state, move)
    new_available_moves = [MoveData(m) for m in valid_moves(new_state)]
    return Node(new_state, node, node.depth+1, 0.0, 0, Vector{Node}(), new_available_moves)
end

Node(state::State) = Node(state, nothing, 0, 0.0, 0, Vector{Node}(), [MoveData(m) for m in valid_moves(state)])

function tree_policy(node::Node)
    while !is_terminal(node.board_state)[1]
        if length(node.children) < length(node.available_moves)
            return expand(node)
        else
            node = best_child(node)
        end
    end
    return node
end

function expand(node::Node)
    # Select a move we haven't tried before
    untried = [m for m in node.available_moves if m.n_tries == 0]
    selected = rand(untried)
    selected.n_tries += 1

    # Make this move and add a node child node to n
    new_node = Node(node, selected.move)
    push!(node.children, new_node)

    return new_node
end

function best_child(node::Node, c::Float64 = 1.0)
    mult = node.board_state.turn == p1turn ? 1.0 : -1.0
    max_val = -Inf * mult
    max_child = node.children[1]
    for child in node.children
        val = child.total_reward / child.total_visits + mult * c * sqrt(2 * log(node.total_visits) / child.total_visits)
        if val*mult > max_val*mult
            max_val = val
            max_child = child
        end
    end
    return max_child
end

function default_policy(state::State)
    while !is_terminal(state)[1]
        move = rand(valid_moves(state))
        state = apply_move(state, move)
    end
    return is_terminal(state)[2]
end

function backup_negamax(node::Node, reward::Float64)
    nnode = Nullable(node)
    while !isnull(nnode)
        n = get(nnode)
        n.total_visits += 1
        n.total_reward += reward
        nnode = n.parent
    end
end

function mcts(state::State, n_iterations = 1)
    node = Node(state)
    for i=1:n_iterations
        working_node = tree_policy(node)
        reward = default_policy(working_node.board_state)
        backup_negamax(working_node, reward)
    end
    return node.total_reward / node.total_visits, node
end


function test()
    # b = [q X O;
    #      q q O;
    #      q q X]
    b = [O q O;
         q X q;
         q q X]
    s = State(p2turn, b)
#    s = State()
    r, n = mcts(s, 10000)

    display(b)
    println("MCTS Score: ", r)
    println("Minimax Score: ", Minimax.minimax(s))
    display(best_child(n, 0.0).board_state.board)
    println("DONE")

    return r, n
end

end


module Game

using TTT
using MCTS

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

#r, n = MCTS.test();

#r = MCTS.mcts(MCTS.s, 1000)




#MCTS.mcts(TTT.State(), 100000)


#Minimax.test()
