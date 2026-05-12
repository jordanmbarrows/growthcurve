# Growth Curve Analysis Application

A comprehensive Shiny application for analyzing microbial growth curves from plate reader and oCelloscope instruments.

## Quick Start

```r
if (!requireNamespace("pak", quietly = TRUE)) {
  install.packages("pak")
}
pak::pak("jordanmbarrows/growthcurve")

library(growthcurve)
run_growthcurve()
```

## Installation

### From GitHub

```r
# Install pak if needed
install.packages("pak")

# Install growthcurve package
pak::pak("jordanmbarrows/growthcurve")
```

### Local Installation

1. Clone or download the repository
```bash
git clone https://github.com/jordanmbarrows/growthcurve.git
cd growthcurve
```

2. In R/RStudio:

```r
devtools::install()
```

## Usage

Once installed, launch the application with:

```r
library(growthcurve)
run_growthcurve()
```

This opens the interactive Shiny app in your default web browser.

## Features

- **Single Plate Analysis**: Analyze individual growth curve experiments
- **Batch Processing**: Process multiple plates automatically
- **Results Aggregation**: Combine results from multiple runs
- **Interactive Visualization**: Explore 11 different analysis plots
- **Quality Control**: Automatic flagging of problematic wells
- **Regional Support**: US and European CSV formats
- **Instrument Support**: Plate reader and oCelloscope data formats

### Screenshot

![Screenshot](inst/app/www/screenshot.png)

## Data Requirements

### Raw Data Files
- CSV format (comma or semicolon delimited)
- 96-well plate layout compatible
- Time-series measurements

### Design Files
- Block-based layout format
- Must include `Well_type` variable
- Additional experimental variables (strain, treatment, etc.)

See the User Guide tab in the app for detailed format specifications.

## Quick Start

1. Launch the app: `run_growthcurve()`
2. Set your working directory in the app
3. Choose analysis mode (Single plate, Batch, or Aggregate)
4. Select your data and design files
5. Configure analysis parameters
6. Run analysis and export results

## System Requirements

- R ≥ 4.0.0
- All required dependencies are installed automatically during installation

## License

MIT License - See LICENSE file for details

## Author

Jordan Barrows

## Support

For issues or questions, please open an issue on GitHub.
"# growthcurve" 
