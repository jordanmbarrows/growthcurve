# Growth Curve Analysis Application

An interactive Shiny application for analyzing microbial growth curves from plate reader and oCelloscope instruments.

## Quick Start

``` r
if (!requireNamespace("pak", quietly = TRUE)) {
  install.packages("pak")
}
pak::pak("jordanmbarrows/growthcurve")

library(growthcurve)
run_growthcurve()
```

## Installation

### From GitHub

``` r
# Install pak if needed
if (!requireNamespace("pak", quietly = TRUE)) {
  install.packages("pak")
}

# Install growthcurve package
pak::pak("jordanmbarrows/growthcurve")
```

### Local Installation

1.  Clone or download the repository

``` bash
git clone https://github.com/jordanmbarrows/growthcurve.git
cd growthcurve
```

2.  In R/RStudio:

``` r
devtools::install()
```

## Usage

Once installed, launch the application with:

``` r
library(growthcurve)
run_growthcurve()
```

This opens the interactive Shiny app in your default web browser.

## Features

- **Single Plate Analysis**: Analyze individual growth curve experiments
- **Batch Processing**: Process multiple plates individually
- **Results Aggregation**: Combine results from multiple runs
- **Interactive Visualization**: Explore 11 different analysis plots
- **Quality Control**: Automatic flagging of problematic wells
- **Regional Support**: US and European CSV formats
- **Instrument Support**: Plate reader and oCelloscope data formats

## Screenshot

Example interface for analyzing microbial growth curves::

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

## Basic Workflow

1.  Launch the app: `run_growthcurve()`
2.  Set your working directory in the app
3.  Choose analysis mode (Single plate, Batch, or Aggregate)
4.  Select your data and design files
5.  Configure analysis parameters
6.  Run analysis and export results

## System Requirements

- R ≥ 4.0.0
- All required dependencies are installed automatically during installation

## License

MIT License - See LICENSE file for details

## Author

Jordan M Barrows

## Acknowledgements

This application relies heavily on the `{gcplyr}` R package for growth curve analysis.
We gratefully acknowledge the developers of `{gcplyr}` for their work in implementing
the core analysis methods used here.

## Citation

If you use this tool, please cite the underlying package:

>Blazanin, M. gcplyr: an R package for microbial growth curve data analysis. 
>BMC Bioinformatics 25, 232 (2024). 
>https://doi.org/10.1186/s12859-024-05817-3

A BibTeX entry for LaTeX users is

```bibtex
@Article{,
  title = {gcplyr: an R package for microbial growth curve data analysis},
  author = {Michael Blazanin},
  year = {2024},
  doi = {10.1186/s12859-024-05817-3},
  journal = {BMC Bioinformatics},
  volume = {25},
  number = {232},
  note = {version 1.12.0},
}
```

## Support

For issues or questions, please open an issue on GitHub.
