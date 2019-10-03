struct ChebyshevWeight{T} <: AbstractJacobiWeight{T} end

function getindex(w::ChebyshevWeight, x::Number)
    x ∈ axes(w,1) || throw(BoundsError())
    1/sqrt(1-x^2)
end

struct UltrasphericalWeight{T,Λ} <: AbstractJacobiWeight{T} 
    λ::Λ
end

UltrasphericalWeight(λ) = UltrasphericalWeight{typeof(λ),typeof(λ)}(λ)

function getindex(w::UltrasphericalWeight, x::Number)
    x ∈ axes(w,1) || throw(BoundsError())
    (1-x^2)^(w.λ-one(w.λ)/2)
end


struct Chebyshev{T} <: AbstractJacobi{T} end
Chebyshev() = Chebyshev{Float64}()
==(a::Chebyshev, b::Chebyshev) = true

struct Ultraspherical{T,Λ<:Real} <: AbstractJacobi{T} 
    λ::Λ
end
Ultraspherical{T}(λ::Λ) where {T,Λ} = Ultraspherical{T,Λ}(λ)
Ultraspherical(λ::Λ) where Λ = Ultraspherical{Float64,Λ}(λ)
Ultraspherical(P::Legendre{T}) where T = Ultraspherical(one(T)/2)

Jacobi(C::Ultraspherical{T}) where T = Jacobi(C.λ-one(T)/2,C.λ-one(T)/2)
Jacobi(C::Chebyshev{T}) where T = Jacobi(-one(T)/2,-one(T)/2)

==(a::Ultraspherical, b::Ultraspherical) = a.λ == b.λ


########
# Jacobi Matrix
########

jacobimatrix(C::Chebyshev{T}) where T = _BandedMatrix(Vcat(Fill(one(T)/2,1,∞), Zeros(1,∞), Hcat(one(T), Fill(one(T)/2,1,∞))), ∞, 1, 1)

function jacobimatrix(P::Ultraspherical{T}) where T
    λ = P.λ
    _BandedMatrix(Vcat((((2λ-1):∞) ./ (2 .*((zero(T):∞) .+ λ)))',
                        Zeros{T}(1,∞),
                        ((one(T):∞) ./ (2 .*((zero(T):∞) .+ λ)))'), ∞, 1, 1)
end


##########
# Derivatives
##########

# Ultraspherical(1)\(D*Chebyshev())
@simplify function *(D::Derivative{<:Any,<:ChebyshevInterval}, S::Chebyshev)
    T = promote_type(eltype(D),eltype(S))
    A = _BandedMatrix((zero(T):∞)', ∞, -1,1)
    ApplyQuasiMatrix(*, Ultraspherical{T}(1), A)
end

# Ultraspherical(1/2)\(D*Legendre())
@simplify function *(D::Derivative{<:Any,<:ChebyshevInterval}, S::Legendre)
    T = promote_type(eltype(D),eltype(S))
    A = _BandedMatrix(Ones{T}(1,∞), ∞, -1,1)
    ApplyQuasiMatrix(*, Ultraspherical{T}(3/2), A)
end


# Ultraspherical(λ+1)\(D*Ultraspherical(λ))
@simplify function *(D::Derivative{<:Any,<:ChebyshevInterval}, S::Ultraspherical)
    A = _BandedMatrix(Fill(2S.λ,1,∞), ∞, -1,1)
    ApplyQuasiMatrix(*, Ultraspherical{eltype(S)}(S.λ+1), A)
end


##########
# Conversion
##########

@simplify \(A::Ultraspherical, B::Legendre) = A\Ultraspherical(B)
@simplify \(A::Legendre, B::Ultraspherical) = Ultraspherical(A)\B

@simplify function \(A::Ultraspherical, B::Jacobi) 
    Ã = Jacobi(A)
    (view(A,1,:)./view(Ã,1,:)) .* (Ã\B)
end
@simplify \(A::Jacobi, B::Ultraspherical) = Ultraspherical(A)\B


@simplify function \(U::Ultraspherical{<:Any,<:Integer}, C::Chebyshev)
    if U.λ == 1
        T = promote_type(eltype(U), eltype(C))
        _BandedMatrix(Vcat(Hcat(Ones{T}(1,3),Ones{T}(1,∞)/2),
                            Zeros{T}(1,∞), 
                            Ones{T}(1,∞)/2), ∞, 0,2)
    elseif U.λ > 0
        (U\Ultraspherical(1)) * (Ultraspherical(1)\C)
    else
        error("Not implemented")
    end
end

@simplify function \(C2::Ultraspherical{<:Any,<:Integer}, C1::Ultraspherical{<:Any,<:Integer})
    λ = C1.λ
    T = promote_type(eltype(C2), eltype(C1))
    if C2.λ == λ+1 
        _BandedMatrix( Vcat(-(λ ./ ((0:∞) .+ λ))', Zeros(1,∞), (λ ./ ((0:∞) .+ λ))'), ∞, 0, 2)
    elseif C2.λ == λ
        Eye{T}(∞)
    elseif C2.λ > λ
        (C2 \ Ultraspherical(λ+1)) * (Ultraspherical(λ+1)\C1)
    else
        error("Not implemented")
    end
end

@simplify function \(C2::Ultraspherical, C1::Ultraspherical)
    λ = C1.λ
    T = promote_type(eltype(C2), eltype(C1))
    if C2.λ == λ+1 
        _BandedMatrix( Vcat(-(λ ./ ((0:∞) .+ λ))', Zeros(1,∞), (λ ./ ((0:∞) .+ λ))'), ∞, 0, 2)
    elseif C2.λ == λ
        Eye{T}(∞)
    else
        error("Not implemented")
    end
end


####
# interrelationships
####

# (18.7.3)

@simplify function \(A::Chebyshev, B::Jacobi)
    T = promote_type(eltype(A), eltype(B))
    (B.a == B.b == -T/2) || throw(ArgumentError())
    Diagonal(Jacobi(-T/2,-T/2)[1,:])
end