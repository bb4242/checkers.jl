# Runs two players against each other and writes the results to a database

module GameGenerator

using SQLite
using JSON

function create_db()
    # Create database
    db = SQLite.DB("games.sqlite")
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

function insert_position(insert_stmt, game_id, move_number, node)
    board_state = JSON.json(node.board_state)
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

end
