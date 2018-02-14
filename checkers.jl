module Checkers

using AutoHashEquals

export State, Move, apply_move, valid_moves, is_terminal, p1turn, p2turn

@enum TURN p1turn=1 p2turn=2
@enum BOARD white black White Black empty xxxxx

struct State
    turn::TURN
    moves_without_capture::Int8
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
    return State(p1turn, 0, board)
end

function Base.show(io::IO, board::Array{BOARD, 2})
    nx, ny = size(board)
    println()
    println("  1 2 3 4 5 6 7 8")
    for x=1:nx
        print(io, x)
        for y=1:ny
            elem = board[x, y]
            if (elem == white) print("|⛂")
            elseif (elem == black) print(io, "|⛀")
            elseif (elem == White) print(io, "|⛃")
            elseif (elem == Black) print(io, "|⛁")
            elseif (elem == empty) print(io, "|.")
            elseif (elem == xxxxx) print(io, "| ")
            end
        end
        println(io, "|", x)
    end
    println("  1 2 3 4 5 6 7 8")
end

@auto_hash_equals struct Move
    path::Array{Int8, 2}             # Path of the piece to move, including start and end board coordinates
    # Rows are the path index, columns are the x, y board coordinates
    isjump::Bool
end

Move() = Move(Array{Int8, 2}(0, 2), false)

function apply_move(s::State, m::Move)
    @assert length(m.path) >= 2
    new_board = deepcopy(s.board)         # TODO: no copies here, 87M
    new_moves_without_capture = s.moves_without_capture + 1

    # Update start and end points on the board
    sx, sy = m.path[1, :]
    ex, ey = m.path[end, :]
    player_piece = new_board[sx, sy]
    @assert player_piece in (s.turn == p1turn ? white_pieces : black_pieces)
    @assert s.board[ex, ey] == empty
    new_board[sx, sy] = empty

    # King promotion
    if s.turn == p1turn && 1 in m.path[:, 1]
        player_piece = White
    elseif s.turn == p2turn && 8 in m.path[:, 1]
        player_piece = Black
    end
    new_board[ex, ey] = player_piece

    # Clear any jumped pieces
    for i=2:size(m.path)[1]
        sx, sy = m.path[i-1, :]
        ex, ey = m.path[i, :]
        if abs(ex - sx) > 1
            tx, ty = div(sx+ex, 2), div(sy+ey, 2)
            @assert s.board[tx, ty] in (s.turn == p1turn ? [black, Black] : [white, White])
            new_board[tx, ty] = empty
            new_moves_without_capture = 0
        end
    end

    new_turn = s.turn == p1turn ? p2turn : p1turn
    return State(new_turn, new_moves_without_capture, new_board)     # TODO: no new creation here, 6M
end


mutable struct SPMove
    move::Move
    directions::Array{Int8, 2}
end

SPMove(x::Int8, y::Int8, isjump::Bool, directions::Array{Int8, 2}) = SPMove(Move([x y], isjump), directions)  # 136M

const white_pieces = [white, White]
const black_pieces = [black, Black]

const king_moves = Int8[-1 1; -1 -1; 1 1; 1 -1]
const white_moves = Int8[-1 1; -1 -1]
const black_moves = Int8[1 1; 1 -1]

function _get_move_directions(s::State, x::Int8, y::Int8)
    piece = s.board[x, y]
    @assert piece in (s.turn == p1turn ? white_pieces : black_pieces)

    if piece == white
        return white_moves
    elseif piece == White
        return king_moves
    elseif piece == black
        return black_moves
    elseif piece == Black
        return king_moves
    else
        @assert false
    end
end

_on_board(x::Int8, y::Int8) = x >= 1 && x <= 8 && y >= 1 && y <= 8

"Compute the valid Move paths for the piece at (x,y)"
function _moves_for_piece(s::State, x::Int8, y::Int8, short_circuit::Bool = false)
    my_pieces = (s.turn == p1turn ? white_pieces : black_pieces)
    enemy_pieces = (s.turn == p1turn ? black_pieces : white_pieces)

    @assert s.board[x, y] in my_pieces

    queue = Vector{SPMove}([SPMove(x, y, false, _get_move_directions(s, x, y))])   # TODO: replace with AGV
    available_moves = Vector{Move}()                                                 # TODO: replace with AGV
    found_jump = false   # Whether we've found a jump move anywhere yet

    while length(queue) > 0
        spmove = pop!(queue)
        jump_available = false   # Whether there is a jump available from this node

        # Get our current location
        loc = spmove.move.path[end, :]

        # Check the possible places we can move to
        for i=1:size(spmove.directions)[1]

            # Check for jumps first
            tx::Int8 = loc[1] + 2*spmove.directions[i, 1]
            ty::Int8 = loc[2] + 2*spmove.directions[i, 2]
            ix::Int8 = loc[1] + spmove.directions[i, 1]
            iy::Int8 = loc[2] + spmove.directions[i, 2]
            if _on_board(tx, ty) && s.board[tx, ty] == empty && s.board[ix, iy] in enemy_pieces
                # Make sure we haven't already visited this square during this move
                already_visited = false
                for j=1:size(spmove.move.path)[1]
                    if tx == spmove.move.path[j, 1] && ty == spmove.move.path[j, 2]
                        already_visited = true
                        break
                    end
                end
                if !already_visited
                    # Handle promotion to king
                    if (s.turn == p1turn && tx == 1) || (s.turn == p2turn && tx == 8)
                        spmove.directions = Int8[-1 1; -1 -1; 1 1; 1 -1]
                    end

                    # Continue searching for further jumps
                    push!(queue, SPMove(Move([spmove.move.path; Int8[tx ty]], true), spmove.directions))   # TODO: 32M
                    jump_available = true
                    found_jump = true
                end
            end
        end

        # Check for moving to empty space
        if !jump_available
            if spmove.move.isjump
                # If we're finishing a jump sequence, we're not allowed to move any further
                push!(available_moves, spmove.move)
                if short_circuit
                    return available_moves, found_jump
                end
            else
                # Otherwise, check for nonjump moves
                for i=1:size(spmove.directions)[1]
                    tx::Int8 = loc[1] + spmove.directions[i, 1]
                    ty::Int8 = loc[2] + spmove.directions[i, 2]
                    if _on_board(tx, ty) && s.board[tx, ty] == empty
                        push!(available_moves, Move([spmove.move.path; [tx ty]], false))    # TODO: 468M
                        if short_circuit
                           return available_moves, found_jump       # TODO: no tuple return, 6M
                        end
                    end
                end
            end
        end
    end

    return available_moves, found_jump     # TODO: 39M (maybe don't allocate a tuple?)
end


function valid_moves(s::State, short_circuit::Bool = false)
    my_pieces = (s.turn == p1turn ? white_pieces : black_pieces)
    all_moves = Vector{Move}()     # TODO: 33M

    nx, ny = size(s.board)
    found_jump = false
    for x::Int8=1:nx, y::Int8=1:ny
        if s.board[x, y] in my_pieces
            moves, _found_jump = _moves_for_piece(s, x, y, short_circuit)
            found_jump |= _found_jump
            if length(moves) > 0
                append!(all_moves, moves)          # TODO: 38M
                if short_circuit
                    return all_moves
                end
            end
        end
    end
    if found_jump
        return filter((move)->move.isjump, all_moves)    # TODO: don't use filter, 6M
    else
        return all_moves
    end
end


function is_terminal(s::State)
    n1 = Int8(0)
    n2 = Int8(0)
    for x in eachindex(s.board)
        if (s.board[x] == white || s.board[x] == White) n1 += 1 end
        if (s.board[x] == black || s.board[x] == Black) n2 += 1 end
    end
    if n1 == 0
        return true, 0.0
    elseif n2 == 0
        return true, 1.0
    else
        if length(valid_moves(s, true)) == 0
            if s.turn == p1turn
                return true, 0.0
            else
                return true, 1.0
            end
        elseif s.moves_without_capture > 100
            return true, 0.5
        else
            return false, 0.0
        end
    end
end



function test_game()
    s = State()
    moves = valid_moves(s)
    while length(moves) > 0
        println("==================================================")
        for i=1:length(moves)
            println(i, ". ", moves[i])
        end
        println("\n", s)
        line = parse(Int, readline())
        s = apply_move(s, moves[line])
        moves = valid_moves(s)
    end

end


b = fill(empty, 8, 8)
b[5, 4] = white
b[4, 5] = black
b[2, 5] = black
s = State(p1turn, 0, b)

#println("HI")
#println(_moves_for_piece(s, Int8(5), Int8(4)))
#println(s)

end


#Checkers.test_game()
