# ============================================================
# growthcurve_system.R
# Growth Curve App – System Configuration & Behavior Layer
#
# Version: 1.0.0
# Date: 2026-05-11
#
# Purpose:
#   Centralizes all environment-dependent behavior, including:
#   - OS detection
#   - Regional settings (CSV / numeric formatting)
#   - App metadata (versioning)
#   - System-level helper functions
#
# Design principle:
#   The rest of the app should NOT know anything about:
#     - operating systems
#     - regional formatting
#
#   Instead, it should call behavior functions defined here.
# ============================================================

# ============================================================
# DEV MODE (global single source of truth)
# ============================================================

DEV_DEFAULT <- FALSE
options(gc.dev_mode = DEV_DEFAULT)

# ============================================================
# ✅ App Metadata (single source of truth)
# ============================================================

APP_VERSION <- "1.0.0"
APP_DATE    <- "2026-05-11"

# ============================================================
# ✅ Backend readiness check (replaces app.R logic)
# ============================================================

gc_backend_ready <- function() {
  tryCatch({
    
    required_objects <- c(
      "run_gc",
      "read_csv_safe",
      "gc_check_packages"
    )
    
    missing <- required_objects[!vapply(required_objects, exists, logical(1))]
    
    if (length(missing) > 0) {
      stop(
        paste0("Missing required backend components: ",
               paste(missing, collapse = ", "))
      )
    }
    
    TRUE
    
  }, error = function(e) {
    assign("gc_startup_error", conditionMessage(e), envir = .GlobalEnv)
    FALSE
  })
}

# ============================================================
# DEBUG LOGGING UTILITIES
# ============================================================
DEV_MODE <- isTRUE(getOption("gc.dev_mode", TRUE))

gc_dev_mode <- function() {
  isTRUE(getOption("gc.dev_mode", FALSE))
}

gc_log <- function(...) {
  if (!gc_dev_mode()) return(invisible(NULL))
  
  cat("[GC]", ..., "\n")
}

gc_log_block <- function(title, obj = NULL) {
  if (!gc_dev_mode()) return(invisible(NULL))
  
  cat("\n==============================\n")
  cat("[GC]", title, "\n")
  cat("==============================\n")
  
  if (!is.null(obj)) {
    try(print(obj), silent = TRUE)
  }
  
  invisble <- NULL
  invisible(invisble)
}

# ============================================================
# Cleaner version of conditionMessage() that allows for failure
# ============================================================

gc_get_message <- function(e) {
  msg <- tryCatch(conditionMessage(e), error = function(...) NULL)
  
  if (is.null(msg) || !nzchar(msg)) {
    msg <- "An unknown error occurred."
  }
  
  msg
}

# ============================================================
# Cleaner version of stop that makes error calling smoother
# ============================================================

gc_abort <- function(message) {
  
  # Ensure message is a single string
  message <- paste(message, collapse = "\n")
  
  cond <- structure(
    list(
      message = message
    ),
    class = c("gc_error", "error", "condition")
  )
  
  stop(cond)
}

# ============================================================
# ✅ OS Detection
# ============================================================

detect_os <- function() {
  sysname <- Sys.info()[["sysname"]]
  
  if (is.null(sysname)) return("unknown")
  
  if (sysname == "Windows") return("windows")
  if (sysname == "Darwin")  return("mac")
  if (sysname == "Linux")   return("linux")
  
  "unknown"
}


# ============================================================
# ✅ Regional Detection (basic heuristic)
# ============================================================

detect_region <- function() {
  dec <- Sys.localeconv()[["decimal_point"]]
  
  if (dec == ",") {
    "EU"
  } else {
    "US"
  }
}

# ============================================================
# ✅ Global Configuration Object
# ============================================================

APP_CONFIG <- list(
  region = detect_region()
)


# ============================================================
# ✅ Behavior: Open Folder
# ============================================================

open_folder <- function(path) {
  
  cat("Opening folder:", path, "\n")
  
  if (is.null(path) || !nzchar(path)) return(FALSE)
  
  tryCatch({
    
    if (.Platform$OS.type == "windows") {
      
      # shell.exec returns NULL, so we treat it as success if no error
      shell.exec(normalizePath(path, mustWork = FALSE))
      return(TRUE)
      
    } else if (Sys.info()[["sysname"]] == "Darwin") {
      
      status <- system2("open", shQuote(path))
      return(identical(status, 0L))
      
    } else {
      
      status <- system2("xdg-open", shQuote(path))
      return(identical(status, 0L))
      
    }
    
  }, error = function(e) {
    
    message("⚠ Could not open folder: ", gc_get_message(e))
    return(FALSE)
    
  })
}

# ============================================================
# ✅ Behavior: Pretty Path (for display/export)
# ============================================================

pretty_export_path <- function(path) {
  
  if (is.null(path) || length(path) != 1 || is.na(path) || !nzchar(path)) {
    return(NA_character_)
  }
  
  tryCatch({
    normalized <- normalizePath(path, winslash = "/", mustWork = FALSE)
    
    if (.Platform$OS.type == "windows") {
      gsub("/", "\\\\", normalized)
    } else {
      normalized
    }
    
  }, error = function(e) {
    path
  })
}

# ============================================================
# ✅ (FOUNDATION) CSV Behavior Abstraction
# ============================================================
# NOTE:
#   These functions are NOT fully wired yet, but they define
#   the correct abstraction layer for upcoming work (Goal 2).
# ============================================================

get_csv_delimiter <- function() {
  if (APP_CONFIG$region == "EU") ";" else ","
}

get_decimal_mark <- function() {
  if (APP_CONFIG$region == "EU") "," else "."
}

# ============================================================
# ✅ Safe CSV Reader (centralized)
# ============================================================

read_csv_safe <- function(file,
                          header = TRUE,
                          nrows = -1,
                          preview = FALSE) {
  
  if (!file.exists(file)) {
    gc_abort(paste0("File does not exist: ", file))
  }
  
  # ---- Peek first lines ----
  lines <- tryCatch(
    readLines(file, n = 5, warn = FALSE),
    error = function(e) NULL
  )
  
  if (is.null(lines)) {
    gc_abort(paste0("Unable to read file: ", file))
  }
  
  # ---- Detect delimiter ----
  comma_count     <- sum(grepl(",", lines))
  semicolon_count <- sum(grepl(";", lines))
  
  if (semicolon_count > comma_count && semicolon_count > 0) {
    sep <- ";"
    dec <- ","
  } else {
    sep <- ","
    dec <- "."
  }
  
  # ---- Read data ----
  df <- tryCatch({
    utils::read.table(
      file,
      sep = sep,
      dec = dec,
      header = header,
      nrows = nrows,
      fill = TRUE,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }, error = function(e) {
    gc_abort(paste0(
      "Failed to parse CSV: ",
      basename(file),
      "\n",
      gc_get_message(e)
    ))
  })
  
  df
}

read_csv_safe_text <- function(text,
                               header = TRUE) {
  
  # ---- Split into lines ----
  lines <- strsplit(text, "\n")[[1]]
  
  # ---- Detect delimiter ----
  comma_count     <- sum(grepl(",", lines))
  semicolon_count <- sum(grepl(";", lines))
  
  if (semicolon_count > comma_count && semicolon_count > 0) {
    sep <- ";"
    dec <- ","
  } else {
    sep <- ","
    dec <- "."
  }
  
  # ---- Read safely ----
  df <- tryCatch({
    utils::read.table(
      text = text,
      sep = sep,
      dec = dec,
      header = header,
      fill = TRUE,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }, error = function(e) {
    gc_abort(paste0(
      "Failed to parse CSV text block: ",
      gc_get_message(e)
    ))
  })
  
  df
}

# ============================================================
# ✅ Safe CSV Writer (future-proof)
# ============================================================

write_csv_safe <- function(df, file, region = NULL) {
  
  
  if (is.null(region)) {
    region <- APP_CONFIG$region
  }
  
  if (!is.data.frame(df)) {
    gc_abort("write_csv_safe expects a data.frame", call. = FALSE)
  }
  
  if (region == "EU") {
    sep <- ";"
    dec <- ","
  } else {
    sep <- ","
    dec <- "."
  }
  
  # convert numeric-like characters back to numeric
  df_fixed <- as.data.frame(lapply(df, function(col) {
    
    # try converting
    num <- suppressWarnings(as.numeric(col))
    
    # keep numeric if conversion succeeded for most values
    
    if (sum(!is.na(num)) > length(col) * 0.8) {
      return(num)
    } else {
      return(col)
    }
    
    
  }), stringsAsFactors = FALSE)

  utils::write.table(
    df_fixed,
    file,
    sep = sep,
    dec = dec,
    row.names = FALSE,
    col.names = TRUE,
    na = "",
    fileEncoding = "UTF-8"
  )
}





