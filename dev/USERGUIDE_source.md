# GrowthCurve

## Shiny Application

## User & Technical Guide

{{VERSION}}

github.com/jordanmbarrows/growthcurve

### Contents:

#### 1.  Overview

- 1.1 Installation
- 1.2 Application Architecture

#### 2.  Analysis Modes

- 2.1 Single Plate
- 2.2 Batch Processing
- 2.3 Aggregate Results

#### 3.  Input Files

- 3.1 Raw Data File — Plate Reader
- 3.2 Raw Data File — oCelloscope
- 3.3 Instrument Detection and Well Name Extraction
- 3.4 CSV Format Compatibility
- 3.5 Design File

#### 4.  Analysis Parameters

- 4.1 Required Parameters
- 4.2 Optional Parameters
- 4.3 Blank Correction Mode
- 4.4 Instrument Defaults

#### 5.  Analysis Pipeline

- 5.1 Pipeline Stages
- 5.2 Data Import Details
- 5.3 Core Computation Details
  - Blank correction
  - Mean curve calculation
  - OD window filtering
  - Growth rate computation (`gcplyr`)
  - Growth summary metrics
  - QC flagging

#### 6.  Diagnostic Plots

#### 7.  Output Files

- 7.1 Plot Report (`plate_report.pdf`)
- 7.2 Tidy Results (`plate_tidy.csv`)
- 7.3 Analysis Metadata (`Analysis_arguments.csv`)
- 7.4 Batch Summary (`batch_run_summary.csv`)
- 7.5 Aggregate Output (`combined_tidy_YYYYMMDD_HHMMSS.csv`)

#### 8.  Regional Settings

#### 9.  System Layer (`growthcurve_system.R`)

- 9.1 Error Handling
- 9.2 Developer Mode
- 9.3 Update Checker
- 9.4 OS-Aware Folder Opening
- 9.5 Backend Readiness Check

#### 10. UI Features

- 10.1 File Preview
- 10.2 Dark Mode
- 10.3 Cancellation
- 10.4 Navigation Lock
- 10.5 User Guide

#### 11. `gcplyr` Integration

- 11.1 Functions Replaced in This Version

#### 12. Input/Output File Structure Reference

- 12.1 Single Plate
- 12.2 Batch Processing
- 12.3 Aggregate Results

#### 13. Troubleshooting

## 1. Overview

GrowthCurve is an interactive R Shiny application for analyzing microbial growth curve data. It supports two instrument types — plate readers and the oCelloscope imaging cytometer — and provides a structured, reproducible workflow for extracting biologically meaningful growth metrics from raw OD or cell-count data.

**The central goal of the pipeline is to extract maximum growth rate and doubling time from raw growth curve data, and export those results in a clean, tidy format ready for downstream statistical analysis.**


Important design principle: The app does not produce publication-ready figures. Every visualization in the app is a diagnostic tool intended to help users evaluate data quality and analysis behavior, not to generate figures for manuscripts.

### 1.1 Installation

GrowthCurve is distributed as an R package installed directly from GitHub. The recommended installer is `pak`, which resolves dependencies automatically.

```         

# Install pak if needed

if (!requireNamespace("pak", quietly = TRUE)) { install.packages("pak") }
```

```         

# Install growthcurve from GitHub

pak::pak("jordanmbarrows/growthcurve")
```

Once installed, launch the app with: 

```

library(growthcurve)

run_growthcurve()
```

The app performs a dependency check on startup and stops with a descriptive error if required packages are missing. Missing packages must be installed manually before the app can run. Required packages include: `ggplot2`, `dplyr`, `tidyr`, `gcplyr`, `lubridate`, `multcomp`, `shiny`, `shinyjs`, `DT`, `future`, `promises`, `later`, `htmlwidgets`, and `shinyBS`.

### 1.2 Application Architecture

The application is organized into three code layers, each with a distinct responsibility:

| File                       | Purpose |
|----------------------------|---------| 
| `app.R`                    | Shiny UI definition and server orchestration. Handles file selection, parameter inputs, progress reporting, cancellation, and export. Contains no scientific computation. |
| `growthcurve_functions.R`  | The analysis backend. Contains all scientific computation, plotting, and file I/O. Designed to be deterministic and batch-safe. |
| `growthcurve_system.R`     | System configuration and behavior layer. Centralizes OS detection, regional settings (CSV and numeric formatting), app versioning, error handling, and developer utilities. |

A strict architectural rule is enforced throughout: the UI layer performs no scientific computation, and the analysis backend has no UI side effects. This separation makes the analysis pipeline independently testable and suitable for batch execution outside the Shiny interface.

## 2. Analysis Modes

The app provides three distinct workflows. Users will typically move through them in order — exploring a single dataset first, then running a batch, then aggregating results across multiple experiments.

### 2.1 Single Plate

Single Plate is the exploratory workflow. It is designed for interactive investigation of a single dataset and gives access to the full suite of 11 diagnostic plots, stage-by-stage.

#### Characteristics:

- Interactive, step-by-step plot navigation with Previous and Next stage buttons
- Immediate visual feedback after each analysis stage completes
- Parameters can be explored and refined before committing to export
- Export produces the same output structure as Batch Processing (plots PDF, tidy CSV, metadata CSV)
- Input controls are locked after analysis runs to prevent accidental modification

Once a Single Plate analysis completes, all input fields are disabled. To re-run with different parameters, reset the analysis state and then run again.

Expected file layout for single plate input:
``` 
/project/
├── <plate_name>.csv                    # plate reader or oCelloscope data 
└── design.csv                          # experimental design
``` 

Output structure per run:
``` 
Analysis/                               # created on export
└──YYYYMMDD_HHMMSS_[prefix_]single/     # created on export
   └── <plate_name>/              
       ├── plate_report.pdf
       ├── plate_tidy.csv
       └── Analysis_arguments.csv
```     

### 2.2 Batch Processing

Batch Processing is the production workflow. It processes multiple datasets in sequence without interactive plotting, making it efficient for routine analysis of many plates.

#### Characteristics:

- No stage-by-stage plot display during processing
- Cancellation is supported mid-batch via a Cancel button
- Each plate is processed into its own subdirectory under the run output folder
- A batch summary CSV is produced at the end of each run

#### Parallel Processing

By default, batch analysis runs two plates simultaneously using parallel workers. This reduces total runtime for multi-plate batches without placing excessive load on the system. The worker count is intentionally capped at two: higher values rarely improve performance for this type of workload because the bottleneck is typically disk I/O (reading and writing CSV files and PDFs) rather than CPU computation. Running more than two workers in parallel tends to cause disk contention that offsets any gains from parallelism.

Parallel processing can be disabled via the `Enable parallel processing` checkbox in the batch parameter panel. When disabled, plates are processed sequentially, one at a time. Sequential mode is useful if you encounter instability on a particular system, are running on a machine with very limited memory, or simply prefer a more predictable execution pattern.

Expected file layout for batch input:

``` 
/batch/
├── data/                               # plate reader or oCelloscope data 
│   ├── <plate1_name>.csv
│   └── <plate2_name>.csv
└── design/                             # experimental design
    ├── <plate1_design>.csv
    └── <plate2_design>.csv
``` 

The Batch Processing UI presents a matching table where each raw data file is paired with a design file using a dropdown selector. Design files that do not match a raw file can be excluded from the run.

Output structure per run:

``` 
Analysis/                               # created on export
└── YYYYMMDD_HHMMSS_[prefix_]batch/     # created on export
    ├── <plate1_name>/
    │   ├── plate_report.pdf
    │   ├── plate_tidy.csv
    │   └── Analysis_arguments.csv
    ├── <plate2_name>/
    │   ...
    └── batch_run_summary.csv
```

`batch_run_summary.csv` records the plate name, analysis status (`success`, `failed`, or `cancelled`), and any diagnostic messages for each plate processed in the run.

### 2.3 Aggregate Results

Aggregate Results combines the output from multiple independent analyses — whether from Single Plate exports or completed Batch Processing runs — into a single unified dataset for downstream statistical analysis.

Functionality:

- Searches recursively through selected directories for all `plate_tidy.csv` files
- Combines all results into a single data frame
- Exports the combined dataset as a timestamped CSV

Output file naming:  
`combined_tidy_YYYYMMDD_HHMMSS.csv`

---

#### Expected directory layout

```
Analysis/
├── run_1/
├── run_2/
└── run_3/
```

Each run folder may contain one or more analyzed plates. The app will automatically scan all subfolders for results.

---

#### Working with multiple experiments

If your analyses are stored in separate locations (e.g., different experiments), you can manually combine them before aggregation:

1. Create a new parent folder (e.g., Analysis_combined)
2. Copy or move individual run folders into this directory
3. Select the parent folder when running Aggregate Results

Example:

```
Analysis_combined/
├── experiment_A/
├── experiment_B/
└── experiment_C/
```

The app treats all subfolders equally, regardless of their origin.

---

#### Notes on combining runs

- Runs do not need to come from the same batch or experiment
- Different experimental designs and variables can be combined

This allows flexible aggregation across experiments, but users should always review the combined dataset before downstream analysis.

Tip: Using consistent naming conventions for runs and prefixes can make combined datasets easier to interpret.

---

#### Duplicate Detection

When aggregating results, the app performs duplicate detection to prevent accidental inflation of replicate counts. A duplicate is defined as any combination of the same plate name (derived from the raw data filename) and the same prefix (a user-defined label). This means the same physical plate analyzed under different parameter settings can coexist in an aggregated dataset, as long as a distinct prefix is used.

Behavior:

- Duplicates are detected before combining begins
- Users are shown a modal dialog listing all overlapping plate/prefix groups with the run files where they appear
- Aggregation is not blocked — users can proceed despite duplicates
- Users are advised to exclude one of the overlapping runs before proceeding

Duplicate detection key: the combination of plate name and prefix forms a unique composite key. Two analyses of the same plate with the same prefix are flagged. Two analyses of the same plate with different prefixes are allowed.

## 3. Input Files

### 3.1 Raw Data File — Plate Reader

Plate reader raw exports are technically CSVs, but they are often produced in a format that is not directly parseable by R without preprocessing. The required workflow is:

1.  Open the exported file in Excel
2.  Save As CSV using your local Excel default CSV format (comma- or semicolon-delimited)
3.  Use this saved file as the raw data input

Skipping this step may cause parsing to fail.

**Supported formats:** Plate reader files may be in either `block` or `wide` format. The app automatically detects which format is present and parses it accordingly.

- **Block format** is the traditional repeating layout: each timepoint appears as a plate-like numeric block with row labels in the first column. The parser (`read_plate_block_flexible()`) detects these rectangular data regions flexibly rather than requiring fixed hard-coded positions.
- **Wide format** has a single header row of well names and one row per timepoint. The parser (`read_plate_wide()`) reads this directly without block detection.

### 3.2 Raw Data File — oCelloscope

oCelloscope files require a specific export and preparation workflow:

1.  Export the .xlsx file from the oCelloscope software
2.  Open in Excel
3.  Select the raw data sheet
4.  Use Save As to save that sheet as a CSV using your local Excel default CSV format (comma- or semicolon-delimited)
5.  Use this saved file as the raw data input

Direct oCelloscope CSV exports are not compatible with this pipeline. Only the workflow above produces a correctly formatted file.

The parser searches the file for a line beginning with `TANormalized`. This is the only supported data block. Everything before and after this block is ignored. If the block is not found, analysis will fail with a descriptive error.

After locating the `TANormalized` header, the parser:

- Skips any empty lines between the header and data
- Reads data lines until it encounters an empty or delimiter-only row
- Passes the extracted block through `read_csv_safe_text()` for robust regional format handling
- Applies a sanity check: the maximum value in the data block must be less than 10 (normalized data). Values exceeding this threshold indicate a parsing error.

### 3.3 Instrument Detection and Well Name Extraction

**Instrument detection** happens before any parsing. The app scans the incoming file for a line beginning with `TANormalized`. Files containing this marker are classified as oCelloscope format; all others are treated as plate reader files.

**Well name extraction** applies to any file read in wide format — both oCelloscope data and wide-format plate reader files. Some instruments include extra text appended to well names in column headers (e.g., `A1_raw` or `A1 (OD600)`). Well identifiers are extracted from column headers using the regex pattern `^([A-H][0-9]+).*` via `extract_well_names()`, which strips any trailing suffixes, leaving only the bare well identifier. If duplicate well names result after stripping, analysis aborts with an error asking the user to remove the redundant columns from the input file. Block-format plate reader files are not affected, as well names are constructed from row labels and column indices rather than read from headers.

### 3.4 CSV Format Compatibility

The app supports both US and EU regional CSV formats:

| Format     | Details   |
|------------|----------|
| US format  | Comma delimiter, dot decimal (e.g., 0.123) |
| EU format  | Semicolon delimiter, comma decimal (e.g., 0,123) |

Detection is performed by `read_csv_safe()`, which peeks at the first five lines of any file and counts commas versus semicolons. The format with the higher count is selected. This detection logic applies to both input reading and the safe text parser used for in-memory data blocks.

Output files are written using the region setting selected by the user in the app (or auto-detected from the R session locale on startup). All CSV I/O is routed through `read_csv_safe()` and `write_csv_safe()` — no direct calls to `read.csv()`, `read.table()`, or `write.csv()` are permitted anywhere in the codebase.

### 3.5 Design File

The design file defines the experimental layout of the plate. It must be a CSV file, and can be provided in either `block` or `wide` format. The app detects the format automatically.

**Block format** (traditional layout):

- Each block begins with a single header cell in the first column (e.g., `Well_type`, Strain, Treatment)
- The header is followed by exactly 8 rows (corresponding to plate rows A through H)
- Each row contains 12 values (corresponding to plate columns 1 through 12)
- Blocks are separated by exactly one empty row
- The stride between block headers is exactly 10 rows (1 header + 8 data rows + 1 empty row)

These requirements apply specifically to block-format design files, which are parsed using a strict 8×12 template.

**Wide format** (transposed layout):

- The first row contains well names (e.g., A1, A2, … H12)
- Each subsequent row represents one design variable, with the variable name in the first column and values for each well in the remaining columns

In both formats, a `Well_type` variable is required and must be the first variable defined. It defines whether each well is a `Blank` or a sample. This block is used for blank correction and is filtered from output metrics.
Note: Although oCelloscope data is not blank corrected during analysis, the `Well_type` variable is still required.

Example design file structures (showing `Well_type`, `Strain`, and `Treatment` variables):

Block format
![an image showing an example layout of a design file with well type, strain, and treatment variables in 96-well plate block layout format with example designations in corresponding wells](inst/app/www/block_design_file_image.png)

Wide format
![an image showing an example layout of a design file with well type, strain, and treatment variables in wide format with example designations in corresponding wells](inst/app/www/wide_design_file_image.png)

Design variable selection: the app reads all design variable names from the design file. Design variables are detected automatically from the design file and used to populate the analysis grouping structure.

Design parsing is handled internally by `gc_read_design()`, which dispatches to format-specific parsers (`read_design_block_strict()` for block format, `read_design_wide()` for wide format) without requiring any external package functions for the design import step. Row labels (single letters A–H) that appear in design variable columns as an artifact of the block format are removed after import.

## 4. Analysis Parameters

### 4.1 Required Parameters

| Parameter                | Description |
|-------------------------|-------------|
| Duration (hours)        | Recorded as an analysis parameter and included in metadata. The time vector used during import is reconstructed from the selected interval and the imported data structure. Must be a positive number. |
| Interval (minutes)      | Measurement frequency in minutes. Used to generate the time vector for both instrument types. Must be a positive number. Default: 15 min for plate reader, 10 min for oCelloscope. |
| Min OD                  | Lower bound of the OD window used for growth rate calculation. Only timepoints with blank-corrected OD greater than this value are analyzed. Default: 0.05 for plate reader, 0.01 for oCelloscope. |
| Max OD                  | Upper bound of the OD window. Only timepoints with OD less than this value are included. Default: 0.7 for both instruments. Max OD value must be a greater than Min OD. |

### 4.2 Optional Parameters

| Parameter | Description |
|------------|-------------|
| Prefix     | A text label prepended to analysis outputs. Used in output filenames and as a component of the duplicate detection key. If left empty, outputs are labeled by timestamp (`YYYYMMDD_HHMMSS`), run type (`_single` or `_batch`), and plate name (subfolder) alone. |
| Parallel processing (batch only) | When enabled (default), two plates are processed simultaneously to reduce total batch runtime. Can be disabled if sequential processing is preferred — for example, on memory-limited systems or when troubleshooting unexpected batch failures. |

### 4.3 Blank Correction Mode

Blank correction is only applicable to plate reader data. oCelloscope data enters the pipeline already internally blanked by the instrument, so blank correction is disabled and the `blank_mode` selector is greyed out when oCelloscope is selected.

| Mode      | Behavior |
|-----------|----------|
| `plate`     | Subtracts the median OD of all wells designated as Blank at time zero from every well at every timepoint. This is the recommended mode and the default. |
| `per_well`  | Subtracts the OD of each individual well at the first timepoint from all subsequent timepoints of that well. Useful when wells have highly variable baseline readings. |
| `none`      | No blank correction applied. The raw measurements are used as-is. Appropriate when data is already baseline-corrected. |

In all cases, blank-corrected values are stored as `Measurements_adj`, and a log transformation of `pmax(Measurements_adj, 1e-6)` is stored as `Measurements_log`. The small floor value (1e-6) prevents log-of-zero errors.

### 4.4 Instrument Defaults

Instrument-specific default parameters are defined in the `gc_instrument_defaults` list in `growthcurve_functions.R`:

#### Plate reader defaults

| Parameter        | Default value |
|-----------------|----------------|
| Interval        | 15 minutes |
| Min OD          | 0.05 |
| Max OD          | 0.7 |
| Smoothing       | Disabled |

---

#### oCelloscope defaults

| Parameter        | Default value |
|-----------------|----------------|
| Interval        | 10 minutes |
| Min OD          | 0.01 |
| Max OD          | 0.7 |
| Smoothing       | Enabled (window = 3) |


## 5. Analysis Pipeline

All scientific computation is orchestrated by `run_gc()`, the top-level coordinator function in `growthcurve_functions.R`. It delegates to a series of explicit pipeline stages, each with clearly defined responsibilities and no side effects between stages.

### 5.1 Pipeline Stages

The `run_gc()` function executes the following stages in order:

| Stage | Responsibility |
|--------|----------------|
| Stage A: `gc_prepare_run()` | Input validation. Checks that all required arguments are present and valid (file paths exist, `hrs` > 0, `interval` > 0, `minod` < `maxod`, `design_vars` is a non-empty character vector). Builds the shared `ggplot` theme object and snapshots all resolved parameters. |
| Stage B: `gc_import_data()` | Data import. Dispatches to instrument-specific readers, imports and parses the design file, then merges the two datasets using `dplyr::left_join()`. Validates that design variables exist in the design file before proceeding. |
| Stage C: `gc_core_compute()` | Core scientific computation. Performs blank correction, OD filtering, derivative calculation, growth rate summarization, and QC flagging. Returns all intermediate and final datasets. This function is pure: no plotting and no file I/O. |
| Stage D: `gc_build_plots()` | Plot construction. Builds all 11 `ggplot` objects from the outputs of `gc_core_compute()`. No saving or printing occurs at this stage. |
| Stage E: Assembly | Final assembly. The return object contains the parameter snapshot, instrument type, blank mode, core compute results, and all plot objects. |

### 5.2 Data Import Details

`gc_import_data()` combines instrument-specific raw-data import with shared design parsing, well matching, and downstream merging.

#### Plate reader data

Plate reader input may follow either the `block` or `wide` import path, depending on `detect_plate_format()`. Internally, this can be overridden by passing `raw_data_format` explicitly, but this is not exposed as a user-facing option in the current app.

- **Block format path:**  
  `read_plate_block_flexible()` scans the file to identify plate-like rectangular numeric data blocks, builds block-specific row/column mappings, and reads those blocks without requiring a rigid fixed layout. It returns a wide table with a `Time_min` column, where the time vector is reconstructed from the selected interval and the number of detected timepoints.
- **Wide format path:**  
  `read_plate_wide()` reads the raw file as a rectangular table with one row per timepoint and one column per well. Internally, it identifies well columns by matching column names against well-like patterns (`A1`–`H12`) and returns a table with `Time_min`. In the full plate-reader import path, the final cleaned wide table is then passed through `format_plate_reader_data()`, which reconstructs the analysis time vector from the selected interval and applies design-based well filtering.
- **Common downstream handling:**  
  In both block and wide paths, a `block_name` column with value `plate_reader` is added, the time column is converted from `Time_min` to `Time` in hours (`Time_min / 60`), and `gcplyr::trans_wide_to_tidy()` converts the result from wide to long format.

#### oCelloscope data

For oCelloscope input:

- `read_ocello_tanormalized()` locates the `TANormalized` section in the exported file, extracts the corresponding raw lines, and parses the measurement block into a rectangular data frame after dropping time/repetition columns.
- `format_ocelloscope_data()` reconstructs the time vector from the selected interval (in normal app-driven use), extracts and normalizes well names, and filters the imported matrix against the set of wells defined in the design file.
- After formatting, a `block_name` column with value `ocelloscope` is added, `Time_min` is converted to `Time` in hours (`Time_min / 60`), and `gcplyr::trans_wide_to_tidy()` converts the result from wide to long format.

#### Shared design parsing and merge

After either raw-data path, the tidy imported data is merged with the parsed design table using `dplyr::left_join()` on the `Well` column.

The design file format (`block` or `wide`) is normally detected automatically by `detect_design_format()`. Internally, this can be overridden by passing `design_file_format` explicitly, but this is not exposed as a user-facing option in the current app.

- `detect_design_format()` determines the design format unless `design_file_format` is already known.
- `read_design_block_strict()` is used for block-format design files.
- `read_design_wide()` is used for wide-format design files.
- `extract_design_blocks()` / `extract_design_blocks_wide()` are used to validate that requested design variables are present before import proceeds.

#### Integrity checks and cleanup

Several validation and cleanup steps occur after import and merge:

- A row-count check after `left_join()` ensures that the join did not introduce spurious rows.
- The merged data is checked for duplicate `(Well, Time)` pairs.
- A design-mapping validation step checks that no well has been assigned to multiple groups for the primary design variable.
- `NA` values are removed using `na.omit()`.
- The `Time` column is coerced to `numeric`.

A warning is emitted if the maximum `Time` value exceeds `200`, because that suggests the time vector may still be in minutes rather than hours.

### 5.3 Core Computation Details

`gc_core_compute()` is the scientific heart of the pipeline. It takes the merged data and blocklist as inputs and returns a structured list containing all intermediate datasets and final metrics.

#### Blank correction

Blank correction proceeds according to the `blank_mode` argument. The `plate` mode extracts all wells where `Well_type == "Blank"` at t0 and computes the median (`blankmed`). This median is subtracted from all wells at all timepoints. The `per_well` mode subtracts each well's own t0 value. All modes produce a `Measurements_adj` column and a `Measurements_log` column.

#### Mean curve calculation

After blank correction, a mean curves dataset (`merged_data_means`) is computed. Blank wells are excluded. Data is grouped by the user-selected design variables and by `Time`. For each group, the mean, standard deviation, sample count, and 95% confidence interval are calculated. A `group_id` column is created as a factor interaction of all design variables for plotting.

#### OD window filtering

The dataset is subset to rows where `Measurements_adj` \> `minod` AND `Measurements_adj` \< `maxod`. If no rows survive this filter, analysis aborts with an error message listing possible causes: mismatched design file, wrong instrument mode, overly restrictive thresholds, or empty post-merge data.

#### Growth rate computation (`gcplyr`)

Within the OD window, the pipeline computes three derivative columns for each well:


| Column          | Computation |
|-----------------|-------------|
| `deriv`           | Raw absolute growth rate: `gcplyr::calc_deriv(x = Time, y = Measurements_used)` |
| `deriv_percap`    | Per-capita growth rate without windowing: `gcplyr::calc_deriv(..., percapita = TRUE, blank = 0)` |
| `deriv_percap3`   | Per-capita growth rate with a 3-timepoint rolling window on log-transformed data: `gcplyr::calc_deriv(..., percapita = TRUE, blank = 0, window_width_n = 3, trans_y = "log")` |


The `deriv_percap3` column is the primary metric used for maximum growth rate extraction. The rolling window of 3 timepoints and log transformation improve robustness to noise while preserving the true growth signal. The `window_width_n=3` choice is intentional and instrument-aware — the same code path is used for both instrument types, but oCelloscope data is pre-smoothed before derivatives are computed.

For oCelloscope data (`smoothing=TRUE`), `gcplyr::smooth_data()` is applied to `Measurements_adj` using a moving-average method with `window_width_n` equal to the `smoothing_window` value (default 3). This produces the `Measurements_used` column. For plate reader data, `Measurements_used` equals `Measurements_adj` directly.

#### Growth summary metrics

Per-well summary statistics are computed by grouping on the design variables and `Well`:

| Metric          | Computation |
|----------------|-------------|
| `max_percap`      | Maximum per-capita growth rate: `gcplyr::max_gc(deriv_percap3, na.rm = TRUE)` |
| `max_percap_time` | Time at which the maximum per-capita growth rate occurs: `gcplyr::extr_val(Time, gcplyr::which_max_gc(deriv_percap3))` |
| `doub_time`       | Doubling time in hours: `gcplyr::doubling_time(y = max_percap)` |


If all values of `deriv_percap3` for a well are `NA`, the summary metrics are set to `NA_real_`. This prevents crashes from wells with no valid data.

#### QC flagging

After summarization, `gc_add_qc()` assigns a `QC_flag` and `QC_reason` to each well based on the computed metrics:

| Flag  | Condition |
|--------|-----------|
| `FAIL`  | `max_percap` is `NA` (no growth rate detected) OR `doub_time` is `NA` (undefined doubling time) |
| `WARN`  | `doub_time` < 0.2 hours (very fast growth, likely a calculation artifact) OR `doub_time` > 10 hours (very slow growth) |
| `OK`    | All metrics are within expected ranges |

QC flags are joined back onto the `merged_data`, `merged_data_sub`, and `ex_dat_mrg_sum` datasets so they are available in all downstream plots.

## 6. Diagnostic Plots

All 11 plots are produced by `gc_build_plots()`, which takes the core compute results and the shared `ggplot` theme as inputs. In Single Plate mode, plots are displayed one at a time with stage navigation. In Batch Processing mode, all plots are rendered directly to the PDF report without display.

`QC_flag` coloring is applied to relevant plots using `gc_qc_scale()`, which maps `OK` wells to black, `WARN` wells to orange (`#E69F00`), and `FAIL` wells to light grey at reduced opacity (alpha = 0.3). This allows rapid visual identification of problematic wells across all summary plots.

| Plot | Content and purpose |
|------|---------------------|
| Plot 1: Blank-corrected OD (linear) | All wells plotted on a linear OD scale after blank correction, colored by `Well_type` (`Blank` vs sample). Used to inspect the overall scale of the data and verify blank subtraction. |
| Plot 2: Blank-corrected OD (log scale) | Same data on a log10 scale. Reveals early exponential growth behavior and helps identify wells that never truly left the blank baseline. |
| Plot 3: Mean curves with 95% CI | Mean growth curves for each experimental group defined by the design variables, with 95% confidence interval ribbons. Groups are distinguished by both color and fill. |
| Plot 4: Per-well OD curves (linear) | Individual well curves faceted by `Well`, shown on a linear scale, colored by `QC_flag`. Used to identify outlier wells and inspect within-group variability. |
| Plot 5: Per-well OD curves (log scale) | Same per-well faceted view on a log10 scale, colored by `QC_flag`. |
| Plot 6: Raw derivatives | Absolute growth rate (`deriv`) over time per well within the OD window, colored by `QC_flag`. Useful for checking the magnitude and timing of the growth rate signal. |
| Plot 7: Per-capita derivatives | Per-capita growth rate (`deriv_percap`, no windowing) over time, colored by `QC_flag`. Shows the unsmoothed growth rate trajectory. |
| Plot 8: Fitted per-capita with maximum | Windowed and fitted per-capita derivative (`deriv_percap3`), colored by `QC_flag`, with a point at the timepoint of maximum growth rate (`max_percap_time`). This is the primary derivative used for metric extraction. |
| Plot 9: OD curves with max growth marked | OD curves (from `merged_data`, excluding blank wells) with a vertical line marking the timepoint of maximum growth for each well, colored by `QC_flag`. |
| Plot 10: Doubling time summary | Summary dot plots showing per-well doubling time (hours) values, jittered points, group mean, and 95% CI. Wells are colored by the first design variable. |
| Plot 11: Maximum growth rate summary | Summary dot plots showing per-well maximum growth rate (per hour) values, jittered points, group mean, and 95% CI. Wells are colored by the first design variable. |

## 7. Output Files

### 7.1 Plot Report (`plate_report.pdf`)

The PDF report contains all 11 diagnostic plots, one per page. It is generated by `gc_save_report()`, which renders each `ggplot` object sequentially to a PDF device. The plate name (derived from the raw data filename) is used as the report title. This file is intended as a visual quality-control record accompanying each analysis.

### 7.2 Tidy Results (`plate_tidy.csv`)

This is the primary scientific output of the analysis. It contains one row per well per measurement type, in long (tidy) format suitable for direct import into statistical analysis tools or `ggplot2`.

Column schema:

| Column | Content |
|------|---------------------|
| [design variables] | One column per design variable selected at analysis time (e.g., Strain, Treatment). Values are taken directly from the design file. |
| `Well` | Well identifier (e.g., A1, B3). |
| `Measurement` | Type of measurement: `max_growth` (the maximum per-capita growth rate) or `doub_time` (the doubling time in hours). |
| `Value` | Numeric value of the measurement. |
| `Replicate` | Integer replicate index assigned within each combination of design variables and measurement type. Assigned by `row_number()` within each group. |
| `QC_flag` | `OK`, `WARN`, or `FAIL`. See Section 5.3 for flag definitions. |
| `QC_reason` | Empty string for `OK` wells; a short description for `WARN` and `FAIL` wells. |
| `instrument` | The instrument type used: `plate_reader` or `ocelloscope`. |
| `prefix` | The user-specified prefix. Empty string if no prefix was provided. |

The tidy format means that `max_growth` and `doub_time` appear as separate rows for the same well, not as separate columns. This makes the file directly usable with `dplyr::group_by` and `ggplot2` facet operations in downstream analysis.

### 7.3 Analysis Metadata (`Analysis_arguments.csv`)

A two-column key-value CSV recording the parameters used for the analysis. This file provides a complete audit trail for reproducibility. 
Note: Some `Argument` names are adjusted from their derived variable names for extra clarity. 

| `Argument` | `Value` |
|------|---------------------|
| `rawdatafile` | Path to the raw data file recorded for reproducibility |
| `designfile` | Path to the design file recorded for reproducibility |
| `instrument` | `plate_reader` or `ocelloscope` |
| `raw_data_format` | `block` or `wide` — the detected or recorded format of the raw data file |
| `design_file_format` | `block` or `wide` — the detected or recorded format of the design file |
| `blank_correction_mode` | `plate`, `per_well`, or `none` (derived from `blank_mode`) |
| `duration (hrs)` | Duration in hours (derived from `hrs`) |
| `interval (min)` | Interval in minutes (derived from `interval`) |
| `minod` | Lower OD threshold |
| `maxod` | Upper OD threshold |
| `extra_design_vars` | Comma-separated list of selected design variables (derived from `design_vars`) |

### 7.4 Batch Summary (`batch_run_summary.csv`)

Produced at the end of every Batch Processing run. Contains one row per plate. Fields include the plate name, analysis status (`success` / `failed` / `cancelled`), and any diagnostic messages produced during analysis of that plate.

### 7.5 Aggregate Output (`combined_tidy_YYYYMMDD_HHMMSS.csv`)

Produced by the Aggregate Results workflow. Contains the combined rows from all `plate_tidy.csv` files in the selected run directories. The timestamp in the filename is derived from the system time at the moment of export.

## 8. Regional Settings

Regional formatting affects how CSV files are written and how numeric axis labels are rendered in plots. The app detects the current region on startup from the R session locale (`Sys.localeconv()[["decimal_point"]]`): a comma decimal mark triggers EU mode, a dot triggers US mode. Users can override this detection in the app's settings area.

| Region | Format |
|-------|---------|
| US format | Comma delimiter (,) and dot decimal (.). Standard for R and most data analysis tools. |
| EU format | Semicolon delimiter (;) and comma decimal (,). Required for compatibility with Excel and other tools in many European locales. |

The region setting affects:

- All CSV output files: `plate_tidy.csv`, `Analysis_arguments.csv`, `batch_run_summary.csv`, and `combined_tidy_YYYYMMDD_HHMMSS.csv` files
- Numeric axis labels in diagnostic plots (`format_axis_labels()` converts dots to commas for EU mode)

All file input/output is routed through two centralized functions defined in `growthcurve_system.R`:

| Function | Behavior |
|-------|---------|
| `read_csv_safe(file, ...)` | Reads a CSV file with automatic delimiter and decimal detection. Calls `read.table()` with the inferred settings. Raises a `gc_error` if the file does not exist or cannot be parsed. |
| `read_csv_safe_text(text, ...)` | Same logic applied to an in-memory text block rather than a file path. Used for parsing extracted oCelloscope data blocks. |
| `write_csv_safe(df, file, region)` | Writes a data frame using the delimiter and decimal mark for the specified region. Converts numeric-like columns back to numeric before writing. |

## 9. System Layer (`growthcurve_system.R`)

The system layer centralizes all environment-dependent behavior. No other part of the application should directly query the operating system, read locale settings, or make version comparisons. All such behavior is delegated to functions in this file.

### 9.1 Error Handling

The app uses a standardized error system based on the `gc_abort()` function, which raises a condition of class `c("gc_error", "error", "condition")` with a clean, user-readable message.

Error formatting is handled by `gc_format_error()`. In user mode (default), this function returns a standardized, non-technical message: `"The analysis could not be completed. Please check your instrument, input files, and formatting."` In developer mode, it returns the full error message and class information.

### 9.2 Developer Mode

Developer mode provides additional logging and debugging output. It is disabled by default and must be explicitly enabled:

```         

options(gc.dev_mode = TRUE)
```

When active, developer mode enables:

- `gc_log()` and `gc_log_block()` print diagnostic messages to the R console with a `[GC]` prefix
- Detailed error output in `gc_format_error()`, including error class and full message
- Debug panels in the Shiny UI
- A debug log file is written to the run output directory for each analysis

**Debug log file**

The debug log is a plain-text file written to the timestamped run directory alongside the normal outputs. In batch mode it is named `<run_folder>_debug_log.txt` and lives at the top level of the batch output directory. In single plate mode it is named `<run_folder>_debug_log.txt` and is written to the analysis directory on successful export. If a single plate run fails before export, the log is copied to `Analysis/_failed_debug/` with a timestamped filename so it is not lost.

The log captures progress flags at each pipeline stage (`STAGE START` / `STAGE DONE` for prepare, import, compute, plots, and return), parameters resolved at run start, and detailed diagnostics from the import step including: raw file format detection, raw row and well counts, design row and well counts, the full active-well mapping table, well-set comparison (wells in raw but not design, wells in design but not raw), and post-merge row counts. Any duplicate well-time pairs detected before or after merging are also logged.

All console output and debug log writing is suppressed in production mode (when `gc.dev_mode` is not set). In production, all `gc_log()` calls and `gc_dbg_file()` calls are no-ops.

### 9.3 Update Checker

The app checks for updates on startup by querying the GitHub releases API:

```         

<https://api.github.com/repos/jordanmbarrows/growthcurve/releases/latest>
```

The latest release tag is compared against the installed package version using `utils::compareVersion()`. If a newer version is available, the user is notified in the UI with instructions for installing the update. The checker does not force installation and does not block app startup if the network request fails.

### 9.4 OS-Aware Folder Opening

The Open export folder button in export dialogs uses `open_folder()`, which dispatches to the appropriate system command based on the detected OS: `shell.exec()` on Windows, `open` on macOS, and `xdg-open` on Linux. Failures are caught and surfaced as console warnings without crashing the app.

### 9.5 Backend Readiness Check

`gc_backend_ready()` verifies that the three core backend components — `run_gc`, `read_csv_safe`, and `gc_check_packages` — are present in the `growthcurve` package namespace. This check runs on app startup and assigns any error message to `gc_startup_error` in the global environment, allowing the UI to display a clear startup failure message if the backend is not properly loaded.

## 10. UI Features

### 10.1 File Preview

When a raw data file is selected, the app attempts to build a preview of the file contents:

- For plate reader files in **block format**: the first 20 rows of the raw CSV are displayed as a table
- For plate reader files in **wide format**: the growth data is extracted and the first 20 rows are displayed, using the selected interval to compute approximate time values
- For oCelloscope files: the `TANormalized` data block is extracted and the first 20 rows are displayed, using the selected interval to compute approximate time values
- If the oCelloscope preview requires a design file that has not yet been selected, a message is shown instead of a table

When a design file is selected, a separate design preview is also rendered:

- For **block format** design files: the raw file contents are displayed as a styled table with variable block headers highlighted
- For **wide format** design files: the file is displayed with well names in the header row and only rows with a defined variable name in the first column shown in the preview
- In Batch Processing mode, the preview shows the first design file found in the selected design directory

The preview helps users verify that the correct file has been selected and that it is being parsed in the expected format before running analysis.

### 10.2 Dark Mode

A dark/light theme toggle is available in the top navigation area. Dark mode applies to all UI elements including modals, tables, and form controls. It does not apply to the `ggplot` diagnostic plots, which always render on a white background regardless of the UI theme. The toggle is implemented via a CSS class (`dark-mode`) applied to the html element and a corresponding `bslib::bs_theme` data attribute.

### 10.3 Cancellation

Batch Processing can be cancelled mid-run using a Cancel button that appears during processing. When cancellation is triggered, the current plate’s analysis is interrupted as early as possible during the batch workflow rather than always being allowed to finish. A plate is considered completed only once its results have been written to disk (`plate_tidy.csv` present in the output folder). The batch summary records `cancelled` as the status for all plates not yet completed.

### 10.4 Navigation Lock

In Single Plate mode, all input controls (raw file, design file, instrument, parameters, design variables) are disabled after analysis runs. This prevents accidental modification of inputs while reviewing results. The controls remain disabled until the analysis state is reset. Navigation between plot stages is provided by Previous and Next buttons that are enabled/disabled according to the current stage index.

### 10.5 User Guide

The app includes a built-in User Guide tab containing embedded documentation covering all workflow steps, file format requirements, parameter descriptions, and output file descriptions. The guide is rendered as styled HTML within the Shiny UI using collapsible details/summary elements for each topic.

## 11. gcplyr Integration

GrowthCurve uses the `gcplyr` R package (Blazanin 2024, BMC Bioinformatics) as its scientific computation engine. `gcplyr` provides the core functions for growth curve data manipulation and analysis. The following `gcplyr` functions are used directly in the pipeline:

| Function | Role in pipeline |
|-------|---------|
| `gcplyr::trans_wide_to_tidy()` | Converts wide-format plate data (one column per well) to tidy long format (one row per well per timepoint). Used for both plate reader and oCelloscope data after the instrument-specific read step. |
| `gcplyr::smooth_data()` | Applies a moving-average smooth to the `Measurements_adj` column for oCelloscope data (`sm_method="moving-average"`, `window_width_n=3`, `subset_by=Well`). |
| `gcplyr::calc_deriv()` | Computes absolute and per-capita derivatives. All calls include `subset_by = Well` to ensure per-well computation. The windowed per-capita derivative (`window_width_n=3, trans_y="log"`) is the primary metric input. |
| `gcplyr::max_gc()` | Extracts the maximum value of the windowed derivative per well. |
| `gcplyr::which_max_gc()` | Returns the index of the maximum in the derivative vector. |
| `gcplyr::extr_val()` | Extracts the Time value at the index returned by `which_max_gc()`. |
| `gcplyr::doubling_time()` | Converts the maximum per-capita growth rate to doubling time in hours: log(2) / `max_percap`. |

### 11.1 Functions Replaced in This Version

Two `gcplyr` functions previously used in the pipeline — `gcplyr::import_blockdesigns()` and `gcplyr::merge_dfs()` — have been replaced with internal implementations. The replacements handle the same logical steps but integrate more directly with the app's format detection, regional CSV handling, and debug logging.

**Design import** (`gcplyr::import_blockdesigns()` → `gc_read_design()`)

`gc_read_design()` dispatches to one of two internal parsers depending on the detected design file format:

- `read_design_block_strict()` handles the traditional block layout (variable name in column 1, followed by 8 data rows, repeated with a stride of 10). It validates that block headers appear at the expected positions and that data dimensions match the 8×12 plate grid.
- `read_design_wide()` handles the transposed wide layout (well names in row 1, one design variable per subsequent row). It identifies well-name columns by regex, maps each variable row to the corresponding wells, and returns a data frame in the same `Well | Var1 | Var2 | …` shape as the block parser.

Both parsers return the same output structure, so the rest of the pipeline is format-agnostic after this step. No temporary file is written; regional format handling is applied internally via `read_csv_safe()`.

**Data/design merge** (`gcplyr::merge_dfs()` → `dplyr::left_join()`)

The tidy raw data and parsed design are now joined with `dplyr::left_join(imported_tidy, my_design, by = "Well")`. A post-join row-count check ensures that no spurious rows were introduced by duplicate keys in the design table. If the row count changes, analysis aborts with a descriptive error.

For a comprehensive explanation of the underlying methodology, including the mathematical basis for per-capita derivative calculation and the interpretation of `window_width_n`, refer to the `gcplyr` documentation at:

<https://mikeblazanin.github.io/gcplyr/articles/gc01_gcplyr.html>

## 12. Input/Output File Structure Reference

### 12.1 Single Plate

Import:
``` 
/project/
├── <plate_name>.csv                    # plate reader or oCelloscope data 
└── design.csv                          # experimental design
``` 

Export:
``` 
Analysis/                               # created on export
└──YYYYMMDD_HHMMSS_[prefix_]single/     # created on export
   └── <plate_name>/              
       ├── plate_report.pdf
       ├── plate_tidy.csv
       └── Analysis_arguments.csv
```     

### 12.2 Batch Processing

Import:
``` 
/batch/
├── data/                               # plate reader or oCelloscope data 
│   ├── <plate1_name>.csv
│   └── <plate2_name>.csv
└── design/                             # experimental design
    ├── <plate1_design>.csv
    └── <plate2_design>.csv
``` 

Export:
``` 
Analysis/                               # created on export
└── YYYYMMDD_HHMMSS_[prefix_]batch/     # created on export
    ├── <plate1_name>/
    │   ├── plate_report.pdf
    │   ├── plate_tidy.csv
    │   └── Analysis_arguments.csv
    ├── <plate2_name>/
    │   ...
    └── batch_run_summary.csv
```

### 12.3 Aggregate Results

``` 
/Analysis/                            
├── <run_1_single_name>/  
│   └── <plate_name>/
│       └── plate_tidy.csv
└── <run_2_batch_name>/
│   └── <plate2_1_name>/
│       └── plate_tidy.csv
│   └── <plate2_2_name>/
│       └── plate_tidy.csv
│   ...
└── combined_tidy_YYYYMMDD_HHMMSS.csv   # produced by Aggregate Results
```

## 13. Troubleshooting

| Error / symptom | Likely cause and resolution |
|-------|---------|
| `"TANormalized block not found"` | The oCelloscope file was not exported correctly, or the wrong sheet was saved. Re-export from oCelloscope, open in Excel, select the raw data sheet, and Save As CSV. |
| `"TANormalized sanity check failed: max value is X"` | The data block contains values greater than 10, indicating the data is not normalized. Check that the correct block/sheet was exported from oCelloscope. |
| `"No data points fall within the OD window"` | The OD window `[minod, maxod]` does not overlap with any blank- corrected measurements. Check that the correct instrument mode is selected, that the design file matches the data, and that the OD thresholds are appropriate for the data range. |
| `"No overlapping wells between data and design"` | Well names in the raw data file do not match well names in the design file. Verify that the design file uses exact plate notation (A1–H12) and that raw-data well names can be reduced cleanly to matching well identifiers. |
| `"Design variables not found in design file"` | One or more selected design variables do not appear as variable names in the design file. Check for typos or verify the design file has been saved correctly. |
| Plate reader file fails to parse | The file was not saved as a standard CSV from Excel. Open in Excel and re-save as CSV before uploading. |
| App fails to start with missing backend error | A required package is not installed. Run `gc_check_packages()` in the R console to identify missing dependencies and install them. |
