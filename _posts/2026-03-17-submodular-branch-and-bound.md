---
title: "Speeding up Sviridenko"
date: 2026-03-17
permalink: /posts/speeding-up-sviridenko/
author: max
tags:
  - algorithms
  - submodular
  - optimization
---

In the previous post I framed budgeted evaluation as monotone submodular maximization under a knapsack constraint. The objective was Gaussian mutual information, the cost was benchmark budget, and the baseline practical algorithm was density greedy with a lazy heap. That already worked well, but there was one expensive piece left on the table: the classical Sviridenko improvement.

Sviridenko's algorithm is conceptually simple:

1. enumerate every seed set of size up to `3`,
2. from each seed, run density greedy on the remaining budget,
3. keep the best completed solution.

That restores the $$1 - 1/e$$ guarantee for monotone submodular knapsack. However, this is a naive implementation. If we do things carefully we can avoid a lot of computation that would otherwise be wasted.

Here is how I made Sviridenko's algorithm much faster in practice without changing the final answer:

1. use ordinary lazy greedy once to get a strong incumbent lower bound,
2. run branch and bound on the seed enumeration,
3. use the lazy heap's stale gains to build a cheap admissible upper bound,
4. recompute that bound only when the lazy state actually changes,
5. memoize the cheap upper bound by the selected set, even though the bound is path-dependent and loose.

The last point is the subtle one. It looks suspicious at first. It turned out to be both valid and useful.

## The setup

Let $$f(S)$$ be the mutual information objective from the previous post, let $$c_j$$ be benchmark costs, and let $$B$$ be the total budget. The optimization problem is

$$
\max_S f(S)
\qquad
\text{subject to}
\qquad
\sum_{j \in S} c_j \leq B.
$$

The density greedy step repeatedly adds the feasible item maximizing

$$
\frac{\Delta(j \mid S)}{c_j},
\qquad
\Delta(j \mid S) = f(S \cup \{j\}) - f(S).
$$

With a lazy heap, each item $$j$$ carries a stale upper bound on its current marginal gain. Submodularity implies

$$
A \subseteq B
\quad \Longrightarrow \quad
\Delta(j \mid A) \geq \Delta(j \mid B),
$$

so any marginal gain computed earlier remains an upper bound later.

That stale-gain fact is exactly what makes the branch-and-bound version cheap.

## Why the naive implementation is wasteful

Suppose I start from a seed set $$S_0$$ of size `3`. The naive algorithm runs lazy density greedy to completion and gets some feasible set $$S$$.

But many seeds are hopeless long before that:

1. some seeds are already worse than the incumbent before greedy even starts,
2. some seeds look plausible at first, but after a few lazy-greedy updates their best possible completion still cannot beat the incumbent,
3. many different seed orders flow into the same selected set after a few greedy steps.

The naive algorithm ignores all three facts.

## A cheap admissible upper bound

Fix the current selected set $$S$$ inside one lazy-greedy run. For each not-yet-selected item $$j$$, let $$u_j(S)$$ denote the stale upper bound currently stored by the lazy heap. By construction,

$$
u_j(S) \geq \Delta(j \mid S).
$$

Now take any feasible continuation $$T$$ disjoint from $$S$$. By submodularity,

$$
f(S \cup T) - f(S)
\leq
\sum_{j \in T} \Delta(j \mid S)
\leq
\sum_{j \in T} u_j(S).
$$

Let $$\operatorname{Knapsack}(S, u, c, B')$$ be the solution to the fractional knapsack problem

$$
\operatorname{maximize}_{x} \sum_{j \in V \setminus S} x_j u_j(S) \quad \text{subject to} \quad \sum_{j \in V \setminus S} x_j c_j \leq B', \quad x_j \in [0,1]
$$

The optimum 
- is given by the usual density ordering on $$\frac{u_j(S)}{c_j}$$.
- upper bounds $$f(S \cup T) - f(S)$$ for any feasible continuation $$T$$ if I set $$B' = B - \sum_{j \in S} c_j$$.

Thus for any $$S$$ we have the upper bound

$$
\operatorname{U}(S)=f(S) + \operatorname{Knapsack}(S, u, c, B- \sum_{j \in S} c_j).
$$

This is not an exact bound. It can be quite loose. But it is cheap, and it is always safe:

1. if $$\operatorname{U}(S)$$ is below the current best lower bound, this branch can never win,
2. pruning on that condition cannot remove the optimal answer.

## Branch and bound around Sviridenko

With that upper bound in hand, the seed enumeration becomes a straightforward branch-and-bound procedure.

1. Run ordinary lazy density greedy once from the empty set and record its value as the incumbent lower bound.
2. Enumerate each feasible seed of size `3`.
3. For each seed, compute the seed-level upper bound. If it cannot beat the incumbent, prune immediately.
4. Otherwise continue the lazy-greedy completion from that seed.
5. During the lazy-greedy run, keep checking whether the current branch upper bound can still beat the incumbent.
6. If not, prune the branch.
7. If a branch completes with a better feasible solution, update the incumbent.

The final answer is the same as naive Sviridenko. The difference is that many seed paths never have to run to completion.

On my current LLM benchmark data, at budget `500`, there are `1614` feasible seeds of size `3`. The optimized version pruned `511` of them immediately at the seed check and another `1056` during the greedy completion, leaving only `47` fully completed seed runs.

That is the main win.

## State-refresh only recomputation

The above method still does something silly: it recomputes the knapsack upper bound at every pass through the lazy-greedy loop.

But the bound only depends on three things:

1. the currently selected set $$S$$,
2. the remaining budget,
3. the vector of stale gains $$u_j(S)$$.

Some heap operations do not change any of those. In particular, if the loop just pops an already-outdated heap entry and discards it, nothing about the branch state changed. Recomputing the upper bound there is pure overhead.

So the next improvement is to mark the upper bound as dirty only when the lazy state changes in a relevant way:

1. an item's stale gain is tightened,
2. or an item is actually accepted into the solution.

Between those events, the cached branch upper bound is still exactly the same cheap bound as before. There is no need to recompute it.

## Memoizing the cheap upper bound

The final improvement is memoization.

Suppose one branch starts from seed items in the order `A, B, C` and inserts `D`, while another branch starts from seed items in the order `A, B, D` and inserts `C`. After four accepted items, both paths have reached the same selected set

$$
S = \{A,B,C,D\}.
$$

At that point, it is natural to want a cache keyed by the sorted tuple of selected items.

The first thought might be: just compute the upper bound as a pure function of $$S$$ and cache it. But the cheap lazy-greedy upper bound is not actually a function of $$S$$ alone. It also depends on how tight the current stale gains happen to be. Different paths can reach the same set with different stale-gain vectors.

So the right statement is slightly weaker:

1. a previously computed cheap bound for set $$S$$ is not canonical,
2. but it is still an admissible upper bound for that same set $$S$$.

Why? Because every stale gain stored by lazy greedy is itself an upper bound on the true marginal gain at the current set. If I previously reached the same selected set $$S$$ by another order and computed

$$
\widetilde{\operatorname{U}}(S),
$$

that value may be loose, but it still upper-bounds every feasible completion from $$S$$.

So when another branch reaches the same sorted set $$S$$, I can safely reuse that cached value:

1. it may fail to prune some branches because it is loose,
2. but it cannot incorrectly prune a branch that should survive.

The implementation is simple:

1. key the cache by `tuple(sorted(selected))`,
2. store the cheap fractional-knapsack upper bound the first time that set is seen,
3. reuse the stored value whenever the same selected set appears again.

On the same budget-`500` run, memoization reduced actual bound computations from about `26k` down to about `4.7k`, with about `22.9k` cache hits.

Stripped down to the algorithmic core, the control flow looks like this:

1. the heap stores stale density bounds,
2. `last_updated_at_size[j]` records whether item `j` has been refreshed for the current selected set,
3. the fractional knapsack upper bound is recomputed only when the lazy state changes,
4. the cheap bound is memoized by the sorted selected set.

```python
def memoized_fractional_upper_bound(
    selected,
    current_value,
    remaining_budget,
    costs,
    stale_upper_gains,
    upper_bound_cache,
):
    key = tuple(sorted(selected))
    if key in upper_bound_cache:
        return upper_bound_cache[key]

    selected_set = set(selected)
    candidate_items = sorted(
        [
            (stale_upper_gains[j] / cost, stale_upper_gains[j], cost)
            for j, cost in enumerate(costs)
            if j not in selected_set
            and cost <= remaining_budget
            and stale_upper_gains[j] > 0.0
        ],
        reverse=True,
    )

    bound = current_value
    for density, upper_gain, cost in candidate_items:
        take = min(cost, remaining_budget)
        bound += density * take
        remaining_budget -= take
        if take < cost:
            break

    upper_bound_cache[key] = bound
    return bound


def lazy_greedy_branch_and_bound_from_seed(
    model,
    budget,
    seed,
    singleton_gains,
    incumbent_lower_bound,
    upper_bound_cache,
):
    selected = list(seed)
    selected_set = set(seed)
    spent_budget = sum(model.costs[j] for j in selected)
    current_value = objective(model, selected)

    # Start with singleton gains as lazy upper bounds.
    stale_upper_gains = singleton_gains.copy()
    last_updated_at_size = [-1] * model.num_items
    heap = [
        (-stale_upper_gains[j] / model.costs[j], j)
        for j in range(model.num_items)
        if j not in selected_set and model.costs[j] <= budget - spent_budget
    ]
    heapify(heap)

    upper_bound_dirty = True
    branch_upper_bound = float("inf")

    while heap:
        remaining_budget = budget - spent_budget

        # Recompute the branch upper bound only after an actual
        # state change: either a tighter stale gain or an accepted item.
        if upper_bound_dirty:
            branch_upper_bound = memoized_fractional_upper_bound(
                selected=selected,
                current_value=current_value,
                remaining_budget=remaining_budget,
                costs=model.costs,
                stale_upper_gains=stale_upper_gains,
                upper_bound_cache=upper_bound_cache,
            )
            upper_bound_dirty = False

        if branch_upper_bound < incumbent_lower_bound:
            return None  # prune branch

        _, j = pop(heap)
        if spent_budget + model.costs[j] > budget:
            continue

        if last_updated_at_size[j] != len(selected):
            new_value = objective(model, selected + [j])
            stale_upper_gains[j] = new_value - current_value
            last_updated_at_size[j] = len(selected)
            push(heap, (-(stale_upper_gains[j] / model.costs[j]), j))
            upper_bound_dirty = True
            continue

        selected.append(j)
        selected_set.add(j)
        spent_budget += model.costs[j]
        current_value += stale_upper_gains[j]
        stale_upper_gains[j] = 0.0
        upper_bound_dirty = True

    return selected, current_value
```

## Empirical timing

All timings below are from my LLM benchmark data. These are local measurements on my machine, so the absolute numbers are less important than the ranking.

At budget `1000`, a single warmed timing gave:

| algorithm | time |
| --- | ---: |
| naive `sviridenko` | `22.15s` |
| branch and bound | `13.80s` |
| branch and bound + state-refresh | `13.21s` |
| branch and bound + memoization | `12.20s` |
| branch and bound + state-refresh + memoization | `11.56s` |

So the pattern is stable:

1. branch and bound helps a lot,
2. recomputing only on state refresh helps a bit more,
3. memoizing the upper bound helps a bit more.
4. combining them helps the most.


## The main lesson

The key insight was being honest about what information the lazy heap was already maintaining. Lazy greedy already gives a vector of admissible per-item upper bounds. Once those are available, the right branch-and-bound question is "what is a cheap upper bound that is strong enough to prune a lot of branches?"

For this problem, the answer was:

1. use the stale gains,
2. turn them into a fractional knapsack upper bound,
3. only recompute when the stale-gain state changes,
4. memoize previously seen selected sets, even if the cached bound is loose.

That was enough to make Sviridenko's algorithm much less painful in practice while keeping the same output.

And there's still room for improvement! Right now I am using sorting to solve the fractional knapsack and not leveraging any data structures. A more principled dynamic data structure that can act like a heap but also compute prefix sums could probably squeeze out more speed. But the current version is already much better and it gets there with a very small amount of additional machinery.
