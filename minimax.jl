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




#Minimax.test()
