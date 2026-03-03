---
title: "Empircal Bayes Factor Analysis"
date: 2026-03-03
permalink: /posts/empirical-bayes/
author: max
tags:
  - AI
  - Machine Learning
---

Factor analysis is the generalization of PCA to the case where the covariance of the noise is diagonal rather than isotropic. Unlike PCA, fitting factor analysis is tricky as the optimization process can take us to any one of many basins of attraction. Here we explore an empirical Bayes prior to mitigate these issues.

## The Model and Likelihood

Suppose \(x_n \in \mathbb{R}^p\) is a centered observation, \(n=1,\dots,N\). Factor analysis assumes
$$
x_n = \Lambda f_n + \varepsilon_n,
$$
where \(f_n \sim \mathcal N(0, I_k)\) are latent factors, \(\varepsilon_n \sim \mathcal N(0, \Psi)\) is idiosyncratic noise, and \(\Psi = \operatorname{diag}(\psi_1,\dots,\psi_p)\). The loading matrix \(\Lambda \in \mathbb{R}^{p\times k}\) captures shared structure, and the diagonal matrix \(\Psi\) captures variable-specific uniqueness.

Marginally, \(x_n \sim \mathcal N(0, \Sigma)\) with \(\Sigma = \Lambda \Lambda^\top + \Psi\). Given sample covariance \(S = \frac{1}{N}\sum_{n=1}^N x_n x_n^\top\), the Gaussian negative log-likelihood (up to a constant) is:
$$
\mathcal L(\Lambda,\Psi) = \frac{N}{2}\left[ \log\det(\Sigma) + \operatorname{tr}(S\Sigma^{-1}) \right]
$$

The factor-analysis MLE minimizes this over \(\Lambda\) and diagonal \(\Psi \succ 0\). The model is rotationally invariant in \(\Lambda\). The more serious issue is that the likelihood is nonconvex and can have many local optima.

## Empirical Bayes Prior

The classic pathology in factor analysis is that one or more uniquenesses are driven to zero, \(\psi_i \to 0\). The intuition is simple: in low-rank factor analysis, the model sometimes finds it profitable to let one factor explain a coordinate almost perfectly, assigning essentially no idiosyncratic variance to that coordinate. The likelihood can reward this, especially in small dimensions or when the covariance has a lopsided structure.

In one \(4\times 4\) example with rank (1), the sample covariance
\[
S=\begin{bmatrix}
 2.5 & 0.8 & -0.6 & 0.5\\
 0.8 & 2.6 & 0.3 & -0.3\\
-0.6 & 0.3 & 1.0 & -0.3\\
 0.5 & -0.3 & -0.3 & 1.5\\
 \end{bmatrix}
\]
gives three stable local optima for rank-1 factor analysis:
1. \(\psi \approx (0,\ 2.29,\ 0.86,\ 1.4)\)
2. \(\psi \approx (2.16,\ 2.45,\ 0,\ 1.41)\)
3. \(\psi \approx (2.26,\ 0,\ 0.96,\ 1.49)\)

These are all versions of the same phenomenon: a favorite coordinate gets its uniqueness driven to zero. 

To prevent degenerate solutions like this, we can place an inverse-gamma prior on each uniqueness: \(\psi_i \sim \operatorname{IG}(\alpha_i,\beta_i)\), which penalizes values near zero. The negative log-posterior becomes
\[
J(\Lambda,\Psi) = \frac{N}{2}\left[\log\det\Sigma + \operatorname{tr}(S\Sigma^{-1})\right] + \sum_{i=1}^p \left[ (\alpha_i+1)\log \psi_i + \frac{\beta_i}{\psi_i} \right]
\]

However, a weak or generic prior often only pushes the solutions slightly inward (e.g. \(\psi_i \approx 10^{-3}\) instead of \(0\)), and the multiple basins remain. Choosing a good prior is hard!

This is where PCA becomes useful. PCA gives a rank-\(k\) common covariance estimate \(L_{\text{PCA}}\). The diagonal residuals
\[
m_i = S_{ii} - (L_{\text{PCA}})_{ii}
\]
tell us how much variance is *not* explained by the top \(k\) principal components. Instead of choosing \(\beta_i\) arbitrarily, we choose the inverse-gamma prior so that its mode is at \(m_i\). For a common hyperparameter \(\alpha\), we set \(\beta_i = (\alpha+1)m_i\).

Now the data-driven prior says: “Before looking at the FA likelihood in detail, I think the uniqueness of coordinate \(i\) should be roughly what PCA leaves unexplained on that coordinate.”

## The empirical Bayes procedure

The full procedure is simple.

### Step 1: Form sufficient statistics
Compute the sample covariance
\[
S = \frac{1}{N}\sum_{n=1}^N x_n x_n^\top.
\]

### Step 2: do PCA
Compute the top \(k\) eigenpairs of \(S\) and form
\[
L_{\text{PCA}} = U_k \operatorname{diag}(d_1,\dots,d_k) U_k^\top,
\]

### Step 3: Choose the prior
Choose a prior strength \(\alpha_i = \alpha\), and set
\[
\beta_i = (\alpha+1)m_i.
\]
where 
\[
m_i = \max(\varepsilon,\ S_{ii} - (L_{\text{PCA}})_{ii}),
\]
with a tiny \(\varepsilon > 0\) for safety. Then the prior mode is exactly \(m_i\).

### Step 4: run EM with multiple restarts

You can choose restarts in different ways. In my experiments one initialization comes from PCA and the rest are random. But I also allow for educated guesses (warm-starts) as those will prove handy in a future post.

In the **E-step**, compute the posterior over the latent factors for each observation, \(f_n \mid x_n \sim \mathcal{N}(\mu_n, V)\). This requires computing:
\[
V = (I_k + \Lambda^\top \Psi^{-1} \Lambda)^{-1}
\]
\[
\mu_n = V \Lambda^\top \Psi^{-1} x_n
\]
From this, the expected sufficient statistics are:
\[
\mathbb{E}[f_n] = \mu_n, \qquad \mathbb{E}[f_n f_n^\top] = V + \mu_n \mu_n^\top
\]

In the **M-step**, first update the loading matrix \(\Lambda\):
\[
\Lambda^{\text{new}} = \left( \sum_{n=1}^N x_n \mu_n^\top \right) \left( \sum_{n=1}^N \mathbb{E}[f_n f_n^\top] \right)^{-1}
\]
Next, compute the expected residual variance for each coordinate \(i\). Let \(r_i\) be the \(i\)-th diagonal element of the expected residual covariance:
\[
r_i = S_{ii} - \left( \Lambda^{\text{new}} \frac{1}{N} \sum_{n=1}^N \mu_n x_n^\top \right)_{ii}
\]
Finally, update the uniquenesses \(\psi_i\) using the MAP update which incorporates the empirical Bayes prior:
\[
\psi_i^{\text{new}} = \frac{\frac{N}{2} r_i + \beta_i}{\frac{N}{2} + \alpha + 1}
\]

**Tips:**

\(\Psi\) is diagonal, so applying \(\Psi^{-1}\) is simply dividing each coordinate by \(\psi_i\). The covariance matrix \(V\) is one of the few cases where you actually need to invert a matrix. The update for \(\Lambda^{\text{new}}\) on the other hand should be done with a solve e.g. using the Cholesky factorization of \(\sum_{n=1}^N \mathbb{E}[f_n f_n^\top]\)

To compute the likelihood \(\mathcal{L}(\Lambda, \Psi)\) to track convergence, you should use the Woodbury matrix identity and the matrix determinant lemma:
\[
\Sigma^{-1} = \Psi^{-1} - \Psi^{-1}\Lambda (I_k + \Lambda^\top \Psi^{-1} \Lambda)^{-1} \Lambda^\top \Psi^{-1} = \Psi^{-1} - \Psi^{-1}\Lambda V \Lambda^\top \Psi^{-1}
\]
\[
\log\det(\Sigma) = \log\det(\Psi) + \log\det(I_k + \Lambda^\top \Psi^{-1} \Lambda) = \log\det(\Psi) - \log\det(V)
\]
This allows you to compute the log-likelihood purely with \(\mathcal{O}(p k^2)\) operations, turning an \(\mathcal{O}(p^3)\) bottleneck into a very fast computation.

## Remarks

This procedure has a pleasing interpretation: use a robust spectral method (PCA) to get the rough scale right, then let the likelihood-based latent-variable model (Factor Analysis) refine it. The empirical Bayes prior prevents the worst degeneracies by penalizing tiny \(\psi_i\). More importantly, it provides coordinate-specific scale information that keeps the optimizer away from degenerate explanations, acting as a stabilizer for factor analysis.

**Caveats to keep in mind:**
1. **The problem is still nonconvex**: Empirical Bayes regularization improves the geometry and simplifies the choice of the prior, but it does not make factor analysis convex. Multiple restarts still matter.
2. **Prior strength matters**: \(\alpha\) is a regularization knob. If \(\alpha\) is too small, the prior may not help much. If \(\alpha\) is too large, the posterior will be dominated by the prior and behave too much like PCA. In my experiments with the above matrix, \(\alpha=0.01\) still allowed multiple basins, but with \(\alpha=0.1\) all restarts (including starting from the generated solutions) converged towards a single basin.
3. **PCA residuals are a heuristic**: The PCA diagonal residuals are not the true uniquenesses; they are simply a sensible default scale.

Stay tuned for how we will use Factor Analysis as a subroutine in a more complex workflow.

