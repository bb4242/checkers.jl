# Runs two players against each other and writes the results to a database
include("mcts.jl")


module GameGenerator

import SQLite
import Blosc
import JSON
import MCTS
import Checkers

struct Player
    mem::Checkers.CheckersMem
    mcts_iterations::Int
    # TODO: Add exploration temperature
    # TODO: Add neural network weights here
end

Player(mcts_iterations) = Player(Checkers.CheckersMem(), mcts_iterations)

struct Position
    board_state::Checkers.State
    mcts_probs::Vector{Float32}
    mcts_moves::Vector{Checkers.Move}
    mcts_score::Float32
end

struct Game
    player1::Player
    player2::Player
    positions::Vector{Position}
end


function compute_move(player::Player, state::Checkers.State)
    est_minimax, node = MCTS.mcts(state, player.mem, player.mcts_iterations)
    # TODO: Choose move according to probability dist and exploration temperature
    move = get(MCTS.best_child(node, 0.0).move)

    position = Position(deepcopy(state),
                        [c.total_visits / node.total_visits for c in node.children],
                        [get(c.move) for c in node.children],
                        est_minimax)
    return move, position
end

function open_db()
    db = SQLite.DB("games.sqlite")

    # Create tables if needed
    SQLite.execute!(db, """
CREATE TABLE IF NOT EXISTS games
 (id INTEGER PRIMARY KEY, player1_id INTEGER, player2_id INTEGER,
 outcome REAL NOT NULL, end_time TEXT NOT NULL);
""")
    SQLite.execute!(db, """
CREATE TABLE IF NOT EXISTS positions
 (id INTEGER PRIMARY KEY, game_id INTEGER, move_number INTEGER NOT NULL,
 board_state BLOB NOT NULL, mcts_moves BLOB NOT NULL, mcts_score REAL NOT NULL);
""")

    # Prepare statements
    position_insert_stmt = SQLite.Stmt(db, """
INSERT INTO positions (game_id, move_number, board_state, mcts_moves, mcts_score)
 VALUES (?, ?, ?, ?, ?)
""")
    game_insert_stmt = SQLite.Stmt(db, """
INSERT INTO games (outcome, end_time) VALUES (?, ?)
""")

    return db, position_insert_stmt, game_insert_stmt
end

#### Serialization routines

function execute_with_retry!(stmt)
    while true
        try
            SQLite.execute!(stmt)
            break
        catch exc
            if isa(exc, SQLite.SQLiteException) && contains(lowercase(exc.msg), "locked")
                println("\n\n\n*****************DB LOCKED; retrying..... **********************\n\n\n")
                sleep(rand())
            else
                throw(exc)
            end
        end
    end
end

function insert_position(insert_stmt, game_id, move_number, position)
    SQLite.bind!(insert_stmt, 1, game_id)
    SQLite.bind!(insert_stmt, 2, move_number)
    SQLite.bind!(insert_stmt, 3,
                 Blosc.compress(Checkers.NN.state_to_tensor(position.board_state), level=9))
    SQLite.bind!(insert_stmt, 4,
                 Blosc.compress(Checkers.NN.moves_to_tensor(position.mcts_probs, position.mcts_moves), level=9))
    SQLite.bind!(insert_stmt, 5, position.mcts_score)
    execute_with_retry!(insert_stmt)
end

function insert_game(db, game_stmt, pos_stmt, outcome, positions)
    SQLite.bind!(game_stmt, 1, outcome)
    SQLite.bind!(game_stmt, 2, JSON.json(now()))
    execute_with_retry!(game_stmt)
    game_id = get(SQLite.query(db, "SELECT last_insert_rowid()")[1][1])

    for position in enumerate(positions)
        insert_position(pos_stmt, game_id, position[1], position[2])
    end

end

function simulate_game(player1, player2)
    positions = Vector{Position}()

    s = Checkers.State()
    players = Dict(Checkers.p1turn => player1, Checkers.p2turn => player2)
    player = player1
    move = Checkers.Move()
    while !Checkers.is_terminal(s, player.mem)[1]
        println("\n", s)
        player = players[s.turn]
        move, position = compute_move(player, s)
        s = Checkers.apply_move(s, move, player.mem)
        push!(positions, position)
    end

    println("\nGame Over")
    println(s)
    outcome = Checkers.is_terminal(s, player.mem)[2]
    println("outcome: ", outcome)

    return positions, outcome
end


function generation_loop()
    db, pi, gi = open_db()
    while true
        positions, outcome = simulate_game(Player(3000), Player(3000))
        insert_game(db, gi, pi, outcome, positions)
    end
end


end
