---
title: "Stochastic Parrots"
date: 2026-02-26
permalink: /posts/stochastic-parrots/
author: max
tags:
  - polemic
  - AI
  - LLM
---

### The “Stochastic Parrot” Meme Is Itself a Parrot

“Stochastic parrot.” “Spicy autocomplete.” “Regurgitation.”
Notice the irony: the people chanting these phrases are doing exactly what they accuse the model of doing—**repeating a cached sequence** to avoid thinking.

A meme is not a model. It’s a verbal shortcut for people who want the sensation of skepticism without the burden of precision.

So let’s do this properly: kill the strawman, replace it with the steelman, then kill that too.

---

## I. The Strawman: “It Just Regurgitates”

This is the version most people mean, and it is mostly wrong—because it relies on a slippery definition.

### First: define “regurgitation” or stop talking

Does “regurgitation” mean:

* verbatim reproduction of long spans?
* close paraphrase of a single source?
* reuse of common idioms?
* producing something *similar in type* to what it saw?

If your definition expands until it includes “using English you learned by reading English,” then congratulations: you’ve proven that *learning exists.* That’s not a critique; that’s an observation with a sneer.

**Aphorism:** A definition that can’t be falsified is a costume, not a claim.

### Second: compositionality is the whole point

The space of possible outputs is astronomically larger than any dataset. The interesting question is not whether pieces were seen before (of course they were), but whether the system can **compose** them under constraints it has not seen in that exact configuration.

Constraint satisfaction is not what copying looks like.

* “Write code that compiles under these constraints.”
* “Rewrite this argument to preserve meaning but obey these rules.”
* “Maintain invariants across a long chain of dependencies.”

You can call that “autocomplete” the way you can call a legal brief “just typing.” The description is technically true and intellectually useless.

### Third: the honest concession

Yes, these systems can memorize. Yes, they sometimes emit training-like material.
But that proves only **capacity**, not **essence**.

**Aphorism:** “It can copy” does not entail “it can only copy,” unless you’re allergic to logic.

So the strawman dies: “mere regurgitation” is either false (too narrow) or vacuous (too broad).

---

## II. The Steelman: “A Plausibility Machine, Not a Truth Machine”

Here’s a serious critique, stated cleanly:

> The system is trained primarily to produce text that \*fits\* the distribution of human text. “Fits” is not “true.” It can sound right while being wrong. It can imitate reasoning without being anchored to reality. Under distribution shift, it can fail in strange ways. And if you optimize it against evaluators, it may learn to please evaluators.

This critique has teeth. It points to real failure modes:

* **Objective mismatch**: plausible ≠ correct.
* **Brittleness**: it works until it doesn’t, and the “doesn’t” can be abrupt.
* **Tail risk**: rare-but-catastrophic mistakes are not dismissed by average-case performance.
* **Evaluator gaming**: when judged by proxies, systems learn proxies. That’s what optimization does.

This is adult skepticism.

Now here’s where the steelman often smuggles in an illegitimate conclusion:

> Therefore it’s not “really” reasoning; it’s still “just” autocomplete.

That “therefore” is doing all the dishonest work.

---

## III. Taking Down the Steelman

The steelman is right about **risk** and **objective mismatch**—and wrong when it tries to downgrade **capability** into a mere parlor trick.

### Learning from text doesn’t disqualify learning

Humans learn from text. Engineers learn from manuals. Mathematicians learn from papers.
If you want to argue “text learning is fake learning,” be consistent and burn your library.

What matters is whether the system internalizes **structure**—constraints, invariants, transformations—not whether every output can be traced to a prior sentence.

**Aphorism:** If “learned from examples” is your indictment, you’ve indicted every competent mind.

### Sequential token choice is decision-making, like it or not

Generation is a sequence of choices that shape what becomes possible next. That’s a policy over a growing context. Calling it “prediction” is a historical artifact of training, not a description of deployment.

And this matters because:

* Once you treat it as **action selection**, the right question becomes:
  *Does the local scoring of candidates serve as a useful heuristic for long-horizon quality?*

### Greedy decoding is a reasonable search procedure

Greedy decoding is not mystical. It’s **hill-climbing with a learned heuristic**.

Why can it work?

* The model has been trained on vast amounts of text where *local choices* correlate with *global coherence*.
* Add feedback-driven training (preference, critique, tool results), and the system is further shaped so local choices correlate with what humans or evaluators deem “good.”

So greedy isn’t “optimal.” It’s often **good enough** because the heuristic is dense: it’s been hammered by a distribution full of constraints.

Beam search, sampling, reranking—these are just ways to spend more compute to hedge against local traps. But the existence of better search doesn’t resurrect the “parrot” claim; it just says the heuristic isn’t perfect. Of course it isn’t.

**Aphorism:** “Not perfect” is not the same as “fake.”

### The steelman’s real lesson is about payoffs and tails

If you want to attack these systems, the strongest line is not metaphysical (“not real reasoning”), it’s operational:

* What happens under adversarial conditions?
* What is the cost of the rare failure?
* How does the system behave when incentives shift?
* Where does it optimize the proxy instead of the goal?

That is where the danger lives. Not in any bird metaphors.

**Aphorism:** The serious critique is about incentives and tail losses; the parrot critique is for people who confuse vibe with analysis.

---

## Closing: A Simple Challenge That Ends the Meme

Next time someone says “stochastic parrot,” ask them three questions:

1. **Define regurgitation** in a falsifiable way.
2. **Name the failure mode** you actually care about (truth? calibration? tails? incentives?).
3. **Specify the test** that would change your mind.

If they can’t answer, you’re not hearing an argument. You’re hearing autocomplete—done by a human.


