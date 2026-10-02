# The WDFW growth-model draft and what it does and does not establish

*2 October 2026. Review of the unpublished draft "Modelling the growth of razor clam (Siliqua patula) in Washington State coast" (Word file dated 18 January to 1 February 2008; 2,710 words; authors not named in the file, but the data section is addressed to "Henry" and signed "Dan", so Henry Cheng and Dan Ayres of WDFW are the evident authors, **to be confirmed by the owner**). The file was supplied by the owner on 2 October 2026 and is not committed to the repository pending permission. This note records what the draft contains, checks its parameters against the survey length data, and fixes the citation that the legacy notebook garbled.*

## 1. What the draft is

A methods paper, never published, on fitting a von Bertalanffy growth curve to mark-recapture data when the age at first capture is unknown. The method is that of Cheng and Kuk (2002, *Biometrics* 58:459–462, doi 10.1111/j.0006-341x.2002.00459.x **[V]** record checked on Crossref; developed for western rock lobster): the unknown age at first capture (square-transformed) and the individual growth coefficient are bivariate normal random effects, fitted as a nonlinear mixed model, and compared with the Fabens (1965) increment method. The draft also fits linear and nonlinear shell length–width relations.

**Data.** Clams were planted in February 2006 along two transects in each of the Copalis and Long Beach razor clam reserves, resampled by the pumped-area method every six months, tagged (PIT tags on all clams under about 75 mm and on a third of larger ones; shell etching on the rest) and replanted. Recaptures to 2007: 75 clams at Copalis (9 twice) and 97 at Long Beach (8 twice); minimum interval 130–142 days, maximum 1.5 years; first-capture lengths 31–137 mm at Copalis (mean 93.7) and 39–131 mm at Long Beach (mean 105.1). A note in the text says more data were collected in January 2008 and are not in the fit.

**Parameter estimates (Table 2 of the draft, shell length).**

| Beach | Model | L∞ (mm) | K (yr⁻¹) | Mean age at first capture (model scale) | corr(L∞, K) |
|---|---|---|---|---|---|
| Copalis | Fabens | 140.16 (2.43) | 1.14 (0.08) | | −0.82 |
| Copalis | Cheng and Kuk | **143.17 (1.78)** | **1.00 (0.06)** | 1.01 (0.05) | −0.69 |
| Long Beach | Fabens | 138.52 (1.96) | 1.16 (0.09) | | −0.85 |
| Long Beach | Cheng and Kuk | **141.67 (1.00)** | **0.98 (0.04)** | 1.16 (0.04) | 0.66 |

Shell width: L∞ 60.8 and 57.5 mm, K 0.89 and 0.90. Length–width: nonlinear fits (length = a·widthᵇ with b = 0.85 and 0.82) beat linear fits (ratio 2.5) by AIC; the ratio of length to width falls as clams grow. The draft reports correlations of −0.94 to −0.96 between the individual growth coefficient and the age at first capture, which it reads as faster-growing clams being caught younger.

The bold values are exactly the parameters the legacy notebook uses (`01_code/razor-clam-recruitment-analysis.Rmd`, "GROWTH MODEL" block), so the provenance is now established.

**Defects of the draft to be aware of.** It is a 2008 working draft: the species is twice given as *Panulirus cygnus* (copied from the lobster paper); equations and figures are placeholders in the file; the random-effects correlation for Long Beach is reported as +0.66 where every other entry is negative (sign or transcription to check); n in Table 1 (159 and 202) counts measurements, not clams; no standard errors are given for the width L∞ random-effects fit beyond the table; and the newer 2008 recaptures are not included.

## 2. What the design can and cannot identify

A mark-recapture growth study with no known-age animals identifies K and L∞ from growth *increments* between captures. It does not identify the position of the curve on the age axis: the "age at first capture" in the model is defined relative to a curve that passes through zero length at age zero (t0 = 0 by construction). The draft's mean first-capture ages (about 1.0–1.2 years for clams averaging 94–105 mm) are therefore on the model's own scale and say nothing about the true age of a 45 mm or a 90 mm clam. The notebook's size-at-age statements ("age 1.0: 91 mm"; "at 75 mm about 0.74 yr") inherit this t0 = 0 assumption, and so do its age classes ("young-of-year < 0.8 yr" for pre-recruits).

## 3. Check against the survey length data

The survey length-frequency data can locate the curve on the age axis, because the year-old cohort (year class Y−1 at survey Y) is the dominant group below 76 mm at every beach and the beaches are surveyed on different dates. The answer depends on how that cohort is identified, so `02_cohort_diagnostics.R` (f) does it two ways for every beach-year with at least 150 measurements (140 beach-years), assigns the cohort an age of (survey date − 1 August of the previous year), and solves the draft's curve for the t0 that places it there [`tables/growth_model_check.csv`, `growth_model_check_by_year.csv`, `fig_growth_curve_check.png`]:

- **Kernel mode.** The density mode of lengths between 15 and 72 mm (current-year settlers of 20 mm or less excluded after mid-July). Simple, but in some beach-years it lands on a secondary group of 20–30 mm clams rather than on the main cohort.
- **Mixture component.** The mean of the year-old component of a 3- or 4-component normal mixture fitted to the whole length range (settlers where BIC supports a fourth component, year-old, two-year-old, older). Uses all the information, but in strong, fast-growing years it can merge the year-old cohort with slow two-year-olds and drift upward.

| Beach | Beach-years | Median survey day | Year-old cohort, median (mm): mode / mixture | Implied t0 (yr), mean ± SD: modes / mixture |
|---|---|---|---|---|
| Long Beach | 29 | 157 (6 Jun) | 43 / 48 | 0.47 ± 0.20 / 0.36 ± 0.18 |
| Copalis | 28 | 168 (17 Jun) | 41 / 53 | 0.51 ± 0.18 / 0.36 ± 0.17 |
| Mocrocks | 29 | 199 (18 Jul) | 48 / 62 | 0.53 ± 0.17 / 0.40 ± 0.14 |
| Kalaloch | 25 | 205 (24 Jul) | 59 / 69 | 0.49 ± 0.21 / 0.37 ± 0.13 |
| Twin Harbors | 29 | 221 (9 Aug) | 64 / 63 | 0.54 ± 0.22 / 0.43 ± 0.19 |
| All | 140 | | | **0.51 ± 0.19 / 0.39 ± 0.17** |

Four things follow.

1. **The draft's K and L∞ are consistent with the survey data once t0 is about 0.4–0.5 yr.** Beaches surveyed two months apart, whose year-old cohorts differ by 15–20 mm, give the same t0 to within 0.07 yr under either identification. The curve L = L∞ (1 − exp(−K (t − t0))) with t0 in that range describes the first two years, the offset representing slow growth through the first winter after settlement (which the increment data, mostly from clams above 75 mm, could not see). Under the single assumption of 1 August settlement, the two identifications bracket the answer; an earlier settlement date would raise t0 by the same amount.
2. **The notebook's age scale is roughly half a year too young.** Pre-recruits at June surveys are about 0.85–1.0 yr old, not "< 0.75 yr"; the 76 mm boundary is crossed at about 1.14–1.27 yr (September to November of the year after spawning), not 0.76 yr. This is the same error as the "lag-0" cohort misalignment in `docs/methodology-review.md`, now with its cause: the growth curve used to label ages had no t0.
3. **The year-class alignment used in the pipeline is confirmed, with one qualification.** A year class is expected at 39–52 mm on 1 June, 63–72 mm on 1 September of Y+1 and 103–110 mm on 1 June of Y+2, so it is counted as pre-recruits at survey Y+1 and as recruits at survey Y+2 at the June- and July-surveyed beaches. At the August surveys (Twin Harbors, some Kalaloch years) the fast tail of the year-old cohort reaches 76 mm: the mixture puts part of that cohort above 76 mm in 55% of Twin Harbors beach-years and 48% at Mocrocks (41% overall), so the 76 mm split cuts through the year-old cohort there in strong-growth years. That is task T14, and the growth curve with t0 supplies the prior a length-mixture separation needs.
4. **A small-clam group is present at June surveys too.** A fourth component of 20–25 mm clams was supported in 41–57% of beach-years at the June-surveyed beaches, where it cannot be current-year settlement. It is either protracted or late settlement (autumn of the previous year) or a slow-growing fraction; either way "settlement on 1 August" is a simplification, and pre-recruits at June surveys are not a single cohort.

## 4. What changes in the repository

- **Citation.** The notebook and all documents now cite the parameters as: Cheng YW, Ayres D [authorship to confirm] (2008, unpublished draft) *Modelling the growth of razor clam (Siliqua patula) in Washington State coast*, Washington Department of Fish and Wildlife, 18 pp. **[V]** (read in full); and the method as Cheng YW, Kuk AYC (2002) *Biometrics* 58:459–462 **[V]** (Crossref record). "Cheng & Kuk (2002)" alone was the method reference, not the source of the razor clam parameters.
- **Ages in the manuscript.** Size classes remain the unit of analysis. Where an age is needed (Section 3.2, the alignment argument), the manuscript states the curve with the empirical t0 range (0.4–0.5 yr) and its basis.
- **Open.** The owner should confirm the authorship and whether the draft may be deposited with the repository; the January 2008 recaptures, if they exist, would extend the fit below 75 mm and could estimate t0 directly. A length-mixture model by survey date (task T14) would replace the single-mode check with a proper cohort separation.
