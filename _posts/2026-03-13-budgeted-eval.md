---
title: "Nearly Optimal Budgeted Evaluation"
date: 2026-03-13
permalink: /posts/nearly-optimal-budgeted-eval/
author: max
tags:
  - LLM
  - evaluation
---

In the last post I covered the modeling problem: given a partially observed benchmark table, fit a sensible low-rank model on the logit scale. Once that model exists, the next question is an experiment design question. For LLMs, a full sweep across benchmarks can be too expensive. So, which datasets should I actually use for a quick model evaluation?

The short answer is:

1. fit a low-rank empirical-Bayes prior for a new run on the latent logit scale,
2. score a candidate subset of benchmarks by how much Gaussian mutual information it gives about the full benchmark profile,
3. optimize that set function under a budget constraint using submodular maximization.

You may be thinking, these embeddings we computed are not entirely identifiable so is this procedure even meaningful. As it will turn out, the resulting selector does not depend on the benchmark embeddings as coordinates. It depends on the induced covariance over benchmark logits. The embeddings are just one convenient factorization of that covariance.

## From weighted PCA to a prior over new runs

For run $$i$$ on benchmark $$j$$, I will use the same basic observation model as before:

$$
X_{ij} \sim \operatorname{Binomial}(n_j, p_{ij}),
\qquad
Y_{ij} = \frac{X_{ij}+1/2}{n_j+1},
\qquad
\eta_{ij} = \operatorname{logit}(p_{ij}).
$$

The previous post fit a weighted PCA model in logit space. The fitted latent logits take the form

$$
\hat \eta_{ij} = \mu_i + a_i^\top z_j.
$$

Here `\mu_i` is a run-specific intercept, `a_i` is a run embedding, and `z_j` is a benchmark embedding.

It is convenient to package those into

$$
x_i =
\begin{bmatrix}
\mu_i \\
a_i
\end{bmatrix},
\qquad
\phi_j =
\begin{bmatrix}
1 \\
z_j
\end{bmatrix}.
$$

Then

$$
\hat \eta_{ij} = \phi_j^\top x_i.
$$

Now treat the historical runs as samples from a population of runs. Estimate the run-state mean and covariance by

$$
\hat m_x = \frac{1}{N} \sum_{i=1}^N x_i,
\qquad
\hat C_x =
\frac{1}{N-1}
\sum_{i=1}^N
(x_i - \hat m_x)(x_i - \hat m_x)^\top.
$$

For a new run `*`, use the empirical-Bayes prior

$$
x_* \sim \mathcal{N}(\hat m_x, \hat C_x).
$$

If $$\Phi$$ is the matrix whose $$j$$-th row is $$\phi_j^\top$$, then the new run's full latent benchmark-logit vector is

$$
\eta_* = \Phi x_*,
$$

so

$$
\eta_* \sim \mathcal{N}(\hat m, \hat K),
\qquad
\hat m = \Phi \hat m_x,
\qquad
\hat K = \Phi \hat C_x \Phi^\top.
$$

This is the key object for design. Once `\hat K` is known, we have a prior over the entire benchmark profile of a new run.

## The Core Objective

When I run benchmark $$j$$ on the new model, I do not observe $$\eta_{*,j}$$ directly. I observe a noisy finite-sample estimate on the logit scale:

$$
y^{\mathrm{logit}}_{*,j} = \eta_{*,j} + \varepsilon_j,
\qquad
\varepsilon_j \sim \mathcal{N}(0, \sigma_j^2).
$$

Let $$\Sigma$$ be the covariance matrix of the observation noise $$\varepsilon$$ for the *newly run* benchmarks, conditional on the latent benchmark logits. This is assumed diagonal:

$$
\Sigma = \operatorname{diag}(\sigma_1^2, \dots, \sigma_D^2).
$$

So $$\hat K$$ is the signal and $$\Sigma$$ is the noise. This distinction matters. If I estimated $$\hat K$$ from raw noisy observations and then also added a separate $$\Sigma$$, I would be counting sampling noise twice. This is why I estimate $$\hat K$$ from the denoised fitted logits and keep $$\Sigma$$ as a separate term. For the actual values we use the same delta method technique as in the previous post 
$$
\sigma_j^2 \approx
\frac{1}{n_j \bar p_j (1 - \bar p_j)},
$$

where $$\bar p_j$$ is a benchmark-level reference accuracy, such as the historical mean accuracy.

If I observe a subset `S`, the posterior covariance of the full latent benchmark vector is

$$
\hat K_{* \mid S}=\hat K-
\hat K_{:S}
(\hat K_{SS} + \Sigma_S)^{-1}
\hat K_{S:}.
$$

So the design problem is: choose `S` so that posterior uncertainty about the full vector becomes small.

An obvious entropy-like objective would be some log-determinant criterion. But there is a numerical wrinkle: the low rank fit induces a low-rank covariance in a much larger benchmark space, so raw entropy formulas can become singular. My solution is to score a set $$S$$ by Gaussian mutual information:

$$
f(S)=I(\eta_* ; y^{\mathrm{logit}}_{*,S})=
\frac{1}{2}
\log \det
\left(
I + \Sigma_S^{-1/2} \hat K_{SS} \Sigma_S^{-1/2}
\right).
$$

This is the set function I maximize under the knapsack constraint

$$
\sum_{j \in S} c_j \leq B,
$$

where $$c_j$$ is the cost for dataset $$j$$. A simple approach is $$c_j = n_j$$ but that assumes that each datapoint needs roughly equal amount of work which is not true. If you have historical benchmark data you can probably come up with more refined ways to measure the relative cost of each dataset. 

This objective is monotone and submodular. Intuitively, each extra benchmark gives diminishing returns because once a region of the benchmark space is already well covered, a highly correlated new benchmark adds less new information.

## Does the selector depend on the embeddings?

At first glance this looks embedding-dependent because the construction started from the low-rank factors `a_i` and `z_j`. But the selector is actually invariant to the exact latent coordinate system.

The reason is that everything downstream can be written in observable space. The same prior covariance satisfies

$$
\hat K =
\frac{1}{N-1}
\sum_{i=1}^N
(\hat \eta_i - \bar \eta)(\hat \eta_i - \bar \eta)^\top,
\qquad
\bar \eta = \frac{1}{N} \sum_{i=1}^N \hat \eta_i.
$$

So the selector depends on the PCA fit only through the fitted-logit covariance $$\hat K$$ and the diagonal noise matrix $$\Sigma$$.

If I replace the latent coordinates by

$$
a_i' = R a_i,
\qquad
z_j' = R^{-T} z_j,
$$

for any invertible matrix $$R$$. Then

$$
\mu_i + {a_i'}^\top z_j' = \mu_i + a_i^\top z_j,
$$

so the fitted logits do not change. Consequently $$\hat K$$ does not change, the mutual-information objective does not change, and the selected subset does not change either.

The important caveat is that this does **not** mean the selector is invariant to every modeling choice. If I change the rank, the weighting scheme, the missing-data fit, or anything else that changes the fitted logits themselves, then $$\hat K$$ changes and the optimal set can change too. The invariance is to reparameterization of the same low-rank fit, not to genuinely different approximations.

## Algorithms

Once the objective is submodular, the optimization story is fairly standard.

### 1. Greedy under a cardinality constraint

If every benchmark had the same cost, the feasible region would just be

$$
|S| \leq k.
$$

Then the classic greedy algorithm starts from the empty set and repeatedly adds the item with largest marginal gain

$$
\Delta(j \mid S) = f(S \cup \{j\}) - f(S).
$$

That is,

$$
j^\star = \arg\max_{j \notin S} \Delta(j \mid S).
$$

For monotone submodular functions, this gives the standard $$1 - 1/e$$ approximation guarantee. This is the right baseline algorithm to keep in mind, even when costs are unequal.

### 2. Lazy greedy

Naive greedy can be slow if you have many datasets. At every round it recomputes every marginal gain from scratch.

Submodularity gives a much cheaper implementation because marginal gains can only go down as the selected set grows:

$$
A \subseteq B
\quad \Longrightarrow \quad
\Delta(j \mid A) \geq \Delta(j \mid B).
$$

So the last marginal gain I computed for benchmark $$j$$ is automatically an upper bound for all future rounds. Lazy greedy stores those stale upper bounds in a max-heap.

1. Pop the current top item from the heap.
2. Recompute its exact marginal gain for the current set.
3. If it is still on top, accept it.
4. Otherwise push the tighter upper bound back into the heap and continue.

The output is the same as ordinary greedy, but the number of objective evaluations is much smaller.

### 3. Knapsack constraints and Sviridenko

Real benchmarks do not all cost the same. Suppose the cost is `c_j = n_j`, so the constraint is

$$
\sum_{j \in S} c_j \leq B.
$$

The natural greedy generalization is density greedy: among the still-feasible items, add the one maximizing

$$
\frac{\Delta(j \mid S)}{c_j}.
$$

This is practical and usually strong, but the cardinality-constraint proof no longer applies.

Sviridenko's fix is that the real damage from knapsack constraints usually happens in the first few steps. The classical recipe is:

1. enumerate all small seed sets, up to size `3`,
2. from each seed, run density greedy on the remaining budget,
3. return the best completed solution.

That restores the $$1 - 1/e$$ approximation guarantee for monotone submodular maximization under a knapsack constraint.

I have seen small benefits from using Sviridenko's algorithm but it does take $$O(n^3)$$ lazy greedy runs. In the future I may cover how to reduce the running time substantially.

## What the selector actually chooses

One thing I like about using $$c_j = n_j$$ is that the behavior is easy to interpret. With a budget of `500`, the current solution spends almost all of its budget on a pile of small but informative benchmarks:

`usamo_2025` (`6`), `imo_2025` (`6`), `matharena_apex_2025` (`12`), `hmmt_2025` (`30`), `aime_2024` (`30`), `aime_2025` (`30`), `brumo_2025` (`30`), `cmimc_2025` (`40`), `critpt` (`70`), `smt_2025` (`53`), `terminal_bench` (`89`), and `terminal_bench_1` (`80`).

At budget `1000`, it keeps most of that core and then starts spending on larger items such as `tau_bench_telecom` (`114`) and `arc_agi_1` (`400`).

Looking at the omitted-but-feasible benchmarks is also revealing. Some of the most egregious cases are exactly what you would hope for from a redundancy-aware selector: `gpqa_diamond` (`198`) is left out after `aime_2024` (`30`) is selected, as it is extremely correlated with it under the fitted prior; `math_500` (`500`) is likewise largely covered by the small AIME-style benchmarks; `ifbench` (`294`) is strongly shadowed by `cmimc_2025` (`40`); and even `mmmu` (`900`) gets passed over because, in this fitted covariance, much of its variation is already picked up by much cheaper selected benchmarks such as `smt_2025` (`53`). So the selector is not merely preferring small benchmarks. It is preferring small benchmarks that seem to span directions that would otherwise require much more expensive evaluations.

That is exactly the kind of tradeoff I wanted the formulation to make. Cheap but distinctive datasets get picked early. Large expensive datasets only enter once their marginal information gain is worth the budget hit.

## Closing thoughts

The main conceptual point is that eval design is not really about the embeddings themselves. It is about the observable covariance structure they induce over benchmark logits. Once that covariance is in hand, benchmark selection becomes a clean submodular optimization problem with a well-understood algorithmic toolbox.
