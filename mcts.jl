include("checkers.jl")

module MCTS

using Checkers

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

function Node(node::Node, move::Move, mem)
    new_state = apply_move(node.board_state, move, mem)
    new_available_moves = [deepcopy(MoveData(m)) for m in valid_moves(new_state, mem)]
    return Node(new_state, node, move, node.depth+1, 0.0, 0, Vector{Node}(), new_available_moves)
end

Node(state::State, mem) = Node(state, nothing, nothing, 0, 0.0, 0, Vector{Node}(),
                               [deepcopy(MoveData(m)) for m in valid_moves(state, mem)])

function tree_policy(node::Node, mem)
    while !is_terminal(node.board_state, mem)[1]
        if length(node.children) < length(node.available_moves)
            return expand(node, mem)
        else
            node = best_child(node)
        end
    end
    return node
end

function expand(node::Node, mem)
    # Select a move we haven't tried before
    untried = [m for m in node.available_moves if m.n_tries == 0]
    selected = rand(untried)
    selected.n_tries += 1

    # Make this move and add a node child node to n
    new_node = Node(node, selected.move, mem)
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

function default_policy(state::State, mem)
    cur = deepcopy(state)
    nxt = State()
    tmp = State()

    while !is_terminal(cur, mem)[1]
        vm = valid_moves(cur, mem)
        if length(vm) == 0
            error("No moves for ", state)
        end
        move = rand(vm)
        apply_move!(nxt, cur, move, mem)
        tmp = cur
        cur = nxt
        nxt = tmp
    end
    return is_terminal(cur, mem)[2]
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
function single_mcts_pass(node::Node, mem)
    working_node = tree_policy(node, mem)
    reward = default_policy(working_node.board_state, mem)
    backup_negamax(working_node, reward)
end

function mcts(state::State, mem, n_iterations::Int = 1)
    node = Node(state, mem)
    for i=1:n_iterations
        single_mcts_pass(node, mem)
    end
    return node.total_reward / node.total_visits, node
end

function mcts(state::State, command_channel::RemoteChannel, response_channel::RemoteChannel)
    mem = Checkers.CheckersMem()
    node = Node(state, mem)
    paused = false
    check_time = time()

    while true
        if !paused
            single_mcts_pass(node, mem)
        else
            wait(command_channel)
        end

        if (time() - check_time) > 0.1 && isready(command_channel)
            cmd = take!(command_channel)
            check_time = time()

            if cmd[1] == :start_thinking
                node = Node(cmd[2])

            elseif cmd[1] == :apply_move
                response = (false, :notfound)
                for c in node.children
                    if get(c.move) == cmd[2]
                        # Move to the child node and garbage collect the unused part of the tree
                        node = c
                        node.parent = nothing
                        node.move = nothing
                        response = (true, node.board_state)
                        gc(true)
                        break
                    end
                end
                put!(response_channel, response)

            elseif cmd[1] == :get_current_stats
                stats = [MoveStats(get(c.move), c.total_visits, c.total_reward / c.total_visits) for c in node.children]
                total_visits = sum([c.total_visits for c in node.children])
                put!(response_channel, (true, WorkerStats(node.board_state, total_visits, stats)))

            elseif cmd[1] == :pause
                paused = true

            elseif cmd[1] == :unpause
                paused = false

            elseif cmd[1] == :quit
                return
            end
        end
    end
end


struct MoveStats
    move::Move
    total_visits::Int
    avg_reward::Float64
end

struct WorkerStats
    current_state::State
    total_visits::Int
    move_stats::Vector{MoveStats}
end

struct WorkerComm
    command_channels::Vector{RemoteChannel}
    response_channels::Vector{RemoteChannel}
end

function start_workers()
    cmds = Vector{RemoteChannel}()
    resps = Vector{RemoteChannel}()

    for p in workers()
        cmd = RemoteChannel(()->Channel(1))
        resp = RemoteChannel(()->Channel(1))
        remote_do(mcts, p, State(), cmd, resp)
        push!(cmds, cmd)
        push!(resps, resp)
    end

    return WorkerComm(cmds, resps)
end

function _send_all(wc::WorkerComm, cmd)
    for cc in wc.command_channels
        put!(cc, cmd)
    end
end

function _call(wc, cmd)
    _send_all(wc, cmd)
    results = []
    allok = true
    for resp in wc.response_channels
        ok, res = take!(resp)
        allok = allok && ok
        push!(results, res)
    end
    @assert allok
    return results
end

start_thinking(wc::WorkerComm, s::State) = _send_all(wc, (:start_thinking, s))
function do_apply_move(wc::WorkerComm, m::Move)
    _call(wc, (:apply_move, m))
    @everywhere gc(true)
end
get_stats(wc::WorkerComm) = _call(wc, (:get_current_stats,))

function get_best_move(wc)
    stats = get_stats(wc)

    # Pick the best move by majority voting based on most-visited nodes
    move_votes = Dict{Move, Int}()
    move_visits = Dict{Move, Int}()
    for stat in stats
        best_move_stats = sort(stat.move_stats, by=ms->ms.total_visits, rev=true)[1]
        bm = best_move_stats.move
        move_votes[bm] = get(move_votes, bm, 0) + 1
        move_visits[bm] = get(move_visits, bm, 0) + best_move_stats.total_visits
    end

    sorted_votes = sort(collect(move_votes), by=tuple->last(tuple), rev=true)
    selected_move = sorted_votes[1][1]
    if length(sorted_votes) > 1 && sorted_votes[1][2] == sorted_votes[2][2]
        # Break tie by visit count
        sorted_visits = sort(collect(move_visits), by=tuple->last(tuple), rev=true)
        selected_move = sorted_visits[1][1]
    end

    # Compute estimated minimax value and total visit count
    total_visits = sum([s.total_visits for s in stats])
    est_minimax = mean([m.avg_reward for s in stats for m in s.move_stats if m.move == selected_move])

    return selected_move, total_visits, est_minimax
end

pause_workers(wc::WorkerComm) = _send_all(wc, (:pause, ))
unpause_workers(wc::WorkerComm) = _send_all(wc, (:unpause, ))
stop_workers(wc::WorkerComm) = _send_all(wc, (:quit, ))


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


module Test

using BenchmarkTools, Compat
using MCTS

function test()
    s = MCTS.State()
    mem = MCTS.Checkers.CheckersMem()
    MCTS.mcts(s, mem, 1)

    srand(42)
    println(@benchmark MCTS.mcts($s, $mem, 3000))

    srand(42)
    Profile.clear_malloc_data()
    @time MCTS.mcts(s, mem, 3000);

    return
end

end

end


#r, n = MCTS.test();

#r = MCTS.mcts(MCTS.s, 1000)




#MCTS.mcts(TTT.State(), 100000)
