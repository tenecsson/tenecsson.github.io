---
title: "The Impatient Boss Problem and Choosing your Confidence Sequence"
date: 2026-04-04
permalink: /posts/impatient-boss/
author: max
tags:
  - algorithms
  - bandits
  - confidence-sequences
---

# The Impatient Boss Problem and Choosing your Confidence Sequence

Suppose you are running an online experiment with a bandit over $$k$$ treatments. Let's say you use an upper confidence bound (UCB) algorithm to select arms. You need to form valid confidence sequences for the arm means, and you have to choose *where they are tight*. Some constructions spend their error budget on the near future, some on the far future, and all of them are valid. 

If the experiment were guaranteed to run for a fixed horizon $$T$$, the usual question would be which bound is best tuned for that horizon. But here the boss is impatient: he may stop the experiment at any time if early regret looks too large.

This note asks a more relevant question:

> If the shutdown time is random, how should you tune a time-uniform confidence sequence? 

As an illustrative example, we will use the classic Robbins mixture martingale. Similar considerations apply to other confidence sequences. Robbins' method mixes a supermartingale with a zero-mean Gaussian prior over the nuance parameter $$\lambda$$. The variance of that prior, $$\rho^2$$, determines the exact shape of the sequence and the horizon at which it is tight. 

By modeling this, we can relate the width of the prior $$\rho^2$$ directly to the probability $$p$$ of the boss pulling the plug.

## 1. Setup & The Robbins Mixture

We have $$k$$ arms with sub-Gaussian means
$$
\mu_1, \mu_2, \dots, \mu_k.
$$

Let the best arm have mean $$\mu_* = \max_i \mu_i$$, and the runner-up have mean $$\mu_{(2)}$$. Define the top-two gap
$$
\Delta = \mu_* - \mu_{(2)} > 0.
$$

The experiment is stopped at a random time $$\tau \sim \mathrm{Geom}(p)$$ on $$\{1,2,\dots\}$$, so
$$
\Pr(\tau \ge t) = (1-p)^{t-1}.
$$

To track the means, we construct a Robbins mixture martingale. For a standard sub-Gaussian arm, we take the basic supermartingale $$M_t(\lambda) = \exp(\lambda S_t - \lambda^2 t / 2)$$ and integrate it over a Gaussian prior $$\lambda \sim \mathcal{N}(0, \rho^2)$$. By Ville's inequality, this yields a confidence sequence whose radius at time $$t$$ is roughly:
$$
\mathrm{rad}_t(\rho) \approx \sqrt{\frac{t\rho^2 + 1}{t^2 \rho^2} \log\left(\frac{\sqrt{t\rho^2 + 1}}{\alpha}\right)}
$$

If you analyze this radius, it shrinks fastest and is tightest around the intrinsic time:
$$
t \approx \frac{1}{\rho^2}
$$

Because it is easier to think in terms of time, let's define the *nominal horizon* of this bound as $$h = 1/\rho^2$$. A wide prior (large $$\rho^2$$) creates a small nominal horizon, pulling the tightness early. A narrow prior (small $$\rho^2$$) pushes the tightness into the future. 

Which value of $$\rho^2$$ minimizes expected regret at the random shutdown time?

## 2. Geometric Shutdown Means Discounted Regret

Let $$r_t(\rho)$$ be the instantaneous regret at time $$t$$ for the algorithm tuned with prior variance $$\rho^2$$. Then
$$
\mathbb{E}[R_\tau(\rho)]
= \sum_{t \ge 1} \Pr(\tau \ge t)\,\mathbb{E}[r_t(\rho)]
= \sum_{t \ge 1} (1-p)^{t-1}\,\mathbb{E}[r_t(\rho)].
$$

Geometric stopping exactly converts the objective into discounted regret with a discount factor of $$1-p$$.

This already gives the zeroth-order answer: If you do not use gap information, the only natural timescale in the problem is the discounted lifetime $$1/p$$. That implies setting the tightness point $$1/\rho^2 \approx 1/p$$, which means choosing a prior variance $$\rho^2 \approx p$$. 

But this is only a first guess. Once the gap is known, the optimal prior is different.

## 3. A Simple Model for the Mixture's Trajectory

To optimize $$\rho^2$$, we need a rough model of how the Robbins mixture behaves over time. Let's write everything in terms of the nominal horizon $$h = 1/\rho^2$$. 

We will use two standard approximations for how the confidence sequence explores and commits.

First, the algorithm needs enough informative samples to shrink the radius down to the gap size $$\Delta$$. Based on the Robbins radius, achieving $$\mathrm{rad}_t \approx \Delta$$ requires a learning phase of roughly
$$
N(h) \approx \frac{a}{\Delta^2}\log h
$$
rounds before it has effectively separated the best arm from the runner-up. The constant $$a > 0$$ absorbs the exact log factors.

Second, after that learning phase, the residual probability of being wrong—driven by the polynomial tail of the mixture—is roughly
$$
q(h) \approx \frac{C}{h}
$$
where $$C > 0$$. 

The tradeoff is clear:
* A **narrow prior** (large $$h$$) makes the bound conservative early on, so the learning phase $$N(h)$$ grows, but the asymptotic mistake probability $$q(h)$$ drops.
* A **wide prior** (small $$h$$) allows the algorithm to commit earlier, but increases the chance of a wrong commitment.

## 4. A Two-Phase Approximation to Discounted Regret

Now approximate the regret trajectory by two phases:
1.  For the first $$N(h)$$ rounds, the algorithm is still learning and incurs regret of order $$\Delta$$ per round.
2.  After that, it identifies the best arm, but with probability $$q(h)$$ it effectively commits incorrectly and continues paying regret $$\Delta$$ forever.

Under this approximation, expected discounted regret is:
$$
J(h)
\approx
\Delta \sum_{t=1}^{N(h)} (1-p)^{t-1}
\;+\;
\frac{\Delta}{p}\,q(h)\,(1-p)^{N(h)}.
$$

The first term is the discounted cost of exploration. The second term is the discounted future cost of being wrong. Evaluating the geometric sum gives:
$$
J(h)
\approx
\frac{\Delta}{p}
\left(
1 - (1-p)^{N(h)} + q(h)(1-p)^{N(h)}
\right).
$$

## 5. Optimize Over the Prior

Let $$s = -\log(1-p)$$. Then the survival probability after the learning phase is:
$$
(1-p)^{N(h)}
= \exp\!\bigl(-s N(h)\bigr)
\approx
\exp\!\left(-s \frac{a}{\Delta^2}\log h\right)
= h^{-\eta},
$$
where
$$
\eta = \frac{a s}{\Delta^2}.
$$

Substituting our mixture tail probability $$q(h) \approx C h^{-1}$$, the objective becomes:
$$
J(h)
\approx
\frac{\Delta}{p}
\left(
1 - h^{-\eta} + C h^{-1-\eta}
\right).
$$

To find the optimal tuning, differentiate with respect to $$h$$:
$$
\frac{dJ}{dh}
\propto
\eta h^{-\eta-1} - C(1+\eta)h^{-\eta-2}.
$$

Setting this to zero reveals the optimal nominal horizon:
$$
h_* = C \frac{1+\eta}{\eta} = C \left(1 + \frac{\Delta^2}{a s}\right).
$$

Because $$h = 1/\rho^2$$, the exact optimal prior variance inside this approximation is:
$$
\rho^2_* = \frac{1}{C \left(1 + \frac{\Delta^2}{a s}\right)}
$$

## 6. The Small-$$p$$ Regime

When the boss is fairly patient in the sense that $$p$$ is small, we can approximate $$s = -\log(1-p) \approx p$$.

The optimal nominal horizon simplifies to:
$$
h_* \approx C \left(1 + \frac{\Delta^2}{a p}\right) \asymp \frac{\Delta^2}{p}.
$$

Converting this back to the language of the Robbins mixture, the optimal Gaussian prior variance scales as:
$$
\rho^2_* \asymp \frac{p}{\Delta^2}.
$$

This is the main conclusion. 

The crude scale $$\rho^2 \approx p$$ is only the gap-free answer. When the problem difficulty is known, the optimal prior variance is scaled by the inverse information rate $$1/\Delta^2$$. 

## 7. How Much Exploration Does This Actually Mean?

It is useful to separate the tightness point of the sequence from the actual number of exploration rounds the algorithm executes. 

We just established that the sequence should be tightest around time:
$$
t \approx \frac{1}{\rho^2_*} \asymp \frac{\Delta^2}{p}
$$

But the number of rounds needed to actually sort out the top two arms is much smaller:
$$
N(\rho_*)
\approx
\frac{a}{\Delta^2}\log\left(\frac{1}{\rho^2_*}\right)
\asymp
\frac{1}{\Delta^2}\log\!\left(1 + \frac{\Delta^2}{p}\right).
$$

The algorithm needs a prior tuned to be tight at $$t \asymp \Delta^2/p$$, but it only takes logarithmically many rounds in that quantity to resolve the top-two comparison and stop exploring.

## 8. The Physical Meaning of the Prior

Situating this in the Robbins mixture gives a very clean, physical interpretation to the Gaussian prior: **the width of the prior $$\rho^2$$ reflects your belief about the boss's impatience, scaled by the difficulty of the problem.**

* **The Impatient Boss (large $$p$$) or Hard Problem (small $$\Delta$$):** The experiment is likely to be shut down before you can gather massive amounts of data, or the gap is so small that exploration is inherently expensive. You must bet on getting lucky early. You do this by setting a **wide prior** (large $$\rho^2$$). This sacrifices asymptotic tightness to rapidly shrink the bounds in the first few dozen rounds.
* **The Patient Boss (small $$p$$) or Easy Problem (large $$\Delta$$):** The experiment will likely run for a long time, or the gap is so obvious that you don't need early tightness to find it. You have the luxury of time. You should use a **narrow prior** (small $$\rho^2$$). This pushes the tightness point far into the future, yielding a bound that converges optimally without paying an early-stopping penalty.

## 9. Caveats

This argument is intentionally coarse. It is not an exact regret theorem for the Robbins mixture martingale. It is an approximation that exposes the correct timescales and scaling laws. 

The constants $$a$$ and $$C$$ matter in practice, and they can be worked out explicitly by taking the exact derivative of the Robbins bound rather than a simplified $$N(h)$$ phase model. Alternatively, if your job is to do / oversee such experiments you may have an idea of what $$p$$ and $$\Delta$$ typically are. 

As much as I find coarse arguments like this a bit lacking, the main message is robust. A geometric shutdown time doesn't ask for a one-size-fits-all confidence sequence. It asks for an exploration-versus-mistake tradeoff optimized for discounted regret, achieved by setting your prior variance to:
$$
\boxed{
\rho^2 \sim \frac{p}{\Delta^2}
}
$$
