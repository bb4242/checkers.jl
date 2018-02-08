include("ttt.jl")
include("checkers.jl")

module Minimax

using Checkers
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

# function test()
#     # Test code
#     s = State(p1turn, [q q q; O X q; q q q])
#     #s = State()

#     r = minimax(s)
#     println("\nRESULT ", r)
#     #display(r[2].board)
#     #@code_warntype minimax(s)

#     println("PLAYING GAME")
#     while !is_terminal(s)[1]
#         val, m = minimax(s)
#         println("\n", val, ": ", m)
#         s = apply_move(s, m)
#         display(s.board)
#     end

#     @test minimax(s)[1] == 1
#     @test minimax(State())[1] == 0

#     @time minimax(State())
# end


end


module MCTS

using Checkers
using Minimax

mutable struct MoveData
    move::Move
    n_tries::Int
end

MoveData(move::Move) = MoveData(move, 0)

mutable struct Node
    board_state::State

    parent::Nullable{Node}
    move::Nullable{Move}     # The move used to arrive at this state
    depth::Int

    total_reward::Float64
    total_visits::Int

    children::Vector{Node}
    available_moves::Vector{MoveData}
end

function Node(node::Node, move::Move)
    new_state = apply_move(node.board_state, move)
    new_available_moves = [MoveData(m) for m in valid_moves(new_state)]
    return Node(new_state, node, move, node.depth+1, 0.0, 0, Vector{Node}(), new_available_moves)
end

Node(state::State) = Node(state, nothing, nothing, 0, 0.0, 0, Vector{Node}(), [MoveData(m) for m in valid_moves(state)])

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
        vm = valid_moves(state)
        if length(vm) == 0
            println("0 moves for ", state)
        end
        move = rand(vm)
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

"Update node by running a single MCTS pass"
function single_mcts_pass(node::Node)
    working_node = tree_policy(node)
    reward = default_policy(working_node.board_state)
    backup_negamax(working_node, reward)
end

function mcts(state::State, n_iterations = 1, command_channel = nothing, response_channel = nothing)
    node = Node(state)

    if command_channel == nothing
        for i=1:n_iterations
            single_mcts_pass(node)
        end
        return node.total_reward / node.total_visits, node

    else
        while true
            if isready(command_channel)
                cmd = take!(command_channel)

                if cmd[1] == :start_thinking
                    node = Node(cmd[2])

                elseif cmd[1] == :apply_move
                    response = (:error, :notfound)
                    for c in node.children
                        if c.move == cmd[2]
                            # Move to the child node and garbage collect the unused part of the tree
                            node = c
                            node.parent = nothing
                            node.move = nothing
                            response = (:ok, node.board_state)
                            break
                        end
                    end
                    put!(response_channel, response)

                elseif cmd[1] == :get_current_stats
                    stats = [(c.total_visits, c.total_reward / c.total_visits, c.move) for c in node.children]
                    put!(response_channel, (:ok, stats))
                end
            end

            single_mcts_pass(node)
        end
    end

end


# function test()
#     # b = [q X O;
#     #      q q O;
#     #      q q X]
#     b = [O q O;
#          q X q;
#          q q X]
#     s = State(p2turn, b)
# #    s = State()
#     r, n = mcts(s, 10000)

#     display(b)
#     println("MCTS Score: ", r)
#     println("Minimax Score: ", Minimax.minimax(s))
#     display(best_child(n, 0.0).board_state.board)
#     println("DONE")

#     return r, n
# end

end



#r, n = MCTS.test();

#r = MCTS.mcts(MCTS.s, 1000)




#MCTS.mcts(TTT.State(), 100000)


#Minimax.test()
