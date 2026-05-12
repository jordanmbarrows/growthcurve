#' Launch the Growth Curve Analysis Shiny Application
#'
#' Opens the interactive Growth Curve Analysis application in your default web browser.
#' The app provides tools for analyzing microbial growth curves from plate reader
#' and oCelloscope instruments.
#'
#' @return
#' Launches a Shiny application. Returns NULL invisibly when the app is closed.
#'
#' @export
run_growthcurve <- function() {
  
  app_dir <- system.file("app", package = "growthcurve")
  
  if (!nzchar(app_dir)) {
    stop("Could not find app directory. Package may not be installed correctly.")
  }
  
  shiny::runApp(app_dir)
}
