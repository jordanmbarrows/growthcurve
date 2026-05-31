# ============================================================
# growthcurve_functions.R
# Growth Curve Analysis - Shiny-Safe Backend
#
# Purpose:
#   Provides deterministic, batch-capable growth curve
#   analysis functions used by the Shiny app.
#
# Notes:
#   - Currently combines computation, plotting, and file I/O.
#   - Designed for refactoring into a pure core computation
#     layer in future versions.
# ============================================================

# ============================================================
# CSV PARSING RULE
#
# All CSV reading MUST go through read_csv_safe().
# No direct read.csv(), read.table(), or delimiter detection allowed.
# 
# All CSV output MUST go through write_csv_safe().
# Do NOT use write.csv() or write.table() directly,
# or regional formatting will break.
# ============================================================

extract_well_names <- function(colnames_vec) {
  sub("^([A-H][0-9]+).*", "\\1", colnames_vec)
}

gc_is_int_label <- function(x) {
  x <- trimws(as.character(x))
  grepl("^\\d+$", x)
}

gc_is_row_label <- function(x) {
  x <- trimws(as.character(x))
  grepl("^[A-Z]$", x)
}

gc_is_numericish <- function(x) {
  x <- trimws(as.character(x))
  out <- logical(length(x))
  
  empty <- is.na(x) | !nzchar(x)
  out[empty] <- FALSE
  
  non_empty <- !empty
  y <- gsub(",", ".", x[non_empty], fixed = TRUE)
  out[non_empty] <- !is.na(suppressWarnings(as.numeric(y)))
  
  out
}

gc_contiguous_runs <- function(idx) {
  if (length(idx) == 0) return(list())
  split(idx, cumsum(c(1, diff(idx) != 1)))
}

gc_is_contiguous_letters <- function(x) {
  x <- trimws(as.character(x))
  pos <- match(x, LETTERS)
  if (any(is.na(pos))) return(FALSE)
  all(diff(pos) == 1)
}

find_plate_blocks_flexible <- function(file,
                                       min_rows = 2L,
                                       min_cols = 2L,
                                       numeric_threshold = 0.8) {
  df <- read_csv_safe(file, header = FALSE)
  df[] <- lapply(df, function(x) trimws(as.character(x)))
  
  nr <- nrow(df)
  nc <- ncol(df)
  
  candidates <- list()
  cand_id <- 0L
  
  for (r in seq_len(nr - 1L)) {
    row_vals <- as.character(unlist(df[r, , drop = FALSE]))
    num_cols <- which(vapply(row_vals, gc_is_int_label, logical(1)))
    
    if (length(num_cols) == 0) next
    
    runs <- gc_contiguous_runs(num_cols)
    
    for (run in runs) {
      run <- as.integer(run)
      if (length(run) < min_cols) next
      if (min(run) <= 1L) next  # need a row-label column immediately to the left
      
      row_label_col <- min(run) - 1L
      startcol <- min(run)
      endcol <- max(run)
      
      col_labels <- trimws(as.character(unlist(df[r, startcol:endcol, drop = FALSE])))
      
      # Walk downward from the header row
      rr <- r + 1L
      row_labels <- character(0)
      data_rows <- integer(0)
      
      while (rr <= nr) {
        lbl <- trimws(as.character(df[rr, row_label_col]))
        if (!gc_is_row_label(lbl)) break
        
        body <- as.character(unlist(df[rr, startcol:endcol, drop = FALSE]))
        frac_numeric <- mean(gc_is_numericish(body))
        
        if (frac_numeric < numeric_threshold) break
        
        row_labels <- c(row_labels, lbl)
        data_rows <- c(data_rows, rr)
        rr <- rr + 1L
      }
      
      if (length(row_labels) < min_rows) next
      if (!gc_is_contiguous_letters(row_labels)) next
      
      cand_id <- cand_id + 1L
      candidates[[cand_id]] <- list(
        header_row = r,
        row_label_col = row_label_col,
        startcol = startcol,
        endcol = endcol,
        data_start = min(data_rows),
        data_end = max(data_rows),
        row_labels = row_labels,
        col_labels = col_labels
      )
    }
  }
  
  if (length(candidates) == 0) {
    gc_abort("No plate-like data blocks could be detected in the file.")
  }
  
  # Group candidates by geometry so we can find the repeated block type
  keys <- vapply(candidates, function(x) {
    paste(
      x$row_label_col,
      x$startcol,
      x$endcol,
      paste(x$row_labels, collapse = ""),
      paste(x$col_labels, collapse = ","),
      sep = "|"
    )
  }, character(1))
  
  key_tab <- table(keys)
  best_key <- names(key_tab)[which.max(key_tab)]
  
  blocks <- candidates[keys == best_key]
  
  # Sort by position in the file
  ord <- order(vapply(blocks, `[[`, integer(1), "data_start"))
  blocks <- blocks[ord]
  
  startrow_vec <- vapply(blocks, `[[`, integer(1), "data_start")
  endrow_vec   <- vapply(blocks, `[[`, integer(1), "data_end")
  stride <- if (length(startrow_vec) >= 2L) {
    diff(startrow_vec)[1]
  } else {
    NA_integer_
  }
  
  list(
    blocks = blocks,
    startrow_vec = startrow_vec,
    endrow_vec = endrow_vec,
    stride = stride,
    startcol = blocks[[1]]$startcol,
    endcol = blocks[[1]]$endcol,
    row_label_col = blocks[[1]]$row_label_col
  )
}

read_plate_block_flexible <- function(file, interval = NULL) {
  df_raw <- read_csv_safe(file, header = FALSE)
  df_chr <- df_raw
  df_chr[] <- lapply(df_chr, function(x) trimws(as.character(x)))
  
  det <- find_plate_blocks_flexible(file)
  
  all_rows <- list()
  
  for (b in det$blocks) {
    vals_chr <- df_chr[b$data_start:b$data_end, b$startcol:b$endcol, drop = FALSE]
    vals_chr <- as.matrix(vals_chr)
    
    vals_num <- suppressWarnings(
      matrix(
        as.numeric(gsub(",", ".", vals_chr, fixed = TRUE)),
        nrow = nrow(vals_chr),
        ncol = ncol(vals_chr),
        byrow = FALSE
      )
    )
    
    rownames(vals_num) <- b$row_labels
    colnames(vals_num) <- b$col_labels
    
    well_names <- as.vector(t(outer(b$row_labels, b$col_labels, paste0)))
    row_vec <- as.list(as.vector(t(vals_num)))
    names(row_vec) <- well_names
    
    all_rows[[length(all_rows) + 1L]] <- row_vec
  }
  
  all_wells <- unique(unlist(lapply(all_rows, names)))
  
  out <- data.frame(
    matrix(NA_real_, nrow = length(all_rows), ncol = length(all_wells)),
    check.names = FALSE
  )
  colnames(out) <- all_wells
  
  for (i in seq_along(all_rows)) {
    out[i, names(all_rows[[i]])] <- unlist(all_rows[[i]])
  }
  
  n <- nrow(out)
  if (!is.null(interval)) {
    time_min <- seq(0, by = interval * 60, length.out = n)
  } else {
    time_min <- seq_len(n) - 1L
  }
  
  out <- data.frame(Time_min = time_min, out, check.names = FALSE)
  out
}

read_design_block_strict <- function(designfile, blocklist) {
  df <- read_csv_safe(designfile, header = FALSE)
  df[] <- lapply(df, function(x) trimws(as.character(x)))
  
  expected_rows <- LETTERS[1:8]
  well_names <- as.vector(t(outer(expected_rows, 1:12, paste0)))
  
  out <- data.frame(Well = well_names, stringsAsFactors = FALSE)
  
  for (k in seq_along(blocklist)) {
    block_name <- blocklist[[k]]
    
    # Strict template: block headers in col 1, spaced every 10 rows
    header_row <- 1 + (k - 1) * 10
    data_rows  <- (header_row + 1):(header_row + 8)
    
    if (max(data_rows) > nrow(df)) {
      gc_abort(
        paste0(
          "Design parsing error: block '", block_name,
          "' does not have 8 data rows."
        )
      )
    }
    
    header_val <- trimws(as.character(df[header_row, 1]))
    if (!identical(header_val, block_name)) {
      gc_abort(
        paste0(
          "Design parsing error: expected block header '", block_name,
          "' at row ", header_row, " but found '", header_val, "'."
        )
      )
    }
    
    row_labels <- trimws(as.character(df[data_rows, 1]))
    if (!identical(row_labels, expected_rows)) {
      gc_abort(
        paste0(
          "Design parsing error in block '", block_name,
          "': expected row labels A-H."
        )
      )
    }
    
    vals <- df[data_rows, 2:13, drop = FALSE]
    vals <- as.matrix(vals)
    vals[!nzchar(vals)] <- NA_character_
    
    out[[block_name]] <- as.vector(t(vals))
  }
  
  # Optional cleanup for non-Well_type blocks:
  for (v in setdiff(names(out), c("Well", "Well_type"))) {
    out[[v]][out[[v]] %in% LETTERS[1:8]] <- NA_character_
  }
  
  # Guardrails
  if (any(out$Well_type %in% LETTERS[1:8], na.rm = TRUE)) {
    gc_abort("Design parsing error: row labels A-H were imported as Well_type values.")
  }
  
  if (any(grepl("^[A-H]13$", out$Well))) {
    gc_abort("Design parsing error: phantom 13th design column detected.")
  }
  
  out
}

get_design_wells <- function(design_file) {
  
  #  Read via safe parser ONLY (single source of truth)
  df <- read_csv_safe(design_file, header = FALSE)
  
  #  Extract first column as text for detection
  col1 <- trimws(as.character(df[[1]]))
  
  #  Find Well_type row INSIDE parsed data
  start_idx <- base::grep("^\\s*Well_type\\b", col1, ignore.case = TRUE)[1]
  
  if (is.na(start_idx)) {
    gc_abort("Well_type block not found in design file.")
  }
  
  #  Extract rows A-H relative to parsed table
  mat <- df[(start_idx + 1):(start_idx + 8), , drop = FALSE]
  
  #  Clean whitespace
  mat[] <- lapply(mat, function(x) trimws(as.character(x)))
  
  rows <- mat[[1]]
  
  design_wells <- character(0)
  
  for (r in seq_len(nrow(mat))) {
    for (c in seq(2, ncol(mat))) {
      
      val <- mat[r, c]
      
      if (!is.na(val) && nzchar(val)) {
        plate_col <- c - 1
        design_wells <- c(design_wells, paste0(rows[r], plate_col))
      }
    }
  }
  
  design_wells
}


validate_design_table <- function(my_design, strict_96 = TRUE) {
  
  if (!"Well" %in% names(my_design)) {
    gc_abort("Design parsing error: design table lacks a Well column.")
  }
  
  if (!"Well_type" %in% names(my_design)) {
    gc_abort("Design parsing error: design table lacks a Well_type column.")
  }
  
  # Duplicate wells
  dup_design <- my_design |>
    dplyr::count(Well, name = "n") |>
    dplyr::filter(n > 1)
  
  if (nrow(dup_design) > 0) {
    gc_abort("Design parsing error: duplicate wells found in design file.")
  }
  
  # Row letters should never appear as Well_type
  if (any(my_design$Well_type %in% LETTERS[1:8], na.rm = TRUE)) {
    gc_abort("Design parsing error: row labels A-H were imported as Well_type values.")
  }
  
  # Optional strict 96-well check
  if (strict_96 && any(grepl("^[A-H]13$", my_design$Well))) {
    gc_abort("Design parsing error: phantom 13th design column detected.")
  }
  
  my_design
}

format_plate_reader_data <- function(df, design_file, interval = NULL) {
  
  n <- nrow(df)
  
  # ---- TIME (identical logic) ----
  if (!is.null(interval)) {
    time_min <- seq(0, by = interval * 60, length.out = n)
  } else {
    time_min <- seq_len(n) - 1L
  }
  
  # ---- RAW MATRIX ----
  mat <- df
  
  mat[] <- lapply(mat, function(x) as.numeric(as.character(x)))
  
  max_val <- suppressWarnings(max(mat, na.rm = TRUE))
  
  if (!is.finite(max_val)) {
    gc_abort("Plate reader parsing failed: non-numeric data.")
  }
  
  raw_cols <- colnames(mat)
  
  wells <- extract_well_names(raw_cols)
  
  design_wells <- get_design_wells(design_file)
  
  # ---- TEMP UNIQUE ----
  tmp_names <- make.unique(wells)
  colnames(mat) <- tmp_names
  
  # ---- FILTER using ORIGINAL wells (critical!) ----
  keep <- wells %in% design_wells
  
  if (!any(keep)) {
    gc_abort("No matching wells between plate reader data and design file.")
  }
  
  mat <- mat[, keep, drop = FALSE]
  wells <- wells[keep]
  
  # ---- RESTORE TRUE WELL NAMES ----
  colnames(mat) <- wells
  
  # ---- BUILD OUTPUT ----
  clean_df <- data.frame(
    Time = time_min,
    mat,
    check.names = FALSE
  )
  
  colnames(clean_df)[1] <- "Time_min"
  
  clean_df
}

# ---------------------------
# Plot titles
# ---------------------------
gc_plot_titles <- list(
  blank_linear    = "Blank-corrected OD (linear scale)",
  blank_log       = "Blank-corrected OD (log scale)",
  mean_curves     = "Mean growth curves with 95% confidence interval",
  perwell_linear  = "Per-well OD curves (linear scale)",
  perwell_log     = "Per-well OD curves (log scale)",
  deriv_raw       = "Raw growth-rate derivatives",
  deriv_percap    = "Per-capita growth-rate derivatives",
  fitted_percap   = "Fitted per-capita growth rate with maximum",
  od_with_maxgc   = "OD curves with maximum growth-rate marked",
  doubling_time   = "Doubling time with mean and 95% confidence interval",
  max_growth_rate = "Maximum growth rate with mean and 95% confidence interval"
)


# ---------------------------
# Unified plot title theme
# ---------------------------
gc_theme_title <- function() {
  ggplot2::theme(
    plot.title = ggplot2::element_text(size = 16)
  )
}

read_ocello_tanormalized <- function(file) {
  
  lines <- base::readLines(file)
  
  # ----------------------------------------------------------
  # 1. Find TANormalized line (prefix only matters)
  # ----------------------------------------------------------
  tn_idx <- base::grep("^\\s*TANormalized", lines, ignore.case = TRUE)[1]
  
  if (is.na(tn_idx)) {
    gc_abort("TANormalized block not found.")
  }
  
  # ----------------------------------------------------------
  # 2. Header is FIRST non-empty line after
  # ----------------------------------------------------------
  idx <- tn_idx + 1
  
  while (idx <= length(lines) && !nzchar(trimws(lines[idx]))) {
    idx <- idx + 1
  }
  
  if (idx > length(lines)) {
    gc_abort("Header not found after TANormalized")
  }
  
  header_line <- lines[idx]
  
  if (!base::grepl("^\\s*Time", header_line, ignore.case = TRUE)) {
    gc_abort("Expected Time header after TANormalized")
  }
  
  # ----------------------------------------------------------
  # 3. Collect data lines
  # ----------------------------------------------------------
  data_lines <- character()
  
  i <- idx + 1
  
  while (i <= length(lines)) {
    
    line <- gsub("\r", "", lines[i])
    
    # Remove ALL separators to check if anything real remains
    stripped <- trimws(gsub("[,;]", "", line))
    
    # Stop at empty / delimiter-only row
    if (!nzchar(stripped)) break
    
    data_lines <- c(data_lines, line)
    
    i <- i + 1
  }
  
  if (length(data_lines) == 0) {
    gc_abort("No data rows found in TANormalized block.")
  }
  
  # ----------------------------------------------------------
  # 4. Build block text
  # ----------------------------------------------------------
  csv_text <- paste(
    c(header_line, data_lines),
    collapse = "\n"
  )
  
  # ----------------------------------------------------------
  # 5. Parse using safe reader ONLY
  # ----------------------------------------------------------
  df <- read_csv_safe_text(
    text = csv_text,
    header = TRUE
  )
  
  drop_cols <- base::grepl("^Time", names(df), ignore.case = TRUE) |
    base::grepl("^Repetition", names(df), ignore.case = TRUE)
  
  df_data <- df[, !drop_cols, drop = FALSE]
  
  max_val <- suppressWarnings(max(as.matrix(df_data), na.rm = TRUE))
  
  if (is.na(max_val) || max_val > 10) {
    gc_abort(paste0(
      "TANormalized sanity check failed: max value is ", max_val,
      " (expected < 10 for normalized data)"
    ))
  }
  
  return(df_data)
}

format_ocelloscope_data <- function(df, design_file, interval = NULL) {
  
  n <- nrow(df)
  
  # ----------------------------------------------------------
  # 1. TIME - ALWAYS MINUTES HERE (single source)
  # ----------------------------------------------------------
  if (!is.null(interval)) {
    time_min <- seq(0, by = interval * 60, length.out = n)
  } else {
    time_min <- as.numeric(df[[1]]) / 60
  }
  
  
  # ----------------------------------------------------------
  # 2. EXTRACT RAW MATRIX
  # ----------------------------------------------------------
  mat <- df  
  
  mat[] <- lapply(mat, function(x) as.numeric(as.character(x)))
  
  max_val <- suppressWarnings(max(mat, na.rm = TRUE))
  
  if (!is.finite(max_val) || max_val > 10) {
    gc_abort(paste0(
      "Data parsing failed: max value = ", max_val,
      ". Possible numeric conversion issue."
    ))
  }
  
  raw_cols <- colnames(mat)
  
  # ----------------------------------------------------------
  # 3. EXTRACT TRUE WELL NAMES
  # ----------------------------------------------------------
  wells <- extract_well_names(raw_cols)
  
  # ----------------------------------------------------------
  # 4. GET DESIGN WELLS (DO THIS EARLY)
  # ----------------------------------------------------------
  design_wells <- get_design_wells(design_file)

  # ----------------------------------------------------------
  # 5. TEMPORARY UNIQUE NAMES (SAFETY ONLY)
  # ----------------------------------------------------------
  tmp_names <- make.unique(wells)
  colnames(mat) <- tmp_names

  # ----------------------------------------------------------
  # 6. FILTER USING ORIGINAL WELLS
  # ----------------------------------------------------------
  keep <- wells %in% design_wells
  
  if (!any(keep)) {
    gc_abort("No matching wells between oCelloscope data and design file.")
  }
  
  mat <- mat[, keep, drop = FALSE]

  wells <- wells[keep]
  
  # ----------------------------------------------------------
  # 7. RESTORE TRUE WELL IDENTITIES (CRITICAL)
  # ----------------------------------------------------------
  colnames(mat) <- wells
  
  # ----------------------------------------------------------
  # 8. BUILD FINAL DATAFRAME
  # ----------------------------------------------------------
  clean_df <- data.frame(
    Time = time_min,
    mat,
    check.names = FALSE
  )
  
  colnames(clean_df)[1] <- "Time_min"
  
  clean_df
}

is_ocelloscope <- function(file) {
  lines <- base::readLines(file, warn = FALSE)
  any(base::grepl("^\\s*TANormalized", lines, ignore.case = TRUE))
}

# ------------------------------------------------------------
# detect_plate_format()
#
# Purpose:
#   Determine whether a plate reader file is in wide format
#   (single header row of well names) or block format
#   (repeated 8-row blocks with row labels A-H).
#
# Strategy:
#   - Wide: first data row contains well-name-like patterns (A1..H12)
#           covering most columns, and there is only ONE such header row.
#   - Block: file contains multiple rows that start with a row letter
#            (A-H) followed by 12 numeric-looking cells.
#
# Returns: "wide" or "block"
# ------------------------------------------------------------

detect_plate_format <- function(file) {

  lines <- base::readLines(file, warn = FALSE)

  # Strip CR
  lines <- gsub("\r", "", lines)

  # ---- Test for TANormalized (oCelloscope) - caller should check first ----
  if (any(base::grepl("^\\s*TANormalized", lines, ignore.case = TRUE))) {
    return("wide")  # handled by read_ocello path; this is a fallback
  }

  # ---- Search for wide well-name header ----
  # A wide header has >= 2 cells matching [A-H][0-9]{1,2}
  # and appears only once (not repeated like block format).
  well_pattern <- "[A-H][0-9]{1,2}"

  n_wide_rows <- sum(vapply(lines, function(l) {
    fields <- strsplit(l, "[,;]")[[1]]
    fields <- trimws(fields)
    n_wells <- sum(grepl(paste0("^", well_pattern, "$"), fields))
    n_wells >= 2
  }, logical(1)))

  for (l in lines) {
    fields <- trimws(strsplit(l, "[,;]")[[1]])
    n_wells <- sum(grepl("^[A-H][0-9]{1,2}$", fields))
    
    if (n_wells >= 6) {  # require stronger signal
      return("wide")
    }
  }

  # ---- Test for block format ----
  # Block rows start with A-H in column 1
  row_label_count <- sum(vapply(lines, function(l) {
    fields <- strsplit(l, "[,;]")[[1]]
    if (length(fields) < 2) return(FALSE)
    grepl("^\\s*[A-H]\\s*$", trimws(fields[1]))
  }, logical(1)))

  if (row_label_count >= 8) {
    return("block")
  }

  # Default: assume block
  "block"
}

# ------------------------------------------------------------
# read_plate_wide()
#
# Purpose:
#   Read a plate reader file in wide format (single measurement
#   row with column headers that are well names A1-H12).
#
# The file must have:
#   - One row whose cells are well names (e.g. A1, A2 ... H12)
#   - Time values in a preceding column (optional; can be absent)
#   - Data rows immediately following
#
# Returns:
#   data.frame with Time_min column + one column per well,
#   matching the format of format_ocelloscope_data() output
#   so it can feed directly into the same tidy pipeline.
# ------------------------------------------------------------

read_plate_wide <- function(file, interval = NULL, designfile = NULL) {

  lines <- base::readLines(file, warn = FALSE)
  lines <- gsub("\r", "", lines)

  well_pattern <- "^[A-H][0-9]{1,2}$"

  # ---- Find header row ----
  header_idx <- NA_integer_

  for (i in seq_along(lines)) {
    fields <- trimws(strsplit(lines[i], "[,;]")[[1]])
    n_wells <- sum(grepl(well_pattern, fields))
    if (n_wells >= 2) {
      header_idx <- i
      break
    }
  }

  if (is.na(header_idx)) {
    gc_abort("Wide format plate reader: could not find well-name header row.")
  }

  # ---- Collect data rows ----
  data_lines <- character()
  i <- header_idx + 1

  while (i <= length(lines)) {
    line <- lines[i]
    stripped <- trimws(gsub("[,;]", "", line))
    if (!nzchar(stripped)) break
    data_lines <- c(data_lines, line)
    i <- i + 1
  }

  if (length(data_lines) == 0) {
    gc_abort("Wide format plate reader: no data rows found after header.")
  }

  # ---- Parse ----
  csv_text <- paste(c(lines[header_idx], data_lines), collapse = "\n")

  df <- read_csv_safe_text(text = csv_text, header = TRUE)

  # ---- Identify well columns vs time/metadata columns ----
  is_well_col <- grepl(well_pattern, names(df))

  time_col_idx <- which(grepl("^Time", names(df), ignore.case = TRUE))[1]

  # ---- Build time vector ----
  n <- nrow(df)

  if (!is.na(time_col_idx)) {
    time_raw <- suppressWarnings(as.numeric(as.character(df[[time_col_idx]])))

    if (!all(is.na(time_raw))) {
      # Successfully parsed: values > 1000 are assumed to be seconds
      if (max(time_raw, na.rm = TRUE) > 1000) {
        time_min <- time_raw / 60
      } else {
        time_min <- time_raw
      }
    } else if (!is.null(interval)) {
      # Time column present but not parseable — fall back to interval
      time_min <- seq(0, by = interval * 60, length.out = n)
    } else {
      time_min <- seq_len(n) - 1L
    }
  } else if (!is.null(interval)) {
    time_min <- seq(0, by = interval * 60, length.out = n)
  } else {
    time_min <- seq_len(n) - 1L
  }

  # ---- Extract well data ----
  df_wells <- df[, is_well_col, drop = FALSE]
  df_wells[] <- lapply(df_wells, function(x) as.numeric(as.character(x)))
  colnames(df_wells) <- extract_well_names(names(df_wells))
  
  dup_cols <- unique(colnames(df_wells)[duplicated(colnames(df_wells))])
  
  if (length(dup_cols) > 0) {
    gc_abort(
      paste0(
        "Wide plate reader file contains duplicated well columns after normalization: ",
        paste(dup_cols, collapse = ", "),
        ". Please remove duplicate/derived columns from the input file."
      )
    )
  }

  # ---- Filter to design wells if provided ----
  if (!is.null(designfile) && file.exists(designfile)) {
  }

  out <- data.frame(Time_min = time_min, df_wells, check.names = FALSE)
  out
}

# ------------------------------------------------------------
# find_block_params()
#
# Purpose:
#   Auto-detect startrow and stride for a block-format plate
#   reader file by scanning for rows whose first column is A-H
#   and subsequent 12 cells look numeric.
#
# Returns: list(startrow, endrow, stride, n_blocks)
# ------------------------------------------------------------

find_block_params <- function(file) {

  df <- read_csv_safe(file, header = FALSE)

  col1 <- trimws(as.character(df[[1]]))

  # Find all rows where col1 is exactly A
  a_rows <- which(col1 == "A")

  if (length(a_rows) == 0) {
    gc_abort("Block format: could not find any row starting with 'A'. Check plate reader file format.")
  }

  # stride = gap between first A rows (if multiple timepoints)
  if (length(a_rows) >= 2) {
    stride <- a_rows[2] - a_rows[1]
  } else {
    # Single timepoint: stride doesn't matter but endrow = startrow + 7
    stride <- nrow(df) + 10
  }

  # First block: A row starts 2 rows after block header (row 1 = header, row 2 = col numbers, row 3 = A)
  # More robustly: startrow is the A row, endrow is startrow + 7 (A-H)
  first_a <- a_rows[1]
  n_blocks <- length(a_rows)

  list(
    startrow = first_a,
    endrow   = first_a + 7,
    stride   = stride,
    n_blocks = n_blocks
  )
}

read_preview_file <- function(file, nrows = 20) {
  
  if (!file.exists(file) || dir.exists(file)) {
    return(NULL)
  }
  
  tryCatch({
    df <- read_csv_safe(file, header = FALSE, nrows = nrows)
    df[] <- lapply(df, as.character)
    df
  }, error = function(e) {
    NULL
  })
}

build_preview <- function(file, design_file = NULL, interval = NULL, instrument,
                          raw_data_format = NULL, nrows = 20) {

  if (!file.exists(file) || dir.exists(file)) return(NULL)

  if (is_ocelloscope(file)) {

    if (is.null(design_file) || !file.exists(design_file)) {
      return(structure(
        list(message = "Please select a valid oCelloscope design file to enable preview."),
        class = "preview_message"
      ))
    }

    result <- tryCatch({

      df  <- read_ocello_tanormalized(file)
      fmt <- format_ocelloscope_data(df, design_file, interval)

      # Return first nrows, drop Time_min for display, round values
      out <- head(fmt, nrows)
      out

    }, error = function(e) {
      structure(
        list(message = paste("Preview error:", gc_get_message(e))),
        class = "preview_message"
      )
    })

    return(result)

  } else if (instrument == "plate_reader") {

    # Detect format for plate reader
    plate_fmt <- if (!is.null(raw_data_format)) {
      raw_data_format
    } else {
      tryCatch(detect_plate_format(file), error = function(e) "block")
    }

    if (plate_fmt == "wide") {
      result <- tryCatch({
        df_raw <- read_plate_wide(file, interval = interval, designfile = NULL)
        
        df_wide <- format_plate_reader_data(
          df_raw[, -1, drop = FALSE],
          design_file,
          interval
        )
        head(df_wide, nrows)
      }, error = function(e) {
        structure(
          list(message = paste("Preview error:", gc_get_message(e))),
          class = "preview_message"
        )
      })
      return(result)
    }

    # Block: fall through to raw preview
    df <- read_preview_file(file, nrows = nrows)
    if (is.null(df)) return(NULL)
    colnames(df) <- NULL
    return(df)

  } else {

    df <- read_preview_file(file, nrows = nrows)
    if (is.null(df)) return(NULL)
    colnames(df) <- NULL
    return(df)
  }
}

build_preview_label <- function(file, preview_result, instrument = NULL,
                                raw_data_format = NULL) {

  #  Do NOT show label if preview is message
  if (inherits(preview_result, "preview_message")) {
    return(NULL)
  }

  if (is_ocelloscope(file)) {
    return(paste(
      "Preview: extracted growth data (oCelloscope)",
      "- time values use selected interval"
    ))
  }

  if (identical(instrument, "plate_reader")) {
    plate_fmt <- if (!is.null(raw_data_format)) raw_data_format else
      tryCatch(detect_plate_format(file), error = function(e) "block")

    if (plate_fmt == "wide") {
      return("Preview: extracted growth data (plate reader, wide format) - time values use selected interval")
    }
    return("Preview: raw file (plate reader, block format)")
  }

  return("Preview: raw file")
}

# ------------------------------------------------------------
# Package bootstrap helper
# Runs once when functions.R is sourced (i.e. at Shiny startup,
# not inside run_gc). Safe to call repeatedly - install only
# happens when a package is genuinely absent.
# ------------------------------------------------------------

# ------------------------------------------------------------
# Dependency check (fail-fast)
# ------------------------------------------------------------

gc_check_packages <- function() {
  required_packages <- c(
    "ggplot2", "dplyr", "tidyr", "gcplyr",
    "lubridate", "multcomp", "shinyjs", "DT",
    "future", "promises", "later", "htmlwidgets", "shinyBS"
  )
  
  status <- vapply(required_packages, function(pkg) {
    if (!requireNamespace(pkg, quietly = TRUE)) "missing" else "ok"
  }, character(1))
  
  list(
    missing = names(status[status == "missing"])
  )
}

run_growthcurve <- function() {
  
  pkgs <- gc_check_packages()
  
  if (length(pkgs$missing) > 0) {
    stop(
      paste0(
        "Missing required packages:\n",
        paste(pkgs$missing, collapse = ", "),
        "\n\nPlease run install.packages()"
      ),
      call. = FALSE
    )
  }
  
  app_dir <- system.file("app", package = "growthcurve")
  shiny::runApp(app_dir)
}

gc_instrument_defaults <- list(
  plate_reader = list(
    interval = 15,
    minod    = 0.05,
    maxod    = 0.7,
    smoothing = FALSE,
    smoothing_window = NULL
  ),
  ocelloscope = list(
    interval = 10,
    minod    = 0.01,
    maxod    = 0.7,
    smoothing = TRUE, 
    smoothing_window = 3
  )
)

# ------------------------------------------------------------
# Helper: gc_prepare_run()
#
# Purpose:
#   Stage A of run_gc(): input validation and setup.
#
# Responsibilities:
#   - Validate arguments
#   - Normalize CSV inputs
#   - Create output directories
#   - Define shared ggplot theme
#   - Snapshot parameters and resolved paths
#
# Returns:
#   list(
#     params,
#     inputs,
#     analysis_dir,
#     ggplot_theme
#   )
# ------------------------------------------------------------

gc_prepare_run <- function(rawdatafile,
                           designfile,
                           design_vars,
                           hrs,
                           interval,
                           minod,
                           maxod,
                           prefix = "",
                           batch  = TRUE) {
  
  # ---------------------------
  # Argument validation
  # ---------------------------
  stopifnot(
    is.character(design_vars),
    length(design_vars) > 0,
    is.numeric(hrs), hrs > 0,
    is.numeric(interval), interval > 0,
    is.numeric(minod), is.numeric(maxod),
    minod < maxod
  )
  
  if (!is.character(rawdatafile) || !file.exists(rawdatafile)) {
    gc_abort("Invalid rawdatafile path.")
  }
  
  if (!is.character(designfile) || !file.exists(designfile)) {
    gc_abort("Invalid designfile path.")
  }
  
  # ---------------------------
  # Output directory naming (NO creation)
  # ---------------------------
  
  prefix_final <- if (is.character(prefix) && nzchar(prefix)) {
    prefix
  } else {
    ""
  }
  
  analysis_dir <- "Analysis"
  
  # ---------------------------
  # Shared ggplot theme
  # ---------------------------
  ggplot_theme <- ggplot2::theme_bw() +
    ggplot2::theme(
      panel.border      = ggplot2::element_blank(),
      panel.grid.major  = ggplot2::element_blank(),
      panel.grid.minor  = ggplot2::element_blank(),
      axis.line         = ggplot2::element_line(colour = "black"),
      axis.text         = ggplot2::element_text(size = 14),
      axis.title        = ggplot2::element_text(size = 16),
      strip.text        = ggplot2::element_text(size = 14),
      legend.title      = ggplot2::element_text(size = 14),
      legend.text       = ggplot2::element_text(size = 12)
    )
  
  # ---------------------------
  # Return structured setup
  # ---------------------------
  list(
    params = list(
      rawdatafile = rawdatafile,
      designfile  = designfile,
      design_vars = design_vars,
      hrs          = hrs,
      interval     = interval,
      minod        = minod,
      maxod        = maxod,
      prefix       = prefix_final,
      batch        = batch
    ),
    inputs = list(
      rawdatafile = rawdatafile,
      designfile  = designfile
    ),
    analysis_dir = analysis_dir,
    ggplot_theme = ggplot_theme
  )
}

# ------------------------------------------------------------
# Helper: gc_read_raw_data()
#
# Purpose:
#   Read and transform raw growth data into tidy format.
#
# Responsibilities:
#   - Handle instrument-specific input formats
#   - Convert wide plate layouts to tidy structure
#   - Attach time column
#
# Inputs:
#   rawdatafile : path to raw CSV file
#   hrs         : experiment duration (hours)
#   interval    : measurement interval (hours)
#   format      : instrument type ("plate_reader" or "ocelloscope")
#
# Returns:
#   Tidy data.frame with columns:
#     block_name, Time, Well, Measurements
# ------------------------------------------------------------

gc_read_raw_data <- function(rawdatafile, designfile, hrs, interval, format,
                             raw_data_format = NULL) {

  format <- match.arg(format, c("plate_reader", "ocelloscope"))

  # ----------------------------------------------------------
  #  SAFETY: detect file/instrument mismatch
  # ----------------------------------------------------------

  is_occo <- is_ocelloscope(rawdatafile)

  format_mismatch <- (
    (format == "plate_reader" && is_occo) ||
      (format == "ocelloscope" && !is_occo)
  )

  if (format_mismatch) {
    message(
      sprintf(
        "[DEBUG] Format mismatch: selected = %s, detected_ocelloscope = %s",
        format,
        is_occo
        )
      )
    }

  if (format == "plate_reader") {

    # ---- Detect sub-format (wide or block) ----
    plate_fmt <- if (!is.null(raw_data_format)) {
      raw_data_format
    } else {
      detect_plate_format(rawdatafile)
    }
    
    message("Detected format: ", plate_fmt)

    if (plate_fmt == "wide") {

      # ---- Wide: single header row of well names ----
      df_raw <- read_plate_wide(rawdatafile, interval = interval, designfile = NULL)
      
      df_wide <- format_plate_reader_data(
        df_raw[, -1, drop = FALSE],
        designfile,
        interval
      )

      # Attach block_name and pivot to tidy
      df_wide$Time    <- df_wide$Time_min / 60
      df_wide$Time_min <- NULL
      df_wide$block_name <- "plate_reader"

      df_wide <- df_wide[, c("block_name", "Time",
                              setdiff(names(df_wide), c("block_name", "Time")))]

      imported_tidy <- gcplyr::trans_wide_to_tidy(
        df_wide,
        id_cols = c("block_name", "Time")
      )

      imported_tidy$Time <- as.numeric(imported_tidy$Time)

    } else {

      # Try auto-detection; fall back to legacy fixed offsets
      df_block <- read_plate_block_flexible(
        rawdatafile,
        interval = interval
      )
      
      df_block$Time <- df_block$Time_min / 60
      df_block$Time_min <- NULL
      df_block$block_name <- "plate_reader"
      
      df_block <- df_block[, c(
        "block_name", "Time",
        setdiff(names(df_block), c("block_name", "Time"))
      )]
      
      imported_tidy <- gcplyr::trans_wide_to_tidy(
        df_block,
        id_cols = c("block_name", "Time")
      )
      
      imported_tidy$Time <- as.numeric(imported_tidy$Time)
    }

  } else {

    # ---- Read raw block ----
    df <- NULL

    df <- read_ocello_tanormalized(rawdatafile)

    if (is.null(df)) {
      gc_abort("Failed to read TANormalized block from oCelloscope file.")
    }

    df <- format_ocelloscope_data(df, designfile, interval)

    #  canonical conversion point
    df$Time <- df$Time_min / 60

    #  drop raw minutes column
    df$Time_min <- NULL

    # ---- Add block_name ----
    df$block_name <- "ocelloscope"

    df <- df[, c("block_name", "Time", setdiff(names(df), c("block_name", "Time")))]

    # ---- Convert to tidy ----
    imported_tidy <- gcplyr::trans_wide_to_tidy(
      df,
      id_cols = c("block_name", "Time")
    )
  }

  imported_tidy
}

# ------------------------------------------------------------
# Helper: gc_read_design()
#
# Purpose:
#   Import plate design metadata and clean invalid entries.
#
# Responsibilities:
#   - Read design blocks using gcplyr
#   - Ensure correct block structure
#   - Remove accidental row/column labels
#
# Inputs:
#   designfile : path to design CSV
#   blocklist  : list of block names (including Well_type)
#
# Returns:
#   Cleaned design data.frame ready for merging
# ------------------------------------------------------------

# ------------------------------------------------------------
# detect_design_format()
#
# Purpose:
#   Detect whether a design file is in block or wide format.
#
# Block: first column contains variable names (Well_type, etc.)
#        followed by row letters A-H.
# Wide:  first row contains well names (A1..H12) and subsequent
#        rows are labelled design variables.
# ------------------------------------------------------------

detect_design_format <- function(file) {

  df <- read_csv_safe(file, header = FALSE, nrows = 5)

  if (nrow(df) == 0 || ncol(df) < 2) return("block")

  # Check if the FIRST row (row 1) has well-name-like column headers
  # (skipping col 1 which would be a row-name label)
  first_row_vals <- trimws(as.character(unlist(df[1, -1])))
  n_wells <- sum(grepl("^[A-H][0-9]{1,2}$", first_row_vals))

  if (n_wells >= 2) return("wide")

  "block"
}

# ------------------------------------------------------------
# read_design_wide()
#
# Purpose:
#   Read a wide-format design file.
#
# Expected layout:
#   Row 1: blank/label | A1 | A2 | ... | H12  (well names)
#   Row 2: Well_type   | Sample | Blank | ...
#   Row 3: Strain      | WT | WT | ...
#   ...
#
# Returns:
#   data.frame in the same format as gcplyr::import_blockdesigns():
#     Well | Well_type | Var1 | Var2 | ...
# ------------------------------------------------------------

read_design_wide <- function(file) {

  df <- read_csv_safe(file, header = FALSE)

  if (nrow(df) < 2) {
    gc_abort("Wide design file must have at least 2 rows (well names + Well_type).")
  }

  # ---- Row 1: well names ----
  well_row <- trimws(as.character(unlist(df[1, ])))

  # Find which columns are well names
  well_pattern <- "^[A-H][0-9]{1,2}$"
  well_col_idx <- which(grepl(well_pattern, well_row))

  if (length(well_col_idx) < 2) {
    gc_abort("Wide design file: first row must contain well names (e.g. A1, B2 ... H12).")
  }

  well_names <- well_row[well_col_idx]

  # ---- Remaining rows: design variables ----
  design_rows <- df[seq(2, nrow(df)), , drop = FALSE]

  # First column = variable name; subsequent cols = values for each well
  var_names <- trimws(as.character(design_rows[[1]]))

  # Remove empty variable rows
  keep_rows <- nzchar(var_names)
  design_rows <- design_rows[keep_rows, , drop = FALSE]
  var_names   <- var_names[keep_rows]

  if (length(var_names) == 0) {
    gc_abort("Wide design file: no design variable rows found.")
  }

  # ---- Build output data.frame ----
  out <- data.frame(Well = well_names, stringsAsFactors = FALSE)

  for (r in seq_len(nrow(design_rows))) {
    vals <- trimws(as.character(unlist(design_rows[r, well_col_idx])))
    # Replace empty strings with NA
    vals[!nzchar(vals)] <- NA_character_
    out[[var_names[r]]] <- vals
  }

  out
}

# ------------------------------------------------------------
# extract_design_blocks_wide()
#
# Purpose:
#   Extract variable names from a wide design file
#   (all row labels except Well_type).
# ------------------------------------------------------------

extract_design_blocks_wide <- function(file) {

  df <- read_csv_safe(file, header = FALSE)

  if (nrow(df) < 2) return(character(0))

  var_names <- trimws(as.character(df[[1]][seq(2, nrow(df))]))
  var_names <- var_names[nzchar(var_names)]

  setdiff(var_names, "Well_type")
}

gc_read_design <- function(designfile, blocklist, design_file_format = NULL) {

  # ---- Detect format ----
  dfmt <- if (!is.null(design_file_format)) {
    design_file_format
  } else {
    detect_design_format(designfile)
  }

  if (dfmt == "wide") {

    # Wide: read directly and return
    my_design <- read_design_wide(designfile)

    # Validate requested variables exist
    avail <- setdiff(names(my_design), "Well")
    missing_vars <- setdiff(unlist(blocklist), c(avail, "Well_type"))
    if (length(missing_vars) > 0) {
      gc_abort(paste0(
        "Wide design file is missing requested variable(s): ",
        paste(missing_vars, collapse = ", ")
      ))
    }

    # Remove accidental row labels (A-H) for non-Well_type vars
    for (v in setdiff(names(my_design), c("Well", "Well_type"))) {
      my_design[[v]] <- as.character(my_design[[v]])
      my_design[[v]][my_design[[v]] %in% LETTERS[1:8]] <- NA
    }

    return(my_design)
  }

  my_design <- read_design_block_strict(designfile, blocklist)
  validate_design_table(my_design, strict_96 = TRUE)
  my_design
}

# ------------------------------------------------------------
# Helper: extract design block names for Shiny UI
# Reads the first column of each block header (stride = 10)
# and returns all names except Well_type (which is added
# internally by run_gc).
# ------------------------------------------------------------
extract_design_blocks <- function(designfile,
                                  start_row = 1,
                                  stride    = 10,
                                  design_file_format = NULL) {

  dfmt <- if (!is.null(design_file_format)) {
    design_file_format
  } else {
    detect_design_format(designfile)
  }

  if (dfmt == "wide") {
    return(extract_design_blocks_wide(designfile))
  }

  df <- read_csv_safe(
    designfile,
    header = FALSE,
    nrows = -1
  )

  blocks <- character()
  r      <- start_row

  while (r <= nrow(df)) {
    val <- trimws(as.character(df[r, 1]))
    if (is.na(val) || val == "") break
    blocks <- c(blocks, val)
    r <- r + stride
  }

  setdiff(blocks, "Well_type")
}

# ------------------------------------------------------------
# Helper: gc_import_data()
#
# Purpose:
#   Unified data import stage for growth curve analysis.
#
# Responsibilities:
#   - Validate requested design variables
#   - Import raw growth data (instrument-specific)
#   - Import design metadata (shared logic)
#   - Merge and clean datasets
#
# Design:
#   Separates instrument-specific parsing from shared pipeline
#   logic to improve maintainability and extensibility.
#
# Inputs:
#   rawdatafile : path to raw data CSV
#   designfile  : path to design CSV
#   design_vars : character vector of design variables
#   hrs         : experiment duration (hours)
#   interval    : measurement interval (hours)
#   format      : instrument type
#
# Returns:
#   list(
#     merged_data,
#     blocklist
#   )
# ------------------------------------------------------------

gc_import_data <- function(
    rawdatafile,
    designfile,
    design_vars,
    hrs,
    interval,
    format = c("plate_reader", "ocelloscope"),
    raw_data_format    = NULL,
    design_file_format = NULL
) {

  format <- match.arg(format)

  # ---- Blocklist ----
  blocklist <- c(list("Well_type"), as.list(design_vars))
  
  vars <- unlist(blocklist[-1])

  # ---- Validate design variables ----
  available_blocks <- extract_design_blocks(
    designfile,
    design_file_format = design_file_format
  )
  
  missing_vars <- setdiff(design_vars, available_blocks)
  if (length(missing_vars) > 0) {
    gc_abort(paste0(
      "Design variables not found in design file: ",
      paste(missing_vars, collapse = ", ")
    ))
  }

  # ==========================================================
  # READ RAW DATA (instrument-specific)
  # ==========================================================

  imported_tidy <- gc_read_raw_data(
    rawdatafile     = rawdatafile,
    designfile      = designfile,
    hrs             = hrs,
    interval        = interval,
    format          = format,
    raw_data_format = raw_data_format
  )
  
  dup_raw <- imported_tidy |>
    dplyr::count(Well, Time, name = "n") |>
    dplyr::filter(n > 1)
  
  if (nrow(dup_raw) > 0) {
    message("Duplicate raw Well-Time pairs detected:")
    print(dup_raw)
  }

  if (is.null(imported_tidy) || nrow(imported_tidy) == 0) {
    gc_abort(paste(
      "No data available after import.",
      "",
      "Possible causes:",
      "- Check that the file is correctly formatted",
      "- Verify the correct instrument mode is selected",
      "- Ensure the file is not empty",
      sep = "\n"
    ))
  }

  if (max(imported_tidy$Time, na.rm = TRUE) > 200) {
    warning("Time appears to still be in minutes - expected hours.")
  }
  # ==========================================================
  # READ DESIGN (shared)
  # ==========================================================

  my_design <- gc_read_design(
    designfile = designfile,
    blocklist  = blocklist,
    design_file_format = design_file_format
  )
  
  keep <- !is.na(my_design$Well_type)
  for (v in vars) {
    keep <- keep | !is.na(my_design[[v]])
  }
  
  mapping_table <- my_design[keep, c("Well", "Well_type", vars), drop = FALSE]
  mapping_table <- mapping_table[order(mapping_table$Well), , drop = FALSE]
  
  print(mapping_table)
  
  # ---- Extract design wells from SAME source ----
  design_wells <- unique(my_design$Well)
  
  # ---- Filter raw data using EXACT same mapping ----
  imported_tidy <- imported_tidy[
    imported_tidy$Well %in% design_wells,
    , drop = FALSE
  ]

  # ==========================================================
  # MERGE + CLEAN (shared)
  # ==========================================================

  merged_data <- dplyr::left_join(
    imported_tidy,
    my_design,
    by = "Well"
  )
  
  if (nrow(merged_data) != nrow(imported_tidy)) {
    gc_abort(
      paste(
        "Merge error:",
        "Joining design onto raw data changed the number of raw rows.",
        "This suggests duplicate wells in the design table or malformed raw keys."
      )
    )
  }
  
  bad_map <- merged_data |>
    dplyr::group_by(Well) |>
    dplyr::summarise(n_groups = dplyr::n_distinct(.data[[blocklist[[2]]]])) |>
    dplyr::filter(n_groups > 1)
  
  if (nrow(bad_map) > 0) {
    gc_abort(
      paste(
        "Design mapping error:",
        "Some wells are assigned to multiple groups.",
        "This indicates a mismatch between raw data and design file."
      )
    )
  }
  
  merged_data[vars] <- lapply(
    merged_data[vars],
    as.character
  )

  dup_postmerge <- merged_data |>
    dplyr::count(Well, Time, name = "n") |>
    dplyr::filter(n > 1)
  
  if (nrow(dup_postmerge) > 0) {
    gc_abort("Merge error: duplicate (Well, Time) pairs detected after joining design to raw data.")
  }

  if (nrow(merged_data) == 0) {
    gc_abort("No overlapping wells between data and design.")
  }

  merged_data <- na.omit(merged_data)

  merged_data$Time <- as.numeric(merged_data$Time)

  list(
    merged_data = merged_data,
    blocklist   = blocklist
  )
}

gc_normalize_path_for_export <- function(path) {
  pretty_export_path(path)
}

# ------------------------------------------------------------
# Core growth-curve computation (PURE, SIDE-EFFECT FREE)
#
# Purpose:
#   Executes the full scientific growth-curve analysis pipeline
#   while remaining completely independent of:
#     - plotting
#     - file I/O
#     - Shiny or UI concerns
#
# Responsibilities:
#   - Import raw plate reader data
#   - Import and merge design metadata
#   - Perform blank correction and log transforms
#   - Compute growth-rate derivatives and summary statistics
#
# Guarantees:
#   - Deterministic: same inputs produce same outputs
#   - Batch-safe and Shiny-safe
#   - Returns all intermediate and final data required for
#     downstream plotting and exporting
#
# Inputs:
#   rawdatafile  : path to plate reader CSV
#   designfile   : path to design CSV
#   design_vars  : character vector of design variables
#   hrs          : total duration (hours)
#   interval     : measurement interval (hours)
#   minod, maxod : OD window for growth-rate calculation
#
# Returns:
#   Named list containing cleaned data, summaries, and metadata
# ------------------------------------------------------------

gc_core_compute <- function(
    merged_data,
    blocklist,
    minod,
    maxod,
    smoothing = FALSE,
    smoothing_window = 3,
    blank_correct = TRUE,
    blank_mode = c("plate", "per_well", "none")
) {
  blank_mode <- match.arg(blank_mode)

  stopifnot(
    is.data.frame(merged_data),
    is.list(blocklist),
    length(blocklist) >= 2
  )
  
  t0 <- min(merged_data$Time, na.rm = TRUE)
  
  # ---- blank correction for plate reader only----
  has_blanks <- "Well_type" %in% names(merged_data) &&
    any(merged_data$Well_type == "Blank")
  
  if (blank_correct && blank_mode == "plate" && has_blanks) {
    
    blank_vals <- merged_data$Measurements[
      merged_data$Well_type == "Blank" &
        merged_data$Time == t0
    ]
    
    blankmed <- if (length(blank_vals) > 0) {
      median(blank_vals, na.rm = TRUE)
    } else {
      NA_real_
    }
    
    merged_data <- merged_data |>
      dplyr::mutate(
        Measurements_adj = Measurements - blankmed,
        Measurements_log = log10(pmax(Measurements_adj, 1e-6)),
        .after = Measurements
      )
    
    } else if (blank_correct && blank_mode == "per_well") {
    
    merged_data <- merged_data |>
      dplyr::group_by(Well) |>
      dplyr::mutate(
        well_t0 = Measurements[Time == t0][1],
        Measurements_adj = Measurements - well_t0,
        Measurements_log = log10(pmax(Measurements_adj, 1e-6))
      ) |>
      dplyr::ungroup()
    
    blankmed <- NA_real_
    
    } else {
    
    blankmed <- NA_real_
    
    # Data are treated as already blank-corrected
    merged_data <- merged_data |>
      dplyr::mutate(
        Measurements_adj = Measurements,
        Measurements_log = log10(pmax(Measurements, 1e-6)),
        .after = Measurements
      )
  }
  
  # ---- SECTION 4: Mean curves data ----
  merged_data_means <- merged_data |>
    dplyr::filter(.data[[blocklist[[1]]]] != "Blank") |>
    dplyr::group_by(dplyr::across(unlist(blocklist[-1])), Time) |>
    dplyr::summarize(
      mean = mean(Measurements_adj),
      sd   = sd(Measurements_adj),
      n    = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      ci       = stats::qt(0.975, df = n - 1) * (sd / sqrt(n)),
      group_id = interaction(
        dplyr::across(unlist(blocklist[-1])),
        sep = " | ", lex.order = TRUE
      )
    )
  
  # ---- SECTION 5: OD window + growth rates ----
  
  merged_data_sub <- subset(
    merged_data,
    Measurements_adj > minod & Measurements_adj < maxod
  )
  
  
  if (nrow(merged_data_sub) == 0) {
    
    hint <- c(
      "Design file may not match the data",
      "Wrong instrument mode selected (plate reader vs oCelloscope)",
      "OD thresholds may be too restrictive",
      "Data may be empty after merging"
    )
    
    gc_abort(paste0(
      "No data points fall within the OD window [",
      minod, ", ", maxod, "].\n\n",
      "Possible causes:\n- ",
      paste(hint, collapse = "\n- ")
    ))
  }
  
  merged_data_sub <- merged_data_sub |>
    dplyr::group_by(
      Well,
      dplyr::across(unlist(blocklist[-1]))
    ) |>
    dplyr::mutate(
      
      Measurements_base = Measurements_adj,
      
      Measurements_used = if (smoothing) {
        gcplyr::smooth_data(
          x = Time,
          y = Measurements_adj,
          sm_method = "moving-average",
          window_width_n = smoothing_window,
          subset_by = Well
        )
      } else {
        Measurements_adj
      },
      
      deriv = gcplyr::calc_deriv(
        x = Time,
        y = Measurements_used
      ),
      
      deriv_percap = gcplyr::calc_deriv(
        x = Time,
        y = Measurements_used,
        percapita = TRUE,
        blank = 0
      ),
      
      deriv_percap3 = gcplyr::calc_deriv(
        x = Time,
        y = Measurements_used,
        percapita = TRUE,
        blank = 0,
        window_width_n = 3,
        trans_y = "log"
      )
    ) |>
    dplyr::ungroup()
  
  # ---- SECTION 6: Growth-rate summaries ----
  ex_dat_mrg_sum <- merged_data_sub |>
    dplyr::group_by(dplyr::across(unlist(blocklist[-1])), Well) |>
    dplyr::summarize(
      max_percap = if (all(is.na(deriv_percap3))) NA_real_
      else gcplyr::max_gc(deriv_percap3, na.rm = TRUE),
      
      max_percap_time = if (all(is.na(deriv_percap3))) NA_real_
      else gcplyr::extr_val(Time, gcplyr::which_max_gc(deriv_percap3)),
      
      doub_time = if (all(is.na(deriv_percap3))) NA_real_
      else gcplyr::doubling_time(
        y = gcplyr::max_gc(deriv_percap3, na.rm = TRUE)
      ),
      .groups = "drop"
    )
  
  data_forplots <- ex_dat_mrg_sum |>
    dplyr::filter(.data[[blocklist[[2]]]] != "Blank")
  
  data_forplots <- gc_add_qc(data_forplots)
  
  qc_lookup <- data_forplots[, c("Well", "QC_flag", "QC_reason")]
  
  #  Attach QC to ALL datasets that need it
  
  merged_data <- dplyr::left_join(
    merged_data,
    qc_lookup,
    by = "Well"
  )
  
  merged_data_sub <- dplyr::left_join(
    merged_data_sub,
    qc_lookup,
    by = "Well"
  )
  
  ex_dat_mrg_sum <- dplyr::left_join(
    ex_dat_mrg_sum,
    qc_lookup,
    by = "Well"
  )
  
  # ---- RETURN CORE RESULTS ----
  list(
    blocklist         = blocklist,
    blankmed          = blankmed,
    blank_mode        = blank_mode,
    merged_data       = merged_data,
    merged_data_means = merged_data_means,
    merged_data_sub   = merged_data_sub,
    ex_dat_mrg_sum    = ex_dat_mrg_sum,
    data_forplots     = data_forplots
  )
}

gc_qc_scale <- function() {
  
  list(
    ggplot2::scale_colour_manual(
      values = c(
        "OK"   = "black",
        "WARN" = "#E69F00",   # orange
        "FAIL" = "grey70"
      )
    ),
    
    ggplot2::scale_alpha_manual(
      values = c(
        "OK"   = 1,
        "WARN" = 1,
        "FAIL" = 0.3
      )
    )
  )
}

format_axis_labels <- function(x, region) {
  lab <- format(x, scientific = FALSE, trim = TRUE)
  if (region == "EU") gsub("\\.", ",", lab) else lab
}

scale_y_gc <- function(region) {
  ggplot2::scale_y_continuous(
    labels = function(x) format_axis_labels(x, region)
  )
}

# ------------------------------------------------------------
# Plot 1: Blank-corrected OD curves (all wells)
#
# Purpose:
#   Visualize raw growth curves after blank correction,
#   colored by Well_type (Blank vs non-Blank).
#
# Inputs:
#   merged_data  : output from gc_core_compute()
#   blocklist    : design block list (Well_type must be [[1]])
#   ggplot_theme : shared ggplot theme
#
# Returns:
#   ggplot object (no saving, no printing)
# ------------------------------------------------------------
gc_plot_blank_corrected <- function(merged_data,
                                    blocklist,
                                    ggplot_theme,
                                    region) {
  
  ggplot2::ggplot(
    merged_data,
    ggplot2::aes(
      Time,
      Measurements_adj,
      group = Well,
      color = .data[[blocklist[[1]]]]
    )
  ) +
    ggplot2::geom_line(linewidth = 0.6) +
    ggplot2::labs(
      title = gc_plot_titles$blank_linear,
      x = "Time (hrs)",
      y = "OD (blank corrected)"
    ) +
    ggplot_theme + 
    gc_theme_title() +
    scale_y_gc(region)
}

# ------------------------------------------------------------
# Plot 2: Log-transformed blank-corrected OD curves
#
# Purpose:
#   Compare blank and non-blank wells on a log10 scale
#   to assess baseline behavior and early growth.
#
# Inputs:
#   merged_data  : output from gc_core_compute()
#   blocklist    : design block list (Well_type must be [[1]])
#   ggplot_theme : shared ggplot theme
#
# Returns:
#   ggplot object (no saving, no printing)
# ------------------------------------------------------------
gc_plot_blank_log <- function(merged_data,
                              blocklist,
                              ggplot_theme,
                              region) {
  
  ggplot2::ggplot(
    merged_data,
    ggplot2::aes(
      Time,
      Measurements_log,
      group = Well,
      color = .data[[blocklist[[1]]]]
    )
  ) +
    ggplot2::geom_line(linewidth = 0.6) +
    ggplot2::labs(
      title = gc_plot_titles$blank_log,
      x = "Time (hrs)",
      y = bquote(log[10] * "OD (blank corrected)")
    ) +
    ggplot_theme + 
    gc_theme_title() +
    scale_y_gc(region)
}

# ------------------------------------------------------------
# Plot 3: Mean growth curves with 95% confidence intervals
#
# Purpose:
#   Display group-averaged growth curves across all
#   user-selected design variables, including uncertainty.
#
# Inputs:
#   merged_data_means : mean/SD/CI summary data
#   ggplot_theme      : shared ggplot theme
#
# Returns:
#   ggplot object (no saving, no printing)
# ------------------------------------------------------------
gc_plot_mean_curves <- function(merged_data_means,
                                ggplot_theme,
                                region) {
  
  ggplot2::ggplot(
    merged_data_means,
    ggplot2::aes(
      Time,
      mean,
      group  = group_id,
      colour = group_id,
      fill   = group_id
    )
  ) +
    ggplot2::geom_line(linewidth = 0.5) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = mean - ci, ymax = mean + ci),
      alpha = 0.2,
      colour = NA
    ) +
    ggplot2::labs(
      title = gc_plot_titles$mean_curves,
      x = "Time (hrs)",
      y = "OD (blank corrected)",
      colour = "Group",
      fill   = "Group"
    ) +
    ggplot_theme + 
    gc_theme_title() +
    scale_y_gc(region)
}

# ------------------------------------------------------------
# Plot 4: Blank-corrected OD curves per well (faceted)
#
# Purpose:
#   Display individual growth curves per well on a linear scale
#   after blank correction.
#
# Notes:
#   - Reorders Well factor to A1-H12 to match plate layout
#   - Drops NA rows before plotting
#
# Inputs:
#   merged_data  : output from gc_core_compute()
#   ggplot_theme : shared ggplot theme
#
# Returns:
#   ggplot object (no saving, no printing)
# ------------------------------------------------------------
gc_plot_perwell_linear <- function(merged_data,
                                   region) {
  
  plot_data <- merged_data
  
  plot_data$Well <- factor(
    plot_data$Well,
    levels = paste0(rep(LETTERS[1:8], each = 12), 1:12)
  )
  
  plot_data <- na.omit(plot_data)
  
  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x = Time,
      y = Measurements_adj,
      colour = QC_flag,
      alpha  = QC_flag
    )
  ) +
    ggplot2::geom_line(linewidth = 0.3) +
    
    gc_qc_scale() +
    
    ggplot2::labs(
      title = gc_plot_titles$perwell_linear,
      y = "OD (blank corrected)",
      x = "Time (hrs)",
      colour = "QC status",
      alpha  = "QC status"
    ) +
    ggplot2::facet_wrap(~Well) + 
    gc_theme_title() +
    scale_y_gc(region)
}

# ------------------------------------------------------------
# Plot 5: Log-transformed blank-corrected OD curves per well
#
# Purpose:
#   Display individual growth curves per well on a log10 scale
#   after blank correction.
#
# Notes:
#   - Reorders Well factor to A1-H12 to match plate layout
#   - Drops NA rows before plotting
#
# Inputs:
#   merged_data  : output from gc_core_compute()
#   ggplot_theme : shared ggplot theme
#
# Returns:
#   ggplot object (no saving, no printing)
# ------------------------------------------------------------
gc_plot_perwell_log <- function(merged_data,
                                region) {
  
  plot_data <- merged_data
  
  plot_data$Well <- factor(
    plot_data$Well,
    levels = paste0(rep(LETTERS[1:8], each = 12), 1:12)
  )
  
  plot_data <- na.omit(plot_data)
  
  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      Time,
      Measurements_log,
      colour = QC_flag,
      alpha  = QC_flag
    )
  ) +
    ggplot2::geom_line(linewidth = 0.3) +
    
    gc_qc_scale() +
    
    ggplot2::labs(
      title = gc_plot_titles$perwell_log,
      y = bquote(log[10] * "OD (blank corrected)"),
      x = "Time (hrs)",
      colour = "QC status",
      alpha  = "QC status"
    ) +
    
    ggplot2::facet_wrap(~Well) + 
    gc_theme_title() +
    scale_y_gc(region)
}

# ------------------------------------------------------------
# Plot 6: Raw derivative per well
#
# Purpose:
#   Visualize instantaneous growth-rate derivatives for each
#   well within the specified OD window.
#
# Inputs:
#   merged_data_sub : OD-windowed growth data with derivatives
#   ggplot_theme    : shared ggplot theme
#
# Returns:
#   ggplot object (no saving, no printing)
# ------------------------------------------------------------
gc_plot_derivative_perwell <- function(merged_data_sub,
                                       region) {
  
  ggplot2::ggplot(
    merged_data_sub,
    ggplot2::aes(
      Time,
      deriv,
      colour = QC_flag,
      alpha  = QC_flag
    )
  ) +
    ggplot2::geom_line(linewidth = 0.3) +
    gc_qc_scale() +
    ggplot2::labs(
      title = gc_plot_titles$deriv_raw,
      y = "Derivative",
      x = "Time (hrs)",
      colour = "QC status",
      alpha  = "QC status"
    ) +
    ggplot2::facet_wrap(~Well, scales = "free") + 
    gc_theme_title() +
    scale_y_gc(region)
}
# ------------------------------------------------------------
# Plot 7: Per-capita derivative per well
#
# Purpose:
#   Visualize per-capita growth-rate derivatives for each well
#   within the specified OD window.
#
# Inputs:
#   merged_data_sub : OD-windowed growth data with derivatives
#   ggplot_theme    : shared ggplot theme
#
# Returns:
#   ggplot object (no saving, no printing)
# ------------------------------------------------------------
gc_plot_percap_derivative_perwell <- function(merged_data_sub,
                                              region) {
  
  ggplot2::ggplot(
    merged_data_sub,
    ggplot2::aes(
      Time,
      deriv_percap,
      colour = QC_flag,
      alpha  = QC_flag
    )
  ) +
    ggplot2::geom_line(linewidth = 0.3) +
    gc_qc_scale() +
    ggplot2::labs(
      title = gc_plot_titles$deriv_percap,
      y = "Per-capita derivative",
      x = "Time (hrs)",
      colour = "QC status",
      alpha  = "QC status"
    ) +
    ggplot2::facet_wrap(~Well, scales = "free") + 
    gc_theme_title() +
    scale_y_gc(region)
}
# ------------------------------------------------------------
# Plot 8: Fitted per-capita derivative with max marked
#
# Purpose:
#   Show fitted per-capita growth-rate curves per well and
#   indicate the maximum growth rate timepoint.
#
# Inputs:
#   merged_data_sub : OD-windowed growth data (fitted derivatives)
#   ex_dat_mrg_sum  : per-well growth-rate summaries
#   ggplot_theme    : shared ggplot theme
#
# Returns:
#   ggplot object (no saving, no printing)
# ------------------------------------------------------------
gc_plot_fitted_percap_with_max <- function(merged_data_sub,
                                           ex_dat_mrg_sum,
                                           region) {
  
  ggplot2::ggplot(
    merged_data_sub,
    ggplot2::aes(
      Time,
      deriv_percap3,
      colour = QC_flag,
      alpha  = QC_flag
    )
  ) +
    ggplot2::geom_line(linewidth = 0.3) +
    gc_qc_scale() +
    ggplot2::facet_wrap(~Well) +
    
    ggplot2::geom_point(
      data = ex_dat_mrg_sum,
      ggplot2::aes(x = max_percap_time, y = max_percap),
      inherit.aes = FALSE,   #  still required
      size = 1,
      color = "red"
    ) +
    
    ggplot2::labs(
      title = gc_plot_titles$fitted_percap,
      y = "Fitted per-capita derivative",
      x = "Time (hrs)",
      colour = "QC status",
      alpha  = "QC status"
    ) +
    gc_theme_title() +
    scale_y_gc(region)
}

# ------------------------------------------------------------
# Plot 9: OD curves per well with max growth-rate time marked
#
# Purpose:
#   Overlay per-well OD curves with a vertical line indicating
#   the time of maximum per-capita growth rate.
#
# Inputs:
#   merged_data     : full merged growth data
#   ex_dat_mrg_sum  : per-well growth-rate summaries
#   blocklist       : design block list (Well_type in [[1]])
#   ggplot_theme    : shared ggplot theme
#
# Returns:
#   ggplot object (no saving, no printing)
# ------------------------------------------------------------
gc_plot_od_curves_with_maxgc <- function(merged_data,
                                         ex_dat_mrg_sum,
                                         blocklist,
                                         region) {
  
  plot_data <- merged_data |>
    dplyr::filter(.data[[blocklist[[1]]]] != "Blank")
  
  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      Time,
      Measurements_adj,
      colour = QC_flag,
      alpha  = QC_flag
    )
  ) +
    ggplot2::geom_line(linewidth = 0.3) +
    gc_qc_scale() +
    ggplot2::facet_wrap(~Well) +
    
    ggplot2::geom_vline(
      data = ex_dat_mrg_sum,
      ggplot2::aes(xintercept = max_percap_time),
      inherit.aes = FALSE,   #  still required
      linewidth = 0.3,
      color = "red",
      linetype = "dotted"
    ) +
    
    ggplot2::labs(
      title = gc_plot_titles$od_with_maxgc,
      y = "OD (blank corrected)",
      x = "Time (hrs)",
      colour = "QC status",
      alpha  = "QC status"
    ) +
    gc_theme_title() +
    scale_y_gc(region)
}

# ------------------------------------------------------------
# Plot 10: Doubling time dot plot
#
# Purpose:
#   Visualize per-well doubling times grouped by the primary
#   design variable, with group means and 95% CI.
#
# Inputs:
#   data_forplots : summarized per-well growth metrics
#   blocklist     : design block list (primary group in [[2]])
#
# Returns:
#   ggplot object (no saving, no printing)
# ------------------------------------------------------------
gc_plot_doubling_time <- function(data_forplots,
                                  blocklist,
                                  region) {
  
  if (length(blocklist) > 2) {
    extra_blocks  <- unlist(blocklist[-(1:2)])
    facet_formula <- as.formula(
      paste("~", paste(extra_blocks, collapse = " + "))
    )
  } else {
    facet_formula <- NULL
  }
  
  p <- ggplot2::ggplot(data_forplots) +
    ggplot2::aes(
      x     = .data[[blocklist[[2]]]],
      y     = doub_time,
      color = .data[[blocklist[[2]]]]
    ) +
    ggplot2::geom_jitter() +
    ggplot2::stat_summary(
      fun = mean,
      geom = "crossbar",
      width = 0.75,
      linewidth = 0.4,
      color = "black"
    ) +
    ggplot2::stat_summary(
      fun.min = function(x)
        mean(x) - qt(0.975, df = length(x) - 1) * (sd(x) / sqrt(length(x))),
      fun.max = function(x)
        mean(x) + qt(0.975, df = length(x) - 1) * (sd(x) / sqrt(length(x))),
      geom = "errorbar",
      width = 0.3,
      color = "black"
    ) +
    ggplot2::theme(legend.position = "none") +
    ggplot2::labs(
      title = gc_plot_titles$doubling_time,
      y     = "Doubling time (hrs)"
    ) + 
    gc_theme_title() +
    scale_y_gc(region)
  
  if (!is.null(facet_formula)) {
    p <- p + ggplot2::facet_wrap(facet_formula)
  }
  
  p
}

# ------------------------------------------------------------
# Plot 11: Max growth rate dot plot
#
# Purpose:
#   Visualize maximum per-capita growth rates grouped by the
#   primary design variable, with group means and 95% CI.
#
# Inputs:
#   data_forplots : summarized per-well growth metrics
#   blocklist     : design block list (primary group in [[2]])
#
# Returns:
#   ggplot object (no saving, no printing)
# ------------------------------------------------------------
gc_plot_max_growth_rate <- function(data_forplots,
                                    blocklist,
                                    region) {
  
  if (length(blocklist) > 2) {
    extra_blocks  <- unlist(blocklist[-(1:2)])
    facet_formula <- as.formula(
      paste("~", paste(extra_blocks, collapse = " + "))
    )
  } else {
    facet_formula <- NULL
  }
  
  p <- ggplot2::ggplot(data_forplots) +
    ggplot2::aes(
      x     = .data[[blocklist[[2]]]],
      y     = max_percap,
      color = .data[[blocklist[[2]]]]
    ) +
    ggplot2::geom_jitter() +
    ggplot2::stat_summary(
      fun = mean,
      geom = "crossbar",
      width = 0.75,
      linewidth = 0.4,
      color = "black"
    ) +
    ggplot2::stat_summary(
      fun.min = function(x)
        mean(x) - qt(0.975, df = length(x) - 1) * (sd(x) / sqrt(length(x))),
      fun.max = function(x)
        mean(x) + qt(0.975, df = length(x) - 1) * (sd(x) / sqrt(length(x))),
      geom = "errorbar",
      width = 0.3,
      color = "black"
    ) +
    ggplot2::theme(legend.position = "none") +
    ggplot2::labs(
      title = gc_plot_titles$max_growth_rate,
      y     = bquote("Max growth rate (hrs"^-1 * ")")
    ) + 
    gc_theme_title() +
    scale_y_gc(region)
  
  if (!is.null(facet_formula)) {
    p <- p + ggplot2::facet_wrap(facet_formula)
  }
  
  p
}

# ------------------------------------------------------------
# Helper: gc_build_plots()
#
# Purpose:
#   Stage C of run_gc(): construct all ggplot objects.
#
# Responsibilities:
#   - Build all plots from gc_core_compute() output
#   - No saving
#   - No printing
#   - No side effects
#
# Returns:
#   Named list of ggplot objects
# ------------------------------------------------------------

gc_build_plots <- function(core, ggplot_theme, region) {
  
  stopifnot(is.list(core), !is.null(core$blocklist))
  
  blocklist         <- core$blocklist
  merged_data       <- core$merged_data
  merged_data_means <- core$merged_data_means
  merged_data_sub   <- core$merged_data_sub
  ex_dat_mrg_sum    <- core$ex_dat_mrg_sum
  data_forplots     <- core$data_forplots
  
  plots <- list()
  
  # ----------------------------------------------------------
  # Plots 1-3: Global growth curves
  # ----------------------------------------------------------
  
  plots$blank_linear <- gc_plot_blank_corrected(
    merged_data  = merged_data,
    blocklist    = blocklist,
    ggplot_theme = ggplot_theme,
    region       = region
  )
  
  plots$blank_log <- gc_plot_blank_log(
    merged_data  = merged_data,
    blocklist    = blocklist,
    ggplot_theme = ggplot_theme,
    region       = region
  )
  
  plots$mean_curves <- gc_plot_mean_curves(
    merged_data_means = merged_data_means,
    ggplot_theme      = ggplot_theme,
    region            = region
  )
  
  # ----------------------------------------------------------
  # Plots 4-5: Per-well OD curves
  # ----------------------------------------------------------
  
  plots$perwell_linear <- gc_plot_perwell_linear(
    merged_data = merged_data,
    region      = region
  )
  
  plots$perwell_log <- gc_plot_perwell_log(
    merged_data = merged_data,
    region      = region
  )
  
  # ----------------------------------------------------------
  # Plots 6-9: Growth-rate diagnostics
  # ----------------------------------------------------------
  
  plots$deriv_raw <- gc_plot_derivative_perwell(
    merged_data_sub = merged_data_sub,
    region          = region
  )
  
  plots$deriv_percap <- gc_plot_percap_derivative_perwell(
    merged_data_sub = merged_data_sub,
    region          = region
  )
  
  plots$fitted_percap <- gc_plot_fitted_percap_with_max(
    merged_data_sub = merged_data_sub,
    ex_dat_mrg_sum  = ex_dat_mrg_sum,
    region          = region
  )
  
  plots$od_with_maxgc <- gc_plot_od_curves_with_maxgc(
    merged_data    = merged_data,
    ex_dat_mrg_sum = ex_dat_mrg_sum,
    blocklist      = blocklist,
    region         = region
  )
  
  # ----------------------------------------------------------
  # Plots 10-11: Summary dot plots
  # ----------------------------------------------------------
  
  # Only construct these if data exist
  if (nrow(data_forplots) > 0) {
    
    plots$doubling_time <- gc_plot_doubling_time(
      data_forplots = data_forplots,
      blocklist     = blocklist,
      region        = region
    )
    
    plots$max_growth_rate <- gc_plot_max_growth_rate(
      data_forplots = data_forplots,
      blocklist     = blocklist,
      region        = region
    )
  }
  
  plots
}

# ------------------------------------------------------------
# Helper: gc_save_report()
#
# Purpose:
#   Stage D of run_gc(): export all plots into a single PDF report.
#
# Responsibilities:
#   - Combine all plots into a multi-page PDF
#   - Ensure consistent formatting and ordering
#
# Returns:
#   Character string with the path to the generated report
# ------------------------------------------------------------

#' Saves plots in single report
#' @export
gc_save_report <- function(plots, file, plate_name = NULL) {
  
  if (!is.list(plots)) {
    gc_abort("Invalid plots object.")
  }
  
  grDevices::pdf(file, width = 10, height = 7, title = plate_name %||% basename(file))
  
  for (name in names(plots)) {
    
    p <- plots[[name]]
    
    if (!is.null(p)) {
      print(p)
      }
  }
  
  dev.off()
  
  file
}

# ------------------------------------------------------------
# Helper: gc_write_summaries()
#
# Purpose:
#   Stage E of run_gc(): write CSV summary outputs.
#
# Responsibilities:
#   - Write summary table (growth rates & doubling times)
#   - Write argument record
#
# Inputs:
#   core        : output from gc_core_compute()
#   params      : validated run parameters (from gc_prepare_run)
#   plate_dir : directory where CSVs should be written
#
# Returns:
#   Named character vector of written file paths
# ------------------------------------------------------------

#' Saves summary files
#' @export
gc_write_summaries <- function(core,
                               params,
                               instrument,
                               out_dir,
                               region,
                               raw_data_format    = NULL,
                               design_file_format = NULL) {
  
  if (!is.data.frame(core$data_forplots)) {
    gc_abort("Core data is invalid - cannot write summaries.")
  }
  
  stopifnot(
    is.list(core),
    is.list(params),
    dir.exists(out_dir)
  )
  
  written <- character()
  
  # ----------------------------------------------------------
  # Core data tables (always written)
  # ----------------------------------------------------------
  
  path <- function(filename)
    file.path(out_dir, filename)
  
  # ----------------------------------------------------------
  # Tidy per-plate output (NEW PRIMARY OUTPUT)
  # ----------------------------------------------------------
  
  # ---- define prefix ONCE (scalar) ----
  prefix_val <- params$prefix %||% ""
  
  # ---- build tidy output ----
  tidy <- gc_make_tidy(core, prefix_val, instrument)

  write_csv_safe(
    tidy,
    path("plate_tidy.csv"),
    region = region
  )
  
  
  # ----------------------------------------------------------
  # Argument record (metadata)
  # ----------------------------------------------------------
  
  safe_val <- function(x) {
    if (is.null(x) || length(x) == 0) {
      ""
    } else {
      as.character(x)
    }
  }
  
  args_record <- data.frame(
    Argument = c(
      "rawdatafile",
      "designfile",
      "instrument",
      "raw_data_format",
      "design_file_format",
      "blank_correction_mode",
      "duration (hrs)",
      "interval (min)",
      "minod",
      "maxod",
      "extra_design_vars"
    ),
    Value = c(
      safe_val(gc_normalize_path_for_export(params$rawdatafile)),
      safe_val(gc_normalize_path_for_export(params$designfile)),
      safe_val(instrument),
      safe_val(if (!is.null(raw_data_format)) raw_data_format else "block"),
      safe_val(if (!is.null(design_file_format)) design_file_format else "block"),
      safe_val(if (!is.null(core$blank_mode)) core$blank_mode else "none"),
      safe_val(params$hrs),
      safe_val(params$interval * 60),
      safe_val(params$minod),
      safe_val(params$maxod),
      safe_val(paste(if (!is.null(params$design_vars)) params$design_vars else character(0), collapse = ", "))
    ),
    stringsAsFactors = FALSE
  )    
    write_csv_safe(
      args_record,
      path("Analysis_arguments.csv"),
      region = region
    )
    written["analysis_arguments"] <- path("Analysis_arguments.csv")
  
  written
}

# ------------------------------------------------------------
# Helper: gc_aggregate_tidies()
#
# Purpose:
#   Combine all plate_tidy.csv files within an Analysis run
#   directory into a single dataset.
#
# Behavior:
#   - Recursively searches for plate_tidy.csv
#   - Safely reads all valid files
#   - Optionally adds source metadata
#   - Harmonizes columns across files
#
# Inputs:
#   analysis_dir : path to Analysis/<run> directory
#
# Returns:
#   Combined data.frame
# ------------------------------------------------------------

gc_aggregate_tidies <- function(analysis_dir) {
  
  # ---------------------------
  # Validate input
  # ---------------------------
  if (!is.character(analysis_dir) ||
      length(analysis_dir) != 1 ||
      !dir.exists(analysis_dir)) {
    gc_abort("Invalid analysis directory.")
  }
  
  # ---------------------------
  # Find tidy files
  # ---------------------------
  files <- base::list.files(
    path        = analysis_dir,
    pattern     = "plate_tidy\\.csv$",
    recursive   = TRUE,
    full.names  = TRUE,
    ignore.case = TRUE
  )
  
  if (length(files) == 0) {
    gc_abort(
      "No plate_tidy.csv files found in selected directory."
    )
  }
  
  # ---------------------------
  # Read files safely
  # ---------------------------
  dfs <- vector("list", length(files))
  
  for (i in seq_along(files)) {
    
    f <- files[i]
    
    df <- tryCatch(
      read_csv_safe(f),
      error = function(e) {
        warning("Failed to read: ", f, " (", gc_get_message(e), ")")
        NULL
      }
    )
    
    if (!is.null(df)) {
      df$Source_file <- basename(dirname(f))
      dfs[[i]] <- df
    }
  }
  
  # Remove failed reads
  dfs <- Filter(Negate(is.null), dfs)
  
  if (length(dfs) == 0) {
    gc_abort("No readable plate_tidy.csv files found.")
  }
  
  # ---------------------------
  # Harmonize columns
  # ---------------------------
  all_cols <- unique(unlist(lapply(dfs, names)))
  
  dfs <- lapply(dfs, function(df) {
    
    missing_cols <- setdiff(all_cols, names(df))
    
    if (length(missing_cols) > 0) {
      for (col in missing_cols) {
        df[[col]] <- NA
      }
    }
    
    # Ensure consistent column order
    df[, all_cols, drop = FALSE]
  })
  
  # ---------------------------
  # Combine
  # ---------------------------
  combined <- do.call(rbind, dfs)
  
  rownames(combined) <- NULL
  
  combined
}

gc_add_qc <- function(df) {
  
  df |>
    dplyr::mutate(
      QC_flag = dplyr::case_when(
        is.na(max_percap) ~ "FAIL",
        is.na(doub_time)  ~ "FAIL",
        doub_time < 0.2   ~ "WARN",
        doub_time > 10    ~ "WARN",
        TRUE              ~ "OK"
      ),
      
      QC_reason = dplyr::case_when(
        is.na(max_percap) ~ "No growth rate detected",
        is.na(doub_time)  ~ "Doubling time undefined",
        doub_time < 0.2   ~ "Very fast growth",
        doub_time > 10    ~ "Very slow growth",
        TRUE              ~ ""
      )
    )
}

gc_make_tidy <- function(core, prefix = NA_character_, instrument = NA_character_) {

  blocklist  <- core$blocklist
  group_vars <- unlist(blocklist[-1])
  
  df <- gc_add_qc(core$data_forplots)
  
  if (nrow(df) == 0) {
    return(data.frame())
  }
  
  tidy <- df |>
    dplyr::select(any_of(group_vars), Well, max_percap, doub_time, QC_flag, QC_reason) |>
    dplyr::rename(max_growth = max_percap) |>
    
   tidyr::pivot_longer(
      cols = c(max_growth, doub_time),
      names_to = "Measurement",
      values_to = "Value"
    ) |>
    dplyr::mutate(Value = as.numeric(Value)) |>

   dplyr::group_by(across(all_of(group_vars)), Measurement) |>
    dplyr::mutate(Replicate = dplyr::row_number()) |>
    dplyr::ungroup()
  
  tidy$instrument <- instrument
  
  tidy$prefix <- if (!is.na(prefix) && nzchar(prefix)) prefix else ""
  
  tidy
  
}

# ------------------------------------------------------------
# run_gc() - Orchestrated growth-curve analysis pipeline
#
# Purpose:
#   High-level coordinator for growth curve analysis.
#   Delegates work to explicit stages:
#     A. Input validation & setup
#     B. Core computation (pure science)
#     C. Plot construction (pure)
#     D. Plot export (I/O, optional)
#     E. Table export (I/O)
#     F. Final assembly & return
#
# Guarantees:
#   - No UI side effects
#   - Deterministic for same inputs
#   - All user-visible outputs returned in a structured object
# ------------------------------------------------------------

#' Run growth curve analysis
#' @export
run_gc <- function(
    rawdatafile,
    designfile,
    design_vars = NULL,
    hrs,
    interval,
    minod,
    maxod,
    instrument = "plate_reader",
    prefix = "",
    blank_mode = "plate",
    batch  = TRUE,
    cancel = NULL,
    region = "US",
    raw_data_format    = NULL,
    design_file_format = NULL
) {
  
  pkgs <- gc_check_packages()
  
  if (length(pkgs$missing) > 0 || length(pkgs$broken) > 0) {
    gc_abort("Required packages are not available. Please install them before running analysis.")
  }
  
  # ----------------------------------------------------------
  # Helper: cancellation check
  # ----------------------------------------------------------
  check_cancel <- function() {
    if (!is.null(cancel) && isTRUE(cancel())) {
      gc_abort("Analysis cancelled by user")
    }
  }
  
  check_cancel()
  
  # ---- Resolve design variables ----
  if (is.null(design_vars)) {
    
    if (batch) {
      design_vars <- extract_design_blocks(designfile)
      
      if (!is.character(design_vars) || length(design_vars) == 0) {
        gc_abort(
          paste0(
            "No design variables could be inferred from design file:\n",
            basename(designfile), "\n\n",
            "Ensure the design file contains valid block headers ",
            "in the first column."
          )
        )
      }
      
    } else {
      gc_abort("design_vars must be provided in single-plate mode.")
    }
  }
  
  # ==========================================================
  # STAGE A - Input validation & setup
  # ==========================================================
  # Responsibilities:
  #   - Validate arguments
  #   - Normalize input files and prefix
  #   - Create output directories
  #   - Define shared ggplot theme
  #   - Snapshot parameters
  #
  # Returns:
  #   list(
  #     params,
  #     inputs,
  #     analysis_dir,
  #     ggplot_theme
  #   )
  # ==========================================================
  
  prep <- gc_prepare_run(
    rawdatafile = rawdatafile,
    designfile  = designfile,
    design_vars = design_vars,
    hrs         = hrs,
    interval    = interval,
    minod       = minod,
    maxod       = maxod,
    prefix      = prefix,
    batch       = batch
  )
  
  # ----------------------------------------------------------
  # Resolve instrument defaults
  # ----------------------------------------------------------
  
  if (!instrument %in% names(gc_instrument_defaults)) {
    gc_abort(paste0("Unknown instrument type: ", instrument))
  }
  
  inst_defaults <- gc_instrument_defaults[[instrument]]
  
  check_cancel()
  
  # ==========================================================
  # STAGE B - Core computation (PURE)
  # ==========================================================
  # Responsibilities:
  #   - All scientific computation
  #   - No plotting
  #   - No file I/O
  #
  # Returns:
  #   gc_core_compute() list
  # ==========================================================
  
  imported <- gc_import_data(
    rawdatafile        = prep$inputs$rawdatafile,
    designfile         = prep$inputs$designfile,
    design_vars        = prep$params$design_vars,
    hrs                = prep$params$hrs,
    interval           = prep$params$interval,
    format             = instrument,
    raw_data_format    = raw_data_format,
    design_file_format = design_file_format
  )
  
  use_blank <- instrument == "plate_reader"
  
  core <- gc_core_compute(
    merged_data      = imported$merged_data,
    blocklist        = imported$blocklist,
    minod            = prep$params$minod,
    maxod            = prep$params$maxod,
    smoothing        = inst_defaults$smoothing,
    smoothing_window = if (!is.null(inst_defaults$smoothing_window)) {
      inst_defaults$smoothing_window
    } else {
      3
    },
    blank_correct    = use_blank,
    blank_mode       = if (use_blank) blank_mode else "none"
  )
  
  check_cancel()
  
  # ==========================================================
  # STAGE C - Plot construction (PURE)
  # ==========================================================
  # Responsibilities:
  #   - Build all ggplot objects
  #   - No saving
  #   - No printing
  #
  # Returns:
  #   named list of ggplot objects
  # ==========================================================
  
  plots <- gc_build_plots(
    core          = core,
    ggplot_theme  = prep$ggplot_theme,
    region        = region
  )
  
  check_cancel()
  
  # ==========================================================
  # STAGE D - Final assembly & return
  # ==========================================================
  # Responsibilities:
  #   - Assemble structured return object
  #   - Surface convenience fields for Shiny
  # ==========================================================
  
  list(
    status        = "success",
    params        = prep$params,
    inputs        = prep$inputs,
    instrument    = instrument,
    blank_mode    = core$blank_mode,
    core          = core,
    plots         = plots,
    blankmed      = core$blankmed,
    raw_data_format    = raw_data_format %||% detect_plate_format(rawdatafile),
    design_file_format = design_file_format %||% detect_design_format(designfile)
  )
}

