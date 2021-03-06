module TTT

export State, Move, apply_move, valid_moves, is_terminal, p1turn, p2turn, q, X, O

@enum TURN p1turn=1 p2turn=2
@enum BOARD q=0 X=1 O=2

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


function is_terminal(s::State)
    nx, ny = size(s.board)

    # Check horizontal wins
    tie = true
    for x=1:nx
        p1win = true
        p2win = true
        for y=1:ny
            elem = s.board[x, y]
            if (elem != X) p1win = false end
            if (elem != O) p2win = false end
            if (elem == q) tie = false end
        end
        if p1win return true, 1.0 end
        if p2win return true, 0.0 end
    end

    # Check vertical wins
    for y=1:nx
        p1win = true
        p2win = true
        for x=1:ny
            elem = s.board[x, y]
            if (elem != X) p1win = false end
            if (elem != O) p2win = false end
        end
        if p1win return true, 1.0 end
        if p2win return true, 0.0 end
    end

    # Check diagonal wins
    p1win = true
    p2win = true
    for x=1:nx
        elem = s.board[x, x]
        if (elem != X) p1win = false end
        if (elem != O) p2win = false end
    end
    if p1win return true, 1.0 end
    if p2win return true, 0.0 end

    p1win = true
    p2win = true
    for x=1:nx
        elem = s.board[x, nx+1-x]
        if (elem != X) p1win = false end
        if (elem != O) p2win = false end
    end
    if p1win return true, 1.0 end
    if p2win return true, 0.0 end

    if tie
        return true, 0.5
    else
        return false, 0.0
    end
end

end
