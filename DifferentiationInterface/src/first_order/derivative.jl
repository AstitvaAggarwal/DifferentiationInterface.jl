## Docstrings

"""
    prepare_derivative(f,     backend, x, [contexts...]; strict=Val(true)) -> prep
    prepare_derivative(f!, y, backend, x, [contexts...]; strict=Val(true)) -> prep

$(docstring_prepare("derivative"; inplace=true))
"""
function prepare_derivative(
    f::F, backend::AbstractADType, x, contexts::Vararg{Context,C}; strict::Val=Val(true)
) where {F,C}
    return prepare_derivative_nokwarg(strict, f, backend, x, contexts...)
end

function prepare_derivative(
    f!::F, y, backend::AbstractADType, x, contexts::Vararg{Context,C}; strict::Val=Val(true)
) where {F,C}
    return prepare_derivative_nokwarg(strict, f!, y, backend, x, contexts...)
end

"""
    prepare!_derivative(f,     prep, backend, x, [contexts...]) -> new_prep
    prepare!_derivative(f!, y, prep, backend, x, [contexts...]) -> new_prep

$(docstring_prepare!("derivative"))
"""
function prepare!_derivative(
    f::F, old_prep::DerivativePrep, backend::AbstractADType, x, contexts::Vararg{Context,C};
) where {F,C}
    check_prep(f, old_prep, backend, x, contexts...)
    return prepare_derivative_nokwarg(is_strict(old_prep), f, backend, x, contexts...)
end

function prepare!_derivative(
    f!::F,
    y,
    old_prep::DerivativePrep,
    backend::AbstractADType,
    x,
    contexts::Vararg{Context,C},
) where {F,C}
    check_prep(f!, y, old_prep, backend, x, contexts...)
    return prepare_derivative_nokwarg(is_strict(old_prep), f!, y, backend, x, contexts...)
end

"""
    value_and_derivative(f,     [prep,] backend, x, [contexts...]) -> (y, der)
    value_and_derivative(f!, y, [prep,] backend, x, [contexts...]) -> (y, der)

Compute the value and the derivative of the function `f` at point `x`.

$(docstring_preparation_hint("derivative"))
"""
function value_and_derivative(
    f::F, backend::AbstractADType, x, contexts::Vararg{Context,C}
) where {F,C}
    prep = prepare_derivative_nokwarg(Val(true), f, backend, x, contexts...)
    return value_and_derivative(f, prep, backend, x, contexts...)
end

function value_and_derivative(
    f!::F, y, backend::AbstractADType, x, contexts::Vararg{Context,C}
) where {F,C}
    prep = prepare_derivative_nokwarg(Val(true), f!, y, backend, x, contexts...)
    return value_and_derivative(f!, y, prep, backend, x, contexts...)
end

"""
    value_and_derivative!(f,     der, [prep,] backend, x, [contexts...]) -> (y, der)
    value_and_derivative!(f!, y, der, [prep,] backend, x, [contexts...]) -> (y, der)

Compute the value and the derivative of the function `f` at point `x`, overwriting `der`.

$(docstring_preparation_hint("derivative"))
"""
function value_and_derivative!(
    f::F, der, backend::AbstractADType, x, contexts::Vararg{Context,C}
) where {F,C}
    prep = prepare_derivative_nokwarg(Val(true), f, backend, x, contexts...)
    return value_and_derivative!(f, der, prep, backend, x, contexts...)
end

function value_and_derivative!(
    f!::F, y, der, backend::AbstractADType, x, contexts::Vararg{Context,C}
) where {F,C}
    prep = prepare_derivative_nokwarg(Val(true), f!, y, backend, x, contexts...)
    return value_and_derivative!(f!, y, der, prep, backend, x, contexts...)
end

"""
    derivative(f,     [prep,] backend, x, [contexts...]) -> der
    derivative(f!, y, [prep,] backend, x, [contexts...]) -> der

Compute the derivative of the function `f` at point `x`.

$(docstring_preparation_hint("derivative"))
"""
function derivative(
    f::F, backend::AbstractADType, x, contexts::Vararg{Context,C}
) where {F,C}
    prep = prepare_derivative_nokwarg(Val(true), f, backend, x, contexts...)
    return derivative(f, prep, backend, x, contexts...)
end

function derivative(
    f!::F, y, backend::AbstractADType, x, contexts::Vararg{Context,C}
) where {F,C}
    prep = prepare_derivative_nokwarg(Val(true), f!, y, backend, x, contexts...)
    return derivative(f!, y, prep, backend, x, contexts...)
end

"""
    derivative!(f,     der, [prep,] backend, x, [contexts...]) -> der
    derivative!(f!, y, der, [prep,] backend, x, [contexts...]) -> der

Compute the derivative of the function `f` at point `x`, overwriting `der`.

$(docstring_preparation_hint("derivative"))
"""
function derivative!(
    f::F, der, backend::AbstractADType, x, contexts::Vararg{Context,C}
) where {F,C}
    prep = prepare_derivative_nokwarg(Val(true), f, backend, x, contexts...)
    return derivative!(f, der, prep, backend, x, contexts...)
end

function derivative!(
    f!::F, y, der, backend::AbstractADType, x, contexts::Vararg{Context,C}
) where {F,C}
    prep = prepare_derivative_nokwarg(Val(true), f!, y, backend, x, contexts...)
    return derivative!(f!, y, der, prep, backend, x, contexts...)
end

## Preparation

struct PushforwardDerivativePrep{SIG,E<:PushforwardPrep} <: DerivativePrep{SIG}
    _sig::Val{SIG}
    pushforward_prep::E
end

function prepare_derivative_nokwarg(
    strict::Val, f::F, backend::AbstractADType, x, contexts::Vararg{Context,C}
) where {F,C}
    _sig = signature(f, backend, x, contexts...; strict)
    pushforward_prep = prepare_pushforward_nokwarg(
        strict, f, backend, x, (one(x),), contexts...
    )
    return PushforwardDerivativePrep(_sig, pushforward_prep)
end

function prepare_derivative_nokwarg(
    strict::Val, f!::F, y, backend::AbstractADType, x, contexts::Vararg{Context,C};
) where {F,C}
    _sig = signature(f!, y, backend, x, contexts...; strict)
    pushforward_prep = prepare_pushforward_nokwarg(
        strict, f!, y, backend, x, (one(x),), contexts...
    )
    return PushforwardDerivativePrep(_sig, pushforward_prep)
end

## One argument

function value_and_derivative(
    f::F,
    prep::PushforwardDerivativePrep,
    backend::AbstractADType,
    x,
    contexts::Vararg{Context,C},
) where {F,C}
    check_prep(f, prep, backend, x, contexts...)
    y, ty = value_and_pushforward(
        f, prep.pushforward_prep, backend, x, (one(x),), contexts...
    )
    return y, only(ty)
end

function value_and_derivative!(
    f::F,
    der,
    prep::PushforwardDerivativePrep,
    backend::AbstractADType,
    x,
    contexts::Vararg{Context,C},
) where {F,C}
    check_prep(f, prep, backend, x, contexts...)
    y, _ = value_and_pushforward!(
        f, (der,), prep.pushforward_prep, backend, x, (one(x),), contexts...
    )
    return y, der
end

function derivative(
    f::F,
    prep::PushforwardDerivativePrep,
    backend::AbstractADType,
    x,
    contexts::Vararg{Context,C},
) where {F,C}
    check_prep(f, prep, backend, x, contexts...)
    ty = pushforward(f, prep.pushforward_prep, backend, x, (one(x),), contexts...)
    return only(ty)
end

function derivative!(
    f::F,
    der,
    prep::PushforwardDerivativePrep,
    backend::AbstractADType,
    x,
    contexts::Vararg{Context,C},
) where {F,C}
    check_prep(f, prep, backend, x, contexts...)
    pushforward!(f, (der,), prep.pushforward_prep, backend, x, (one(x),), contexts...)
    return der
end

## Two arguments

function value_and_derivative(
    f!::F,
    y,
    prep::PushforwardDerivativePrep,
    backend::AbstractADType,
    x,
    contexts::Vararg{Context,C},
) where {F,C}
    check_prep(f!, y, prep, backend, x, contexts...)
    y, ty = value_and_pushforward(
        f!, y, prep.pushforward_prep, backend, x, (one(x),), contexts...
    )
    return y, only(ty)
end

function value_and_derivative!(
    f!::F,
    y,
    der,
    prep::PushforwardDerivativePrep,
    backend::AbstractADType,
    x,
    contexts::Vararg{Context,C},
) where {F,C}
    check_prep(f!, y, prep, backend, x, contexts...)
    y, _ = value_and_pushforward!(
        f!, y, (der,), prep.pushforward_prep, backend, x, (one(x),), contexts...
    )
    return y, der
end

function derivative(
    f!::F,
    y,
    prep::PushforwardDerivativePrep,
    backend::AbstractADType,
    x,
    contexts::Vararg{Context,C},
) where {F,C}
    check_prep(f!, y, prep, backend, x, contexts...)
    ty = pushforward(f!, y, prep.pushforward_prep, backend, x, (one(x),), contexts...)
    return only(ty)
end

function derivative!(
    f!::F,
    y,
    der,
    prep::PushforwardDerivativePrep,
    backend::AbstractADType,
    x,
    contexts::Vararg{Context,C},
) where {F,C}
    check_prep(f!, y, prep, backend, x, contexts...)
    pushforward!(f!, y, (der,), prep.pushforward_prep, backend, x, (one(x),), contexts...)
    return der
end

## Shuffled

function shuffled_derivative(
    x, f::F, backend::AbstractADType, rewrap::Rewrap{C}, unannotated_contexts::Vararg{Any,C}
) where {F,C}
    return derivative(f, backend, x, rewrap(unannotated_contexts...)...)
end
