module AutoGrowVectors

import Base: getindex, setindex!, size

export AutoGrowVector, shrink!, reset!

mutable struct AutoGrowVector{T} <: AbstractVector{T}
    _data::Vector{T}
    _constructor
    _viewable_size::Int64
end

AutoGrowVector{T}(constructor) where {T} = AutoGrowVector{T}(Vector{T}(), constructor, 0)
AutoGrowVector{T}() where {T} = AutoGrowVector{T}(T)

function getindex(v::AutoGrowVector, i::Int64)
    if i == v._viewable_size + 1
        v._viewable_size += 1
    end
    if i == length(v._data) + 1
        resize!(v._data, i)
        v._data[i] = v._constructor()
    end
    return v._data[i]
end

setindex!(v::AutoGrowVector, X, inds...) = setindex!(v._data, X, inds...)

size(v::AutoGrowVector) = (v._viewable_size, )

function reset!(v::AutoGrowVector)
    v._viewable_size = 0
end

function shrink!(v::AutoGrowVector, amount::Int = 1)
    if v._viewable_size >= amount
        v._viewable_size -= amount
    else
        error("Can't shrink by more than the size of the vector ($(v._viewable_size) < $amount)")
    end
end


module Test

using Base.Test
using AGV

mutable struct S
    x::Int
    y::Int
end

S() = S(0, 0)


function test()

    v = AutoGrowVector{S}()

    for i in 1:10
        s = v[end+1]
        s.x = i
        s.y = i^2
    end

    display(v)
    @test length(v) == 10
    @test v[4].x == 4

    shrink!(v)
    @test length(v) == 9
    shrink!(v, 2)
    @test length(v) == 7

    @test (@allocated v[end+1]) == 0

    reset!(v)
    @test length(v) == 0

    @test_throws ErrorException shrink!(v)


end

end

end
