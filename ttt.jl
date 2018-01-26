module TTT

@enum TURN p1turn=1 p2turn=2
@enum BOARD empty=0 player1=1 player2=2
@enum TERMINAL nonterminal=0 p1wins=1 p2wins=2 tie=3

struct State
    turn::TURN
    board::Array{BOARD, 2}
end

State() = State(p1turn, fill(empty, 3, 3))

struct Move
    x::Int8
    y::Int8
end

function move(s::State, m::Move)
    @assert s.board[m.x, m.y] == empty
    new_board = deepcopy(s.board)
    new_board[m.x, m.y] = s.turn == p1turn ? player1 : player2
    new_turn = s.turn == p1turn ? p2turn : p1turn
    State(new_turn, new_board)
end

function valid_moves(s::State)
    nx, ny = size(s.board)
    moves::Array{Move, 1} = []
    for x=1:nx, y=1:ny
        if s.board[x, y] == empty
            push!(moves, Move(x, y))
        end
    end
    moves
end

function _check_array(a::BitArray{2})
    nx, ny = size(a)
    for x=1:nx
        if all(a[x, :]) return true end
    end

    for y=1:ny
        if all(a[:, y]) return true end
    end

    if all(a[[CartesianIndex(i, i) for i=1:nx]]) return true end
    if all(a[[CartesianIndex(i, nx+1-i) for i=1:nx]]) return true end

    return false
end

function is_terminal(s::State)
    if _check_array(s.board .== player1) return p1wins end
    if _check_array(s.board .== player2) return p2wins end
    if !any(s.board .== empty) return tie end
    return nonterminal
end


function minimax(s::State)
    t = is_terminal(s)
    if t == p1wins
        return 1.0, Array{Move, 1}()
    elseif t == p2wins
        return -1.0, Array{Move, 1}()
    elseif t == tie
        return 0.0, Array{Move, 1}()
    else

        bestval::Float64 = -Inf
        winpath = Array{Move, 1}()
        mult = s.turn == p1turn ? 1 : -1
        for m=valid_moves(s)
            new_s = move(s, m)
            val, winpath = minimax(new_s)
            if val*mult > bestval
                bestval = val
                push!(winpath, m)
            end
        end

        return bestval, winpath
    end
end

# Test code
s = State(p1turn, [player1 player1 empty; empty empty player2; empty player2 empty])
println(minimax(s))
#@code_warntype minimax(s)

end
