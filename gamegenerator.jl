# Runs two players against each other and writes the results to a database
include("mcts.jl")


module GameGenerator

using SQLite
using JSON
using MCTS
using Checkers

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
                        [get(c.move) for c in node.children])
    return move, position
end

function open_db()
    db = SQLite.DB("games.sqlite")

    # Create tables if needed
    SQLite.execute!(db, """
CREATE TABLE IF NOT EXISTS games
 (id INTEGER PRIMARY KEY, player1_id INTEGER, player2_id INTEGER,
 outcome REAL NOT NULL, start_time TEXT NOT NULL);
""")
    SQLite.execute!(db, """
CREATE TABLE IF NOT EXISTS positions
 (id INTEGER PRIMARY KEY, game_id INTEGER, move_number INTEGER NOT NULL,
 board_state TEXT NOT NULL, mcts_probs TEXT NOT NULL);
""")

    # Prepare statements
    insert_stmt = SQLite.Stmt(db, """
INSERT INTO positions (game_id, move_number, board_state, mcts_probs)
 VALUES (?, ?, ?, ?)
""")

    return db, insert_stmt
end

function insert_position(insert_stmt, game_id, move_number, position)
    board_state = JSON.json(position.board_state)
    mcts_probs = JSON.json([
        [c.total_visits / node.total_visits for c in node.children],
        [get(c.move) for c in node.children]
    ])

    SQLite.bind!(insert_stmt, 1, game_id)
    SQLite.bind!(insert_stmt, 2, move_number)
    SQLite.bind!(insert_stmt, 3, board_state)
    SQLite.bind!(insert_stmt, 4, mcts_probs)

    SQLite.execute!(insert_stmt)
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
    println(Checkers.is_terminal(s, player.mem))

    return positions
end

#simulate_game(Player(10000), Player(10000))

end
