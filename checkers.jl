module Checkers

export State, Move, apply_move, valid_moves, is_terminal, p1turn, p2turn

@enum TURN p1turn=1 p2turn=2
@enum BOARD white black White Black empty xxxxx

struct State
    turn::TURN
    board::Array{BOARD, 2}
end

function State()
    board = Array{BOARD, 2}(8, 8)
    for x=1:8, y=1:8
        if mod(x+y, 2) == 0
            board[x, y] = xxxxx
        elseif x <= 3
            board[x, y] = black
        elseif x >= 6
            board[x, y] = white
        else
            board[x, y] = empty
        end
    end
    return State(p1turn, board)
end

function Base.show(io::IO, board::Array{BOARD, 2})
    nx, ny = size(board)
    println()
    for x=1:nx
        for y=1:ny
            elem = board[x, y]
            if (elem == white) print("|w")
            elseif (elem == black) print(io, "|b")
            elseif (elem == White) print(io, "|W")
            elseif (elem == Black) print(io, "|B")
            elseif (elem == empty) print(io, "|.")
            elseif (elem == xxxxx) print(io, "| ")
            end
        end
        println(io, "|")
    end
end

mutable struct Move
    path::Vector{Tuple{Int8, Int8}}  # Path of the piece to move, including start and end board coordinates
end

function apply_move(s::State, m::Move)
    @assert length(m.path) >= 2
    new_board = deepcopy(s.board)

    # Update start and end points on the board
    sx, sy = m.path[1]
    ex, ey = m.path[end]
    player_piece = new_board[sx, sy]
    @assert player_piece in (s.turn == p1turn ? [white, White] : [black, Black])
    @assert s.board[ex, ey] == empty
    new_board[sx, sy] = empty
    new_board[ex, ey] = player_piece

    # Clear any jumped pieces
    for i=2:length(m.path)
        sx, sy = m.path[i-1]
        ex, ey = m.path[i]
        if abs(ex - sx) > 1
            tx, ty = div(sx+ex, 2), div(sy+ey, 2)
            @assert s.board[tx, ty] in (s.turn == p1turn ? [black, Black] : [white, White])
            new_board[tx, ty] = empty
        end
    end

    new_turn = s.turn == p1turn ? p2turn : p1turn
    return State(new_turn, new_board)
end

function valid_moves(s::State)

end


end
