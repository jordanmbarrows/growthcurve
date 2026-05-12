#' Launch the Growth Curve Analysis Shiny Application
#'
#' Opens the interactive Growth Curve Analysis application in your default web browser.
#' The app provides tools for analyzing microbial growth curves from plate reader
#' and oCelloscope instruments.
#'
#' @return
#' Launches a Shiny application. Returns NULL invisibly when the app is closed.
#'
#' @details
#' The application includes:
#' - Single plate analysis with interactive visualization
#' - Batch processing for multiple plates
#' - Results aggregation and export
#' - Quality control flagging
#' - Regional format support (US/European)
#'
#' @examples
#' \dontrun{
#' run_growthcurve()
#' }
#'
#' @export
run_growthcurve <- function() {
  
  # Source backend files
  app_dir <- system.file("app", package = "growthcurve")
  
  if (!nzchar(app_dir)) {
    stop("Could not find app directory. Package may not be installed correctly.")
  }
  
  # Source required backend files
  source(file.path(app_dir, "growthcurve_system.R"), local = TRUE)
  source(file.path(app_dir, "growthcurve_functions.R"), local = TRUE)
  
  # Source and run the app
  source(file.path(app_dir, "app.R"), local = TRUE)
}
