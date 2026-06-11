# oscesim

A simulation framework for studying the psychometric properties of Objective Structured Clinical Examinations (OSCEs) under a Generalizability Theory design.

---

## Background

OSCEs are widely used in health professions education to assess clinical competence. Each candidate rotates through a series of stations, and at each station one or more examiners rate their performance. The resulting scores reflect not only the candidate's true ability but also systematic and random variation introduced by the specific stations and examiners encountered — a measurement problem well-suited to Generalizability Theory (G-theory).

This simulation framework was developed to study how design features of an OSCE — in particular the number of stations — affect score reliability, the precision of the passing standard, and the accuracy with which candidates are classified as competent or not yet ready.

---

## Simulation approach

### Data-generating model

Each simulated OSCE follows a fully-crossed G-theory design in which candidates are observed at every station, with examiners nested within stations. The observed score for a given candidate at a given station is modelled as:

```
station_score = true_score + station_effect + examiner_effect + error_effect
```

Each component is drawn independently from a Beta distribution (see below). The station, examiner, and error effects are mean-centred after sampling so that they average to zero across the simulated cohort, and the grand mean of station scores therefore equals the mean candidate true score.

| Component | Interpretation |
|---|---|
| `true_score` | Candidate's latent ability, scaled to a 0–100 metric |
| `station_effect` | Difficulty deviation of the station from the mean station |
| `examiner_effect` | Stringency deviation of the examiner, plus an individual slope modifier that captures idiosyncratic scale usage |
| `error_effect` | Residual within-cell variation not attributable to any of the above facets |

In addition to the additive stringency effect, each examiner is assigned an individual slope modifier drawn from a Uniform distribution. This modifier scales how steeply the examiner maps candidate performance onto scores, reflecting the well-documented tendency for some examiners to compress or expand the range of marks they award.

### The Beta distribution as a modelling choice

The Beta distribution is a natural choice for generating scores and score-like quantities in this simulation. It is defined on the interval (0, 1) — easily rescaled to any bounded range such as 0–100 — and it can take a wide variety of shapes depending on two positive shape parameters, conventionally called α (alpha) and β (beta):

- When α = β the distribution is **symmetric** about its midpoint. Small values (e.g., α = β = 1) produce a flat, uniform distribution; larger values (e.g., α = β = 20) produce a tightly concentrated bell around the centre.
- When α > β the distribution is **skewed toward higher values** (a high-scoring cohort); when α < β it is **skewed toward lower values**.
- The theoretical mean is α / (α + β) and the variance is αβ / [(α + β)²(α + β + 1)], so both the location and spread of the distribution can be controlled by choosing α and β appropriately.

In the simulation, shape parameters are specified separately for each facet (candidates, stations, examiners, residual error), allowing the researcher to calibrate each source of variation to match empirical data or a theoretical scenario of interest.

### Standard setting: Borderline Regression Method

After scores are generated, the Borderline Regression Method (BRM) is applied to determine a station-level passing standard. Each examiner assigns a global rating to every candidate they observe, derived from a linear mapping of station scores that also incorporates the examiner's individual slope modifier. A regression of station score on global rating is then fitted within each station, and the predicted score at the borderline global rating level is taken as that station's cut-score. The overall OSCE pass score is the mean of the station cut-scores.

This mirrors the procedure used in many real OSCE programmes and allows the simulation to study how sampling variability in examiners and candidates propagates into variability in the derived passing standard. Because the true underlying pass score is known by construction, the simulation can quantify how closely the BRM-derived standard recovers it.

### Classification accuracy

For each simulated OSCE, candidates are classified as pass or fail on the basis of the observed OSCE score relative to the BRM-derived pass score (or, alternatively, a fixed administrative cut-score). Because the simulation generates both observed and true scores, these classifications can be compared against a ground truth defined by the candidate's true score relative to the true passing standard:

- **Pass rate** — proportion of candidates who pass under the observed scoring
- **N competent fail** — candidates who were truly competent but failed (false positives)
- **Share of failing that are competent** — false positive rate among observed failures; indicates how often the examination wrongly rejects a competent candidate
- **N not-ready pass** — candidates who were truly not ready but passed (false negatives)
- **Share of passing that are not ready** — false negative rate among observed passes; indicates how often the examination wrongly certifies an unprepared candidate
- **Overall accuracy** — proportion of candidates correctly classified

### Psychometric analysis

Each simulated dataset is analysed with a three-facet random-effects model fitted with the `lme4` package in R:

```
station_score ~ 1 + (1 | candidate) + (1 | station) + (1 | examiner)
```

The variance components estimated from this model partition the total observed score variance into contributions from candidates, stations, examiners, and residual error. These components are then used to compute standard G-theory indices:

- **G-coefficient (Eρ²)** — reliability of scores for relative (rank-order) decisions; analogous to Cronbach's alpha but derived from the G-theory framework. Only residual variance contributes to relative error because facet means cancel when candidates are compared to one another.
- **Phi coefficient (Φ)** — reliability for absolute decisions such as pass/fail against a fixed standard; station and examiner variance contribute to error because they shift the absolute level of scores.
- **SEM (relative and absolute)** — standard errors of measurement corresponding to each decision type, expressed on the same scale as scores.

---

## Code structure

The simulation is organised into a small library of R functions in the `func/` directory, plus top-level run scripts.

### Function files (`func/`)

| File | Purpose |
|---|---|
| `distributions.R` | Samples random effects for each G-theory facet from Beta (or Uniform) distributions. One function per facet: `CandDistr()`, `ExaminerDistr()`, `StationDistr()`, `ErrorDistr()`. |
| `simulate_osce.R` | Main simulation function `SimulateOSCE()`. Calls the distribution functions, assembles the G-theory design matrix, applies BRM standard-setting, and returns one data frame per simulated OSCE administration. |
| `scoring.R` | Helper functions for the BRM pipeline: `CalcGlobalLm()` (score-to-global-rating mapping), `StandardSetting()` (regression-based cut-score), `CalcOscePass()` (mean cut-score across stations). |
| `analyse_osce.R` | `AnalyseOSCE()` fits the G-theory mixed model to a simulated dataset and returns a one-row summary of variance components, reliability indices, and classification accuracy statistics. |
| `table_osce.R` | Two table-building functions. `TableOSCE()` displays sampled individual runs alongside the mean across all replications. `TableOSCEConditions()` compares condition means in a vertically-oriented layout with conditions as columns and metrics as rows grouped into sections. Both produce publication-ready `flextable` output and can optionally save to Word. |

### Run scripts

| File | Purpose |
|---|---|
| `_runsim_only.R` | Runs a single condition (the Homer 2020 parameter set) for a small number of draws and produces a summary table. Good for checking the pipeline end-to-end. |
| `_runsim_stations.R` | Full study varying the number of stations (6, 18, 35) across many replications. Produces per-condition tables and a cross-condition comparison table. |

### Typical workflow

```
SimulateOSCE()      # generate one synthetic OSCE dataset
      ↓
AnalyseOSCE()       # fit G-theory model, compute accuracy stats → one-row summary
      ↓
rbind() across runs # stack summaries from all replications
      ↓
TableOSCE()         # per-condition table (sampled runs + mean)
TableOSCEConditions() # cross-condition comparison table
```

---

## Simulation design

Simulation studies are run as full factorial designs in which one or more design factors are varied across conditions — for example, the number of stations (6, 18, or 35). Each condition is replicated many times (e.g., 50 or 1000 runs) to obtain stable estimates of expected outcomes and their variability. Results are summarised as means across replications and presented in publication-ready tables.

### Key simulation parameters

| Parameter | Description |
|---|---|
| `stations` | Number of OSCE stations |
| `candidates` | Number of candidates |
| `examiners_per_station` | Number of examiners available per station |
| `cand_distr_prop` | Shape parameters (α, β) for the candidate true-score distribution |
| `stations_distr_prop` | Shape parameters for the station difficulty distribution |
| `examiner_distr_prop` | Shape parameters for the examiner stringency distribution |
| `examiner_slope_fact` | Bounds of a Uniform distribution for examiner slope modifiers |
| `error_distr_prop` | Shape parameters for the residual error distribution |
| `brm_intercept` | Expected score for a borderline candidate (BRM anchor) |
| `brm_slope` | Score range mapped to one global-rating unit |
| `cut_score` | Fixed administrative cut-score (used as an alternative to BRM) |

---

## Dependencies

- **lme4** — mixed-effects model for G-theory analysis
- **flextable** — publication-ready tables
- **officer** — Word document export

---

*This README was generated with the assistance of Claude AI (Anthropic). The simulation code and methods were developed by the project authors.*
