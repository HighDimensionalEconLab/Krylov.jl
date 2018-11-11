# A standard implementation of the Conjugate Gradient method.
# The only non-standard point about it is that it does not check
# that the operator is definite.
# It is possible to check that the system is inconsistent by
# monitoring ‖p‖, which would cost an extra norm computation per
# iteration.
#
# Dominique Orban, <dominique.orban@gerad.ca>
# Salt Lake City, UT, March 2015.

export cg


"""The conjugate gradient method to solve the symmetric linear system Ax=b.

The method does _not_ abort if A is not definite.

A preconditioner M may be provided in the form of a linear operator and is
assumed to be symmetric and positive definite.
"""
function cg(A :: AbstractLinearOperator, b :: AbstractVector{T};
            M :: AbstractLinearOperator=opEye(size(A,1)), atol :: Float64=1.0e-8,
            rtol :: Float64=1.0e-6, itmax :: Int=0, radius :: Float64=0.0) where T <: Number

  m, n = size(A)
  m == n == length(b) || @error "inconsistent problem size: $m x $n"
  @debug "system of $m equations and $n variables"

  # Initial state.
  x = zeros(T, n);
  r = copy(b)
  z = M * r
  p = copy(z)
  γ = @kdot(n, r, z)
  γ == 0 && return x, SimpleStats(true, false, [0.0], [], "x = 0 is a zero-residual solution")

  iter = 0;
  itmax == 0 && (itmax = 2 * n);
  @debug "maximum number of iterations set to ", itmax

  rNorm = sqrt(γ);
  rNorms = [rNorm;];
  ε = atol + rtol * rNorm;
  @info @sprintf("%5s  %7s  %8s  %7s  %7s", "iter", "⁠‖res‖", "curv", "CGstep", "step")

  solved = rNorm <= ε;
  tired = iter >= itmax;
  on_boundary = false;
  status = "unknown";

  while ! (solved || tired)
    Ap = A * p;
    pAp = @kdot(n, p, Ap)

    α = γ / pAp;

    # Compute step size to boundary if applicable.
    σ = radius > 0.0 ? maximum(to_boundary(x, p, radius)) : α

    @info @sprintf("%5d  %7.1e  %8.1e  %7.1e  %7.1e", iter, rNorm, pAp, α, σ)

    # Move along p from x to the boundary if either
    # the next step leads outside the trust region or
    # we have nonpositive curvature.
    if (radius > 0.0) & ((pAp <= 0.0) | (α > σ))
      @debug("stepping to trust-region boundary")
      α = σ
      on_boundary = true
    end

    @kaxpy!(n,  α,  p, x)
    @kaxpy!(n, -α, Ap, r)
    z = M * r
    γ_next = @kdot(n, r, z)
    rNorm = sqrt(γ_next);
    push!(rNorms, rNorm);

    solved = (rNorm <= ε) | on_boundary;
    if !solved
      β = γ_next / γ;
      γ = γ_next;

      @kscal!(n, β, p)
      @kaxpy!(n, 1.0, z, p)
    end

    iter = iter + 1;
    tired = iter >= itmax;
  end

  status = on_boundary ? "on trust-region boundary" : (tired ? "maximum number of iterations exceeded" : "solution good enough given atol and rtol")
  stats = SimpleStats(solved, false, rNorms, T[], status);
  return (x, stats);
end
