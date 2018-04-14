include("autogrowvectors.jl")

module Checkers

using AutoHashEquals
using AutoGrowVectors

import Base: copy!, show

export State, Move, apply_move, apply_move!, valid_moves, is_terminal, p1turn, p2turn

@enum TURN p1turn=1 p2turn=2
@enum BOARD white black White Black empty xxxxx

const white_pieces = [white, White]
const black_pieces = [black, Black]

const king_moves = Int8[-1 1; -1 -1; 1 1; 1 -1]
const white_moves = Int8[-1 1; -1 -1]
const black_moves = Int8[1 1; 1 -1]


mutable struct State
    turn::TURN
    moves_without_capture::Int8
    must_move_x::Int8
    must_move_y::Int8
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
    return State(p1turn, 0, 0, 0, board)
end

function show(io::IO, state::State)
    state.turn == p1turn ? println("Player 1's turn") : println("Player 2's turn")
    println("Moves without capture: $(state.moves_without_capture)")
    if state.must_move_x > 0
        println("Must move ($(state.must_move_x), $(state.must_move_y))")
    end
    show(state.board)
end

function show(io::IO, board::Array{BOARD, 2})
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

@auto_hash_equals mutable struct Move
    # Start position x and y coordinates
    sx::Int8
    sy::Int8

    # End position x and y coordinates
    ex::Int8
    ey::Int8
end

Move() = Move(0, 0, 0, 0)

function copy!(dest::Move, src::Move)
    dest.sx = src.sx
    dest.sy = src.sy
    dest.ex = src.ex
    dest.ey = src.ey
    return dest
end

function show(io::IO, move::Move)
    print(io, "($(move.sx), $(move.sy)) ➔ ($(move.ex), $(move.ey))")
end


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

"All memory used by checkers functions should be contained within this object"
struct CheckersMem
    jump_moves::AutoGrowVector{Move}
    nonjump_moves::AutoGrowVector{Move}
end

CheckersMem() = CheckersMem(AutoGrowVector{Move}(), AutoGrowVector{Move}())


"Applies the move m to the state src, and puts the result into dest"
function apply_move!(dest::State, src::State, m::Move, mem::CheckersMem)
    copy!(dest.board, src.board)
    dest.moves_without_capture = src.moves_without_capture + 1
    dest.turn = src.turn == p1turn ? p2turn : p1turn
    dest.must_move_x = 0
    dest.must_move_y = 0

    # Update start and end points on the board
    player_piece = dest.board[m.sx, m.sy]
    @assert player_piece in (src.turn == p1turn ? white_pieces : black_pieces)
    @assert src.board[m.ex, m.ey] == empty
    dest.board[m.sx, m.sy] = empty

    # Check if this is a jump continuation
    if src.must_move_x > 0
        @assert m.sx == src.must_move_x && m.sy == src.must_move_y
    end

    # King promotion
    if src.turn == p1turn && m.ex == 1
        player_piece = White
    elseif src.turn == p2turn && m.ex == 8
        player_piece = Black
    end
    dest.board[m.ex, m.ey] = player_piece

    # Clear jumped pieces
    if abs(m.ex - m.sx) > 1
        tx::Int8 = div(m.sx+m.ex, 2)
        ty::Int8 = div(m.sy+m.ey, 2)
        @assert src.board[tx, ty] in (src.turn == p1turn ? black_pieces : white_pieces)
        dest.board[tx, ty] = empty
        dest.moves_without_capture = 0

        # Check to see whether we have a continuation jump
        dest.turn = src.turn
        dest.must_move_x = m.ex
        dest.must_move_y = m.ey
        reset!(mem.nonjump_moves)
        reset!(mem.jump_moves)
        _moves_for_piece!(dest, m.ex, m.ey, mem)
        if length(mem.jump_moves) == 0
            dest.turn = src.turn == p1turn ? p2turn : p1turn
            dest.must_move_x = 0
            dest.must_move_y = 0
        end
    end
end

"Applies the move m to the state s, and returns a newly-allocated state"
function apply_move(s::State, m::Move, mem::CheckersMem)
    dest = State(p1turn, 0, 0, 0, similar(s.board))
    apply_move!(dest, s, m, mem)
    return dest
end

_on_board(x::Int8, y::Int8) = x >= 1 && x <= 8 && y >= 1 && y <= 8

"Compute the valid Move paths for the piece at (x,y), and append them to mem"
function _moves_for_piece!(s::State, x::Int8, y::Int8, mem::CheckersMem)
    my_pieces = (s.turn == p1turn ? white_pieces : black_pieces)
    enemy_pieces = (s.turn == p1turn ? black_pieces : white_pieces)

    @assert s.board[x, y] in my_pieces

    directions = _get_move_directions(s, x, y)

    # Check the possible places we can move to
    for i in 1:size(directions)[1]

        # Check for jumps
        tx::Int8 = x + 2*directions[i, 1]
        ty::Int8 = y + 2*directions[i, 2]
        ix::Int8 = x + directions[i, 1]
        iy::Int8 = y + directions[i, 2]
        if _on_board(tx, ty) && s.board[tx, ty] == empty && s.board[ix, iy] in enemy_pieces
            m = mem.jump_moves[end+1]
            m.sx = x
            m.sy = y
            m.ex = tx
            m.ey = ty
        end

        # Check for non-jumps
        tx = x + directions[i, 1]
        ty = y + directions[i, 2]
        if _on_board(tx, ty) && s.board[tx, ty] == empty
            m = mem.nonjump_moves[end+1]
            m.sx = x
            m.sy = y
            m.ex = tx
            m.ey = ty
        end
    end

    return
end


function valid_moves(s::State, mem::CheckersMem, short_circuit::Bool = false)
    my_pieces = (s.turn == p1turn ? white_pieces : black_pieces)

    reset!(mem.jump_moves)
    reset!(mem.nonjump_moves)

    nx, ny = size(s.board)
    found_jump = false
    for x::Int8=1:nx, y::Int8=1:ny
        if s.must_move_x != 0 && (x != s.must_move_x || y != s.must_move_y)
            continue
        end
        if s.board[x, y] in my_pieces
            _moves_for_piece!(s, x, y, mem)
            (length(mem.jump_moves) > 0 || length(mem.nonjump_moves) > 0) && short_circuit && break
        end
    end

    if length(mem.jump_moves) > 0
        return mem.jump_moves
    else
        return mem.nonjump_moves
    end
end


function is_terminal(s::State, mem::CheckersMem)
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
        if length(valid_moves(s, mem, true)) == 0
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




module Test

using Base.Test
using Checkers
using AutoGrowVectors

function test()
    s = State()
    mem = Checkers.CheckersMem()
    Checkers._moves_for_piece(s, Int8(6), Int8(3), mem)
    @test length(mem.nonjump_moves) == 2
    @test length(mem.jump_moves) == 0

    s.board[5, 4] = Checkers.black
    reset!(mem.jump_moves)
    reset!(mem.nonjump_moves)
    Checkers._moves_for_piece(s, Int8(6), Int8(3), mem)
    @test length(mem.jump_moves) == 1
    @test length(mem.nonjump_moves) == 0

    s.board[5, 2] = Checkers.black
    @test length(Checkers.valid_moves(s, mem)) == 4

end


function test_game()
    s = State()
    mem = Checkers.CheckersMem()
    moves = valid_moves(s, mem)
    while length(moves) > 0
        println("==================================================")
        for i=1:length(moves)
            println(i, ". ", moves[i])
        end
        println("\n", s)
        line = parse(Int, readline())
        s = apply_move(s, moves[line], mem)
        moves = valid_moves(s, mem)
    end

end


b = fill(Checkers.empty, 8, 8)
b[5, 4] = Checkers.white
b[4, 5] = Checkers.black
b[2, 5] = Checkers.black
s = State(p1turn, 0, 0, 0, b)

#println("HI")
#println(_moves_for_piece(s, Int8(5), Int8(4)))
#println(s)

end


module NN

using Checkers
using Knet

function state_to_tensor(s::State)
    tensor = zeros(UInt8, 8, 4, 8)

    # Populate board in the first five layers
    for i in 1:8, j in 1:8
        slot = s.board[i, j]
        if slot == Checkers.xxxxx
            continue
        end
        tensor[i, div(j + 1, 2), Int8(slot) + 1] = 1
    end

    # Populate turn
    tensor[:, :, 6] =  s.turn == Checkers.p1turn ? 1 : 0

    # Populate must move slot
    if s.must_move_x > 0
        tensor[s.must_move_x, div(s.must_move_y + 1, 2), 7] = 1
    end

    # Populate turns without capture layer
    tensor[:, :, 8] = s.moves_without_capture

    return tensor
end

function state_from_tensor(tensor::Array{Float64, 2})

end

function moves_to_tensor(mcts_probs::Vector{T}, mcts_moves::Vector{Move}) where T <: Real
    tensor = zeros(Float16, 8, 4, 4)
    for mi in 1:length(mcts_moves)
        move = mcts_moves[mi]
        prob = mcts_probs[mi]
        delta_x = move.ex - move.sx > 0 ? 1 : 0
        delta_y = move.ey - move.sy > 0 ? 1 : 0
        di = 2 * delta_y + delta_x + 1
        tensor[move.sx, div(move.sy + 1, 2), di] = prob
    end
    return tensor
end

function moves_from_tensor(tensor)

end

# Segmentation-like model in Knet
function predict(w, x0)
    x1 = pool(relu.(conv4(w[1], x0, padding=1) .+ w[2]))
    x2 = pool(relu.(conv4(w[3], x0, padding=1) .+ w[4]))
end


end


end

#Checkers.test_game()
