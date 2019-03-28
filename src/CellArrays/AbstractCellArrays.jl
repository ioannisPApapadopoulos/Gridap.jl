
"""
Abstract type representing an iterable collection of Arrays{T,N},
where each array is associated to a cell.
"""
abstract type CellArray{T,N} end

Base.iterate(::CellArray)::Union{Nothing,Tuple{Tuple{Array{T,N},NTuple{N,Int}},Any}} = @abstractmethod

Base.iterate(::CellArray,state)::Union{Nothing,Tuple{Tuple{Array{T,N},NTuple{N,Int}},Any}} = @abstractmethod

Base.length(::CellArray)::Int = @abstractmethod

maxsize(::CellArray{T,N} where {T,N})::NTuple{N,Int} = @abstractmethod

Base.eltype(::Type{C}) where C<:CellArray{T,N} where {T,N} = Array{T,N}

maxsize(self::CellArray,i::Int) = (s = maxsize(self); s[i])

maxlength(self::CellArray) = prod(maxsize(self))

function Base.show(io::IO,self::CellArray)
  for (i,(a,s)) in enumerate(self)
    v = viewtosize(a,s)
    println(io,"$i -> $v")
  end
end

"""
Abstract type representing an indexable CellArray.
By implementing a concrete IndexableCellArray, one automatically
gets a type that is also iterable
"""
abstract type IndexableCellArray{T,N} <: CellArray{T,N} end

Base.getindex(::IndexableCellArray{T,N} where {T,N},cell::Int)::Tuple{Array{T,N},NTuple{N,Int}} = @abstractmethod

@inline Base.iterate(self::IndexableCellArray) = iterate(self,0)

@inline function Base.iterate(self::IndexableCellArray,state::Int)
  if length(self) == state
    nothing
  else
    k = state+1
    (self[k],k)
  end
end

"""
Abstract type to be used for the implementation of types representing
the lazy result of applying an unary operation on a CellArray
"""
abstract type CellArrayFromUnaryOp{C<:CellArray,T,N} <: CellArray{T,N} end

inputcellarray(::CellArrayFromUnaryOp{C,T,N} where {C,T,N})::C = @abstractmethod

computesize(::CellArrayFromUnaryOp, asize) = @abstractmethod

computevals!(::CellArrayFromUnaryOp, a, asize, v, vsize) = @abstractmethod

Base.length(self::CellArrayFromUnaryOp) = length(inputcellarray(self))

maxsize(self::CellArrayFromUnaryOp) = computesize(self,maxsize(inputcellarray(self)))

@inline function Base.iterate(self::CellArrayFromUnaryOp{C,T,N}) where {C,T,N}
  v = Array{T,N}(undef,maxsize(self))
  anext = iterate(inputcellarray(self))
  if anext === nothing; return nothing end
  iteratekernel(self,anext,v)
end

@inline function Base.iterate(self::CellArrayFromUnaryOp,state)
  v, astate = state
  anext = iterate(inputcellarray(self),astate)
  if anext === nothing; return nothing end
  iteratekernel(self,anext,v)
end

function iteratekernel(self::CellArrayFromUnaryOp,anext,v)
  (a,asize), astate = anext
  vsize = computesize(self,asize)
  computevals!(self,a,asize,v,vsize)
  state = (v, astate)
  ((v,vsize),state)
end

"""
Like CellArrayFromUnaryOp but for the particular case of element-wise operation
in the elements of the returned array
"""
abstract type CellArrayFromElemUnaryOp{C,T,N} <: CellArrayFromUnaryOp{C,T,N} end

computesize(::CellArrayFromElemUnaryOp, asize) = asize

"""
Abstract type to be used for the implementation of types representing
the lazy result of applying a binary operation on two CellArray objects
"""
abstract type CellArrayFromBinaryOp{A<:CellArray,B<:CellArray,T,N} <: CellArray{T,N} end

leftcellarray(::CellArrayFromBinaryOp{A,B,T,N} where {A,B,T,N})::A = @abstractmethod

rightcellarray(::CellArrayFromBinaryOp{A,B,T,N} where {A,B,T,N})::B = @abstractmethod

computesize(::CellArrayFromBinaryOp, asize, bsize) = @abstractmethod

computevals!(::CellArrayFromBinaryOp, a, asize, b, bsize, v, vsize) = @abstractmethod

function Base.length(self::CellArrayFromBinaryOp)
  @assert length(rightcellarray(self)) == length(leftcellarray(self))
  length(rightcellarray(self))
end

maxsize(self::CellArrayFromBinaryOp) = computesize(self,maxsize(leftcellarray(self)),maxsize(rightcellarray(self)))

@inline function Base.iterate(self::CellArrayFromBinaryOp{A,B,T,N}) where {A,B,T,N}
  v = Array{T,N}(undef,maxsize(self))
  anext = iterate(leftcellarray(self))
  if anext === nothing; return nothing end
  bnext = iterate(rightcellarray(self))
  if bnext === nothing; return nothing end
  iteratekernel(self,anext,bnext,v)
end

@inline function Base.iterate(self::CellArrayFromBinaryOp,state)
  v, astate, bstate = state
  anext = iterate(leftcellarray(self),astate)
  if anext === nothing; return nothing end
  bnext = iterate(rightcellarray(self),bstate)
  if bnext === nothing; return nothing end
  iteratekernel(self,anext,bnext,v)
end

function iteratekernel(self::CellArrayFromBinaryOp,anext,bnext,v)
  (a,asize), astate = anext
  (b,bsize), bstate = bnext
  vsize = computesize(self,asize,bsize)
  computevals!(self,a,asize,b,bsize,v,vsize)
  state = (v, astate, bstate)
  ((v,vsize),state)
end

"""
Like CellArrayFromBinaryOp but for the particular case of element-wise operation
in the elements of the returned array
"""
abstract type CellArrayFromElemBinaryOp{A,B,T,N} <: CellArrayFromBinaryOp{A,B,T,N} end

function computesize(::CellArrayFromElemBinaryOp, asize, bsize)
  @assert asize == bsize
  asize
end

