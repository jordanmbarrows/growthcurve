# ============================================================
# Growthcurve environment setup
# ============================================================

dev_flag <- file.exists(".dev_mode")

options(gc.dev_mode = dev_flag)

if (dev_flag) {
  message("🔧 Growthcurve DEV mode enabled")
} else {
  message("🚀 Growthcurve PRODUCTION mode")
}

# ------------------------------------------------------------
# Auto-update USERGUIDE.md on project load
# ------------------------------------------------------------

update_userguide_if_present <- function() {
  
  script_path <- file.path("scripts", "update_userguide.R")
  source_file <- "dev/USERGUIDE_source.md"
  output_file <- "USERGUIDE.md"
  
  if (!file.exists(script_path) || !file.exists(source_file)) {
    return(invisible(NULL))
  }
  
  source_time <- file.info(source_file)$mtime
  output_time <- if (file.exists(output_file)) file.info(output_file)$mtime else as.POSIXct(0)
  
  # Only update if source is newer
  if (source_time > output_time) {
    tryCatch(
      {
        source(script_path, local = TRUE)
        message("[GrowthCurve] USERGUIDE.md refreshed (source changed)")
      },
      error = function(e) {
        message("[GrowthCurve] Failed to update USERGUIDE.md: ", e$message)
      }
    )
  }
}

header <- c(
  "<!--",
  "This file is auto-generated from dev/USERGUIDE_source.md",
  "Do not edit manually.",
  "-->",
  ""
)

writeLines(c(header, lines), output_file)
