## Docstrings

"""
    prepare_second_derivative(f, backend, x, [contexts...]; strict=Val(true)) -> prep

$(docstring_prepare("second_derivative"))
"""
function prepare_second_derivative(
    f::F, backend::AbstractADType, x, contexts::Vararg{Context,C}; strict::Val=Val(true)
) where {F,C}
    return prepare_second_derivative_nokwarg(strict, f, backend, x, contexts...)
end

"""
    prepare!_second_derivative(f, prep, backend, x, [contexts...]) -> new_prep

$(docstring_prepare!("second_derivative"))
"""
function prepare!_second_derivative(
    f::F,
    old_prep::SecondDerivativePrep,
    backend::AbstractADType,
    x,
    contexts::Vararg{Context,C};
) where {F,C}
    check_prep(f, old_prep, backend, x, contexts...)
    return prepare_second_derivative_nokwarg(
        is_strict(old_prep), f, backend, x, contexts...
    )
end

"""
    second_derivative(f, [prep,] backend, x, [contexts...]) -> der2

Compute the second derivative of the function `f` at point `x`.

$(docstring_preparation_hint("second_derivative"))
"""
function second_derivative(
    f::F, backend::AbstractADType, x, contexts::Vararg{Context,C}
) where {F,C}
    prep = prepare_second_derivative_nokwarg(Val(true), f, backend, x, contexts...)
    return second_derivative(f, prep, backend, x, contexts...)
end

"""
    second_derivative!(f, der2, [prep,] backend, x, [contexts...]) -> der2

Compute the second derivative of the function `f` at point `x`, overwriting `der2`.

$(docstring_preparation_hint("second_derivative"))
"""
function second_derivative!(
    f::F, der2, backend::AbstractADType, x, contexts::Vararg{Context,C}
) where {F,C}
    prep = prepare_second_derivative_nokwarg(Val(true), f, backend, x, contexts...)
    return second_derivative!(f, der2, prep, backend, x, contexts...)
end

"""
    value_derivative_and_second_derivative(f, [prep,] backend, x, [contexts...]) -> (y, der, der2)

Compute the value, first derivative and second derivative of the function `f` at point `x`.

$(docstring_preparation_hint("second_derivative"))
"""
function value_derivative_and_second_derivative(
    f::F, backend::AbstractADType, x, contexts::Vararg{Context,C}
) where {F,C}
    prep = prepare_second_derivative_nokwarg(Val(true), f, backend, x, contexts...)
    return value_derivative_and_second_derivative(f, prep, backend, x, contexts...)
end

"""
    value_derivative_and_second_derivative!(f, der, der2, [prep,] backend, x, [contexts...]) -> (y, der, der2)

Compute the value, first derivative and second derivative of the function `f` at point `x`, overwriting `der` and `der2`.

$(docstring_preparation_hint("second_derivative"))
"""
function value_derivative_and_second_derivative!(
    f::F, der, der2, backend::AbstractADType, x, contexts::Vararg{Context,C}
) where {F,C}
    prep = prepare_second_derivative_nokwarg(Val(true), f, backend, x, contexts...)
    return value_derivative_and_second_derivative!(
        f, der, der2, prep, backend, x, contexts...
    )
end

## Preparation

struct DerivativeSecondDerivativePrep{SIG,E<:DerivativePrep} <: SecondDerivativePrep{SIG}
    _sig::Val{SIG}
    outer_derivative_prep::E
end

function prepare_second_derivative_nokwarg(
    strict::Val, f::F, backend::AbstractADType, x, contexts::Vararg{Context,C}
) where {F,C}
    _sig = signature(f, backend, x, contexts...; strict)
    rewrap = Rewrap(contexts...)
    new_contexts = (
        FunctionContext(f), Constant(inner(backend)), Constant(rewrap), contexts...
    )
    outer_derivative_prep = prepare_derivative_nokwarg(
        strict, shuffled_derivative, outer(backend), x, new_contexts...
    )
    return DerivativeSecondDerivativePrep(_sig, outer_derivative_prep)
end

## One argument

function second_derivative(
    f::F,
    prep::DerivativeSecondDerivativePrep,
    backend::AbstractADType,
    x,
    contexts::Vararg{Context,C},
) where {F,C}
    check_prep(f, prep, backend, x, contexts...)
    (; outer_derivative_prep) = prep
    rewrap = Rewrap(contexts...)
    new_contexts = (
        FunctionContext(f), Constant(inner(backend)), Constant(rewrap), contexts...
    )
    return derivative(
        shuffled_derivative, outer_derivative_prep, outer(backend), x, new_contexts...
    )
end

function value_derivative_and_second_derivative(
    f::F,
    prep::DerivativeSecondDerivativePrep,
    backend::AbstractADType,
    x,
    contexts::Vararg{Context,C},
) where {F,C}
    check_prep(f, prep, backend, x, contexts...)
    (; outer_derivative_prep) = prep
    rewrap = Rewrap(contexts...)
    new_contexts = (
        FunctionContext(f), Constant(inner(backend)), Constant(rewrap), contexts...
    )
    y = f(x, map(unwrap, contexts)...)
    der, der2 = value_and_derivative(
        shuffled_derivative, outer_derivative_prep, outer(backend), x, new_contexts...
    )
    return y, der, der2
end

function second_derivative!(
    f::F,
    der2,
    prep::SecondDerivativePrep,
    backend::AbstractADType,
    x,
    contexts::Vararg{Context,C},
) where {F,C}
    check_prep(f, prep, backend, x, contexts...)
    (; outer_derivative_prep) = prep
    rewrap = Rewrap(contexts...)
    new_contexts = (
        FunctionContext(f), Constant(inner(backend)), Constant(rewrap), contexts...
    )
    return derivative!(
        shuffled_derivative, der2, outer_derivative_prep, outer(backend), x, new_contexts...
    )
end

function value_derivative_and_second_derivative!(
    f::F,
    der,
    der2,
    prep::SecondDerivativePrep,
    backend::AbstractADType,
    x,
    contexts::Vararg{Context,C},
) where {F,C}
    check_prep(f, prep, backend, x, contexts...)
    (; outer_derivative_prep) = prep
    rewrap = Rewrap(contexts...)
    new_contexts = (
        FunctionContext(f), Constant(inner(backend)), Constant(rewrap), contexts...
    )
    y = f(x, map(unwrap, contexts)...)
    new_der, _ = value_and_derivative!(
        shuffled_derivative, der2, outer_derivative_prep, outer(backend), x, new_contexts...
    )
    return y, copyto!(der, new_der), der2
end
