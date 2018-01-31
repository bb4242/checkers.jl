include("ttt.jl")

module Minimax

using TTT
using Base.Test


function minimax(s::State)
    t, v = is_terminal(s)
    if t
        return v, Move()
    else

        mult = s.turn == p1turn ? 1 : -1
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

mutable struct MoveData
    move::Move
    n_tries::UInt
end

MoveData(move::Move) = MoveData(move, 0)

mutable struct Node
    board_state::State

    parent::Nullable{Node}
    depth::Int

    total_reward::Float32
    total_visits::UInt

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
    untried_moves = [m.move for m in node.available_moves if m.n_tries == 0]
    selected_move = rand(untried_moves)

    # Make this move and add a node child node to n
    new_node = Node(node, selected_move)
    push!(node.children, new_node)

    return new_node
end

function best_child(node::Node)
    max_val = -Inf
    max_child = node.children[1]
    for child in node.children
        val = child.total_reward / child.total_visits + sqrt(2 * log(node.total_visits) / child.total_visits)
        if val > max_val
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
    while !isnull(node)
        node = get(node)
        node.total_visits += 1
        node.total_reward += reward
        reward *= -1
        node = node.parent
    end
end

function mcts(state::State, n_iterations = 100000)
    node = Node(state)
    for i=1:n_iterations
        working_node = tree_policy(node)
        reward = default_policy(working_node.board_state)
        backup_negamax(working_node, reward)
    end
    return node
end

end





#Minimax.test()
