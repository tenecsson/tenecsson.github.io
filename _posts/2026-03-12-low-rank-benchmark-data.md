---
title: "Low rank modeling of benchmark data"
date: 2026-03-12
permalink: /posts/low-rank-benchmark-data/
author: max
tags:
  - AI
  - Machine Learning
---

In a previous post I looked at Factor Analysis for modeling benchmark tables whose rows are models (or more precisely model configurations, since the same base model can be run with different reasoning efforts), columns are datasets, and entries are accuracies. Shortly after publishing that post it dawned on me that there is a much simpler approach:

1. transform the accuracies to smoothed logits,
2. weight each dataset by its number of examples,
3. fit a low-rank approximation by a single SVD.

That simple recipe ended up being robust across a wide range of simulated deviations from the ideal model, and on real benchmark tables it has been a very strong default. The likelihood-based refinements are still useful, but I now think weighted PCA in logit space should be the baseline.

For model $$i$$ on benchmark $$j$$,

$$
X_{ij} \sim \operatorname{Binomial}(n_j, p_{ij}),
\qquad
Y_{ij} = \frac{X_{ij}}{n_j},
$$

where $$n_j$$ is the number of examples in benchmark $$j$$. We only observe the aggregated accuracies $$Y_{ij}$$, not the individual example outcomes, but we do know $$n_j$$ for each dataset. Thus we also have a good handle on the variance

$$
\operatorname{Var}(Y_{ij}) = \frac{p_{ij}(1-p_{ij})}{n_j}.
$$

The main structural fact is that models and benchmarks are correlated. One model may be distilled from another or trained with a similar pipeline. Benchmarks may be measuring similar capabilities. A simple way to encode this is to model the natural parameter on the logit scale:

$$
\eta_{ij} = \operatorname{logit}(p_{ij}) = \mu_i + \langle L_i, z_j \rangle.
$$

The row intercept $$\mu_i$$ captures overall model strength, while the low-rank term captures a small number of shared latent directions. Here $$L_i \in \mathbb{R}^k$$ is the latent vector for model $$i$$ and $$z_j \in \mathbb{R}^k$$ is the latent vector for dataset $$j$$.

## Weighted PCA in logit space

To stay close to this model, start by transforming the observed data once:

$$
\widetilde Y_{ij} =
\operatorname{logit}\!\left(\frac{X_{ij} + a}{n_j + 2a}\right),
\qquad a > 0.
$$

We typically use $$a=1/2$$. If we apply the delta method, we find that

$$
\operatorname{Var}(\widetilde Y_{ij}) \approx \frac{1}{n_j (p_{ij}+\delta_j)(1-p_{ij}+\delta_j)} \qquad \delta_j = a/n_j.
$$

The full expression is messier; the display above is only meant to capture the scale. The key point is that larger benchmarks are intrinsically more precise. In principle one could also weight by a plug-in estimate of $$p_{ij}(1-p_{ij})$$, but in practice the known counts $$n_j$$ already capture the dominant heteroskedasticity and are much stabler. This suggests fitting the low-rank component by minimizing

$$
\min_{\mu,\; B\; }
\sum_{i,j} n_j \bigl(\widetilde Y_{ij} - \mu_i - B_{ij}\bigr)^2 \quad \textrm{subject to} \operatorname{rank}(B)\le k.
$$

If $$D = \operatorname{diag}(n_1,\dots,n_d)$$, this is just ordinary PCA on
$$
(\widetilde Y - \mu \mathbf{1}^\top) D^{1/2}.
$$
In practice the algorithm is:

1. Compute the weighted row intercepts
$$
\mu_i = \frac{\sum_j n_j \widetilde Y_{ij}}{\sum_j n_j}
$$
2. Take a rank-$$k$$ SVD of the centered and rescaled matrix:
$$
U_k \Sigma_k V_k^\top = \operatorname{SVD}\left(
  (\widetilde Y - \mu \mathbf{1}^\top) D^{1/2}, k
  \right)
$$.
3. Factor the rank-$$k$$ term as
$$
L = U_k \Sigma_k^{1/2},\;
Z = \Sigma_k^{1/2} V_k^\top D^{-1/2},
$$
so that $$B \approx LZ$$ and column $$j$$ of $$Z$$ is $$z_j$$.

Unlike factor analysis, this objective is solved exactly once the rank is fixed. No retries, no delicate initialization, and no optimization babysitting.

## Robustness under misspecification

I tried a fair number of alternatives, including decomposing the probabilities directly, using a variance-stabilizing transform, dropping the weights, and methods that are attractive in the fully well-specified setting. I also simulated a range of data-generating processes: the well-specified case, mild misspecification such as using the wrong rank, and more complicated settings with

- sparse omitted-factor residuals on a subset of datasets,
- dataset-specific affine warps,
- global nonlinear warps of the logits,
- balanced and highly imbalanced dataset sizes.

The qualitative pattern was consistent. Weighted PCA in logit space was almost always near the top by out-of-sample performance, not just training fit. The proximal likelihood-based variant below could sometimes do a bit better, but the plain weighted-PCA fit was far simpler and much harder to derail.

## Partial data

Real benchmark matrices are incomplete. Let $$\Omega$$ be the set of observed model-benchmark pairs. The above ideas extend cleanly.

For weighted PCA, define the smoothed empirical logits only on $$\Omega$$ and then alternate the following steps:

1. initialize missing cells with the observed row intercepts,
2. run the same weighted SVD on the filled-in matrix,
3. replace only the missing cells by the current low-rank fit,
4. repeat until the imputations stabilize.

This hard-impute loop reuses the complete-data routine almost unchanged.

## Proximal weighted-PCA IRLS

The one method that was consistently competitive with, and sometimes slightly better than, weighted PCA was Iteratively Reweighted Least Squares (IRLS) with a proximal regularization toward the weighted-PCA solution. Let $$\eta^{\mathrm{pca}}$$ be the weighted-PCA fit and let $$J(\theta)$$ be the binomial negative log-likelihood. Instead of minimizing only $$J(\theta)$$, which can overfit under misspecification, solve

$$
J_{\tau}(\theta)=J(\theta)+
\frac{\tau}{2}
\sum_{i,j} n_j \bigl(\eta_{ij}(\theta) - \eta^{\mathrm{pca}}_{ij}\bigr)^2.
$$

Here $$\theta=(\mu,L,Z)$$ parameterizes

$$ 
\eta_{ij}(\theta)=\mu_i + \langle L_i , z_j\rangle.
$$ 

At the current iterate $$\eta^{(t)}$$, define

$$
p_{ij}^{(t)}=\sigma(\eta_{ij}^{(t)}),\qquad
w_{ij}^{(t)}=n_j p_{ij}^{(t)}(1-p_{ij}^{(t)}),
$$

and the IRLS working response

$$
r_{ij}^{(t)}=
\eta_{ij}^{(t)}+
\frac{X_{ij}-n_j p_{ij}^{(t)}}{w_{ij}^{(t)}}.
$$

Then the local quadratic problem is

$$
\min_\theta
\frac12\sum_{i,j}
w_{ij}^{(t)}
\bigl(r_{ij}^{(t)}-\eta_{ij}(\theta)\bigr)^2
+
\frac{\tau}{2}\sum_{i,j}
n_j\bigl(\eta_{ij}(\theta)-\eta^{\mathrm{pca}}_{ij}\bigr)^2.
$$

Combining the two quadratic terms entrywise gives

$$
\bar w_{ij}^{(t)} = w_{ij}^{(t)}+\tau n_j,
\qquad
\bar r_{ij}^{(t)}=
\frac{
w_{ij}^{(t)} r_{ij}^{(t)}+\tau n_j \eta^{\mathrm{pca}}_{ij}
}{
w_{ij}^{(t)}+\tau n_j
}.
$$

So each proximal IRLS step is exactly the same alternating weighted least-squares update as ordinary IRLS, but with $$\bar w^{(t)}$$ and $$\bar r^{(t)}$$ in place of $$w^{(t)}$$ and $$r^{(t)}$$. In other words, the proximal term acts like a pseudo-observation centered at $$\eta^{\mathrm{pca}}$$ with weight $$\tau n_j$$. For missing entries the likelihood weight is zero, so the update falls back to $$\bar r_{ij}^{(t)}=\eta^{\mathrm{pca}}_{ij}$$ and $$\bar w_{ij}^{(t)}=\tau n_j$$. This keeps the likelihood fit anchored to the robust weighted-PCA solution even when the matrix is incomplete.

For incomplete data, I use the same outer structure as above: fill in the missing entries using the current parameters, then run the inner proximal-IRLS updates on that completed matrix. The important point is that the proximal term keeps the missing cells tied to the more robust weighted-PCA estimate rather than letting them drift.

By tuning $$\tau$$ we can trade off efficiency ($$\tau \to 0$$) and robustness ($$\tau \to \infty$$). In practice, I have found $$\tau = 0.25$$ to be a reasonable default.

## Remarks

If you only want one method, weighted PCA in logit space is the one I would start with. It uses the right scale, respects that some benchmarks are much more precise than others, extends naturally to missing data, and has no tuning parameter beyond the rank. For selecting the rank, one reasonable option is bootstrap-based model selection. If you want a bit more likelihood fidelity without giving up robustness, the proximal IRLS variant is the natural next step.
