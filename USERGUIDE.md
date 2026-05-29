# GrowthCurve

## Shiny Application

## User & Technical Guide

```         
Version 1.0.9 — 28 May 2026
```

```         
github.com/jordanmbarrows/growthcurve
```

- 

  1.  Overview

  - 1.1 Installation
  - 1.2 Application Architecture

- 

  2.  Analysis Modes

  - 2.1 Single Analysis
  - 2.2 Batch Analysis
  - 2.3 Aggregate Results
  - 2.4 Duplicate Detection

- 

  3.  Input Files

  - 3.1 Raw Data File — Plate Reader
  - 3.2 Raw Data File — oCelloscope
  - 3.3 CSV Format Compatibility 
  - 3.4 Design File 

- 

  4.  Analysis Parameters 

  - 4.1 Required Parameters
  - 4.2 Optional Parameters 
  - 4.3 Blank Correction Mode 
  - 4.4 Instrument Defaults 

- 

  5.  Analysis Pipeline 

  - 5.1 Pipeline Stages
  - 5.2 Data Import Details 
  - 5.3 Core Computation Details 
    - Blank correction 
    - Mean curve calculation 
    - OD window filtering 
    - Growth rate computation (gcplyr)
    - Growth summary metrics
    - QC flagging 

- 

  6.  Diagnostic Plots 

- 

  7.  Output Files

  - 7.1 Plot Report (plate_report.pdf)
  - 7.2 Tidy Results (plate_tidy.csv)
  - 7.3 Analysis Metadata (Analysis_arguments.csv)
  - 7.4 Batch Summary (batch_summary.csv) 
  - 7.5 Aggregate Output (combined_tidy_YYYYMMDD_HHMMSS.csv) 

- 

  8.  Regional Settings

- 

  9.  System Layer (growthcurve_system.R)

  - 9.1 Error Handling 
  - 9.2 Developer Mode 
  - 9.3 Update Checker 
  - 9.4 OS-Aware Folder Opening 
  - 9.5 Backend Readiness Check 

- 

  10. UI Features

  - 10.1 File Preview 
  - 10.2 Dark Mode 
  - 10.3 Cancellation 
  - 10.4 Navigation Lock
  - 10.5 User Guide 

- 

  11. gcplyr Integration

- 

  12. File Structure Reference

  - 12.1 Single Analysis
  - 12.2 Batch Analysis
  - 12.3 Aggregate Analysis 

- 

  13. Troubleshooting
  

## 1. Overview

GrowthCurve is an interactive R Shiny application for analyzing microbial growth curve data. It supports two instrument types — plate readers and the oCelloscope imaging cytometer — and provides a structured, reproducible workflow for extracting biologically meaningful growth metrics from raw OD or cell-count data.

**The central goal of the pipeline is:**

```         
To extract maximum growth rate and doubling time from raw growth curve data, and export
those results in a clean, tidy format ready for downstream statistical analysis.
```

Important design principle: The app does not produce publication-ready figures. Every visualization in the app is a diagnostic tool intended to help users evaluate data quality and analysis behavior, not to generate figures for manuscripts.

### 1.1 Installation

GrowthCurve is distributed as an R package installed directly from GitHub. The recommended installer is pak, which resolves dependencies automatically.

```         
# Install pak if needed
if (!requireNamespace("pak", quietly = TRUE)) {
install.packages("pak")
}
```

```         
# Install growthcurve from GitHub
pak::pak("jordanmbarrows/growthcurve")
```

Once installed, launch the app with: library(growthcurve) run_growthcurve()

The app performs a dependency check on startup and will fail with a descriptive error message if any required packages are missing. Required packages include: ggplot2, dplyr, tidyr, gcplyr, lubridate, multcomp, shinyjs, DT, future, promises, later, htmlwidgets, and shinyBS.

### 1.2 Application Architecture

The application is organized into three code layers, each with a distinct responsibility:

```         
File Purpose
```

```         
app.R Shiny UI definition and server orchestration. Handles file
selection, parameter inputs, progress reporting, cancellation, and
export. Contains no scientific computation.
```

```         
growthcurve_functions.R The analysis backend. Contains all scientific computation, plotting,
and file I/O. Designed to be deterministic and batch-safe.
```

```         
growthcurve_system.R System configuration and behavior layer. Centralizes OS
detection, regional settings (CSV and numeric formatting), app
versioning, error handling, and developer utilities.
```

A strict architectural rule is enforced throughout: the UI layer performs no scientific computation, and the analysis backend has no UI side effects. This separation makes the analysis pipeline independently testable and suitable for batch execution outside the Shiny interface.

## 2. Analysis Modes

The app provides three distinct workflows. Users will typically move through them in order — exploring a single dataset first, then running a batch, then aggregating results across multiple experiments.

### 2.1 Single Analysis

Single Analysis is the exploratory workflow. It is designed for interactive investigation of a single dataset and gives access to the full suite of 11 diagnostic plots, stage-by-stage.

Characteristics:

- Interactive, step-by-step plot navigation with Previous and Next stage buttons
- Immediate visual feedback after each analysis stage completes
- Parameters can be explored and refined before committing to export
- Export produces the same output structure as Batch Analysis (plots PDF, tidy CSV, metadata CSV)
- Input controls are locked after analysis runs to prevent accidental modification

Once a Single Analysis completes, all input fields are disabled. To re-run with different parameters, the page must be refreshed.

### 2.2 Batch Analysis

Batch Analysis is the production workflow. It processes multiple datasets in sequence without interactive plotting, making it efficient for routine analysis of many plates.

Characteristics:

- No stage-by-stage plot display during processing
- Cancellation is supported mid-batch via a Cancel button
- Each plate is processed into its own subdirectory under the run output folder
- A batch summary CSV is produced at the end of each run

Expected file layout for batch input:

```         
/batch/
data/
plate1.csv
plate2.csv
design/
plate1_design.csv
plate2_design.csv
```

The batch UI presents a matching table where each raw data file is paired with a design file using a dropdown selector. Design files that do not match a raw file can be excluded from the run.

Output structure per run:

```         
Run/
Plate_1/
plate_report.pdf
plate_tidy.csv
Analysis_arguments.csv
Plate_2/
```

```         
batch_summary.csv
```

The batch_summary.csv records the plate name, analysis status (success, failed, or cancelled), and any diagnostic messages for each plate processed in the run.

### 2.3 Aggregate Results

Aggregate Results combines the output from multiple independent analyses — whether from Single Analysis exports or completed Batch runs — into a single unified dataset for downstream statistical analysis.

Functionality:

- Searches recursively through selected run directories for all plate_tidy.csv files
- Harmonizes column structure across files (missing columns are filled with NA)
- Combines all results into a single data frame
- Exports the combined dataset as a timestamped CSV

Output file naming: combined_tidy_YYYYMMDD_HHMMSS.csv

Expected directory layout for aggregation: /Analysis/ run_1/ run_2/ run_3/

### 2.4 Duplicate Detection

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
2.  Save As CSV (standard comma-separated format)
3.  Use this saved file as the raw data input

Skipping this step will cause parsing to fail.

Internally, the plate reader parser uses gcplyr::import_blockmeasures() to extract the repeating 8-row x 12-column data blocks from the file. It expects data blocks starting at row 3 with a stride of 12 rows per timepoint. Columns 1–13 are read, and the first column (row labels) is dropped after import.

Instrument detection: the app distinguishes plate reader files from oCelloscope files by scanning the first 200 lines of the raw file and counting the number of occurrences of "Time (seconds)" as a row header. Files with more than one such header are classified as oCelloscope format.

### 3.2 Raw Data File — oCelloscope

oCelloscope files require a specific export and preparation workflow:

4.  Export the .xlsx file from the oCelloscope software
5.  Open in Excel
6.  Select the raw data sheet
7.  Use Save As to save that sheet as a CSV

Direct oCelloscope CSV exports are not compatible with this pipeline. Only the workflow above produces a correctly formatted file.

The parser searches the file for a line beginning with TANormalized. This is the only supported data block. Everything before and after this block is ignored. If the block is not found, analysis will fail with a descriptive error.

After locating the TANormalized header, the parser:

- Skips any empty lines between the header and data

- Reads data lines until it encounters an empty or delimiter-only row

- Passes the extracted block through read_csv_safe_text() for robust regional format handling

- Applies a sanity check: the maximum value in the data block must be less than 10 (normalized data). Values exceeding this threshold indicate a parsing error.

Well name extraction: well identifiers are extracted from column headers using a regex pattern (\^([A-H][0-9]+).\*), stripping any trailing suffixes. Only wells that appear in the design file's Well_type block are retained.

### 3.3 CSV Format Compatibility

The app supports both US and EU regional CSV formats:

```         
Format Details
US format Comma delimiter, dot decimal (e.g. 0.123)
```

```         
EU format Semicolon delimiter, comma decimal (e.g. 0,123)
```

Detection is performed by read_csv_safe(), which peeks at the first five lines of any file and counts commas versus semicolons. The format with the higher count is selected. This detection logic applies to both input reading and the safe text parser used for in-memory data blocks.

Output files are written using the region setting selected by the user in the app (or auto-detected from the R session locale on startup). All CSV I/O is routed through read_csv_safe() and write_csv_safe() — no direct calls to read.csv(), read.table(), or write.csv() are permitted anywhere in the codebase.

### 3.4 Design File

The design file defines the experimental layout of the plate. It must be a CSV file structured as a series of named blocks, one block per variable.

Block structure:

- Each block begins with a single header cell in the first column (e.g. Well_type, Strain, Treatment)
- The header is followed by exactly 8 rows (corresponding to plate rows A through H)
- Each row contains 12 values (corresponding to plate columns 1 through 12)
- Blocks are separated by exactly one empty row
- The stride between block headers is exactly 10 rows (1 header + 8 data rows + 1 empty row)

The first block must always be named Well_type. It defines whether each well is a Blank or a Sample. This block is used for blank correction and is filtered from output metrics.

Example design file structure (showing Well_type and Strain blocks):

```         
Well_type
```

##### ,1,2,3,4,5,6,7,8,9,10,11,

```         
A,Blank,Sample,Sample,Sample,...
B,Blank,Sample,Sample,Sample,...
...
H,Blank,Sample,Sample,Sample,...
```

```         
Strain
,1,2,3,4,...
A,WT,WT,KO,KO,...
...
```

Design variable selection: the app reads all block header names from the design file (excluding Well_type) and presents them as selectable design variables. In Single Analysis mode, the user selects which variables to include in the analysis. In Batch Analysis mode, design variables are inferred automatically from the design file if not explicitly provided.

Design parsing is handled by gcplyr::import_blockdesigns(). A temporary normalized copy of the design file is written before passing it to gcplyr, ensuring regional format compatibility. Row labels (single letters A–H) that appear in design variable columns as an artifact of the block format are removed after import.

## 4. Analysis Parameters

### 4.1 Required Parameters

```         
Parameter Description
Design variables One or more variable names selected from the design file blocks
(excluding Well_type). These define the grouping structure for
mean curve calculation, derivative computation, and summary
statistics.
Duration (hours) Total experiment duration in hours. Used to generate the time
vector for plate reader data. Must be a positive number.
```

```         
Interval (minutes) Measurement frequency in minutes. Used to generate the time
vector for both instrument types. Must be a positive number.
Default: 15 min for plate reader, 10 min for oCelloscope.
Min OD Lower bound of the OD window used for growth rate calculation.
Only timepoints with blank-corrected OD greater than this value
are analyzed. Default: 0.05 for plate reader, 0.01 for oCelloscope.
```

```         
Max OD Upper bound of the OD window. Only timepoints with OD less
than this value are included. Default: 0.7 for both instruments. Min
OD must be strictly less than Max OD.
```

### 4.2 Optional Parameters 

```         
Parameter Description
```

```         
Prefix A text label prepended to analysis outputs. Used in output
filenames and as a component of the duplicate detection key. If
left empty, outputs are labeled by plate name alone.
```

### 4.3 Blank Correction Mode

Blank correction is only applicable to plate reader data. oCelloscope data enters the pipeline already internally blanked by the instrument, so blank correction is disabled and the blank mode selector is greyed out when oCelloscope is selected.

```         
Mode Behavior
```

```         
plate Subtracts the median OD of all wells designated as Blank at time
zero from every well at every timepoint. This is the recommended
mode and the default.
per_well Subtracts the OD of each individual well at the first timepoint from
all subsequent timepoints of that well. Useful when wells have
highly variable baseline readings.
```

```         
none No blank correction applied. The raw measurements are used as-
is. Appropriate when data is already baseline-corrected.
```

In all cases, blank-corrected values are stored as Measurements_adj, and a log transformation of pmax(Measurements_adj, 1e-6) is stored as Measurements_log. The small floor value (1e-6) prevents log-of-zero errors.

### 4.4 Instrument Defaults

Instrument-specific default parameters are defined in the gc_instrument_defaults list in growthcurve_functions.R:

```         
Parameter Default value
```

```         
Plate reader interval 15 minutes
```

```         
Plate reader Min OD 0.
Plate reader Max OD 0.
```

```         
Plate reader smoothing Disabled
oCelloscope interval 10 minutes
```

```         
oCelloscope Min OD 0.
oCelloscope Max OD 0.
```

```         
oCelloscope smoothing Enabled, window = 3
```

## 5. Analysis Pipeline

All scientific computation is orchestrated by run_gc(), the top-level coordinator function in growthcurve_functions.R. It delegates to a series of explicit pipeline stages, each with clearly defined responsibilities and no side effects between stages.

### 5.1 Pipeline Stages

The run_gc() function executes the following stages in order:

```         
Stage Responsibility
```

```         
Stage A: gc_prepare_run() Input validation. Checks that all required arguments are present
and valid (file paths exist, hrs > 0, interval > 0, minod < maxod,
design_vars is a non-empty character vector). Builds the shared
ggplot theme object. Snapshots all resolved parameters.
```

```         
Stage B: gc_import_data() Data import. Dispatches to instrument-specific readers, imports
and parses the design file, then merges the two datasets using
gcplyr::merge_dfs(). Validates that design variables exist in the
design file before proceeding.
```

```         
Stage C: gc_core_compute() Core scientific computation. Performs blank correction, OD
filtering, derivative calculation, growth rate summarization, and
QC flagging. Returns all intermediate and final datasets. This
function is pure: no plotting, no file I/O.
```

```         
Stage D: gc_build_plots() Plot construction. Builds all 11 ggplot objects from the outputs of
gc_core_compute(). No saving or printing occurs at this stage.
```

```         
Stage E: Assembly The final return object is assembled, containing the parameter
snapshot, instrument type, blank mode, core compute results, and
all plot objects.
```

### 5.2 Data Import Details

gc_import_data() combines instrument-specific reading logic with shared design parsing and merging:

For plate reader data:

- The raw file is normalized through read_csv_safe() first
- A clean temporary copy is written in standard CSV format for gcplyr compatibility
- gcplyr::import_blockmeasures() reads the repeating 8x12 data blocks
- The first column (row labels) is stripped
- A time vector in hours is computed from the interval and number of timepoints
- gcplyr::trans_wide_to_tidy() converts from wide to long format

For oCelloscope data:

- read_ocello_tanormalized() extracts the TANormalized block as raw lines

- format_ocelloscope_data() assigns the time vector and filters wells against the design

- A block_name column is added with value "ocelloscope"

- gcplyr::trans_wide_to_tidy() converts to long format

After either path, the tidy data is merged with the parsed design using gcplyr::merge_dfs(), NA values are removed with na.omit(), and the Time column is coerced to numeric. A warning is emitted if the maximum Time value exceeds 200, which suggests the time vector may still be in minutes rather than hours.

### 5.3 Core Computation Details

gc_core_compute() is the scientific heart of the pipeline. It takes the merged data and blocklist as inputs and returns a structured list containing all intermediate datasets and final metrics.

#### Blank correction

Blank correction proceeds according to the blank_mode argument. The plate mode extracts all wells where Well_type == "Blank" at t0 and computes the median (blankmed). This median is subtracted from all wells at all timepoints. The per_well mode subtracts each well's own t 0 value. All modes produce a Measurements_adj column and a Measurements_log column.

#### Mean curve calculation

After blank correction, a mean curves dataset (merged_data_means) is computed. Blank wells are excluded. Data is grouped by the user-selected design variables and by Time. For each group, the mean, standard deviation, sample count, and 95% confidence interval are calculated. A group_id column is created as a factor interaction of all design variables for plotting.

#### OD window filtering

The dataset is subset to rows where Measurements_adj \> minod AND Measurements_adj \< maxod. If no rows survive this filter, analysis aborts with an error message listing possible causes: mismatched design file, wrong instrument mode, overly restrictive thresholds, or empty post-merge data.

#### Growth rate computation (gcplyr)

Within the OD window, the pipeline computes three derivative columns for each well:

```         
Column Computation
```

```         
deriv Raw absolute growth rate: gcplyr::calc_deriv(x=Time,
y=Measurements_used)
deriv_percap Per-capita growth rate without windowing: gcplyr::calc_deriv(...,
percapita=TRUE, blank=0)
deriv_percap3 Per-capita growth rate with 3-timepoint rolling window on log-
transformed data: gcplyr::calc_deriv(..., percapita=TRUE, blank=0,
window_width_n=3, trans_y="log")
```

The deriv_percap3 column is the primary metric used for maximum growth rate extraction. The rolling window of 3 timepoints and log transformation improve robustness to noise while preserving the true growth signal. The window_width_n=3 choice is intentional and instrument- aware — the same code path is used for both instrument types, but oCelloscope data is pre- smoothed before derivatives are computed.

For oCelloscope data, when smoothing=TRUE, gcplyr::smooth_data() is applied to Measurements_adj using a moving-average method with window_width_n equal to the smoothing_window value (default 3). This produces the Measurements_used column. For plate reader data, Measurements_used equals Measurements_adj directly.

#### Growth summary metrics

Per-well summary statistics are computed by grouping on the design variables and Well:

```         
Metric Computation
```

```         
max_percap Maximum per-capita growth rate: gcplyr::max_gc(deriv_percap3,
na.rm=TRUE)
```

```         
max_percap_time Time at which max_percap occurs: gcplyr::extr_val(Time,
gcplyr::which_max_gc(deriv_percap3))
```

```         
doub_time Doubling time in hours: gcplyr::doubling_time(y = max_percap)
```

If all values of deriv_percap3 for a well are NA, the summary metrics are set to NA_real\_. This prevents crashes from wells with no valid data.

#### QC flagging

After summarization, gc_add_qc() assigns a QC_flag and QC_reason to each well based on the computed metrics:

```         
Flag Condition
FAIL max_percap is NA (no growth rate detected) or doub_time is NA
(undefined doubling time)
```

```         
WARN doub_time < 0.2 hours (very fast growth, likely a calculation
artifact) or doub_time > 10 hours (very slow growth)
```

```         
OK All metrics are within expected ranges
```

QC flags are joined back onto the merged_data, merged_data_sub, and ex_dat_mrg_sum datasets so they are available in all downstream plots.

## 6. Diagnostic Plots

All 11 plots are produced by gc_build_plots(), which takes the core compute results and the shared ggplot theme as inputs. In Single Analysis mode, plots are displayed one at a time with stage navigation. In Batch Analysis mode, all plots are rendered directly to the PDF report without display.

QC-flag coloring is applied to relevant plots using gc_qc_scale(), which maps OK wells to black, WARN wells to orange (#E69F00), and FAIL wells to light grey at reduced opacity (alpha = 0.3). This allows rapid visual identification of problematic wells across all summary plots.

```         
Plot Content and purpose
Plot 1: Blank-corrected OD
(linear)
```

```         
All wells plotted on a linear OD scale after blank correction,
colored by Well_type (Blank vs Sample). Used to inspect the
overall scale of the data and verify blank subtraction.
```

```         
Plot 2: Blank-corrected OD (log
scale)
```

```         
Same data on a log10 scale. Reveals early exponential growth
behavior and helps identify wells that never truly left the blank
baseline.
```

```         
Plot 3: Mean curves with 95% CI Mean growth curves for each experimental group defined by the
design variables, with 95% confidence interval ribbons. Groups
are distinguished by both color and linetype.
```

```         
Plot 4: Per-well OD curves
(linear)
```

```         
Individual well curves faceted by design variable combinations,
linear scale. Used to identify outlier wells and inspect within-group
variability.
```

```         
Plot 5: Per-well OD curves (log
scale)
```

```         
Same per-well faceted view on a log10 scale.
```

```         
Plot 6: Raw derivatives Absolute growth rate (deriv) over time, per well, within the OD
window. Useful for checking the magnitude and timing of the
growth rate signal.
Plot 7: Per-capita derivatives Per-capita growth rate (deriv_percap, no windowing) over time.
Shows the unsmoothed growth rate trajectory.
Plot 8: Fitted per-capita with
maximum
```

```         
The windowed per-capita derivative (deriv_percap3) with a vertical
marker at the timepoint of maximum growth rate
(max_percap_time). This is the primary derivative used for metric
extraction.
```

```         
Plot 9: OD curves with max
growth marked
```

```         
OD curves (from merged_data_sub) with a dot plotted at the
timepoint of maximum growth for each well, colored by QC flag.
```

```         
Plot 10: Doubling time summary Boxplot and jitter of doubling time per experimental group, with
mean and 95% CI. Wells colored by QC flag.
```

```         
Plot 11: Maximum growth rate
summary
```

```         
Boxplot and jitter of max_percap per experimental group, with
mean and 95% CI. Wells colored by QC flag.
```

## 7. Output Files

### 7.1 Plot Report (plate_report.pdf)

The PDF report contains all 11 diagnostic plots, one per page. It is generated by gc_save_report(), which renders each ggplot object sequentially to a PDF device. The plate name (derived from the raw data filename) is used as the report title. This file is intended as a visual quality-control record accompanying each analysis.

### 7.2 Tidy Results (plate_tidy.csv)

This is the primary scientific output of the analysis. It contains one row per well per measurement type, in long (tidy) format suitable for direct import into statistical analysis tools or ggplot2.

Column schema:

```         
Column Content
```

```         
[design variables] One column per design variable selected at analysis time (e.g.
Strain, Treatment). Values are taken directly from the design file.
```

```         
Well Well identifier (e.g. A1, B3).
Measurement Type of measurement: max_growth (the maximum per-capita
growth rate) or doub_time (the doubling time in hours).
```

```         
Value Numeric value of the measurement.
Replicate Integer replicate index assigned within each combination of
design variables and measurement type. Assigned by
row_number() within each group.
```

```         
QC_flag OK, WARN, or FAIL. See Section 5.3 for flag definitions.
QC_reason Empty string for OK wells; a short description for WARN and FAIL
wells.
instrument The instrument type used: plate_reader or ocelloscope.
```

```         
prefix The user-specified prefix. Empty string if no prefix was provided.
```

The tidy format means that max_growth and doub_time appear as separate rows for the same well, not as separate columns. This makes the file directly usable with dplyr group_by and ggplot2 facet operations in downstream analysis.

### 7.3 Analysis Metadata (Analysis_arguments.csv)

A single-row CSV recording all parameters used for the analysis. This file provides a complete audit trail for reproducibility.

```         
Field Content
```

```         
rawdatafile Full path to the raw data file
```

```         
designfile Full path to the design file
instrument plate_reader or ocelloscope
```

```         
blank_mode plate, per_well, or none
hrs Duration in hours
```

```         
interval Interval in minutes
```

```         
minod Lower OD threshold
maxod Upper OD threshold
```

```         
design_vars Comma-separated list of selected design variables
prefix Prefix used (empty if none)
```

### 7.4 Batch Summary (batch_summary.csv)

Produced at the end of every Batch Analysis run. Contains one row per plate. Fields include the plate name, analysis status (success / failed / cancelled), and any diagnostic messages produced during analysis of that plate.

### 7.5 Aggregate Output (combined_tidy_YYYYMMDD_HHMMSS.csv)

Produced by the Aggregate Results workflow. Contains the combined rows from all plate_tidy.csv files in the selected run directories. Column structure is harmonized across files (missing columns filled with NA). The timestamp in the filename is derived from the system time at the moment of export.

## 8. Regional Settings

Regional formatting affects how CSV files are written and how numeric axis labels are rendered in plots. The app detects the current region on startup from the R session locale (Sys.localeconv()[["decimal_point"]]): a comma decimal mark triggers EU mode, a dot triggers US mode. Users can override this detection in the app's settings area.

```         
Region Format
```

```         
US format Comma delimiter (,) and dot decimal (.). Standard for R and most
data analysis tools.
```

```         
EU format Semicolon delimiter (;) and comma decimal (,). Required for
compatibility with Excel and other tools in many European locales.
```

The region setting affects:

- All CSV output files: plate_tidy.csv, Analysis_arguments.csv, batch_summary.csv, and combined_tidy files
- Numeric axis labels in diagnostic plots (format_axis_labels() converts dots to commas for EU mode)

All file I/O is routed through two centralized functions defined in growthcurve_system.R:

```         
Function Behavior
read_csv_safe(file, ...) Reads a CSV file with automatic delimiter and decimal detection.
Calls read.table() with the inferred settings. Raises a gc_error if
the file does not exist or cannot be parsed.
```

```         
read_csv_safe_text(text, ...) Same logic applied to an in-memory text block rather than a file
path. Used for parsing extracted oCelloscope data blocks.
write_csv_safe(df, file, region) Writes a data frame using the delimiter and decimal mark for the
specified region. Converts numeric-like columns back to numeric
before writing.
```

## 9. System Layer (growthcurve_system.R)

The system layer centralizes all environment-dependent behavior. No other part of the application should directly query the operating system, read locale settings, or make version comparisons. All such behavior is delegated to functions in this file.

### 9.1 Error Handling

The app uses a standardized error system based on the gc_abort() function, which raises a condition of class c("gc_error", "error", "condition") with a clean, user-readable message.

Error formatting is handled by gc_format_error(). In user mode (default), this function returns a standardized, non-technical message: "The analysis could not be completed. Please check your instrument, input files, and formatting." In developer mode, it returns the full error message and class information.

### 9.2 Developer Mode

Developer mode provides additional logging and debugging output. It is disabled by default and must be explicitly enabled:

```         
options(gc.dev_mode = TRUE)
```

When active, developer mode enables:

- gc_log() and gc_log_block() print diagnostic messages to the R console with a [GC] prefix
- Detailed error output in gc_format_error(), including error class and full message
- Debug panels in the Shiny UI

### 9.3 Update Checker

The app checks for updates on startup by querying the GitHub releases API:

```         
https://api.github.com/repos/jordanmbarrows/growthcurve/releases/latest
```

The latest release tag is compared against the installed package version using utils::compareVersion(). If a newer version is available, the user is notified in the UI with instructions for installing the update. The checker does not force installation and does not block app startup if the network request fails.

### 9.4 OS-Aware Folder Opening

The Open export folder button in export dialogs uses open_folder(), which dispatches to the appropriate system command based on the detected OS: shell.exec() on Windows, open on macOS, and xdg-open on Linux. Failures are caught and surfaced as console warnings without crashing the app.

### 9.5 Backend Readiness Check

gc_backend_ready() verifies that the three core backend components — run_gc, read_csv_safe, and gc_check_packages — are present in the growthcurve package namespace. This check runs on app startup and assigns any error message to gc_startup_error in the global environment, allowing the UI to display a clear startup failure message if the backend is not properly loaded.

## 10. UI Features

### 10.1 File Preview

When a raw data file is selected, the app attempts to build a preview of the file contents:

- For plate reader files: the first 20 rows of the raw CSV are displayed as a table
- For oCelloscope files: the TANormalized data block is extracted and the first 20 rows are displayed, using the selected interval to compute approximate time values
- If the oCelloscope preview requires a design file that has not yet been selected, a message is shown instead of a table

The preview helps users verify that the correct file has been selected and that it is being parsed in the expected format before running analysis.

### 10.2 Dark Mode

A dark/light theme toggle is available in the top navigation area. Dark mode applies to all UI elements including modals, tables, and form controls. It does not apply to the ggplot diagnostic plots, which always render on a white background regardless of the UI theme. The toggle is implemented via a CSS class (dark-mode) applied to the html element and a corresponding bslib bs_theme data attribute.

### 10.3 Cancellation

Batch Analysis can be cancelled mid-run using a Cancel button that appears during processing. Cancellation is implemented via a reactive flag checked between each plate in the batch. When cancellation is triggered, the current plate's analysis is allowed to complete, and then the batch loop exits. The batch summary records cancelled as the status for all plates not yet processed.

### 10.4 Navigation Lock

In Single Analysis mode, all input controls (raw file, design file, instrument, parameters, design variables) are disabled after analysis runs. This prevents accidental modification of inputs while reviewing results. The controls remain disabled until the page is refreshed. Navigation between plot stages is provided by Previous and Next buttons that are enabled/disabled according to the current stage index.

### 10.5 User Guide

The app includes a built-in User Guide tab containing embedded documentation covering all workflow steps, file format requirements, parameter descriptions, and output file descriptions. The guide is rendered as styled HTML within the Shiny UI using collapsible details/summary elements for each topic.

## 11. gcplyr Integration

GrowthCurve uses the gcplyr R package (Blazanin 2024, BMC Bioinformatics) as its scientific computation engine. gcplyr provides the core functions for growth curve data manipulation and analysis. The following gcplyr functions are used directly in the pipeline:

```         
Function Role in pipeline
```

```         
gcplyr::import_blockmeasures() Reads repeating data blocks from plate reader CSV files. Called
with startrow, endrow, startcol, and endcol vectors defining the
position of each timepoint block.
```

```         
gcplyr::trans_wide_to_tidy() Converts wide-format plate data (one column per well) to tidy long
format (one row per well per timepoint).
```

```         
gcplyr::import_blockdesigns() Reads the design file block structure. Called with block_names,
startrow, and endrow vectors.
```

```         
gcplyr::merge_dfs() Merges the tidy data with the design metadata by the Well
column.
```

```         
gcplyr::smooth_data() Applies a moving-average smooth to the Measurements_adj
column for oCelloscope data (sm_method="moving-average",
window_width_n=3).
gcplyr::calc_deriv() Computes absolute and per-capita derivatives. The windowed
per-capita derivative (window_width_n=3, trans_y="log") is the
primary metric input.
gcplyr::max_gc() Extracts the maximum value of the windowed derivative per well.
```

```         
gcplyr::which_max_gc() Returns the index of the maximum in the derivative vector.
gcplyr::extr_val() Extracts the Time value at the index returned by which_max_gc().
```

```         
gcplyr::doubling_time() Converts the maximum per-capita growth rate to doubling time in
hours: log(2) / max_percap.
```

For a comprehensive explanation of the underlying methodology, including the mathematical basis for per-capita derivative calculation and the interpretation of window_width_n, refer to the gcplyr documentation at:

<https://mikeblazanin.github.io/gcplyr/articles/gc01_gcplyr.html>

## 12. File Structure Reference

### 12.1 Single Analysis

```         
/project/
raw_data.csv # plate reader or oCelloscope data
design.csv # experimental design
```

```         
Analysis/ # created on export
[prefix_]raw_data/
plate_report.pdf
plate_tidy.csv
Analysis_arguments.csv
```

### 12.2 Batch Analysis

```         
/batch/
data/
plate1.csv
plate2.csv
design/
plate1_design.csv
plate2_design.csv
```

```         
Analysis/ # created on export
Run_YYYYMMDD_HHMMSS/
plate1/
plate_report.pdf
plate_tidy.csv
Analysis_arguments.csv
plate2/
```

```         
batch_summary.csv
```

### 12.3 Aggregate Analysis

```         
/Analysis/
Run_1/
plate1/
plate_tidy.csv
batch_summary.csv
Run_2/
```

```         
combined_tidy_YYYYMMDD_HHMMSS.csv # produced by Aggregate
```

## 13. Troubleshooting

**Error / symptom Likely cause and resolution**

"TANormalized block not found" The oCelloscope file was not exported correctly, or the wrong sheet was saved. Re-export from oCelloscope, open in Excel, select the raw data sheet, and Save As CSV.

"TANormalized sanity check failed: max value is X"

```         
The data block contains values greater than 10, indicating the
data is not normalized. Check that the correct block/sheet was
exported from oCelloscope.
```

"No data points fall within the OD window"

```         
The OD window [minod, maxod] does not overlap with any blank-
corrected measurements. Check that the correct instrument mode
is selected, that the design file matches the data, and that the OD
thresholds are appropriate for the data range.
```

"No overlapping wells between data and design"

```         
Well names in the raw data file do not match well names in the
design file. Verify both files use standard plate notation (A1–H12).
```

"Design variables not found in design file"

```         
One or more selected design variables do not appear as block
headers in the design file. Check for typos or verify the design file
has been saved correctly.
```

Plate reader file fails to parse The file was not saved as a standard CSV from Excel. Open in Excel and re-save as CSV before uploading.

EU-format files produce wrong numbers in output

```         
The region setting does not match the file format. Override the
region in the app settings to match your locale.
```

App fails to start with missing backend error

```         
A required package is not installed. Run gc_check_packages() in
the R console to identify missing dependencies and install them.
```
