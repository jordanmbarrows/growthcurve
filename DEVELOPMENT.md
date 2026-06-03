# Development Setup

## Project Structure

```
growthcurve/
├── DESCRIPTION
├── NAMESPACE
├── LICENSE
├── README.md
├── DEVELOPMENT.md
├── R/
│   ├── growthcurve_system.R
│   ├── growthcurve_functions.R
│   ├── run_growthcurve.R
│   └── growthcurve-package.R
└── inst/
    └── app/
        ├── app.R
        ├── preview_files/
        └── templates/
```

## Development Workflow

### Load Package During Development

```r
devtools::load_all()
```

### Install Locally

```r
# From the project root directory
devtools::install()
```

### Check for Errors

```r
devtools::check()
```

### Build Documentation

```r
devtools::document()
```

### Build Package

```r
devtools::build()
```

### Fast Development Loop

During development, use:

```r
Ctrl + Shift + L  # devtools::load_all()
run_growthcurve()
```

## Installation Methods for Users

### Method 1: From GitHub

```r
if (!requireNamespace("pak", quietly = TRUE)) {
  install.packages("pak")
}
pak::pak("jordanmbarrows/growthcurve")
library(growthcurve)
run_growthcurve()
```

### Method 2: From Local File

Users can download and install locally:

```r
devtools::install()
library(growthcurve)
run_growthcurve()
```

### Method 3: Binary Package

Build a binary package:

```bash
R CMD build .
```

Then share the `.tar.gz` file for installation.

## Troubleshooting

### Package Not Found

Ensure the package is installed:

```r
library(growthcurve)
```

If this fails, reinstall:

```r
devtools::install()
```

## Next Steps

- [x] “Potential optimization: avoid double-reading block-format files and precompute detection masks.”
- [ ] Fix bug where dropdown selectors flicker if nothing selectable is present. Just make this a little more informative/smooth
- [ ] Add unit tests in `tests/testthat/`
- [ ] Add example data in `inst/extdata/`
- [ ] Consider submitting to CRAN
