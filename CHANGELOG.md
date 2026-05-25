# Changelog

## Unreleased

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
- Updated Aggregate runs selection table to show all directories, rather than just 10

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
