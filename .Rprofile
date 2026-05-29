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
  
  if (file.exists(script_path)) {
    tryCatch(
      {
        source(script_path, local = TRUE)
        message("[GrowthCurve] USERGUIDE.md updated")
      },
      error = function(e) {
        message("[GrowthCurve] Failed: ", e$message)
      }
    )
  }
}

update_userguide_if_present()


