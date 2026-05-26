# Changelog

## Unreleased

### Improvements
- Added check update function to see if the current version matches the most recent on Github
 - Prompts user to install the latest one if not
- Generalized run failure message and improved console log output (dev mode only)

### Fixes
- Replaced non-ASCII characters with either ASCII-safe characters or HTML codes for emojis
- Disabled blank mode radio buttons at all times if oCelloscope is selected
  - Generalized blank mode state enforcement
- Fixed issue where European regional formatting was misinterpreting scientific notation for preview tables

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

---

## [0.6.4] - 2026-05-12

### Added
- Prototype version of app
