pmap(f::RemoteFunction, exec::BaseExecutor, its...) = pmap(f, exec, zip(its...))

struct ParGenerator{I}
  exec::BaseExecutor
  f::RemoteFunction
  iter::I
end

import Base: IteratorEltype, IteratorSize, eltype, EltypeUnknown, iterate, isdone, length, size, axes, ndims
function iterate(g::ParGenerator)
	next = iterate(g.iter)
	while next !== nothing && resources_available(g.exec)
			(x, state) = next
      submit!(g.exec, g.f, x)
			next = iterate(iter, state)
  end

  f = run_until!(g.exec)
  f === nothing && return nothing

  val = get!(f)

  if next !== nothing
			(x, state) = next
      submit!(g.exec, g.f, x)
  end

  val, state
end

function iterate(g::ParGenerator, state)
  f = run_until!(g.exec)
  f === nothing && return nothing

  val = get!(f)

  next = iterate(g.iter, state)
  if next !== nothing
			(x, state) = next
      submit!(g.exec, g.f, x)
  end

  val, state
end

@inline isdone(g::ParGenerator) = isdone(g.iter)

length(g::ParGenerator) = length(g.iter)
size(g::ParGenerator) = size(g.iter)
axes(g::ParGenerator) = axes(g.iter)
ndims(g::ParGenerator) = ndims(g.iter)

IteratorSize(::Type{ParGenerator{I}}) where {I} = IteratorSize(I)
IteratorEltype(::Type{ParGenerator{I}}) where {I} = EltypeUnknown()

function pforeach(f::RemoteFunction, exec::BaseExecutor, iter)
	next = iterate(iter)
	while next !== nothing
			(x, state) = next

			if resources_available(exec)
				submit!(exec, f, x)
			else
				f = run_until!(exec)
				val = get!(f)
			end

			next = iterate(iter, state)
	end

  while (f = run_until!(exec)) !== nothing
      val = get!(f)
  end

  nothing
end

pforeach(f::RemoteFunction, exec::BaseExecutor, its...) = pforeach(f, exec, zip(its...))

export pforeach, pmap
