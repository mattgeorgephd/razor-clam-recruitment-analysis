# manuscript

Draft manuscript built on the robust re-analysis.

| File | Contents |
|---|---|
| `manuscript.md` | Source of truth: Markdown draft (v0.1, 2026-10-02) with embedded figures and reference list |
| `manuscript.docx` | Word rendering for co-authors. Regenerate after editing `manuscript.md`; do not edit the .docx directly |

Regenerate the Word file from this folder with:

```bash
pandoc manuscript.md -o manuscript.docx --resource-path=.:..
```

## Rules for editing

- **Numbers.** Every number must come from `03_analyses/robust-reanalysis/tables/`; the source table is named in square brackets next to each result. If you change the analysis, rerun `Rscript 01_code/R/run_all.R` and update the text.
- **Citations.** Each reference is flagged: **[V]** verified in source, **[A]** abstract or index record only, **[C]** to check. Resolve every [A] and [C] before submission. Do not add references without checking them.
- **TODO markers.** `TODO` markers (and bracketed placeholders) flag input that the repository cannot supply: affiliations and co-authors, the literature check, the BEUTI product documentation, WDFW sampling variances, the forecast-blindness statement, data-sharing permissions, and acknowledgements.
- **Style.** No em dashes, per the corresponding author's preference.

## Possible target journals

Fisheries Oceanography, ICES Journal of Marine Science, Canadian Journal of Fisheries and Aquatic Sciences, Marine Ecology Progress Series, Journal of Shellfish Research. The methods emphasis (survey timing, selection bias, honest validation) also suits Fish and Fisheries or Methods in Ecology and Evolution as a case study. These are suggestions to discuss, not a decision.
