using Revise

include("checkers.jl")

module GameServer

using Checkers
using HttpServer
import JSON

function fibonacci(n)
  if n == 1 return 1 end
  if n == 2 return 1 end
  prev = BigInt(1)
  pprev = BigInt(1)
  for i=3:n
    curr = prev + pprev
    pprev = prev
    prev = curr
  end
  return prev
end

function to_json(s::State)

end

next_id = 1
game_states = Dict{Int, State}()

http = HttpHandler() do req::Request, res::Response
    global next_id
    global game_states
    println(req.resource)
    m = match(r"^/games/new/?$", req.resource)
    if m != nothing
        game_states[next_id] = State()
        next_id += 1
        return Response(string(next_id-1))
    end

    m = match(r"^/games/(\d+)/?$", req.resource)
    if m != nothing
        game_id = parse(Int, m.captures[1])
        return Response(200, Dict{AbstractString,AbstractString}([("Content-Type","application/json")]), JSON.json(game_states[game_id], 2))
    end



    #m = match(r"^/games/(\d+)/?$", req.resource)
    #if m == nothing return Response(404) end
    #println(m.captures)
    #number = parse(BigInt, m.captures[1])
    #if number < 1 || number > 100_000 return Response(500) end
    #return Response(string(fibonacci(number)))
end

http.events["error"]  = (client, err) -> println(err)
http.events["listen"] = (port)        -> println("Listening on $port...")

server = Server( http )
run( server, 8000 )





end
