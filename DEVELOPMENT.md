# Development Setup

## Project Structure

```
growthcurve_app/
├── DESCRIPTION           # Package metadata
├── NAMESPACE             # Exported functions
├── LICENSE               # MIT license
├── README.md             # User documentation
├── DEVELOPMENT.md        # This file
├── R/
│   ├── run_growthcurve.R
│   └── growthcurve-package.R
└── inst/
    └── app/
        ├── app.R                    # Main Shiny app 
        ├── growthcurve_system.R     # System functions
        ├── growthcurve_functions.R  # Core analysis functions
        ├── preview_files/
        │   └── plate_design_for_preview.csv
        └── templates/
            ├── design_template_us.csv
            └── design_template_eu.csv
```

## Setup Instructions

### 1. Create Directory Structure

```bash
mkdir -p R inst/app/templates inst/app/"preview files"
```

### 2. Move Your Files

```bash
# Move app files to inst/app/
mv growthcurve_app.R inst/app/app.R
mv growthcurve_system.R inst/app/
mv growthcurve_functions.R inst/app/

# Move preview file to inst/app/preview files/
mv plate_design_for_preview.csv inst/app/"preview files"/

# Remove the old launcher (no longer needed)
rm launch_app.R
```

### 3. Create R/ Files

Create the wrapper files in the `R/` directory as shown in the files below.

## Development Workflow

### Load Package During Development

```r
devtools::load_all()
```

### Install Locally

```r
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

## Installation Methods for Users

### Method 1: From GitHub

```r
devtools::install_github("jordanmbarrows/growthcurve_app")
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

### Missing Dependencies

If users encounter missing package errors, they can install all dependencies:

```r
install.packages(c("shiny", "shinyjs", "shinyBS", "DT", "ggplot2", 
                   "dplyr", "tidyr", "gcplyr", "lubridate", "multcomp",
                   "future", "promises", "later", "htmlwidgets", "tidyselect"))
```

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

- [ ] Create GitHub repository
- [ ] Add design file templates to `inst/app/templates/`
- [ ] Add unit tests in `tests/testthat/`
- [ ] Add example data in `inst/extdata/`
- [ ] Consider submitting to CRAN
