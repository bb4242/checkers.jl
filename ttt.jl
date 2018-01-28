module TTT

@enum TURN p1turn=1 p2turn=2
@enum BOARD e=0 X=1 O=2
@enum TERMINAL nonterminal=0 p1wins=1 p2wins=2 tie=3

struct State
    turn::TURN
    board::Array{BOARD, 2}
end

State() = State(p1turn, fill(e, 3, 3))

struct Move
    x::Int8
    y::Int8
end

Move() = Move(-1, -1)

function move(s::State, m::Move)
    @assert s.board[m.x, m.y] == e
    new_board = deepcopy(s.board)
    new_board[m.x, m.y] = s.turn == p1turn ? X : O
    new_turn = s.turn == p1turn ? p2turn : p1turn
    State(new_turn, new_board)
end

function valid_moves(s::State)
    nx, ny = size(s.board)
    moves::Array{Move, 1} = []
    for x=1:nx, y=1:ny
        if s.board[x, y] == e
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
    if _check_array(s.board .== X) return p1wins end
    if _check_array(s.board .== O) return p2wins end
    if !any(s.board .== e) return tie end
    return nonterminal
end


function minimax(s::State)
    t = is_terminal(s)
    if t == p1wins
        return 1.0, Move()
    elseif t == p2wins
        return -1.0, Move()
    elseif t == tie
        return 0.0, Move()
    else

        mult = s.turn == p1turn ? 1 : -1
        bestval::Float64 = -Inf * mult
        bestmove = Move()
        for m=valid_moves(s)
            new_s = move(s, m)
            val, _wm = minimax(new_s)
            if val*mult > bestval*mult
                bestval = val
                bestmove = m
            end
        end
        return bestval, bestmove
    end
end

# Test code
s = State(p1turn, [e e e; O X e; e e e])
#s = State()

r = minimax(s)
@time r = minimax(s)
println("\nRESULT ", r)
#display(r[2].board)
#@code_warntype minimax(s)

println("PLAYING GAME")
while is_terminal(s) == nonterminal
    val, m = minimax(s)
    println("\n", val, ": ", m)
    s = move(s, m)
    display(s.board)
end

end
