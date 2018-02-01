module TTT

export State, Move, apply_move, valid_moves, is_terminal, p1turn, p2turn, q, X, O, nonterminal, p1wins, p2wins, tie

@enum TURN p1turn=1 p2turn=2
@enum BOARD q=0 X=1 O=2
@enum TERMINAL nonterminal=0 p1wins=1 p2wins=2 tie=3

struct State
    turn::TURN
    board::Array{BOARD, 2}
end

State() = State(p1turn, fill(q, 3, 3))

mutable struct Move
    x::Int8
    y::Int8
end

Move() = Move(-1, -1)

function apply_move(s::State, m::Move)
    @assert s.board[m.x, m.y] == q
    new_board = deepcopy(s.board)
    new_board[m.x, m.y] = s.turn == p1turn ? X : O
    new_turn = s.turn == p1turn ? p2turn : p1turn
    State(new_turn, new_board)
end

function valid_moves(s::State)
    nx, ny = size(s.board)
    moves::Array{Move, 1} = []
    for x=1:nx, y=1:ny
        if s.board[x, y] == q
            push!(moves, Move(x, y))
        end
    end
    moves
end

# Valid moves iterator
struct ValidMoves
    state::State
end

mutable struct _VMState
    sx::Int8
    xy::Int8
    mv::Move
end

Base.start(::ValidMoves) = _VMState(1, 1, Move())

function Base.next(vm::ValidMoves, vms::_VMState)
    nx, ny = size(vm.state.board)
    for x=vms.sx:nx, y=vms.sy:ny
        if vm.state.board[x, y] == q
            vms.mv.x = x
            vms.mv.y = y
            break
        end
    end
    vms.mv
end

function Base.done(vm::ValidMoves, vms::_VMState)
    vms.sx == nothing
end


##################


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
    if _check_array(s.board .== X) return true, 1.0 end
    if _check_array(s.board .== O) return true, 0.0 end
    if !any(s.board .== q) return true, 0.5 end
    return false, 0.0
end

end
