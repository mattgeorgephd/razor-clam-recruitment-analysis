# ═══════════════════════════════════════════════════════════════════════════════
# 00_correct_inputs.R — corrected copies of raw inputs, with a changelog
# ═══════════════════════════════════════════════════════════════════════════════
# The raw workbooks in 02_data/ are never edited (AGENTS.md). Where a raw value
# is demonstrably wrong or inconsistently encoded, this step writes a corrected
# copy to 02_data/corrected/ together with CHANGELOG.md, which lists every rule,
# every affected record group and the evidence, so that each change can be
# checked against the source and reversed. The pipeline reads the corrected
# copies (read_lengths() in 00_config.R); the notebook still reads the raw file.
#
# Rules for the shell-length records (All_Clams_Raw; tasks T20, T21):
#   R1  Three date encodings (ISO text, Excel serial numbers, "11-Aug-2011")
#       are parsed to one ISO date column; the raw text is kept as date_raw.
#   R2  A record whose date-year differs from its survey_year, but whose
#       month-day falls inside the window of correctly dated records of the
#       same beach-year, is a year typo: the year is set to survey_year.
#       Records that fail that test are left as recorded and flagged.
#   R3  Records without a date stay without a date (Kalaloch 2001: no dates in
#       the source); nothing is imputed here. Survey timing for such beach-years
#       is imputed from the beach median in 01_build_datasets.R and flagged.
#   R4  Shell lengths outside 3-180 mm, or missing, are flagged and kept; the
#       analyses filter on length_flag == "ok".
#   R5  Copalis 2003 has abundance estimates but no length records (T22):
#       nothing can be corrected; it is listed so the gap is not forgotten.
# Output: 02_data/corrected/shell_lengths_corrected.csv.gz, CHANGELOG.md

source(here::here("01_code", "R", "00_config.R"))

RAW_LENGTHS <- file.path(DATA_DIR, "shell_length_data-summary", "All_Beaches_shell_lengths_1997-2025.xlsx")
CORR_DIR <- file.path(DATA_DIR, "corrected")
dir.create(CORR_DIR, showWarnings = FALSE)

raw <- read_excel(RAW_LENGTHS, sheet = "All_Clams_Raw", col_types = "text") %>%
  mutate(row_id = row_number())
n_raw <- nrow(raw)

# ── R1: one date encoding ───────────────────────────────────────────────────
parsed <- raw %>%
  mutate(survey_year = as.integer(survey_year),
         length_mm = suppressWarnings(as.numeric(length_mm)),
         date_raw = date,
         date_encoding = case_when(
           is.na(date_raw) ~ "missing",
           str_detect(date_raw, "^\\d{4}-\\d{2}-\\d{2}$") ~ "ISO 8601",
           str_detect(date_raw, "^\\d{5}$") ~ "Excel serial",
           str_detect(date_raw, "^\\d{1,2}-[A-Za-z]{3}-\\d{4}$") ~ "d-b-Y",
           TRUE ~ "unparsed"),
         date = case_when(
           date_encoding == "ISO 8601" ~ suppressWarnings(as.Date(date_raw)),
           date_encoding == "Excel serial" ~ as.Date(suppressWarnings(as.numeric(date_raw)), origin = "1899-12-30"),
           date_encoding == "d-b-Y" ~ as.Date(date_raw, format = "%d-%b-%Y"),
           TRUE ~ as.Date(NA)))
enc_tab <- parsed %>% count(date_encoding, name = "records") %>% arrange(desc(records))
unparsed <- parsed %>% filter(date_encoding == "unparsed") %>% count(beach, survey_year, date_raw)

# ── R2: year typos ──────────────────────────────────────────────────────────
windows <- parsed %>% filter(!is.na(date), year(date) == survey_year) %>%
  group_by(beach, survey_year) %>%
  summarise(window_first = min(date), window_last = max(date), n_dated_ok = n(), .groups = "drop")
cross <- parsed %>% filter(!is.na(date), year(date) != survey_year) %>%
  left_join(windows, by = c("beach", "survey_year")) %>%
  mutate(candidate = suppressWarnings(as.Date(sprintf("%d-%02d-%02d", survey_year, month(date), day(date)))),
         within_window = !is.na(window_first) & !is.na(candidate) & candidate >= window_first & candidate <= window_last)
cross_tab <- cross %>% count(beach, survey_year, date_as_recorded = date, candidate, within_window, window_first, window_last, name = "records") %>%
  arrange(beach, survey_year)
corrected <- parsed %>%
  left_join(cross %>% select(row_id, candidate, within_window), by = "row_id") %>%
  mutate(date_year_corrected = coalesce(within_window, FALSE),
         date_flag = case_when(date_encoding == "missing" ~ "missing",
                               date_encoding == "unparsed" ~ "unparsed",
                               date_year_corrected ~ "year set to survey_year (R2)",
                               !is.na(candidate) & !within_window ~ "date-year differs from survey_year; kept as recorded",
                               TRUE ~ "ok"),
         date = if_else(date_year_corrected, candidate, date)) %>%
  select(-candidate, -within_window)

# ── R4: length flags ────────────────────────────────────────────────────────
corrected <- corrected %>%
  mutate(length_flag = case_when(is.na(length_mm) ~ "missing",
                                 length_mm < 3 | length_mm > 180 ~ "outside 3-180 mm",
                                 TRUE ~ "ok"))
len_tab <- corrected %>% filter(length_flag != "ok") %>%
  transmute(beach, survey_year, date, length_mm, length_flag, source_file) %>% arrange(beach, survey_year, length_mm)

# ── R5: beach-years with abundance but no lengths ───────────────────────────
season <- read_excel(file.path(DATA_DIR, "razor-clam-season-summary-1997-2025.xlsx"), sheet = "data") %>%
  transmute(beach, survey_year = as.integer(str_sub(season, 1, 4)), pre_recruits, recruits)
no_lengths <- season %>% filter(!is.na(pre_recruits)) %>%
  anti_join(corrected %>% distinct(beach, survey_year), by = c("beach", "survey_year")) %>% arrange(beach, survey_year)

# ── write ───────────────────────────────────────────────────────────────────
out <- corrected %>%
  select(row_id, survey_year, beach, type, date, date_raw, date_encoding, date_year_corrected, date_flag,
         transect, elevation, plot, clams, length_mm, length_flag, length_cm, class, note, est_age_yr,
         size_class, age_class, source_file)
stopifnot(nrow(out) == n_raw, !anyDuplicated(out$row_id))
write_csv(out, file.path(CORR_DIR, "shell_lengths_corrected.csv.gz"), na = "")

md_tab <- function(df) {
  if (nrow(df) == 0) return("(none)")
  df <- df %>% mutate(across(everything(), ~ ifelse(is.na(.x), "", as.character(.x))))
  c(paste0("| ", paste(names(df), collapse = " | "), " |"), paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    paste0("| ", apply(df, 1, paste, collapse = " | "), " |"))
}
md5 <- unname(tools::md5sum(RAW_LENGTHS))
changelog <- c(
  "# Changelog of the corrected inputs",
  "",
  paste0("Generated by `01_code/R/00_correct_inputs.R` (pipeline step 00) from `", basename(RAW_LENGTHS),
         "`, sheet `All_Clams_Raw` (md5 ", md5, "; ", format(n_raw, big.mark = ","), " records). ",
         "The source workbook is unchanged. Every rule below is applied by the script; rerunning it reproduces this file."),
  "",
  "## R1. One date encoding", "",
  "Raw `date` values occur in three encodings and are parsed to one ISO 8601 `date` column; the raw text is kept in `date_raw` and the encoding in `date_encoding`.", "",
  md_tab(enc_tab), "",
  if (nrow(unparsed) > 0) c("Unparsed values:", "", md_tab(unparsed), "") else "No value failed to parse.", "",
  "## R2. Year typos set to the survey year", "",
  paste0("A record whose date-year differs from its `survey_year` is a year typo when its month-day falls inside the window of correctly dated records of the same beach-year ",
         "(`window_first` to `window_last`). Such dates have the year replaced by `survey_year` (`date_year_corrected = TRUE`). ",
         "Records failing the test are kept as recorded and flagged in `date_flag`. ",
         sum(corrected$date_year_corrected), " of ", nrow(cross), " cross-year records were corrected."), "",
  md_tab(cross_tab %>% mutate(across(c(date_as_recorded, candidate, window_first, window_last), as.character))), "",
  "## R3. Missing dates", "",
  paste0(sum(corrected$date_encoding == "missing"), " records have no date in the source (",
         paste(sprintf("%s %d: %d", (corrected %>% filter(date_encoding == "missing") %>% count(beach, survey_year))$beach,
                       (corrected %>% filter(date_encoding == "missing") %>% count(beach, survey_year))$survey_year,
                       (corrected %>% filter(date_encoding == "missing") %>% count(beach, survey_year))$n), collapse = "; "),
         "). Nothing is imputed here; `01_build_datasets.R` imputes the survey day of year for such beach-years from the beach median and flags it (`survey_doy_imputed`)."), "",
  "## R4. Shell lengths outside 3-180 mm, or missing (flagged, not changed)", "",
  paste0(nrow(len_tab), " records. The analyses use `length_flag == \"ok\"`."), "",
  md_tab(len_tab %>% mutate(date = as.character(date))), "",
  "## R5. Beach-years with abundance estimates but no length records (nothing to correct)", "",
  md_tab(no_lengths), "",
  "## Not changed here", "",
  "- Harvest, TAC and habitat-area values in the season summary (tasks T36-T38) await reconciliation with WDFW's records; no corrected season summary exists yet.",
  "- Length heaping at Kalaloch (spikes at 50 and 58-60 mm) is a property of one data source and cannot be corrected record by record; it is flagged in task T13.")
writeLines(changelog, file.path(CORR_DIR, "CHANGELOG.md"))

message("00_correct_inputs: wrote ", file.path("02_data", "corrected", "shell_lengths_corrected.csv.gz"), " (", n_raw, " records; ",
        sum(corrected$date_year_corrected), " dates year-corrected; ", sum(corrected$date_encoding == "missing"), " without date; ",
        nrow(len_tab), " length flags) and CHANGELOG.md")
