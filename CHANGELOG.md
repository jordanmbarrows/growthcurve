# Changelog

## Unreleased

- Added flexibility to input file strategy
  - Plate reader vs oCelloscope detection works simply by searching for `TANormalized`
  - Plate reader inputs are now quickly scanned to determine if `block` or `wide` format
  - Both `block` and `wide` format are automatically parsed
  - Plate reader `block` format parser is now more flexible and allows for detection of rectangular blocks anywhere in the source file
    - Can detect partial blocks (rectangles that are not full 96-well plates)
    - Increases analysis runtime because scanning files and designing custom detection vectors takes longer
  - Added `raw_data_format` and `design_file_format` fields to `Analysis_args.csv` to record `block` vs `wide` format
- Updated preview table for `wide` format (both plate reader and oCelloscope)
- Explicitly assigned `subset_by = Well` in all `gcplyr::calc_deriv` calls for future-proofing and console noise
- Cancellation during batch mode now kills current plate analyses so that it happens more quickly after user presses button.
  - Completed plates are now defined as those that have results written to the disk, rather than those that started processing.  
- Added comprehensive debug logging including well/design/data matching and progress updates in the console as well as an exported debug file that includes progress flags, total and active wells, and several other informative metrics.
  - Exported file is written to timestamped run directory
  - Debug logging is dev-mode only. Console debug output and temporary debug log files are suppressed for normal users and enabled only when `gc.dev_mode` is active.
  - All console output (including ggplot2 warnings) is now suppressed in production mode

### Fixes

- Fixed hidden bug with design file input leading to phantom 13th column and well assignment mismatches
  - Replaced `gcplyr::import_block_designs` and `gcplyr::merge_dfs` because the updated pipeline handles those actions better
  -Corrected oCelloscope design parsing so that active wells are assigned according to the actual design file layout. Active values in the oCelloscope design template begin in plate column 2; older output behavior was consistent with a one-column-right shift followed by truncation during raw/design overlap.
    -This affected oCelloscope well assignment and replicate grouping in previous versions. Current single and batch oCelloscope outputs now align with the design file and raw well set. Users may wish to re-run older oCelloscope analyses with the corrected parser.
- Fixed bug where blank mode radio buttons were not disabled after running single plate analysis
- Fixed bug where batch mode was writing `plate_name` to `prefix` column in `plate_tidy.csv`


## [1.0.10] - 2026-05-29

- Renamed `deriv_percap5` object to `deriv_percap3` in `growthcurve_functions.R`
  - Does not change behavior, but now accurately reflects usage of `window_width_n = 3` when calculating fitted per-capita derivative
- Added comprehensive User & Technical Guide to main page in repo (`USERGUIDE.md`)
  - This guide is sourced from `USERGUIDE_source.md`, which automatically pulls version number from `DESCRIPTION` to keep it up to date
  - Script in `.Rprofile` automatically sources `update_userguide.R` to update `USERGUIDE.md` every time `growthcurve.Rproj` is launched
- Added note at bottom of User Guide tab in app that displays current version number and provides a link to the repo for more info and latest updates
- Enhanced Aggregate Results section in the User Guide tab
- Made parallel processing the default for batch processing

## [1.0.9] - 2026-05-28

### Improvements

- Updated plots 10 and 11 titles to reflect mean and 95% CI
- Changed `Plate` column name in plate_tidy.csv to `prefix` (more accurate) and changed behavior to always include it, even if `NULL`
- Included `prefix` column from `plate_tidy.csv` in `combined__*.csv` file
- Reordered columns in `combined__*.csv` so that metadata cols are first: `file_index | source_file | run_name | prefix | instrument | plate_ | Well | ...`
- Made variable detection during aggregation more flexible; works by selecting all columns beyond those expected to be present and placing them after `Well`
- Updated duplication detection prior to detection to include both prefix and plate name (raw data file name)
  - Allows users to run analyses with different parameters on the same data and not have them flagged as duplicates
  - Updated duplication warning modal to reflect these changes and demonstrate plate and prefix names for duplicates
  - Updated Prefix section in User guide with guidance on using prefixes to differentiate analyses with different parameters
- Added horizontal scroll bar to aggregate selection table so users can see entire tool tip
  - Vertical and horizontal scroll bars are now controlled entirely by CSS, not DT, so they live outside the table
    - Results in both scroll bars always being visible, rather than having to scroll to see one or the other
  - Removing container settings from DT also allowed tooltips on duplicate runs showing the matching runs to show up on hover

## [1.0.8] - 2026-05-28

### Improvements

- Restructured output strategy:
  - Eliminate Plots/ and Summaries/ directories
  - Save all plots in single PDF file called plate_report.pdf
  - Eliminate export of merged_data.csv and ex_dat_mrg_sum.csv (these are diagnostic intermediates and not necessary for general use)
  - Analysis_args.csv and plate_tidy.csv files are unchanged
  - Modify Aggregate results behavior to be more flexible (still backwards compatible)
- Clarified design file preview and templates to say 'Sample' instead of 'Not_Blank'
- Updated User guide tab instructions to clarify that 'Well-type' and 'Blank' must be written exactly
- Clarified downloadable Design file templates
- Added .gitattributes file directing Git to convert CRLF to LF upon commit (standardize CSVs)
- Added `run_gc`, `gc_save_report`, and `gc_write_summaries` to NAMESPACE

### Fixes

- Added `scrollCollapse = TRUE` to Aggregate results selection table so it only fills space if it needs it

## [1.0.7] - 2026-05-26

### Internal

- Improved update modal with user instructions

## [1.0.6] - 2026-05-26

### Internal

- Version bump to test update system behavior

## [1.0.5] - 2026-05-26

### Internal

- Version bump to test update system behavior
- Improved update modal with user instructions

## [1.0.4] - 2026-05-26

### Internal

- Version bump to test update system behavior

## [1.0.3] - 2026-05-26

### Improvements

- Added check update function to see if the current version matches the most recent on GitHub
- Prompts user to install the latest one if not
- Generalized run failure message and improved console log output (dev mode only)

### Fixes

- Replaced non-ASCII characters with ASCII-safe characters or HTML codes for emojis
- Disabled blank mode radio buttons when oCelloscope is selected
- Generalized blank mode state enforcement
- Fixed issue where European formatting misinterpreted scientific notation in preview tables
- Updated imports in DESCRIPTION
- Fixed inconsistency between GitHub tags and DESCRIPTION version
- Cleaned up documentation
- Added `check_for_updates()` to NAMESPACE
- Replaced obsolete `APP_CONFIG$region` calls with `gc_app_config()$region`

## [1.0.2] - 2026-05-26

### Improvements

- Simplified global control over regional settings for previews and exports (US vs European)
  - Now more obvious with radio buttons under working directory select
- Made preview tables responsive to regional settings in real time to match exported files

### Fixes

- Disabled Cancel button in batch mode when not running analysis

## [1.0.1] - 2026-05-26

### Internal improvements & bug fixes

- Moved helper functions into `R/` directory
- Fixed namespace resolution issues in Shiny runtime
- Removed `source()`-based function loading
- Stabilized async batch execution (future + promises)
- Hardened error handlers against missing conditions
- Resolved `"argument 'e' is missing"` crashes
- Improved compatibility with `devtools::load_all()`
- Added dark mode with in-app toggle
- Condensed and removed redundancy from app.R file
- Added cancellation function to batch mode
- Updated plate failure behavior in batch mode
- Updated Aggregate runs selection table to show all directories

## [1.0.0] - 2026-05-12

### Added

- Initial release
- Shiny app for growth curve analysis
- CSV import functionality
- Interactive visualization

### Stabilized

- Path handling issues
- Namespace errors

------------------------------------------------------------------------

## [0.6.4] - 2026-05-12

### Added

- Prototype version of app
