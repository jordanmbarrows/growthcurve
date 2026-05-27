# Changelog

## Unreleased

### Improvements
- Updated all instances of 'Not_Blank' to 'Sample'

## [1.0.7] - 2026-05-26

### Improvements
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

---

## [0.6.4] - 2026-05-12

### Added
- Prototype version of app
