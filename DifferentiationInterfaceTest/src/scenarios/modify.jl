abstract type FunctionModifier end

"""
    zero(scen::Scenario)

Return a new `Scenario` identical to `scen` except for the first- and second-order results which are set to zero.
"""
function Base.zero(scen::Scenario{op,pl_op,pl_fun}) where {op,pl_op,pl_fun}
    return Scenario{op,pl_op,pl_fun}(
        scen.f;
        x=scen.x,
        y=scen.y,
        tang=scen.tang,
        contexts=scen.contexts,
        res1=myzero(scen.res1),
        res2=myzero(scen.res2),
        smaller=isnothing(scen.smaller) ? nothing : zero(scen.smaller),
        name=isnothing(scen.name) ? nothing : scen.name * " [zero]",
    )
end

"""
    change_function(scen::Scenario, new_f)

Return a new `Scenario` identical to `scen` except for the function `f` which is changed to `new_f`.
"""
function change_function(
    scen::Scenario{op,pl_op,pl_fun}, new_f; keep_smaller
) where {op,pl_op,pl_fun}
    return Scenario{op,pl_op,pl_fun}(
        new_f;
        x=scen.x,
        y=scen.y,
        tang=scen.tang,
        contexts=scen.contexts,
        res1=scen.res1,
        res2=scen.res2,
        smaller=if isnothing(scen.smaller) || !keep_smaller
            nothing
        else
            change_function(scen.smaller, new_f; keep_smaller=false)
        end,
        name=isnothing(scen.name) ? nothing : scen.name * " [new function]",
    )
end

function set_smaller(
    scen::Scenario{op,pl_op,pl_fun}, smaller::Scenario
) where {op,pl_op,pl_fun}
    @assert scen.f == smaller.f
    return Scenario{op,pl_op,pl_fun}(
        scen.f;
        x=scen.x,
        y=scen.y,
        tang=scen.tang,
        contexts=scen.contexts,
        res1=scen.res1,
        res2=scen.res2,
        smaller=smaller,
    )
end

"""
    batchify(scen::Scenario)

Return a new `Scenario` identical to `scen` except for the tangents `tang` and associated results `res1` / `res2`, which are duplicated (batch mode).

Only works if `scen` is a `pushforward`, `pullback` or `hvp` scenario.
"""
function batchify(scen::Scenario{op,pl_op,pl_fun}) where {op,pl_op,pl_fun}
    (; f, x, y, tang, contexts, res1, res2, smaller) = scen
    if op == :pushforward || op == :pullback
        new_tang = (only(tang), -only(tang))
        new_res1 = (only(res1), -only(res1))
        return Scenario{op,pl_op,pl_fun}(
            f;
            x,
            y,
            tang=new_tang,
            contexts,
            res1=new_res1,
            res2,
            smaller=isnothing(smaller) ? nothing : batchify(smaller),
            name=isnothing(scen.name) ? nothing : scen.name * " [batchified]",
        )
    elseif op == :hvp
        new_tang = (only(tang), -only(tang))
        new_res2 = (only(res2), -only(res2))
        return Scenario{op,pl_op,pl_fun}(
            f;
            x,
            y,
            tang=new_tang,
            contexts,
            res1,
            res2=new_res2,
            smaller=isnothing(smaller) ? nothing : batchify(smaller),
            name=isnothing(scen.name) ? nothing : scen.name * " [batchified]",
        )
    end
end

struct WritableClosure{pl_fun,F,X,Y} <: FunctionModifier
    f::F
    x_buffer::Vector{X}
    y_buffer::Vector{Y}
end

function WritableClosure{pl_fun}(
    f::F, x_buffer::Vector{X}, y_buffer::Vector{Y}
) where {pl_fun,F,X,Y}
    return WritableClosure{pl_fun,F,X,Y}(f, x_buffer, y_buffer)
end

Base.show(io::IO, f::WritableClosure) = print(io, "WritableClosure($(f.f))")

function (mc::WritableClosure{:out})(x)
    mc.x_buffer[1] = x
    mc.y_buffer[1] = mc.f(x)
    return copy(mc.y_buffer[1])
end

function (mc::WritableClosure{:in})(y, x)
    mc.x_buffer[1] = x
    mc.f(mc.y_buffer[1], mc.x_buffer[1])
    copyto!(y, mc.y_buffer[1])
    return nothing
end

"""
    closurify(scen::Scenario)

Return a new `Scenario` identical to `scen` except for the function `f` which is made to close over differentiable data.
"""
function closurify(scen::Scenario)
    (; f, x, y) = scen
    @assert isempty(scen.contexts)
    x_buffer = [zero(x)]
    y_buffer = [zero(y)]
    closure_f = WritableClosure{function_place(scen)}(f, x_buffer, y_buffer)
    return change_function(scen, closure_f; keep_smaller=false)
end

struct MultiplyByConstant{pl_fun,F} <: FunctionModifier
    f::F
end

MultiplyByConstant{pl_fun}(f::F) where {pl_fun,F} = MultiplyByConstant{pl_fun,F}(f)

Base.show(io::IO, f::MultiplyByConstant) = print(io, "MultiplyByConstant($(f.f))")

function (mc::MultiplyByConstant{:out})(x, a)
    y = a * mc.f(x)
    return y
end

function (mc::MultiplyByConstant{:in})(y, x, a)
    mc.f(y, x)
    y .*= a
    return nothing
end

"""
    constantify(scen::Scenario)

Return a new `Scenario` identical to `scen` except for the function `f`, which is made to accept an additional constant argument by which the output is multiplied.
The output and result fields are updated accordingly.
"""
function constantify(scen::Scenario{op,pl_op,pl_fun}) where {op,pl_op,pl_fun}
    (; f,) = scen
    @assert isempty(scen.contexts)
    multiply_f = MultiplyByConstant{pl_fun}(f)
    a = 3.0
    return Scenario{op,pl_op,pl_fun}(
        multiply_f;
        x=scen.x,
        y=mymultiply(scen.y, a),
        tang=scen.tang,
        contexts=(Constant(a),),
        res1=mymultiply(scen.res1, a),
        res2=mymultiply(scen.res2, a),
        smaller=isnothing(scen.smaller) ? nothing : constantify(scen.smaller),
        name=isnothing(scen.name) ? nothing : scen.name * " [constantified]",
    )
end

struct StoreInCache{pl_fun,F} <: FunctionModifier
    f::F
end

function StoreInCache{pl_fun}(f::F) where {pl_fun,F}
    return StoreInCache{pl_fun,F}(f)
end

Base.show(io::IO, f::StoreInCache) = print(io, "StoreInCache($(f.f))")

(sc::StoreInCache{:out})(x, y_cache::NamedTuple) = sc(x, y_cache.useful_cache)
(sc::StoreInCache{:in})(y, x, y_cache::NamedTuple) = sc(y, x, y_cache.useful_cache)
(sc::StoreInCache{:out})(x, y_cache::Tuple) = sc(x, first(y_cache))
(sc::StoreInCache{:in})(y, x, y_cache::Tuple) = sc(y, x, first(y_cache))

function (sc::StoreInCache{:out})(x, y_cache)  # no annotation otherwise Zygote.Buffer cries
    y = sc.f(x)
    if y isa Number
        y_cache[1] = y
        return y_cache[1]
    else
        copyto!(y_cache, y)
        return copy(y_cache)
    end
end

function (sc::StoreInCache{:in})(y, x, y_cache)
    sc.f(y_cache, x)
    copyto!(y, y_cache)
    return nothing
end

"""
    cachify(scen::Scenario)

Return a new `Scenario` identical to `scen` except for the function `f`, which is made to accept an additional cache argument to store the result before it is returned.

If `tup=true` the cache is a tuple of arrays, otherwise just an array.
"""
function cachify(scen::Scenario{op,pl_op,pl_fun}; use_tuples) where {op,pl_op,pl_fun}
    (; f,) = scen
    @assert isempty(scen.contexts)
    cache_f = StoreInCache{pl_fun}(f)
    if use_tuples
        y_cache = if scen.y isa Number
            (; useful_cache=([myzero(scen.y)],), useless_cache=[myzero(scen.y)])
        else
            (; useful_cache=(mysimilar(scen.y),), useless_cache=mysimilar(scen.y))
        end
    else
        y_cache = if scen.y isa Number
            [myzero(scen.y)]
        else
            mysimilar(scen.y)
        end
    end
    return Scenario{op,pl_op,pl_fun}(
        cache_f;
        x=scen.x,
        y=scen.y,
        tang=scen.tang,
        contexts=(Cache(y_cache),),
        res1=scen.res1,
        res2=scen.res2,
        smaller=isnothing(scen.smaller) ? nothing : cachify(scen.smaller; use_tuples),
        name=isnothing(scen.name) ? nothing : scen.name * " [cachified]",
    )
end

struct MultiplyByConstantAndStoreInCache{pl_fun,F} <: FunctionModifier
    f::F
end

function MultiplyByConstantAndStoreInCache{pl_fun}(f::F) where {pl_fun,F}
    return MultiplyByConstantAndStoreInCache{pl_fun,F}(f)
end

function Base.show(io::IO, f::MultiplyByConstantAndStoreInCache)
    return print(io, "MultiplyByConstantAndStoreInCache($(f.f))")
end

function (sc::MultiplyByConstantAndStoreInCache{:out})(x, constantorcache)
    (; constant, cache) = constantorcache
    y = constant * sc.f(x)
    if eltype(y) == eltype(cache)
        newcache = cache
    else
        # poor man's PreallocationTools
        newcache = similar(cache, eltype(y))
    end
    if y isa Number
        newcache[1] = y
        return newcache[1]
    else
        copyto!(newcache, y)
        return copy(newcache)
    end
end

function (sc::MultiplyByConstantAndStoreInCache{:in})(y, x, constantorcache)
    (; constant, cache) = constantorcache
    if eltype(y) == eltype(cache)
        newcache = cache
    else
        # poor man's PreallocationTools
        newcache = similar(cache, eltype(y))
    end
    sc.f(newcache, x)
    newcache .*= constant
    copyto!(y, newcache)
    return nothing
end

"""
    constantorcachify(scen::Scenario)

Return a new `Scenario` identical to `scen` except for the function `f`, which is made to accept an additional "constant or cache" argument.
"""
function constantorcachify(scen::Scenario{op,pl_op,pl_fun}) where {op,pl_op,pl_fun}
    (; f,) = scen
    @assert isempty(scen.contexts)
    constantorcache_f = MultiplyByConstantAndStoreInCache{pl_fun}(f)
    a = 3.0
    constantorcache = if scen.y isa Number
        (; cache=[myzero(scen.y)], constant=a)
    else
        (; cache=mysimilar(scen.y), constant=a)
    end
    return Scenario{op,pl_op,pl_fun}(
        constantorcache_f;
        x=scen.x,
        y=mymultiply(scen.y, a),
        tang=scen.tang,
        contexts=(ConstantOrCache(constantorcache),),
        res1=mymultiply(scen.res1, a),
        res2=mymultiply(scen.res2, a),
        smaller=isnothing(scen.smaller) ? nothing : constantorcachify(scen.smaller),
        name=isnothing(scen.name) ? nothing : scen.name * " [constantorcachified]",
    )
end

## Group functions

function batchify(scens::AbstractVector{<:Scenario})
    batchifiable_scens = filter(s -> operator(s) in (:pushforward, :pullback, :hvp), scens)
    return batchify.(batchifiable_scens)
end

closurify(scens::AbstractVector{<:Scenario}) = closurify.(scens)
constantify(scens::AbstractVector{<:Scenario}) = constantify.(scens)
cachify(scens::AbstractVector{<:Scenario}; use_tuples) = cachify.(scens; use_tuples)
constantorcachify(scens::AbstractVector{<:Scenario}) = constantorcachify.(scens)
