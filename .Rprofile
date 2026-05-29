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
  
  # Only run if script exists (prevents errors in other contexts)
  if (file.exists(script_path)) {
    tryCatch(
      {
        source(script_path, local = TRUE)
        message("[GrowthCurve] USERGUIDE.md updated")
      },
      error = function(e) {
        message("[GrowthCurve] Failed to update USERGUIDE.md: ", e$message)
      }
    )
  }
}

# Run automatically when project starts
update_userguide_if_present()
