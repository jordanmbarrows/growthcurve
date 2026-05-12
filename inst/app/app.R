# ============================================================
# app.R
# Growth Curve Shiny App – UI and Server Orchestration
#
# Version: 1.0.0
# Date: 2026-05-11
#
# Purpose:
#   Defines the Shiny user interface and server logic.
#   Orchestrates file selection, parameter input, progress
#   reporting, cancellation, and execution of the analysis
#   backend.
#
# Notes:
#   - No scientific analysis is implemented here.
#   - Analysis logic lives in growthcurve_functions.R.
# ============================================================

# ============================================================
# ⚠️ CSV PARSING RULE
#
# All CSV reading MUST go through read_csv_safe().
# No direct read.csv(), read.table(), or delimiter detection allowed.
#
# All CSV output MUST go through write_csv_safe().
# Do NOT use write.csv() or write.table() directly,
# or regional formatting will break.
# ============================================================

guide_summary_style <- function() {
  "
  cursor: pointer;
  padding: 6px 8px;
  margin-top: 6px;
  background-color: #e0e0e0;
  border-radius: 4px;
  font-weight: 600;
  "
}

guide_body_style <- function() {
  "padding: 10px 4px;"
}

guide_note_style <- function() {
  "font-size: 0.9em; color: #555;"
}

ui <- fluidPage(shinyjs::useShinyjs(), tagList(if (!gc_backend_ready()) {
  verbatimTextOutput("startup_error")
  
} else {
  tagList(
    titlePanel("Growth Curve Analysis"),
    
    wellPanel(
      h4("Working directory"),
      textInput(
        "wd",
        "Working directory path",
        value = if (isTRUE(DEV_DEFAULT))
          "C:/Users/Jordan/Desktop/Shiny app development/dev/Dummy data/"
        else
          ""
      ),
      actionButton("set_wd", "Set working directory"),
      actionButton("refresh_files", "Refresh files"),
      verbatimTextOutput("wd_txt"),
      
      
      tags$details(
        tags$summary(
          style = "
                cursor: pointer;
                padding: 6px 8px;
                margin-top: 6px;
                background-color: #e0e0e0;
                border-radius: 4px;
                font-weight: 600;
              ",
          "ℹ️  How do I copy a folder path?"
        ),
        tags$div(
          style = "padding: 8px 4px;",
          tags$ul(
            tags$li(strong("RStudio:"), " Files tab → ⚙️ → Copy Path to Clipboard"),
            tags$li(
              strong("Windows:"),
              " Address bar → Ctrl + C (or Shift + Right-click → Copy as path)"
            ),
            tags$li(strong("macOS:"), " Option + Right-click → Copy as Pathname"),
            tags$li(strong("Linux:"), " Right-click → Copy Path / Copy Location")
          ),
          tags$p(
            "Paste the path above and click ",
            tags$strong("Set working directory"),
            ". Quoted paths are OK."
          )
        )
      ),
      
      tags$details(
        tags$summary(style = guide_summary_style(), "🌍 Regional settings"),
        tags$div(
          style = guide_body_style(),
          
          tags$hr(),
          
          h4("CSV format (regional settings)"),
          
          tags$p("Detected:", tags$strong(
            textOutput("region_detected_txt", inline = TRUE)
          )),
          
          tags$p(
            style = guide_note_style(),
            "Note: Detection is based on your R session rather than your operating system or Excel settings. If this looks incorrect, please adjust the setting below."
          ),
          
          selectInput(
            "region_override",
            "Output format",
            choices = c(
              "Auto-detect" = "auto",
              "US (comma, decimal point)" = "US",
              "European (semicolon, decimal comma)" = "EU"
            ),
            selected = "auto"
          ),
          
          tags$p(
            style = guide_note_style(),
            "This controls how data preview tables are rendered and exported plots and CSV files are written. Input files are handled automatically."
          )
        )
      )
    ),
    
    tabsetPanel(
      tabPanel("User guide", div(uiOutput("user_guide_ui"))),
      tabPanel("Single plate", uiOutput("single_ui")),
      tabPanel(
        "Batch processing",
        
        uiOutput("batch_gate"),
        
        div(
          id = "batch_controls",
          
          h3("Batch analysis"),
          
          hr(),
          
          h4("Select instrument"),
          
          radioButtons(
            "batch_instrument",
            label = NULL,
            choices = c("Plate reader" = "plate_reader", "oCelloscope"  = "ocelloscope"),
            selected = "plate_reader",
            inline = TRUE
          ),
          
          hr(),
          
          tags$details(
            tags$summary(style = guide_summary_style(), "ℹ️  Directory requirements"),
            tags$div(style = guide_body_style(), tags$ul(
              tags$li("Each raw data file must match exactly one design file."),
              tags$li("Matching is based on a shared identifier in filenames."),
              tags$li("Each pair is processed independently."),
              tags$li("If one plate fails, others will still complete.")
            ))
          ),
          
          selectInput("batch_data_dir", "Raw data directory", choices = NULL),
          
          tags$details(
            tags$summary(style = guide_summary_style(), "👁 Preview raw data (first file)"),
            tags$div(
              style = guide_body_style(),
              textOutput("batch_preview_label"),
              uiOutput("batch_raw_preview_ui")
            )
          ),
          
          selectInput("batch_design_dir", "Design file directory", choices = NULL),
          
          tags$details(
            tags$summary(style = guide_summary_style(), "🧬 Preview design file (first pair)"),
            tags$div(style = guide_body_style(), div(
              class = "preview-table", uiOutput("batch_design_preview")
            ))
          ),
        ),
        
        uiOutput("batch_ui")  # rest of UI
      ),
      tabPanel(
        "Aggregate results",
        
        uiOutput("aggregate_gate"),
        
        div(
          id = "aggregate_controls",
          
          h3("Aggregate results"),
          
          hr(),
          
          selectInput("agg_dir", "Analysis run directory", choices = NULL)
        ),
        
        uiOutput("aggregate_ui")
      )
    ),
    
    tags$style(HTML(
      "
          .shiny-progress .modal-dialog {
            max-width: 300px;
          }
        "
    )),
    
    tags$style(HTML("
      details {
        margin-bottom: 16px;
      }
    ")),
    
    tags$style(
      HTML(
        "
          .stage-nav .btn {
            margin-right: 6px;
            min-width: 110px;
          }

          .stage-nav .btn.disabled,
          .stage-nav .btn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
          }
        "
      )
    ),
    
    tags$style(
      HTML(
        "
          .dataTables_wrapper select.form-control {
            border-radius: 4px;
            border: 1px solid #ccc;
          }

          .dataTables_wrapper select.form-control:focus {
            border-color: #66afe9;
            outline: 0;
            box-shadow: inset 0 1px 1px rgba(0,0,0,.075), 0 0 8px rgba(102,175,233,.6);
          }
          .batch-design-select {
            width: 100%;
            padding: 4px 6px;
            font-size: 12px;

            border: 1px solid #ccc;
            border-radius: 4px;

            background-color: #fff;
            color: #333;

            transition: border-color 0.2s, box-shadow 0.2s;
          }

          /* Hover */
          .batch-design-select:hover {
            border-color: #999;
          }

          /* Focus (matches your DT styling) */
          .batch-design-select:focus {
            border-color: #66afe9;
            outline: 0;
            box-shadow:
              inset 0 1px 1px rgba(0,0,0,.075),
              0 0 6px rgba(102,175,233,.6);
          }

          /* Disabled look */
          .batch-design-select:disabled {
            background-color: #f5f5f5;
            color: #999;
            cursor: not-allowed;
          }

          .batch_match_table td {
            padding-top: 6px !important;
            padding-bottom: 6px !important;
          }

          .batch-design-select:focus {
            background-color: #f8fbff;
          }

        "
      )
    ),
    tags$style(
      HTML(
        "
          th span[title] {
            cursor: help;
            text-decoration: underline dotted;
          }
        "
      )
    ),
    tags$style(
      HTML(
        "
         /* =========================================================
            ✅ BATCH LAYOUT (CORE FIX)
         ========================================================= */

        .batch-flex {
          display: flex;
          align-items: stretch;     /* ✅ prevents reflow jumping */
          gap: 24px;
          margin-bottom: 40px;
        }

        .batch-left {
          flex: 1 1 0;
          min-width: 0;             /* ✅ critical for flex stability */
          max-width: 100%;
          overflow: hidden;         /* ✅ prevents expansion spike */
        }

        .batch-right {
          flex: 0 0 480px;          /* ✅ fixed width → no shifting */
          max-width: 480px;
        }

        /* Keep DT contained inside left panel */
        .batch-left .dataTables_wrapper {
          width: 100% !important;
          overflow-x: auto;         /* ✅ scroll instead of expand */
        }

        /* Responsive fallback */
        @media (max-width: 1200px) {
          .batch-flex {
            flex-direction: column;
            align-items: stretch;
          }

          .batch-left {
            min-width: 100%;
            max-width: 100%;
            overflow: visible;   /* ✅ CRITICAL FIX */
          }

          .batch-right {
            max-width: 100%;
            flex: 0 0 auto;
          }
        }

        /* =========================================================
            ✅ DT TABLE BEHAVIOR
         ========================================================= */

        #agg_runs_table table.dataTable {
          table-layout: auto !important;
        }


        /* =========================================================
            ✅ COLUMN STRUCTURE (LOCK WIDTHS FIRST)
         ========================================================= */

        #agg_runs_table th:first-child,
        #agg_runs_table td:first-child {
          width: 60px !important;
          min-width: 60px !important;
          max-width: 60px !important;
          text-align: left !important;
          padding-left: 8px !important;
        }

        #agg_runs_table th:nth-child(2),
        #agg_runs_table td:nth-child(2) {
          width: 300px !important;
          min-width: 300px !important;
          max-width: 300px !important;
        }

        #agg_runs_table th:nth-child(3),
        #agg_runs_table td:nth-child(3) {
          width: 220px !important;
          min-width: 220px !important;
          max-width: 220px !important;
        }


        /* =========================================================
            ✅ CELL CONTENT BEHAVIOR (AFTER WIDTH LOCK)
         ========================================================= */

        /* Checkbox column */
        #agg_runs_table td:first-child {
          cursor: pointer;
          user-select: none;
          font-family: monospace;
        }

        /* Run column */
        #agg_runs_table td:nth-child(2) {
          white-space: nowrap;
        }

        /* Status column */
        #agg_runs_table td:nth-child(3) {
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
          font-family: monospace;
        }


        /* =========================================================
            ✅ SCROLLING + STABILITY
         ========================================================= */

        /* Ensure horizontal scrolling instead of layout shift */
        #agg_runs_table .dataTables_scrollBody {
          overflow-x: auto;
        }

        /* Prevent DT wrapper from expanding parent container */
        #agg_runs_table .dataTables_wrapper {
          max-width: 100% !important;
        }
        "
      )
    ),
    tags$style(
      HTML(
        "
        .guide-container {
          max-width: 900px;
          margin: 0;
          padding: 20px;
        }
        .guide-container pre {
          background: #f6f8fa;
          padding: 12px;
          border-radius: 8px;
          overflow-x: auto;
          font-family: monospace;
          font-size: 13px;
        }
        .guide-container h3 {
          margin-top: 28px;
        }
        #user_guide_ui h3 {
          margin-top: 20px;
        }
        #user_guide_ui hr {
          margin-top: 10px;
          margin-bottom: 15px;
        }
      "
      )
    ),
    tags$style(
      HTML(
        "
        .preview-table table {
          font-size: 12px;
          border-collapse: collapse;
          table-layout: auto;
          white-space: nowrap;
        }
        .preview-table td,
        .preview-table th {
          padding: 4px 6px;
        }
        .preview-table table {
          table-layout: fixed !important;
          width: max-content;
        }

        .preview-table td,
        .preview-table th {
          min-width: 70px;
          max-width: 70px;
          text-align: center;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
        }
        .preview-table table.expanding td,
        .preview-table table.expanding th {
          min-width: 90px;
          max-width: none;
        }
      "
      )
    ),
    tags$style(HTML(
      "
        .preview-table-fixed-rows table tr {
          height: 24px;
        }
      "
    )),
    tags$script(
      HTML(
        "
        Shiny.addCustomMessageHandler('toggle_all_checkboxes', function(value) {
          var checked = (value === 'true');
          document.querySelectorAll('input[id^=\"agg_include_\"]').forEach(function(el) {
            el.checked = checked;
            el.dispatchEvent(new Event('change', { bubbles: true }));
          });
        });
      "
      )
    ),
    tags$script(
      HTML(
        "
        (function() {
          let clicks = 0;
          let timer = null;

          document.addEventListener('DOMContentLoaded', function() {
            const el = document.getElementById('dev_toggle');
            if (!el) return;

            el.addEventListener('click', function() {
              clicks++;

              clearTimeout(timer);
              timer = setTimeout(() => { clicks = 0; }, 1500);

              if (clicks >= 5) {
                Shiny.setInputValue('dev_toggle_clicks', Math.random(), {priority: 'event'});
                clicks = 0;
              }
            });
          });
        })();
      "
      )
    ),
    # ---- App version footer ----
    div(
      id = "dev_toggle",
      style = "
    position: fixed;
    bottom: 6px;
    right: 10px;
    font-size: 11px;
    color: #888;
    z-index: 9999;
    cursor: default;
  ",
      paste0("GrowthCurve v", APP_VERSION)
    )
  )
}))

server <- function(input, output, session) {
  dev_mode <- reactiveVal(DEV_DEFAULT)
  
  if (!isTRUE(getOption("gc.dev_mode"))) {
    sink_null <- function()
      sink("/dev/null")
    
    gc_run_quiet <- function(expr) {
      # capture all output channels
      zz <- file(tempfile(), open = "wt")
      sink(zz)
      sink(zz, type = "message")
      
      result <- withCallingHandlers(
        suppressWarnings(suppressMessages(expr)),
        warning = function(w) {
          invokeRestart("muffleWarning")  # ✅ kills ALL warnings
        },
        message = function(m) {
          invokeRestart("muffleMessage")  # ✅ kills ALL messages
        }
      )
      
      sink(type = "message")
      sink()
      close(zz)
      
      result
    }
    
  } else {
    gc_run_quiet <- function(expr)
      expr
  }
  
  if (!isTRUE(getOption("gc.dev_mode"))) {
    gc_silent <- function(expr) {
      sink(tempfile())
      on.exit(sink(), add = TRUE)
      suppressWarnings(suppressMessages(expr))
    }
    
  } else {
    gc_silent <- function(expr)
      expr
    
  }
  
  # Keep global option in sync (used by gc_log functions)
  observe({
    options(gc.dev_mode = dev_mode())
  })
  
  quiet <- function(expr) {
    if (isTRUE(getOption("gc.dev_mode"))) {
      expr
    } else {
      suppressWarnings(suppressMessages(expr))
    }
  }
  
  `%||%` <- function(a, b)
    if (!is.null(a))
      a
  else
    b
  
  output$startup_error <- renderText({
    if (exists("gc_startup_error", envir = .GlobalEnv)) {
      paste("Startup error:\n", gc_startup_error)
    } else {
      ""
    }
  })
  
  options(
    shiny.error = function(e) {
      gc_silent(gc_log_block(
        "SHINY ERROR",
        list(message = conditionMessage(e), callstack = sys.calls())
      ))
    }
  )
  
  options(
    promises.onRejected = function(e) {
      gc_log_block("GLOBAL PROMISE REJECTION",
                   list(message   = conditionMessage(e), callstack = try(sys.calls(), silent = TRUE)))
      
      NULL
    }
  )
  
  clean_path <- function(path) {
    if (is.null(path) || length(path) != 1 || is.na(path)) {
      return(NA_character_)
    }
    
    path <- trimws(path)
    path <- sub("^[\"']", "", path)
    path <- sub("[\"']$", "", path)
    path.expand(path)
  }
  
  region_selected <- reactiveVal(APP_CONFIG$region)
  wd_set <- reactiveVal(FALSE)
  wd_path <- reactiveVal(NULL)
  file_refresh <- reactiveVal(0)
  batch_pairs <- reactiveVal(NULL)
  batch_failures <- reactiveVal(character(0))
  batch_root <- reactiveVal(NULL)
  batch_pairs_last_valid <- reactiveVal(NULL)
  agg_runs <- reactiveVal(NULL)
  agg_result <- reactiveVal(NULL)
  batch_state <- new.env(parent = emptyenv())
  batch_state$progress_open <- FALSE
  app_locked <- reactiveVal(FALSE)
  batch_abort <- reactiveVal(FALSE)
  interval_hours <- reactive({
    req(!is.null(input$interval_min))
    input$interval_min / 60
  })
  
  if (requireNamespace("future", quietly = TRUE)) {
    future::plan(future::sequential)
  }
  
  design_file_choices <- reactive({
    req(input$batch_design_dir)
    
    sort(basename(list.files(input$batch_design_dir, full.names = TRUE)))
  })
  
  selected_runs <- reactive({
    req(agg_runs())
    
    df <- agg_runs()
    
    keep <- vapply(df$run_name, function(name) {
      safe_name <- gsub("[^a-zA-Z0-9_]", "_", name)
      
      val <- input[[paste0("agg_include_", safe_name)]]
      
      isTRUE(val)
      
    }, logical(1))
    
    df <- df[keep, , drop = FALSE]
    
    if (nrow(df) == 0)
      return(NULL)
    
    df
  })
  
  duplicate_info <- reactive({
    df_selected <- selected_runs()
    
    if (is.null(df_selected) || nrow(df_selected) == 0) {
      return(list(
        run_flags = setNames(logical(0), character(0)),
        duplicate_map = list()
      ))
    }
    
    detect_duplicate_plates(df_selected)
  })
  
  output$wd_ready <- reactive({
    wd_set()
  })
  
  observeEvent(input$dev_toggle_clicks, {
    new_val <- !dev_mode()
    dev_mode(new_val)
    
    showNotification(
      if (new_val)
        "Developer mode enabled"
      else
        "Developer mode disabled",
      type = if (new_val)
        "message"
      else
        "default",
      duration = 2
    )
  })
  
  observe({
    req(input$region_override)
    
    if (input$region_override == "auto") {
      # re-detect default (what you initialized from)
      region_selected(APP_CONFIG$region)
      
    } else {
      region_selected(input$region_override)
      
    }
  })
  
  output$region_detected_txt <- renderText({
    region <- region_selected()
    
    if (region == "EU") {
      "European (semicolon, decimal comma)"
    } else {
      "US (comma, decimal point)"
    }
  })
  
  observe({
    locked <- app_locked()
    
    ids <- c(
      "run_batch",
      "refresh_files",
      "batch_data_dir",
      "batch_design_dir",
      "batch_instrument",
      "batch_blank_mode",
      "batch_interval",
      "batch_hrs",
      "batch_minod",
      "batch_maxod",
      "batch_prefix",
      "batch_parallel"
    )
    
    if (locked) {
      lapply(ids, shinyjs::disable)
    } else {
      lapply(ids, shinyjs::enable)
    }
    
  })
  
  observe({
    if (wd_set()) {
      shinyjs::show("batch_controls")
    } else {
      shinyjs::hide("batch_controls")
    }
    
  })
  
  observe({
    if (wd_set()) {
      shinyjs::show("aggregate_controls")
    } else {
      shinyjs::hide("aggregate_controls")
    }
    
  })
  
  output$batch_gate <- renderUI({
    if (wd_set())
      return(NULL)
    
    tags$div(style = "padding: 20px; background-color: #f8f9fa; border-radius: 6px;",
             h4("Batch processing"),
             p("Please set a working directory to continue."))
    
  })
  
  output$aggregate_gate <- renderUI({
    if (wd_set())
      return(NULL)
    
    tags$div(style = "padding: 20px; background-color: #f8f9fa; border-radius: 6px;",
             h4("Aggregate results"),
             p("Please set a working directory to continue."))
    
  })
  
  outputOptions(output, "wd_ready", suspendWhenHidden = FALSE)
  
  default_blank_mode <- "plate"
  
  # ------------------------------------------------------------
  # Single-plate review state
  # ------------------------------------------------------------
  current_stage <- reactiveVal("not_run")
  
  stage_order <- c(
    "blank_linear",
    "blank_log",
    "mean_curves",
    "perwell_linear",
    "perwell_log",
    "deriv_raw",
    "deriv_percap",
    "fitted_percap",
    "od_with_maxgc",
    "doubling_time",
    "max_growth_rate"
  )
  
  gc_abort_if <- function(condition, message) {
    if (isTRUE(condition)) {
      gc_abort(message)
    }
  }
  
  update_blank_mode_state <- function(session,
                                      instrument,
                                      current_blank_mode) {
    if (instrument == "ocelloscope") {
      if (!is.null(current_blank_mode) && current_blank_mode != "plate") {
        updateRadioButtons(session, "blank_mode", selected = "plate")
      }
      
      shinyjs::disable("blank_mode_container")
      
    } else {
      shinyjs::enable("blank_mode_container")
      
    }
  }
  
  format_preview_df <- function(df, region) {
    if (is.null(df) || !is.data.frame(df))
      return(df)
    
    df[] <- lapply(df, function(col) {
      # Try numeric conversion
      num <- suppressWarnings(as.numeric(col))
      
      # If conversion fails → leave column as-is
      if (all(is.na(num))) {
        return(ifelse(is.na(col), "", col))
      }
      
      # Format WITHOUT padding
      formatted <- ifelse(is.na(num), "", as.character(signif(num, digits = 6)))
      
      # Replace decimal separator if EU
      if (region == "EU") {
        formatted <- gsub("\\.", ",", formatted)
      }
      
      # Replace NA values explicitly
      formatted[is.na(num)] <- ""
      
      formatted
    })
    
    df
  }
  
  unwrap_preview <- function(res) {
    if (is.null(res))
      return(NULL)
    
    # ✅ NEW: detect backend preview_message
    if (inherits(res, "preview_message")) {
      return(list(type = "message", message = res$message))
    }
    
    # Case 1: already a data.frame
    if (is.data.frame(res)) {
      return(list(type = "data", data = res))
    }
    
    # Case 2: structured return (future-proof)
    if (is.list(res) && !is.null(res$type)) {
      return(res)
    }
    
    # Fallback
    list(type = "unknown",
         data = NULL,
         message = NULL)
  }
  
  is_preview_message <- function(x) {
    is.list(x) && identical(x$type, "message")
  }
  
  apply_instrument_defaults <- function(session, prefix, instrument) {
    defaults <- gc_instrument_defaults[[instrument]]
    
    if (is.null(defaults))
      return()
    
    # Build input IDs dynamically
    interval_id <- if (nzchar(prefix))
      paste0(prefix, "_interval")
    else
      "interval_min"
    minod_id    <- if (nzchar(prefix))
      paste0(prefix, "_minod")
    else
      "minod"
    maxod_id    <- if (nzchar(prefix))
      paste0(prefix, "_maxod")
    else
      "maxod"
    
    updateNumericInput(session, interval_id, value = defaults$interval)
    updateNumericInput(session, minod_id, value = defaults$minod)
    updateNumericInput(session, maxod_id, value = defaults$maxod)
  }
  
  make_export_dirs <- function(wd, prefix) {
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    
    tag <- if (nzchar(prefix)) {
      paste0(timestamp, "_", prefix, "_single")
    } else {
      paste0(timestamp, "_single")
    }
    
    analysis_dir <- file.path(wd, "Analysis", tag)
    
    list(
      analysis_dir = analysis_dir,
      plots_dir    = file.path(analysis_dir, "Plots"),
      summary_dir  = file.path(analysis_dir, "Summaries")
    )
  }
  
  advance_stage <- function() {
    idx <- match(current_stage(), stage_order)
    if (!is.na(idx) && idx < length(stage_order)) {
      current_stage(stage_order[idx + 1])
    }
  }
  
  retreat_stage <- function() {
    idx <- match(current_stage(), stage_order)
    if (!is.na(idx) && idx > 1) {
      current_stage(stage_order[idx - 1])
    }
  }
  
  format_runtime <- function(sec) {
    hrs  <- floor(sec / 3600)
    mins <- floor((sec %% 3600) / 60)
    secs <- round(sec %% 60)
    
    if (hrs > 0) {
      sprintf("%dh %dm %ds", hrs, mins, secs)
    } else if (mins > 0) {
      sprintf("%dm %ds", mins, secs)
    } else {
      sprintf("%ds", secs)
    }
  }
  
  finish_batch <- function(completed_val,
                           n,
                           root_path,
                           batch_start_time,
                           progress,
                           old_plan,
                           failures,
                           all_failed) {
    shiny::withReactiveDomain(session, {
      # --- Close progress ---
      if (isTRUE(batch_state$progress_open)) {
        progress$close()
        batch_state$progress_open <- FALSE
      }
      
      # --- Re-enable UI ---
      app_locked(FALSE)
      
      # --- Runtime calculation ---
      elapsed_sec <- as.numeric(difftime(Sys.time(), batch_start_time, units = "secs"))
      elapsed_str <- format_runtime(elapsed_sec)
      
      # ✅ --- Build failure UI OUTSIDE modal ---
      failure_ui <- if (length(failures) == 0) {
        p("All plates were processed successfully.")
        
      } else {
        tagList(p("Batch completed with some failures."),
                p(strong("Failed plates:")),
                tags$ul(lapply(failures, function(x) {
                  tags$li(tags$code(x))
                })))
      }
      
      pretty_path <- tryCatch(
        pretty_export_path(root_path),
        error = function(e)
          root_path
      )
      
      showModal(
        modalDialog(
          title = "Batch analysis complete",
          
          tagList(
            failure_ui,
            
            tags$hr(),
            
            p(paste("Total runtime:", elapsed_str)),
            
            if (!all_failed && dir.exists(root_path))
              tagList(
                p("Results were written to:"),
                tags$div(
                  style = "margin-top: 6px;",
                  tags$code(style = "color: #1f78b4; font-size: 0.95em;", pretty_path)
                )
              )
          ),
          
          easyClose = TRUE,
          
          footer = tagList(if (!all_failed &&
                               dir.exists(root_path)) {
            actionButton("open_batch_dir", "📂 Open output folder", class = "btn-primary")
          }, modalButton("Close"))
        )
      )
      
      # --- Restore future plan ---
      if (!is.null(old_plan) &&
          requireNamespace("future", quietly = TRUE)) {
        future::plan(old_plan)
      }
      
    })
  }
  
  observeEvent(input$open_batch_dir, {
    req(batch_root())
    
    success <- open_folder(batch_root())
    
    if (!isTRUE(success)) {
      showNotification("Could not open folder automatically. Please open it manually.",
                       type = "warning")
    }
  })
  
  observeEvent(input$open_agg_dir, {
    req(input$agg_dir)
    
    success <- open_folder(input$agg_dir)
    
    if (!isTRUE(success)) {
      showNotification("Could not open folder automatically. Please open it manually.",
                       type = "warning")
    }
  })
  
  qc_blank_note <- function(res) {
    if (res$blank_mode == "plate") {
      "Blank correction was applied using early-timepoint plate blanks."
    } else if (res$blank_mode == "per_well") {
      "Each well was internally baseline-corrected using its earliest timepoint."
    } else {
      "No blank correction was applied."
    }
  }
  
  combine_tidy_files <- function(run_df) {
    all_files <- unlist(lapply(run_df$full_path, function(dir) {
      list.files(
        path       = dir,
        pattern    = "plate_tidy\\.csv$",
        recursive  = TRUE,
        full.names = TRUE
      )
    }))
    
    if (length(all_files) == 0) {
      return(NULL)
    }
    
    data_list <- lapply(all_files, function(f) {
      df <- tryCatch(
        read_csv_safe(f),
        error = function(e)
          NULL
      )
      if (is.null(df))
        return(NULL)
      
      # ✅ FIX: normalize column types BEFORE anything else
      df[] <- lapply(df, as.character)
      
      # ✅ EXISTING metadata
      df$source_file <- basename(f)
      df$run_name    <- basename(dirname(dirname(f)))
      
      df
    })
    
    data_list <- Filter(Negate(is.null), data_list)
    
    if (length(data_list) == 0) {
      return(NULL)
    }
    
    dplyr::bind_rows(data_list, .id = "file_index")
  }
  
  detect_duplicate_runs <- function(run_df) {
    fingerprints <- sapply(run_df$full_path, function(dir) {
      files <- list.files(
        path       = dir,
        pattern    = "plate_tidy\\.csv$",
        recursive  = TRUE,
        full.names = TRUE
      )
      
      if (length(files) == 0)
        return(NA_character_)
      
      info <- file.info(files)
      
      # Simple fingerprint: filenames + sizes
      paste(paste(basename(files), collapse = "|"),
            paste(info$size, collapse = "|"),
            sep = "::")
    })
    
    dup <- duplicated(fingerprints) |
      duplicated(fingerprints, fromLast = TRUE)
    
    dup[is.na(fingerprints)] <- FALSE
    
    dup
  }
  
  detect_duplicate_plates <- function(run_df) {
    if (is.null(run_df) ||
        !is.data.frame(run_df) || nrow(run_df) == 0) {
      return(list(
        run_flags = setNames(logical(0), character(0)),
        duplicate_map = list()
      ))
    }
    
    plate_records <- data.frame()
    
    # ---- Collect all plates across all runs ----
    n <- nrow(run_df)
    if (is.null(n) || n == 0) {
      return(list(
        run_flags = setNames(logical(0), character(0)),
        duplicate_map = list()
      ))
    }
    
    for (i in seq_len(n)) {
      run_name <- run_df$run_name[i]
      run_dir  <- run_df$full_path[i]
      
      files <- list.files(
        path       = run_dir,
        pattern    = "plate_tidy\\.csv$",
        recursive  = TRUE,
        full.names = TRUE
      )
      
      if (length(files) == 0)
        next
      
      info <- file.info(files)
      
      plate_folder <- basename(dirname(dirname(files)))
      
      tmp <- data.frame(
        run_name     = run_name,
        plate_file   = basename(files),
        plate_folder = plate_folder,
        size         = info$size,
        stringsAsFactors = FALSE
      )
      
      tmp$label <- paste(tmp$run_name, ">", tmp$plate_folder)
      
      tmp$group_key <- sub(" - Copy$", "", tmp$plate_folder)
      
      # Fingerprint = filename + size
      tmp$fingerprint <- paste(tmp$plate_file, tmp$size, sep = "::")
      
      plate_records <- rbind(plate_records, tmp)
    }
    
    if (nrow(plate_records) == 0) {
      return(list(
        run_flags = setNames(rep(FALSE, nrow(run_df)), run_df$run_name),
        duplicate_plates = character(0)
      ))
    }
    
    # ---- Detect duplicated plates ----
    dup_idx <-
      duplicated(plate_records$fingerprint) |
      duplicated(plate_records$fingerprint, fromLast = TRUE)
    
    plate_records$duplicate_plate <- dup_idx
    
    # ---- Build duplicate map: plate -> (run > plate folder) ----
    duplicate_map <- split(plate_records$label[dup_idx], plate_records$group_key[dup_idx])
    
    # Keep only true duplicates (appear in >1 place)
    duplicate_map <- duplicate_map[sapply(duplicate_map, length) > 1]
    
    duplicate_map <- lapply(duplicate_map, unique)
    
    # Optional: clean plate names (remove .csv)
    names(duplicate_map) <- tools::file_path_sans_ext(names(duplicate_map))
    
    # ---- Map back to runs ----
    run_flags <- tapply(plate_records$duplicate_plate,
                        plate_records$run_name,
                        any)
    
    run_flags[is.na(run_flags)] <- FALSE
    run_flags <- run_flags[run_df$run_name]
    run_flags[is.na(run_flags)] <- FALSE
    
    list(run_flags = run_flags, duplicate_map = duplicate_map)
  }
  
  design_example <- reactive({
    path <- system.file(
      "app/preview_files",
      "plate_design_for_preview.csv",
      package = "growthcurve"
    )
    
    # fallback for development
    if (path == "") {
      path <- file.path("preview_files", "plate_design_for_preview.csv")
    }
    
    if (!file.exists(path))
      return(NULL)
    
    read_preview_file(path, nrows = 30)
  })
  
  output$design_example_table <- renderTable({
    df <- design_example()
    req(df)
    
    df
    
  }, striped = TRUE, bordered = TRUE, spacing = "xs", colnames = FALSE, na = "")
  
  validated_batch_pairs <- reactive({
    req(batch_pairs())
    
    df <- batch_pairs()
    
    n <- nrow(df)
    
    inferred_vars <- vector("list", n)
    design_ok     <- logical(n)
    
    for (i in seq_len(n)) {
      dfile <- df$design_file[i]
      
      if (is.na(dfile) || dfile == "" || !file.exists(dfile)) {
        inferred_vars[[i]] <- character(0)
        design_ok[i] <- FALSE
        next
      }
      
      vars <- tryCatch(
        extract_design_blocks(dfile),
        error = function(e)
          character(0)
      )
      
      inferred_vars[[i]] <- vars
      design_ok[i] <- length(vars) > 0
    }
    
    # ---- Status logic ----
    status <- character(n)
    
    missing_data   <- is.na(df$data_file)   | df$data_file == ""
    missing_design <- is.na(df$design_file) | df$design_file == ""
    
    status[missing_data | missing_design] <- "❌ unmatched"
    status[!missing_design & !design_ok]  <- "❌ invalid design"
    
    dup_design <- duplicated(df$design_file) & !missing_design
    dup_design <- dup_design |
      duplicated(df$design_file, fromLast = TRUE)
    status[dup_design] <- "⚠️ duplicate design"
    
    status[status == ""] <- "✅ matched"
    
    result_df <- data.frame(
      data_file        = df$data_file,
      design_file      = df$design_file,
      data_file_name   = basename(df$data_file),
      design_file_name = basename(df$design_file),
      design_vars      = vapply(inferred_vars, function(x)
        paste(x, collapse = ", "), character(1)),
      status = status,
      stringsAsFactors = FALSE
    )
    
    # ✅ DEBUG (safe: no side effects)
    gc_silent(gc_log_block("VALIDATED BATCH PAIRS", result_df))
    
    result_df
  })
  
  validated_pairs_cached <- bindCache(reactive({
    validated_batch_pairs()
  }), batch_pairs())
  
  batch_can_parallel <- function() {
    cores <- parallel::detectCores(logical = TRUE)
    ! is.na(cores) && cores > 1
  }
  
  analysis_result <- reactiveVal(NULL)
  
  last_export_dir <- reactiveVal(NULL)
  
  observeEvent(input$install_no, {
    stopApp()
  })
  
  observeEvent(input$close_app_after_failed_install, {
    stopApp()
  })
  
  observeEvent(input$install_yes, {
    removeModal()
    
    pkgs_before <- gc_check_packages()
    missing <- c(pkgs_before$missing, pkgs_before$broken)
    
    tryCatch({
      install.packages(missing)
      
      # ✅ Re-check after installation attempt
      pkgs_after <- gc_check_packages()
      still_missing <- c(pkgs_after$missing, pkgs_after$broken)
      
      if (length(still_missing) == 0) {
        # ✅ SUCCESS
        showModal(
          modalDialog(
            title = "Installation complete",
            
            tagList(
              p(
                "All required packages have been installed successfully."
              ),
              p(
                "The application will now close. Please restart it to continue."
              )
            ),
            
            footer = tagList(actionButton(
              "close_app_after_install", "Close app"
            )),
            
            easyClose = FALSE
          )
        )
        
      } else {
        # ✅ FAILURE
        showModal(
          modalDialog(
            title = "Installation incomplete",
            
            tagList(
              p("Some packages could not be installed."),
              p("The following are still missing:"),
              tags$ul(lapply(still_missing, tags$li)),
              
              p("This is usually due to:"),
              tags$ul(
                tags$li("No internet connection"),
                tags$li("CRAN mirror not reachable"),
                tags$li("Restricted permissions")
              ),
              
              p(
                "The application cannot continue without these packages."
              )
            ),
            
            footer = tagList(
              actionButton("close_app_after_failed_install", "Close app", class = "btn-danger")
            ),
            
            easyClose = FALSE
          )
        )
      }
      
    }, error = function(e) {
      showModal(
        modalDialog(
          title = "Installation failed",
          
          tagList(
            p("We couldn't install the required packages."),
            p(paste(
              "Technical error:", gc_get_message(e)
            )),
            p("Please check your internet connection and try again."),
            p("The application cannot continue.")
          ),
          
          footer = tagList(
            actionButton("close_app_after_failed_install", "Close app", class = "btn-danger")
          ),
          
          easyClose = FALSE
        )
      )
    })
  })
  
  observeEvent(input$close_app_after_install, {
    stopApp()
  })
  
  observeEvent(input$set_wd, {
    req(nzchar(input$wd))
    
    cleaned_path <- clean_path(input$wd)
    
    if (!dir.exists(cleaned_path)) {
      showModal(modalDialog(
        title = "Invalid directory",
        p("The specified directory does not exist."),
        p("Please check the path and try again."),
        easyClose = TRUE
      ))
      return(NULL)
    }
    
    wd_path(normalizePath(cleaned_path, mustWork = FALSE))
    wd_set(TRUE)
    file_refresh(file_refresh() + 1)
    
    output$wd_txt <- renderText({
      paste("Working directory:", wd_path())
    })
  })
  
  observeEvent(input$refresh_files, {
    file_refresh(file_refresh() + 1)
  })
  
  session$onFlushed(function() {
    pkgs <- gc_check_packages()
    missing <- c(pkgs$missing, pkgs$broken)
    
    if (length(missing) > 0) {
      showModal(
        modalDialog(
          title = "Missing required packages",
          
          tagList(
            p(
              "The following packages are required but are not properly installed:"
            ),
            tags$ul(lapply(missing, tags$li)),
            p("Would you like to install them now?")
          ),
          
          footer = tagList(
            actionButton("install_yes", "Yes"),
            actionButton("install_no", "No")
          ),
          easyClose = FALSE
        )
      )
    }
  }, once = TRUE)
  
  observe({
    if (is.null(analysis_result()) ||
        current_stage() == stage_order[1]) {
      shinyjs::disable("prev_stage")
    } else {
      shinyjs::enable("prev_stage")
    }
  })
  
  observe({
    req(input$next_stage)
    req(current_stage())
    
    if (current_stage() == tail(stage_order, 1)) {
      shinyjs::disable("next_stage")
      updateActionButton(session, "next_stage", label = "Final stage")
    } else {
      shinyjs::enable("next_stage")
      updateActionButton(session, "next_stage", label = "Continue →")
    }
  })
  
  observe({
    if (!is.null(analysis_result())) {
      shinyjs::enable("export_files")
    } else {
      shinyjs::disable("export_files")
    }
  })
  
  observe({
    if (!is.null(analysis_result())) {
      shinyjs::enable("reset_analysis")
    } else {
      shinyjs::disable("reset_analysis")
    }
  })
  
  observe({
    # ✅ FIRST: handle directory readiness (no req yet)
    dir_ready <-
      !is.null(input$batch_data_dir) &&
      nzchar(input$batch_data_dir) &&
      !is.null(input$batch_design_dir) &&
      nzchar(input$batch_design_dir)
    
    # ✅ If directories not ready → always disable
    if (!dir_ready) {
      shinyjs::disable("run_batch")
      return()
    }
    
    # ✅ ONLY now require the pairs
    req(batch_pairs())
    
    df <- validated_pairs_cached()
    
    ok <- nrow(df) > 0 &&
      all(df$status == "✅ matched")
    
    if (ok) {
      shinyjs::enable("run_batch")
    } else {
      shinyjs::disable("run_batch")
    }
  })
  
  observeEvent(list(wd_set(), file_refresh()), {
    req(wd_set(), wd_path())
    
    dirs <- list.dirs(path       = wd_path(),
                      recursive  = FALSE,
                      full.names = TRUE)
    
    names(dirs) <- basename(dirs)
    
    current_data   <- isolate(input$batch_data_dir)
    current_design <- isolate(input$batch_design_dir)
    
    updateSelectInput(
      session,
      "batch_data_dir",
      choices  = dirs,
      selected = if (!is.null(current_data) &&
                     current_data %in% dirs)
        current_data
      else
        character(0)
    )
    
    updateSelectInput(
      session,
      "batch_design_dir",
      choices  = dirs,
      selected = if (!is.null(current_design) &&
                     current_design %in% dirs)
        current_design
      else
        character(0)
    )
    
  }, ignoreInit = TRUE)
  
  observeEvent(list(wd_set(), file_refresh()), {
    req(wd_set(), wd_path())
    
    dirs <- list.dirs(path       = wd_path(),
                      recursive  = FALSE,
                      full.names = TRUE)
    
    names(dirs) <- basename(dirs)
    
    # ✅ Preserve current selection
    current <- isolate(input$agg_dir)
    
    updateSelectInput(
      session,
      "agg_dir",
      choices  = dirs,
      selected = if (!is.null(current) &&
                     current %in% dirs)
        current
      else
        character(0)
    )
    
  }, ignoreInit = TRUE)
  
  observeEvent(input$agg_select_all, {
    req(agg_runs())
    
    value <- if (isTRUE(input$agg_select_all))
      "true"
    else
      "false"
    
    session$sendCustomMessage("toggle_all_checkboxes", value)
  })
  
  output$blank_info <- renderText({
    res <- analysis_result()
    validate(need(!is.null(res), ""))
    
    bm <- res$blank_mode %||% "none"
    
    if (bm == "plate") {
      paste(
        "Blank correction: plate‑based blanks.",
        "\nMedian t₀ blank OD =",
        signif(analysis_result()$blankmed, 4)
      )
    } else if (bm == "per_well") {
      "Blank correction: per‑well internal baseline (t₀ subtraction)."
    } else {
      "Blank correction: none."
    }
  })
  
  wd_files <- reactive({
    req(wd_set(), wd_path())
    file_refresh()
    
    list.files(
      path       = wd_path(),
      pattern    = "\\.csv$",
      ignore.case = TRUE,
      full.names = FALSE
    )
  })
  
  output$user_guide_ui <- renderUI({
    tagList(
      h3("User guide"),
      
      tags$p(
        style = "color: #666; margin-bottom: 12px;",
        "Guidance on data preparation, file structure, and common pitfalls."
      ),
      
      tags$p(
        style = "font-style: italic; color: #555;",
        "New to this app? Start with a single plate before running batch analysis."
      ),
      
      tags$div(
        style = "
    padding: 12px;
    background-color: #f8f9fa;
    border: 1px solid #e0e0e0;
    border-left: 4px solid #4a90e2;
    border-radius: 6px;
    margin-bottom: 15px;
  ",
        
        h4("Getting started"),
        
        tags$ol(
          tags$li("Set your working directory."),
          tags$li("Choose an analysis mode (Single plate or Batch)."),
          tags$li("Select your raw data and matching design file(s)."),
          tags$li("Run the analysis and review outputs.")
        ),
        
        tags$p(
          style = guide_note_style(),
          "Tip: Most issues arise from mismatched data and design files."
        )
      ),
      
      hr(),
      
      # =========================================================
      # ⚙️ INPUT PARAMETERS
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), "⚙️ Analysis parameters (what do these mean?)"),
        tags$div(
          style = guide_body_style(),
          
          tags$p(
            "These parameters control how the growth curves are analyzed. ",
            "Most can be left at their default values, but it is important ",
            "to understand how they influence the results."
          ),
          
          tags$p(
            style = guide_note_style(),
            "Default parameter values are automatically set based on the selected instrument (e.g., plate reader or oCelloscope). You can modify these values at any time."
          ),
          
          tags$hr(),
          
          # -----------------------------------------------------
          # Instrument selection
          # -----------------------------------------------------
          
          h4("Instrument selection"),
          
          tags$p("Select the instrument used to generate the growth curve data."),
          
          tags$ul(
            tags$li("Determines how the input file is parsed."),
            tags$li(
              "Automatically sets appropriate default values for interval and OD thresholds."
            ),
            tags$li("Controls whether blank correction is applied.")
          ),
          
          tags$p(
            style = guide_note_style(),
            "Plate reader and oCelloscope data have different formats and preprocessing requirements, so selecting the correct instrument is essential."
          ),
          
          tags$hr(),
          
          # -----------------------------------------------------
          # Duration
          # -----------------------------------------------------
          h4("Duration (hours)"),
          tags$p(
            "Specifies the total length of the experiment to include in the analysis."
          ),
          tags$ul(
            tags$li("Only data within this time window are used."),
            tags$li(
              "Should match (or slightly exceed) your experimental runtime."
            )
          ),
          
          tags$hr(),
          
          # -----------------------------------------------------
          # Interval
          # -----------------------------------------------------
          h4("Interval (minutes)"),
          tags$p("Time between consecutive measurements."),
          tags$ul(
            tags$li("Used to correctly reconstruct the time axis."),
            tags$li("Must match the acquisition interval of your instrument."),
            tags$li("Incorrect values will distort growth rates and timing.")
          ),
          
          tags$hr(),
          
          # -----------------------------------------------------
          # Min OD
          # -----------------------------------------------------
          h4("Min OD (lower threshold)"),
          
          tags$p(
            strong("This is a critical parameter."),
            " It defines the lower bound of optical density values used ",
            "for growth rate estimation."
          ),
          
          tags$ul(
            tags$li(
              "Values below this threshold are ignored when calculating growth rates."
            ),
            tags$li("Helps exclude noise and baseline fluctuations at very low OD."),
            tags$li("Prevents false growth-rate estimates during lag phase.")
          ),
          
          tags$p(
            style = "color: #b22222;",
            strong("If set too low:"),
            " growth rates may be dominated by noise."
          ),
          
          tags$p(
            style = "color: #b22222;",
            strong("If set too high:"),
            " early exponential growth may be missed."
          ),
          
          tags$p(
            style = guide_note_style(),
            "Typical values are around 0.03–0.08 for plate reader data, and ~0.01 for oCelloscope data due to lower baseline noise."
          ),
          
          tags$hr(),
          
          # -----------------------------------------------------
          # Max OD
          # -----------------------------------------------------
          h4("Max OD (upper threshold)"),
          
          tags$p(
            strong("This is a critical parameter."),
            " It defines the upper bound of optical density values used ",
            "for growth rate estimation."
          ),
          
          tags$ul(
            tags$li(
              "Values above this threshold are excluded from growth-rate calculations."
            ),
            tags$li("Removes saturated or non-exponential growth phases.")
          ),
          
          tags$hr(),
          
          # -----------------------------------------------------
          # Output prefix
          # -----------------------------------------------------
          
          h4("Output prefix"),
          
          tags$p("An optional label added to the name of the output folder."),
          
          tags$ul(
            tags$li("Does not affect the analysis itself."),
            tags$li("Helps you distinguish between multiple runs."),
            tags$li("Useful when testing different parameter settings.")
          ),
          
          tags$p("If provided, output folders will be named like:"),
          
          tags$pre(
            "yyyymmdd_hhmmss_myexperiment_single\nyyyymmdd_hhmmss_myexperiment_batch"
          ),
          
          tags$p(
            style = guide_note_style(),
            "If left empty, only a timestamp and single/batch label will be used."
          ),
          
          tags$hr(),
          
          # -----------------------------------------------------
          # Design variables
          # -----------------------------------------------------
          
          h4("Design variables"),
          
          tags$p(
            "Design variables describe the experimental layout of the plate (e.g., strain, treatment, replicate)."
          ),
          
          tags$ul(
            tags$li(
              "These are automatically extracted from the selected design file."
            ),
            tags$li("Each variable corresponds to a block in the design file."),
            tags$li(
              "All detected variables are included in the analysis by default."
            ),
            tags$li(
              "They are used to group wells when calculating summary statistics."
            )
          ),
          
          tags$p(
            style = guide_note_style(),
            "You do not need to configure these manually. If variables are missing or incorrect, check the structure of the design file."
          ),
          
          # -----------------------------------------------------
          # Blank correction
          # -----------------------------------------------------
          
          tags$hr(),
          
          h4("Blank correction"),
          
          tags$p(
            "Controls how baseline optical density values are handled before growth-rate calculations."
          ),
          
          tags$ul(
            tags$li(
              strong("Plate-based blanks:"),
              " uses designated blank wells to estimate and subtract background signal from all wells."
            ),
            tags$li(
              strong("Per-well baseline:"),
              " subtracts the first recorded value from each well individually."
            )
          ),
          
          tags$p(
            style = guide_note_style(),
            "For oCelloscope data, blank correction is not applied because values are already normalized during acquisition."
          ),
          
        ),
        
      ),
      
      
      # =========================================================
      # 📄 RAW DATA — PLATE READER
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), "📄 Raw data (Plate reader)"),
        tags$div(
          style = guide_body_style(),
          
          p(strong(
            "Important: file preparation step required"
          )),
          
          p(
            "Plate reader output files must be re-saved to ensure a consistent CSV format."
          ),
          
          tags$ol(
            tags$li("Open the CSV file in Excel"),
            tags$li("If prompted, import it as a comma-separated table"),
            tags$li("Use File → Save As and save it again as a CSV file")
          ),
          
          tags$p(
            style = guide_note_style(),
            "This does not change your data. It ensures correct delimiter and encoding."
          ),
          
          tags$hr(),
          
          p("Expected structure:"),
          
          tags$ul(
            tags$li("96-well plate layout (rows A–H, columns 1–12)"),
            tags$li("May contain multiple reads (kinetic measurements)"),
            tags$li(
              "Includes header/metadata rows (these are handled automatically)"
            )
          ),
          
          tags$p(
            style = guide_note_style(),
            "No manual reformatting is required beyond re-saving the file in Excel."
          ),
          
          tags$hr(),
          
          p("Example data format snippet:"),
          
          tags$pre(
            "      1     2     3     ...\n
A   0.09  0.09  0.09\n
B   0.09  0.09  0.09\n
C   0.09  0.09  0.09\n
...\n"
          )
        )
      ),
      
      # =========================================================
      # 🔬 RAW DATA — OCELLOSCOPE
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), "🔬 Raw data (oCelloscope)"),
        tags$div(
          style = guide_body_style(),
          
          p(strong(
            "Important: file preparation step required"
          )),
          
          p(
            "oCelloscope data must be exported as an Excel (.xlsx) file and then converted to CSV format."
          ),
          
          tags$ol(
            tags$li("Open the .xlsx file exported from UniExplorer in Excel"),
            tags$li("Use File → Save As and save it as a CSV file"),
            tags$li(
              "When prompted that CSV files can only contain a single sheet, click ",
              tags$strong("OK"),
              " to continue"
            )
          ),
          
          tags$p(
            style = "color: #b22222; font-weight: 600;",
            "Important: Do not use CSV files exported directly from UniExplorer. They are not compatible with this analysis."
          ),
          
          tags$hr(),
          
          p(strong("TANormalized data required")),
          
          tags$ul(
            tags$li("The analysis only works with TANormalized values"),
            tags$li(
              "Ensure TANormalized measurements were collected during the experiment"
            ),
            tags$li(
              "Ensure TANormalized is included when exporting from UniExplorer"
            )
          ),
          
          
          tags$p(
            style = "color: #b22222; font-weight: 600;",
            "Only TANormalized data are supported. Other measurement types will not work."
          )
          ,
          
          tags$hr(),
          
          p("Expected structure:"),
          
          tags$ul(
            tags$li("File contains one or more data blocks with repeated headers"),
            tags$li(
              "Includes a TANormalized section containing growth measurements"
            ),
            tags$li("Each block contains time and well measurements")
          ),
          
          tags$p(
            style = guide_note_style(),
            "The app automatically extracts the correct TANormalized block and formats it for analysis."
          )
        )
      ),
      
      # =========================================================
      # 🧬 DESIGN FILE
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), "🧬 Design file format"),
        tags$div(
          style = guide_body_style(),
          
          h4("Concept"),
          
          tags$p(
            "The design file describes what each well in your plate contains ",
            "(e.g., strain, treatment, replicate). It is used to group wells and calculate summary statistics."
          ),
          
          tags$p(
            "It is structured as multiple full plate layouts stacked on top of each other, ",
            "where each block defines a single variable."
          ),
          
          tags$p(
            style = guide_note_style(),
            "Think of it as a stack of identical 96‑well plates, each labeling a different attribute."
          ),
          
          hr(),
          
          h4("Structure rules"),
          
          tags$ul(
            tags$li("Each variable is one block (e.g., Strain, Treatment)."),
            tags$li("Each block must be a complete 96‑well layout (A–H, 1–12)."),
            tags$li("The top-left cell of each block contains the variable name."),
            tags$li(
              "Each block must contain one header row followed by eight rows (A–H)."
            ),
            tags$li("All blocks must have identical dimensions and alignment."),
            tags$li("Each block must be separated by one completely empty row."),
            tags$li(
              "The 'Well_type' variable must always be included as the first block."
            ),
            tags$li(
              "Blank wells are identified exclusively through the Well_type block. In other variable blocks, these wells can be left empty without affecting the analysis."
            ),
            tags$li("Cells representing unused wells must be left empty")
          ),
          
          tags$p(
            style = "color: #b22222; font-weight: 600;",
            "Each block must begin with the variable name in the top-left cell (e.g., 'Strain')."
          ),
          
          tags$p(
            style = "color: #b22222; font-weight: 600;",
            "Empty wells must remain completely blank and must not contain any text values."
          ),
          
          tags$p(
            style = "color: #b22222; font-weight: 600;",
            "Important: If blocks are misaligned or incomplete, the analysis will fail."
          ),
          
          hr(),
          
          h4("Visual layout"),
          
          tags$p("Example of two variables (Strain and Treatment):"),
          
          tags$pre(
            "Strain   1   2   3   ...
A        WT  WT  KO
B        WT  KO  KO
...

[empty row required]

Treatment   1   2   3   ...
A           0   1   1
B           0   0   1
..."
          ),
          
          tags$p(
            style = guide_note_style(),
            "Every position (e.g., B3) must correspond across all blocks."
          ),
          
          tags$p(
            style = guide_note_style(),
            "The example and preview use different plate layouts and values. Only the structure (block format and alignment) must match — the contents will depend on your experiment."
          ),
          
          hr(),
          
          div(class = "preview-table-fixed-rows", tableOutput("design_example_table")),
          
          tags$p(
            style = guide_note_style(),
            "This preview shows how blocks are stacked and aligned."
          )
        )
      ),
      
      # =========================================================
      # 📥 TEMPLATES
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), "📥 Download templates"),
        tags$div(
          style = guide_body_style(),
          
          p(
            "Templates provide a ready‑to‑use design file with the correct structure."
          ),
          
          tags$ul(
            tags$li("Each block represents one variable."),
            tags$li(
              "Replace the template cells with your own experimental design."
            ),
            tags$li(
              "Cells can contain any identifiers (e.g., strain, treatment, replicate, or plate ID)."
            ),
            tags$li(
              "To add a variable, copy a full block, paste it below, and rename it."
            ),
            tags$li(
              'Blank wells only need to be defined in the Well_type block; other blocks can leave these cells empty.'
            )
          ),
          
          tags$p(
            style = "color: #b22222; font-weight: 600;",
            "Do not insert, delete, or shift cells inside a block. Only replace the values."
          ),
          
          tags$p(
            style = "color: #b22222; font-weight: 600;",
            "Remove any unused blocks from the template before running the analysis."
          ),
          
          tags$p(
            style = "color: #1f78b4;",
            "The template files include instructions to the right of the blocks. They will not interfere with analysis."
          ),
          
          tags$p(
            style = guide_note_style(),
            "Minimum requirement: one experimental variable (in addition to Well_type) is enough to run an analysis."
          ),
          
          tags$p(
            style = guide_note_style(),
            "Tip: Start by editing the template rather than creating a file from scratch."
          ),
          
          hr(),
          
          tags$p(
            style = guide_note_style(),
            "Download the template matching your regional CSV format."
          ),
          
          fluidRow(column(
            6,
            downloadButton("download_template_us", "US format (comma)")
          ), column(
            6,
            downloadButton("download_template_eu", "European format (semicolon)")
          ))
        )
      ),
      
      # =========================================================
      # 📁 BATCH STRUCTURE
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), "📁 Batch processing structure"),
        tags$div(
          style = guide_body_style(),
          
          tags$pre(
            "my_experiment/
├── data/
│   ├── plate1.csv
│   ├── plate2.csv
└── design/
    ├── plate1_design.csv
    ├── plate2_design.csv"
          ),
          
          tags$ul(
            tags$li("Each data file must match one design file"),
            tags$li(
              "Matching is based on shared identifiers in filenames (not order)"
            ),
            tags$li("Order does not matter")
          )
        )
      ),
      
      # =========================================================
      # 📊 AGGREGATE MODE
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), "📊 Aggregate results"),
        tags$div(
          style = guide_body_style(),
          
          tags$pre("Analysis/
├── run_1/
├── run_2/"),
          
          p("Each subfolder is treated as a separate run.")
        )
      ),
      
      # =========================================================
      # ⚠️ COMMON ISSUES
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), "⚠️ Common issues"),
        tags$div(style = guide_body_style(), tags$ul(
          tags$li("Selecting a design file that does not match the raw data"),
          tags$li("Design blocks with inconsistent dimensions or missing rows"),
        ))
      ),
      
      # =========================================================
      # ⚠️ What happens if something goes wrong?
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), "🛠️ Troubleshooting"),
        tags$div(
          style = guide_body_style(),
          
          tags$ol(
            tags$li("Check that your data and design files match."),
            tags$li("Ensure CSV files were re-saved from Excel."),
            tags$li("Verify that all design blocks are complete."),
            tags$li("Try running a single plate before batch mode.")
          ),
          
          tags$p(
            style = guide_note_style(),
            "Most issues arise from incorrect file formatting rather than analysis errors."
          )
        )
      ),
      
      # =========================================================
      # ✅ CHECKLIST
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), "✅ Validation checklist"),
        tags$div(style = guide_body_style(), tags$ul(
          tags$li("✅ Files match"),
          tags$li("✅ Required columns present"),
          tags$li("✅ Correct delimiter"),
          tags$li("✅ No empty header rows")
        ))
      )
    )
    
  })
  
  output$download_template_us <- downloadHandler(
    filename = function() {
      "design_template_us.csv"
    },
    content = function(file) {
      
      path <- system.file(
        "app/templates",
        "design_template_us.csv",
        package = "growthcurve"
      )
      
      # fallback for development
      if (path == "") {
        path <- file.path("templates", "design_template_us.csv")
      }
      
      file.copy(from = path, to = file, overwrite = TRUE)
    }
  )
  
  
  output$download_template_eu <- downloadHandler(
    filename = function() {
      "design_template_eu.csv"
    },
    content = function(file) {
      
      path <- system.file(
        "app/templates",
        "design_template_eu.csv",
        package = "growthcurve"
      )
      
      # fallback for development
      if (path == "") {
        path <- file.path("templates", "design_template_eu.csv")
      }
      
      file.copy(from = path, to = file, overwrite = TRUE)
    }
  )
  
  output$stage_ready <- reactive({
    !is.null(analysis_result())
  })
  
  outputOptions(output, "stage_ready", suspendWhenHidden = FALSE)
  
  output$single_ui <- renderUI({
    if (!wd_set()) {
      return(tagList(
        tags$div(
          style = "padding: 20px; background-color: #f8f9fa; border-radius: 6px;",
          h4("Single plate analysis"),
          p("Please set a working directory to continue.")
        )
      ))
    }
    
    files <- wd_files()
    
    tagList(
      # =========================================================
      # INPUT SECTION
      # =========================================================
      
      h3("Single plate analysis"),
      
      hr(),
      
      h4("Select instrument"),
      radioButtons(
        inputId = "instrument",
        label   = NULL,
        choices = c("Plate reader" = "plate_reader", "oCelloscope"  = "ocelloscope"),
        selected = "plate_reader",
        inline = TRUE
      ),
      
      hr(),
      
      empty_choice <- setNames("", ""),
      
      
      selectInput(
        "raw_file",
        "Raw data file",
        choices = c(empty_choice, files),
        selected = ""
      ),
      
      tags$details(
        tags$summary(style = guide_summary_style(), "👁 Preview raw data"),
        tags$div(
          style = guide_body_style(),
          textOutput("single_preview_label"),
          uiOutput("single_raw_preview_ui")
        )
      ),
      
      
      selectInput(
        "design_file",
        "Design file",
        choices = c(empty_choice, files),
        selected = ""
      ),
      
      tags$details(
        tags$summary(style = guide_summary_style(), "🧬 Preview design file"),
        tags$div(style = guide_body_style(), div(class = "preview-table", uiOutput(
          "design_preview"
        )))
      ),
      
      hr(),
      
      # =========================================================
      # PARAMETERS
      # =========================================================
      
      numericInput("hrs", "Duration (hours)", 24),
      numericInput("interval_min", "Interval (minutes)", 15, step = 1),
      numericInput("minod", "Min OD", 0.05),
      numericInput("maxod", "Max OD", 0.7),
      
      textInput("prefix", "Output prefix (optional)", ""),
      
      uiOutput("design_section"),
      
      tags$hr(),
      tags$span(
        id    = "run_wrapper",
        title = "Select both files to enable analysis",
        actionButton(
          "run",
          "Run analysis",
          class    = "btn-success",
          disabled = TRUE
        )
      ),
      
      hr(),
      
      actionButton(
        "reset_analysis",
        "🔄 Reset analysis",
        class = "btn-warning",
        disabled = TRUE
      ),
      
      # =========================================================
      # CONTROLS
      # =========================================================
      
      # ---- Export FIRST ----
      div(
        style = "margin-top:10px;",
        actionButton(
          "export_files",
          "📁 Export analysis files",
          class = "btn-success",
          disabled = TRUE
        )
      ),
      
      hr(),
      
      # ---- Stage counter ----
      verbatimTextOutput("stage_counter"),
      
      # ---- Navigation stays with plots ----
      div(
        style = "display:flex; gap:10px;",
        actionButton("prev_stage", "← Back", class = "btn-secondary"),
        actionButton("next_stage", "Next →", class = "btn-primary")
      ),
      
      hr(),
      
      # =========================================================
      # PLOTS (ONLY WHEN AVAILABLE)
      # =========================================================
      
      conditionalPanel(condition = "output.stage_ready == true", uiOutput("stage_ui"))
    )
  })
  
  single_preview_raw <- reactive({
    req(input$raw_file, wd_path(), input$instrument)
    
    file <- file.path(wd_path(), input$raw_file)
    
    design <- if (nzchar(input$design_file %||% "")) {
      file.path(wd_path(), input$design_file)
    } else {
      NULL
    }
    
    build_preview(file,
                  design,
                  interval = interval_hours(),
                  instrument = input$instrument)
    
  })
  
  single_preview_raw <- bindCache(
    single_preview_raw,
    input$raw_file,
    input$design_file,
    input$instrument,
    input$interval_min
  )
  
  single_preview_data <- reactive({
    unwrap_preview(single_preview_raw())
  })
  
  batch_preview_raw <- reactive({
    req(input$batch_data_dir)
    
    files <- base::list.files(input$batch_data_dir, full.names = TRUE)
    if (length(files) == 0)
      return(NULL)
    
    file <- files[1]
    
    # 🚨 Guard for oCelloscope without design
    if (input$batch_instrument == "ocelloscope" &&
        (is.null(input$batch_design_dir) ||
         !nzchar(input$batch_design_dir))) {
      return(structure(
        list(message = "Select a design directory to preview oCelloscope data."),
        class = "preview_message"
      ))
    }
    
    # Optional design file
    design <- NULL
    
    if (!is.null(input$batch_design_dir) &&
        nzchar(input$batch_design_dir)) {
      df <- tryCatch(
        validated_pairs_cached(),
        error = function(e)
          NULL
      )
      
      if (!is.null(df) && nrow(df) > 0) {
        design <- df$design_file[1]
        
        if (is.na(design) || !file.exists(design)) {
          design <- NULL
        }
      }
    }
    
    build_preview(
      file,
      design,
      interval = input$batch_interval / 60,
      instrument = input$batch_instrument
    )
    
  })
  
  batch_preview_raw <- bindCache(
    batch_preview_raw,
    input$batch_data_dir,
    input$batch_design_dir,
    input$batch_instrument,
    input$batch_interval
  )
  
  output$single_raw_preview_table <- renderTable({
    result <- single_preview_data()
    
    if (is_preview_message(result)) {
      return(NULL)
    }
    
    format_preview_df(result$data, region_selected())
    
  }, striped = TRUE, bordered = TRUE, spacing = "xs", colnames = TRUE, na = "")
  
  output$single_preview_label <- renderText({
    req(input$raw_file, wd_path())
    
    file <- file.path(wd_path(), input$raw_file)
    
    res <- single_preview_raw()
    
    build_preview_label(file, res, instrument = input$instrument)
  })
  
  output$single_raw_preview_ui <- renderUI({
    result <- single_preview_data()
    
    # ✅ Case 1: warning / message
    if (is_preview_message(result)) {
      return(
        div(
          style = "
          padding: 12px;
          background-color: #fff3cd;
          border: 1px solid #ffeeba;
          border-radius: 6px;
          color: #856404;
          max-width: 600px;
        ",
          strong("⚠ "),
          result$message
        )
      )
    }
    
    # ✅ Case 2: render table
    div(class = "preview-table",
        style = "overflow-x: auto; white-space: nowrap;",
        tableOutput("single_raw_preview_table"))
  })
  
  output$design_preview <- renderUI({
    req(input$design_file, wd_path())
    
    file <- file.path(wd_path(), input$design_file)
    req(file.exists(file))
    
    df <- read_preview_file(file, nrows = 100)
    
    req(df)
    
    # Detect block starts (first column non-empty rows)
    block_starts <- which(df[[1]] != "" & !is.na(df[[1]]))
    
    n_blocks <- length(block_starts)
    
    row_block_id <- rep(NA, nrow(df))
    
    for (k in seq_along(block_starts)) {
      start <- block_starts[k]
      end <- if (k < n_blocks)
        block_starts[k + 1] - 1
      else
        nrow(df)
      row_block_id[start:end] <- k
    }
    
    # Build HTML table manually
    rows <- lapply(seq_len(min(30, nrow(df))), function(i) {
      block_id <- row_block_id[i]
      is_block_header <- (i - 1) %% 10 == 0
      
      cells <- lapply(seq_len(ncol(df)), function(j) {
        val <- df[i, j]
        if (is.na(val))
          val <- ""
        
        style_parts <- c(
          "border: 1px solid #e6e6e6;"  # ✅ soft gridlines
        )
        
        # ✅ Block header (only first cell)
        if (j == 1 && is_block_header) {
          style_parts <- c(style_parts,
                           "font-weight: bold; border: 2px solid #666;")
        }
        
        # ✅ Column headers (1–12 row)
        if (is_block_header && j > 1) {
          style_parts <- c(style_parts, "font-weight: bold;")
        }
        
        # ✅ Row labels (A–H)
        if (j == 1 && !is_block_header) {
          style_parts <- c(style_parts, "font-weight: 500;")
        }
        
        style <- paste(style_parts, collapse = " ")
        
        tags$td(style = style, val)
      })
      
      # ✅ Thick separator between blocks
      row_style <- ""
      if (is_block_header && i != 1) {
        row_style <- "border-top: 4px solid #666;"
      }
      
      tags$tr(style = row_style, cells)
    })
    
    needs_expand <- any(nchar(unlist(df)) > 10, na.rm = TRUE)
    
    tags$table(
      class = paste("design-preview-table", if (needs_expand)
        "expanding"
        else
          ""),
      style = "border-collapse: collapse;",
      tags$tbody(rows)
    )
    
  })
  
  output$batch_ui <- renderUI({
    if (!wd_set())
      return(NULL)
    
    div(
      class = "batch-flex",
      
      # LEFT
      div(
        class = "batch-left",
        
        # ✅ Show table ONLY when valid pairs exist
        conditionalPanel(condition = "output.batch_has_pairs == true", DT::DTOutput("batch_match_table")),
        
        # ✅ Show placeholder when no valid pairs exist
        conditionalPanel(
          condition = "output.batch_has_pairs == false",
          tags$p(
            style = "color: #777; margin-top: 10px;",
            "No valid file pairs available. Please select compatible directories."
          )
        ),
        
        uiOutput("batch_param_section")
      ),
      
      # RIGHT
      div(
        class = "batch-right",
        
        h3("Batch processing mode"),
        
        tags$p(
          "This mode runs the full growth‑curve analysis pipeline on ",
          "all matched data / design file pairs."
        ),
        
        tags$ul(
          tags$li("No plots are displayed."),
          tags$li("All results are exported automatically."),
          tags$li("Each plate is processed independently."),
          tags$li("Failures in one plate do not stop the batch.")
        )
      )
    )
  })
  
  output$batch_has_pairs <- reactive({
    !is.null(batch_pairs()) && nrow(batch_pairs()) > 0
  })
  outputOptions(output, "batch_has_pairs", suspendWhenHidden = FALSE)
  
  output$batch_raw_preview_ui <- renderUI({
    req(input$batch_data_dir)
    
    files <- list.files(input$batch_data_dir, full.names = TRUE)
    if (length(files) == 0)
      return(NULL)
    
    file <- files[1]
    
    # 🚨 NEW: explicit oCelloscope guard
    if (input$batch_instrument == "ocelloscope" &&
        (is.null(input$batch_design_dir) ||
         !nzchar(input$batch_design_dir))) {
      return(
        div(
          style = "
        padding: 12px;
        background-color: #fff3cd;
        border: 1px solid #ffeeba;
        border-radius: 6px;
        color: #856404;
        max-width: 600px;
      ",
          strong("⚠ "),
          "Select a design directory to preview oCelloscope data."
        )
      )
    }
    
    # Optional design
    design <- NULL
    if (!is.null(input$batch_design_dir) &&
        nzchar(input$batch_design_dir)) {
      df <- tryCatch(
        validated_pairs_cached(),
        error = function(e)
          NULL
      )
      
      if (!is.null(df) && nrow(df) > 0) {
        design <- df$design_file[1]
        if (is.na(design) || !file.exists(design)) {
          design <- NULL
        }
      }
    }
    
    result <- unwrap_preview(batch_preview_raw())
    
    if (is_preview_message(result)) {
      return(
        div(
          style = "
          padding: 12px;
          background-color: #fff3cd;
          border: 1px solid #ffeeba;
          border-radius: 6px;
          color: #856404;
          max-width: 600px;
        ",
          strong("⚠ "),
          result$message
        )
      )
    }
    
    # ✅ Table
    # ✅ Table placeholder ONLY
    div(class = "preview-table",
        style = "overflow-x: auto; white-space: nowrap;",
        tableOutput("batch_raw_preview_table"))
  })
  
  output$batch_raw_preview_table <- renderTable({
    req(input$batch_data_dir)
    
    files <- list.files(input$batch_data_dir, full.names = TRUE)
    if (length(files) == 0)
      return(NULL)
    
    # 🚨 NEW: block table rendering if design missing for oCelloscope
    if (input$batch_instrument == "ocelloscope" &&
        (is.null(input$batch_design_dir) ||
         !nzchar(input$batch_design_dir))) {
      return(NULL)
    }
    
    file <- files[1]
    
    # Optional design
    design <- NULL
    if (!is.null(input$batch_design_dir) &&
        nzchar(input$batch_design_dir)) {
      df <- tryCatch(
        validated_pairs_cached(),
        error = function(e)
          NULL
      )
      
      if (!is.null(df) && nrow(df) > 0) {
        design <- df$design_file[1]
        if (is.na(design) || !file.exists(design)) {
          design <- NULL
        }
      }
    }
    
    result <- unwrap_preview(batch_preview_raw())
    
    if (is_preview_message(result)) {
      return(NULL)
    }
    
    format_preview_df(result$data, region_selected())
    
  }, striped = TRUE, bordered = TRUE, spacing = "xs", colnames = TRUE, na = "")
  
  output$batch_preview_label <- renderText({
    req(input$batch_data_dir)
    
    files <- list.files(input$batch_data_dir, full.names = TRUE)
    if (length(files) == 0)
      return(NULL)
    
    file <- files[1]
    
    # Optional design
    design <- NULL
    if (!is.null(input$batch_design_dir) &&
        nzchar(input$batch_design_dir)) {
      df <- tryCatch(
        validated_pairs_cached(),
        error = function(e)
          NULL
      )
      
      if (!is.null(df) && nrow(df) > 0) {
        design <- df$design_file[1]
      }
    }
    
    res <- batch_preview_raw()
    
    build_preview_label(file, res, instrument = isolate(input$batch_instrument))
  })
  
  output$batch_design_preview <- renderUI({
    # ✅ Only require design directory (NOT matching logic)
    req(input$batch_design_dir)
    
    files <- list.files(input$batch_design_dir, full.names = TRUE)
    if (length(files) == 0)
      return(NULL)
    
    file <- files[1]
    req(!is.na(file), file.exists(file))
    
    # ✅ Read preview
    df <- read_preview_file(file, nrows = 100)
    req(df)
    
    # ✅ Detect block starts
    block_starts <- which(df[[1]] != "" & !is.na(df[[1]]))
    n_blocks <- length(block_starts)
    
    row_block_id <- rep(NA, nrow(df))
    
    for (k in seq_along(block_starts)) {
      start <- block_starts[k]
      end <- if (k < n_blocks)
        block_starts[k + 1] - 1
      else
        nrow(df)
      row_block_id[start:end] <- k
    }
    
    # ✅ Build styled table
    rows <- lapply(seq_len(min(30, nrow(df))), function(i) {
      block_id <- row_block_id[i]
      is_block_header <- (i - 1) %% 10 == 0
      
      cells <- lapply(seq_len(ncol(df)), function(j) {
        val <- df[i, j]
        if (is.na(val))
          val <- ""
        
        style_parts <- c("border: 1px solid #e6e6e6;")
        
        # ✅ Block header (first column)
        if (j == 1 && is_block_header) {
          style_parts <- c(style_parts,
                           "font-weight: bold; border: 2px solid #666;")
        }
        
        # ✅ Column headers (1–12)
        if (is_block_header && j > 1) {
          style_parts <- c(style_parts, "font-weight: bold;")
        }
        
        # ✅ Row labels (A–H)
        if (j == 1 && !is_block_header) {
          style_parts <- c(style_parts, "font-weight: 500;")
        }
        
        style <- paste(style_parts, collapse = " ")
        
        tags$td(style = style, val)
      })
      
      # ✅ Thick separator between blocks
      row_style <- ""
      if (is_block_header && i != 1) {
        row_style <- "border-top: 4px solid #666;"
      }
      
      tags$tr(style = row_style, cells)
    })
    
    needs_expand <- any(nchar(unlist(df)) > 10, na.rm = TRUE)
    
    tags$table(
      class = paste("design-preview-table", if (needs_expand)
        "expanding"
        else
          ""),
      style = "border-collapse: collapse;",
      tags$tbody(rows)
    )
    
  })
  
  output$aggregate_ui <- renderUI({
    if (!wd_set())
      return(NULL)
    
    div(
      class = "batch-flex",
      
      # LEFT
      div(
        class = "batch-left",
        
        tags$details(
          tags$summary(
            style = "
              cursor: pointer;
              padding: 6px 8px;
              margin-top: 6px;
              background-color: #e0e0e0;
              border-radius: 4px;
              font-weight: 600;
            ",
            "ℹ️  What folder should I select?"
          ),
          tags$div(
            style = "padding: 8px 4px;",
            tags$p("Select a directory that contains one or more analysis runs."),
            tags$ul(
              tags$li("Each subfolder will be treated as a separate run."),
              tags$li("You can choose which runs to include below."),
              tags$li(
                "Example: a folder containing multiple *_batch or *_single runs."
              )
            )
          )
        ),
        
        hr(),
        
        checkboxInput("agg_select_all", "Select all runs", TRUE),
        
        DT::DTOutput("agg_runs_table"),
        
        hr(),
        
        actionButton("run_aggregate", "📊 Combine summaries", class = "btn-success"),
        
        hr(),
        
        h4("Preview"),
        
        DT::DTOutput("agg_preview"),
        
        hr(),
        
        actionButton("export_agg", "📁 Export combined file", class = "btn-primary")
      ),
      
      # RIGHT
      div(
        class = "batch-right",
        
        h3("Aggregate results mode"),
        
        tags$p(
          "This mode combines all plate-level tidy summary files ",
          "into a single experiment-level dataset."
        ),
        
        tags$ul(
          tags$li("Automatically detects all plate_tidy.csv files."),
          tags$li("Works for both batch and single-plate analyses."),
          tags$li(
            "Produces a combined tidy dataset ready for downstream analysis."
          ),
          tags$li("Preview the combined data before exporting.")
        )
      )
    )
  })
  
  table_proxy <- DT::dataTableProxy("agg_runs_table")
  
  output$agg_runs_table <- DT::renderDT({
    req(agg_runs())
    
    df <- agg_runs()
    
    df$status <- "…"   # placeholder
    
    df$include_ui <- vapply(df$run_name, function(name) {
      safe_name <- gsub("[^a-zA-Z0-9_]", "_", name)
      
      as.character(tags$input(
        type = "checkbox",
        id = paste0("agg_include_", safe_name),
        checked = "checked"
      ))
      
    }, character(1))
    
    DT::datatable(
      df[, c("include_ui", "run_name", "status")],
      rownames = FALSE,
      escape = FALSE,
      selection = "none",
      colnames = c("Include", "Run", "Status"),
      options = list(
        dom = "t",
        ordering = FALSE,
        autoWidth = FALSE
      ),
      callback = htmlwidgets::JS(
        "
      table.on('draw.dt', function() {
        Shiny.bindAll(table.table().node());
      });
    "
      )
    )
    
  }, server = TRUE)
  
  observe({
    req(agg_runs())
    
    df <- agg_runs()
    
    dup_info <- duplicate_info()
    
    # build status column
    df$status <- ifelse(
      df$run_name %in% names(dup_info$run_flags) &
        dup_info$run_flags[df$run_name],
      "⚠️ overlapping plates",
      "✅ unique"
    )
    
    # preserve checkbox column structure
    df$include_ui <- vapply(df$run_name, function(name) {
      safe_name <- gsub("[^a-zA-Z0-9_]", "_", name)
      
      val <- input[[paste0("agg_include_", safe_name)]]
      
      as.character(tags$input(
        type = "checkbox",
        id = paste0("agg_include_", safe_name),
        checked = if (isTRUE(val) ||
                      is.null(val))
          "checked"
        else
          NULL
      ))
      
    }, character(1))
    
    DT::replaceData(table_proxy,
                    df[, c("include_ui", "run_name", "status")],
                    resetPaging = FALSE,
                    rownames = FALSE)
    
  })
  
  
  output$agg_preview <- DT::renderDT({
    req(agg_result())
    
    df <- agg_result()
    
    # ✅ drop unwanted column if present
    df <- df[, setdiff(names(df), "source_file"), drop = FALSE]
    
    DT::datatable(
      head(df, 100),
      options = list(pageLength = 10, scrollX = TRUE),
      rownames = FALSE
    )
  })
  
  output$batch_param_section <- renderUI({
    req(wd_set())
    
    tagList(
      hr(),
      
      h4("Analysis parameters"),
      
      numericInput("batch_hrs", "Duration (hours)", 24),
      numericInput("batch_interval", "Interval (minutes)", 15, step = 1),
      numericInput("batch_minod", "Min OD", 0.05),
      numericInput("batch_maxod", "Max OD", 0.7),
      
      textInput("batch_prefix", "Output prefix (optional)", ""),
      
      div(
        id = "batch_blank_mode_container",
        
        radioButtons(
          inputId = "batch_blank_mode",
          label   = "Blank correction",
          choices = c(
            "Plate-based blanks (recommended)" = "plate",
            "Per-well internal baseline"        = "per_well"
          ),
          selected = "plate"
        ),
        
        conditionalPanel(
          condition = "input.batch_instrument == 'ocelloscope'",
          helpText(
            "oCelloscope data are already baseline-corrected during acquisition, so additional blank correction is not applied."
          )
        )
      ),
      
      hr(),
      
      checkboxInput("batch_parallel", "Enable parallel processing", FALSE),
      
      conditionalPanel(
        condition = "input.batch_parallel == true",
        helpText(
          "Note: Parallel processing is intentionally limited to 2 plates at a time.",
          "Higher values often slow down disk‑heavy analyses."
        )
      ),
      
      hr(),
      
      div(
        style = "display: flex; align-items: center; gap: 8px;",
        
        tagList(
          actionButton(
            "run_batch",
            "🚀 Run batch analysis",
            class = "btn-success",
            disabled = TRUE
          ),
          
          shinyBS::bsTooltip(
            "run_batch",
            title = "Select both directories and ensure valid matching",
            placement = "top",
            trigger = "hover"
          )
        ),
        
        actionButton("how_to_stop", "⚠️ How to stop a running batch", class = "btn-warning")
      )
    )
  })
  
  observeEvent(list(
    input$batch_data_dir,
    input$batch_design_dir,
    file_refresh()
  ),
  {
    # ✅ Only proceed if BOTH are selected AND non-empty
    req(
      !is.null(input$batch_data_dir),
      nzchar(input$batch_data_dir),!is.null(input$batch_design_dir),
      nzchar(input$batch_design_dir)
    )
    
    if (identical(input$batch_data_dir, input$batch_design_dir)) {
      showModal(modalDialog(
        title = "Invalid directory selection",
        p("Raw data directory and design directory cannot be the same."),
        easyClose = TRUE
      ))
      
      batch_pairs(NULL)
      
      return(NULL)
    }
    
    if (input$batch_data_dir == "" ||
        input$batch_design_dir == "") {
      batch_pairs(NULL)
      return(NULL)
    }
    
    # List files in deterministic order
    data_files <- sort(list.files(input$batch_data_dir, full.names = TRUE))
    
    design_files <- sort(list.files(input$batch_design_dir, full.names = TRUE))
    
    # Default matching by position
    n <- max(length(data_files), length(design_files))
    
    df <- data.frame(
      data_file   = data_files[seq_len(n)],
      design_file = design_files[seq_len(n)],
      stringsAsFactors = FALSE
    )
    
    # Pad with NA if lengths differ
    df$data_file[is.na(df$data_file)]     <- NA_character_
    df$design_file[is.na(df$design_file)] <- NA_character_
    
    batch_pairs_last_valid(df)
    batch_pairs(df)
    
    gc_log_block("BATCH PAIRS", df)
    
  })
  
  design_blocks <- reactive({
    req(input$design_file, wd_path())
    
    extract_design_blocks(file.path(wd_path(), input$design_file))
    
  })
  
  design_blocks <- bindCache(design_blocks, input$design_file)
  
  output$design_section <- renderUI({
    tagList(
      selectInput(
        "design_vars",
        "Design variables",
        choices  = character(0),
        selected = character(0),
        multiple = TRUE
      ),
      
      div(id = "blank_mode_container", tagList(
        radioButtons(
          inputId  = "blank_mode",
          label    = "Blank correction",
          choices  = c(
            "Plate-based blanks (recommended)" = "plate",
            "Per-well internal baseline"        = "per_well"
          ),
          selected = "plate"
        ),
        
        conditionalPanel(
          condition = "input.instrument == 'ocelloscope'",
          helpText(
            "oCelloscope data are already baseline-corrected during acquisition, so additional blank correction is not applied."
          )
        )
        
      )),
      
      tags$div(style = "margin-top: 8px;", verbatimTextOutput("blank_info"))
    )
  })
  
  observeEvent(input$design_file, {
    req(wd_path(), input$design_file)
    
    file <- file.path(wd_path(), input$design_file)
    
    vars <- tryCatch(
      extract_design_blocks(file),
      error = function(e)
        character(0)
    )
    
    updateSelectInput(session,
                      "design_vars",
                      choices  = vars,
                      selected = vars)
    
  })
  
  observeEvent(input$instrument, {
    if (input$instrument == "ocelloscope") {
      updateRadioButtons(session, "blank_mode", selected = "plate")
      shinyjs::disable("blank_mode_container")
      
    } else {
      shinyjs::enable("blank_mode_container")
      
    }
    
  }, ignoreNULL = TRUE)
  
  output$stage_ui <- renderUI({
    req(analysis_result(), current_stage())
    
    if (current_stage() == "blank_linear") {
      tagList(
        h3("Blank‑corrected OD (linear scale)"),
        plotOutput("plot_blank_linear", height = "500px"),
        p(
          "Inspect blank wells and confirm that non‑blank wells ",
          "start near zero after blank correction."
        ),
        if (identical(analysis_result()$instrument, "ocelloscope")) {
          p(
            style = "font-style: italic; color: #555;",
            "Note: oCelloscope data are not blank-corrected; baseline offsets reflect imaging artifacts."
          )
        }
      )
      
    } else if (current_stage() == "blank_log") {
      tagList(
        h3("Blank‑corrected OD (log scale)"),
        plotOutput("plot_blank_log", height = "500px"),
        p(
          "Inspect baseline behavior and early growth on a log scale. ",
          "Look for unexpected curvature or offsets."
        ),
        if (identical(analysis_result()$instrument, "ocelloscope")) {
          p(
            style = "font-style: italic; color: #555;",
            "Note: oCelloscope data are not blank-corrected; baseline offsets reflect imaging artifacts."
          )
        }
      )
      
    } else if (current_stage() == "mean_curves") {
      tagList(
        h3("Mean growth curves with 95% confidence interval"),
        plotOutput("plot_mean_curves", height = "500px"),
        p(
          "Inspect group‑averaged growth curves and confidence intervals. ",
          "Check that trends align with expectations and that variability ",
          "looks reasonable."
        )
      )
      
    } else if (current_stage() == "perwell_linear") {
      tagList(
        h3("Per‑well OD curves (linear scale)"),
        plotOutput("plot_perwell_linear", height = "500px"),
        p(
          "Inspect individual wells for anomalies such as contamination, ",
          "edge effects, or failed growth. Look for wells that clearly ",
          "deviate from others in the same condition."
        )
      )
      
    } else if (current_stage() == "perwell_log") {
      tagList(
        h3("Per‑well OD curves (log scale)"),
        plotOutput("plot_perwell_log", height = "500px"),
        p(
          "Inspect individual wells on a log scale to assess early ",
          "exponential growth behavior and subtle deviations between wells."
        )
      )
      
    } else if (current_stage() == "deriv_raw") {
      tagList(
        h3("Raw growth‑rate derivatives"),
        plotOutput("plot_deriv_raw", height = "500px"),
        p(
          "Inspect raw growth‑rate derivatives per well. ",
          "Look for excessive noise, spikes, or discontinuities ",
          "that could indicate unreliable numerical differentiation."
        )
      )
      
    } else if (current_stage() == "deriv_percap") {
      tagList(
        h3("Per‑capita growth‑rate derivatives"),
        plotOutput("plot_deriv_percap", height = "500px"),
        p(
          "Inspect fitted per‑capita growth‑rate derivatives. ",
          "These curves drive the maximum growth rate and ",
          "doubling‑time estimates used in downstream summaries."
        )
      )
      
    } else if (current_stage() == "fitted_percap") {
      tagList(
        h3("Fitted per‑capita growth rate with maximum marked"),
        plotOutput("plot_fitted_percap", height = "500px"),
        p(
          "Inspect the fitted per‑capita growth‑rate curves with the ",
          "detected maximum marked. Confirm that the peak corresponds ",
          "to a biologically plausible region of the curve."
        )
      )
      
    } else if (current_stage() == "od_with_maxgc") {
      tagList(
        h3("OD curves with maximum growth‑rate time marked"),
        plotOutput("plot_od_with_maxgc", height = "500px"),
        p(
          "Inspect OD curves with the time of maximum per‑capita growth ",
          "rate overlaid. The marked timepoint should occur during ",
          "exponential growth, not during lag or saturation."
        )
      )
      
    } else if (current_stage() == "doubling_time") {
      tagList(
        h3("Doubling time summary (mean and 95% confidence interval)"),
        plotOutput("plot_doubling_time", height = "500px"),
        p(
          "Inspect per‑well doubling times grouped by condition. ",
          "Look for biologically implausible values or unusually ",
          "large variation within groups."
        )
      )
      
    } else if (current_stage() == "max_growth_rate") {
      tagList(
        h3(
          "Maximum growth‑rate summary (mean and 95% confidence interval)"
        ),
        plotOutput("plot_max_growth_rate", height = "500px"),
        p(
          "Inspect maximum per‑capita growth rates by condition. ",
          "These values are central to downstream interpretation ",
          "and should be checked carefully."
        )
      )
      
    } else {
      p("Next stage coming…")
      
    }
  })
  
  output$plot_blank_linear <- renderPlot({
    analysis_result()$plots$blank_linear
  })
  
  output$plot_blank_log <- renderPlot({
    analysis_result()$plots$blank_log
  })
  
  output$plot_mean_curves <- renderPlot({
    analysis_result()$plots$mean_curves
  })
  
  output$plot_perwell_linear <- renderPlot({
    analysis_result()$plots$perwell_linear
  })
  
  output$plot_perwell_log <- renderPlot({
    analysis_result()$plots$perwell_log
  })
  
  output$plot_deriv_raw <- renderPlot({
    analysis_result()$plots$deriv_raw
  })
  
  output$plot_deriv_percap <- renderPlot({
    analysis_result()$plots$deriv_percap
  })
  
  output$plot_fitted_percap <- renderPlot({
    analysis_result()$plots$fitted_percap
  })
  
  output$plot_od_with_maxgc <- renderPlot({
    analysis_result()$plots$od_with_maxgc
  })
  
  output$plot_doubling_time <- renderPlot({
    analysis_result()$plots$doubling_time
  })
  
  output$plot_max_growth_rate <- renderPlot({
    analysis_result()$plots$max_growth_rate
  })
  
  output$stage_counter <- renderText({
    req(current_stage())
    idx <- match(current_stage(), stage_order)
    paste0("Stage ", idx, " of ", length(stage_order))
  })
  
  output$batch_match_table <- DT::renderDT({
    df <- validated_pairs_cached()
    choices <- design_file_choices()
    
    if (is.null(choices) || length(choices) == 0) {
      choices <- character(0)
    }
    
    # Inject a <select> into the design file column
    df$design_file_name <- vapply(seq_len(nrow(df)), function(i) {
      current <- df$design_file_name[i]
      opts <- vapply(choices, function(ch) {
        selected <- if (!is.na(current) &&
                        ch == current)
          " selected"
        else
          ""
        sprintf('<option value="%s"%s>%s</option>', ch, selected, ch)
      }, character(1))
      sprintf(
        '<select class="batch-design-select" data-row="%d">%s</select>',
        i,
        paste(opts, collapse = "")
      )
    }, character(1))
    
    DT::datatable(
      df[, c("data_file_name",
             "design_file_name",
             "design_vars",
             "status")],
      rownames = FALSE,
      escape = FALSE,
      selection = "none",
      colnames = c(
        '<span title="Growth-curve measurement CSV file">Raw data file</span>',
        '<span title="Plate layout or experimental design file">Design file</span>',
        '<span title="Variables automatically inferred from the design file">Design variables</span>',
        '<span title="Validation status for batch execution">Status</span>'
      ),
      options = list(
        pageLength = 15,
        dom = "tip",
        ordering = FALSE,
        autoWidth = FALSE,
        fixedHeader = TRUE,
        columnDefs = list(
          list(width = "25%", targets = 0),
          list(width = "35%", targets = 1),
          list(width = "30%", targets = 2),
          list(width = "10%", targets = 3)
        )
      ),
      callback = htmlwidgets::JS(
        "
      table.on('change', '.batch-design-select', function() {
        var row = parseInt($(this).data('row'));
        var val = $(this).val();
        Shiny.setInputValue('batch_design_select', {row: row, value: val}, {priority: 'event'});
      });
    "
      )
    )
  })
  
  observeEvent(input$run, {
    if (requireNamespace("future", quietly = TRUE)) {
      future::plan(future::sequential)
    }
    
    APP_CONFIG$region <- region_selected()
    
    analysis_result(NULL)
    
    req(input$raw_file, input$design_file, input$design_vars)
    
    if (input$raw_file == "" || input$design_file == "") {
      showModal(modalDialog(
        title = "Missing input",
        p(
          "Please select both a raw data file and a design file before running the analysis."
        ),
        easyClose = TRUE
      ))
      
      return(NULL)
    }
    
    if (identical(input$raw_file, input$design_file)) {
      showModal(modalDialog(
        title = "Invalid selection",
        p("Raw data file and design file cannot be the same."),
        easyClose = TRUE
      ))
      return(NULL)
    }
    
    withProgress(message = "Running growth curve analysis",
                 detail  = "Importing data and generating plots…",
                 value   = 0,
                 {
                   incProgress(0.1)
                   
                   raw_file_path    <- file.path(wd_path(), input$raw_file)
                   design_file_path <- file.path(wd_path(), input$design_file)
                   
                   # Enforce instrument-specific blanking policy
                   blank_mode_effective <- if (input$instrument == "ocelloscope") {
                     "none"
                   } else {
                     input$blank_mode
                   }
                   
                   res <- tryCatch({
                     gc_log_block(
                       "SINGLE RUN PARAMS",
                       list(
                         raw_file = raw_file_path,
                         design   = design_file_path,
                         vars     = input$design_vars
                       )
                     )
                     
                     gc_run_quiet(
                       run_gc(
                         rawdatafile = raw_file_path,
                         designfile  = design_file_path,
                         design_vars = input$design_vars,
                         hrs         = input$hrs,
                         interval    = interval_hours(),
                         minod       = input$minod,
                         maxod       = input$maxod,
                         instrument  = input$instrument,
                         blank_mode  = blank_mode_effective,
                         prefix      = input$prefix,
                         batch       = FALSE,
                         region      = region_selected()
                       )
                     )
                     
                   }, error = function(e) {
                     gc_log_block("SINGLE RUN INTERNAL ERROR",
                                  list(error = e, callstack = sys.calls()))
                     
                     msg <- if (inherits(e, "gc_error")) {
                       gc_get_message(e)
                     } else {
                       paste("Unexpected error:\n", gc_get_message(e))
                     }
                     
                     showModal(modalDialog(
                       title = "Analysis failed",
                       tagList(
                         p("The analysis could not be completed."),
                         tags$hr(),
                         tags$pre(style = "white-space: pre-wrap;", msg)
                       ),
                       easyClose = TRUE
                     ))
                     
                     return(NULL)
                   })
                   
                   req(!is.null(res))
                   
                   incProgress(0.9)
                   
                   # ---- Success ----
                   analysis_result(res)
                   current_stage(stage_order[1])
                   
                   showModal(
                     modalDialog(
                       title = "Analysis complete",
                       tagList(
                         p("Your growth curve analysis has finished successfully."),
                         p("No files have been written yet."),
                         p("You can explore the results and export files when ready.")
                       ),
                       easyClose = TRUE,
                       footer = modalButton("Close")
                     )
                   )
                 })
  })
  
  observeEvent(input$reset_analysis, {
    showModal(
      modalDialog(
        title = "Reset analysis?",
        "This will clear the current results.",
        footer = tagList(
          modalButton("Cancel"),
          actionButton("confirm_reset", "Reset", class = "btn-danger")
        )
      )
    )
    
  })
  
  observeEvent(input$confirm_reset, {
    removeModal()
    
    analysis_result(NULL)
    current_stage("not_run")
    
    shinyjs::enable("hrs")
    shinyjs::enable("interval_min")
    shinyjs::enable("minod")
    shinyjs::enable("maxod")
    shinyjs::enable("prefix")
    shinyjs::enable("design_vars")
    shinyjs::enable("blank_mode")
    shinyjs::enable("raw_file")
    shinyjs::enable("design_file")
    shinyjs::enable("instrument")
    
    shinyjs::disable("export_files")
    
  })
  
  observeEvent(input$batch_instrument, {
    if (input$batch_instrument == "ocelloscope") {
      updateRadioButtons(session, "batch_blank_mode", selected = "plate")
      shinyjs::disable("batch_blank_mode_container")
    } else {
      shinyjs::enable("batch_blank_mode_container")
      
      if (is.null(input$batch_blank_mode) ||
          input$batch_blank_mode == "none") {
        updateRadioButtons(session, "batch_blank_mode", selected = "plate")
      }
    }
    
    apply_instrument_defaults(session,
                              prefix = "batch",
                              instrument = input$batch_instrument)
  })
  
  observeEvent(input$agg_dir, {
    req(input$agg_dir)
    
    root <- input$agg_dir
    
    dirs <- list.dirs(path = root,
                      recursive = FALSE,
                      full.names = TRUE)
    
    if (length(dirs) == 0) {
      agg_runs(NULL)
      return()
    }
    
    df <- data.frame(
      run_name  = basename(dirs),
      full_path = dirs,
      stringsAsFactors = FALSE
    )
    
    agg_runs(df)
  })
  
  observeEvent(input$next_stage, {
    req(current_stage() != "not_run")
    advance_stage()
  })
  
  observeEvent(input$instrument, {
    apply_instrument_defaults(session,
                              prefix = "",
                              instrument = input$instrument)
    
  })
  
  observeEvent(input$run_batch, {
    APP_CONFIG$region <- region_selected()
    
    batch_abort(FALSE)
    
    # Hard guard: reject run if any pair is not fully matched
    pairs_check <- tryCatch(
      validated_pairs_cached(),
      error = function(e)
        NULL
    )
    if (is.null(pairs_check) || nrow(pairs_check) == 0 ||
        !all(pairs_check$status == "✅ matched")) {
      showModal(modalDialog(
        title = "Cannot run batch",
        p("All file pairs must be matched and valid before running."),
        p("Check the table above for rows marked ❌ or ⚠️."),
        easyClose = TRUE
      ))
      return(NULL)
    }
    
    batch_failures(character(0))
    
    req(validated_pairs_cached(),
        nrow(validated_pairs_cached()) > 0)
    
    pairs_val      <- validated_pairs_cached()
    n              <- nrow(pairs_val)
    batch_start_time <- Sys.time()
    old_plan       <- if (requireNamespace("future", quietly = TRUE))
      future::plan()
    else
      NULL
    
    params <- list(
      hrs        = input$batch_hrs,
      interval   = input$batch_interval / 60,
      minod      = input$batch_minod,
      maxod      = input$batch_maxod,
      instrument = input$batch_instrument,
      blank_mode = if (input$batch_instrument == "ocelloscope") {
        "none"
      } else {
        input$batch_blank_mode
      }
    )
    
    gc_silent(gc_log_block("RUN BATCH START", list(n = n, params = params)))
    
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    batch_tag <- if (nzchar(input$batch_prefix)) {
      paste0(timestamp, "_", input$batch_prefix, "_batch")
    } else {
      paste0(timestamp, "_batch")
    }
    root_path <- file.path(wd_path(), "Analysis", batch_tag)
    batch_root(root_path)
    
    app_locked(TRUE)
    
    # ── Single source of truth ──────────────────────────────────────────────────
    bs <- new.env(parent = emptyenv())
    bs$queue     <- as.list(seq_len(n))   # plates yet to launch
    bs$running   <- 0L                    # plates currently in flight
    bs$completed <- 0L                    # plates fully done (success or fail)
    bs$aborted   <- FALSE                 # latched TRUE on first failure
    bs$failures  <- character(0)          # collected synchronously
    bs$finished  <- FALSE                 # finish_batch called exactly once
    # ────────────────────────────────────────────────────────────────────────────
    
    workers <- if (isTRUE(input$batch_parallel) &&
                   batch_can_parallel())
      2L
    else
      1L
    
    if (workers > 1 && !inherits(future::plan(), "multisession")) {
      future::plan(future::multisession, workers = workers)
    }
    
    if (requireNamespace("future", quietly = TRUE)) {
      if (workers > 1L) {
        future::plan(future::multisession, workers = workers)
      } else {
        future::plan(future::sequential)
      }
    }
    
    progress <- Progress$new(session, min = 0, max = n)
    batch_state$progress_open <- TRUE
    tryCatch(
      progress$set(
        message = "Batch analysis running",
        detail = "Starting…",
        value = 0
      ),
      error = function(e)
        NULL
    )
    
    # ── maybe_finish: called after every plate completes ───────────────────────
    maybe_finish <- function() {
      if (bs$running > 0 || length(bs$queue) > 0)
        return()
      if (bs$finished)
        return()
      bs$finished <- TRUE
      
      gc_log_block("BATCH FINISH STATE",
                   list(
                     completed = bs$completed,
                     failures  = bs$failures
                   ))
      
      later::later(function() {
        tryCatch({
          # ── Only attempt cleanup if every plate failed ──
          all_failed <- (length(bs$failures) == n)
          
          finish_batch(
            completed_val    = bs$completed,
            n                = n,
            root_path        = root_path,
            batch_start_time = batch_start_time,
            progress         = progress,
            old_plan         = old_plan,
            failures         = bs$failures,
            all_failed       = all_failed
          )
          
          shiny::withReactiveDomain(session, {
            batch_failures(bs$failures)
            app_locked(FALSE)
          })
          
        }, error = function(e) {
          gc_log_block("MAYBE_FINISH ERROR", conditionMessage(e))
        })
      }, delay = 0)
    }
    
    # ── launch_next: schedules the next plate, respecting abort + concurrency ──
    launch_next <- function() {
      gc_log(
        "Queue:",
        length(bs$queue),
        "| Running:",
        bs$running,
        "| Completed:",
        bs$completed
      )
      
      if (bs$aborted || length(bs$queue) == 0) {
        # If everything that was running has now finished, wrap up
        if (bs$running == 0)
          maybe_finish()
        return()
      }
      
      if (bs$running >= workers) {
        later::later(launch_next, delay = 0.2)
        return()
      }
      
      i         <- bs$queue[[1]]
      bs$queue  <- if (length(bs$queue) > 1)
        bs$queue[-1]
      else
        list()
      bs$running <- bs$running + 1L
      
      tryCatch(
        progress$set(
          value  = bs$completed,
          detail = paste("Completed", bs$completed, "of", n, "| Running plate", i)
        ),
        error = function(e)
          NULL
      )
      
      run_one_plate_future(
        i         = i,
        pairs_val = pairs_val,
        params    = params,
        root_path = root_path,
        bs        = bs,
        # pass the env directly — no closure capture issues
        session   = session,
        progress  = progress,
        n         = n,
        launch_next_fn = launch_next,
        maybe_finish_fn = maybe_finish
      )
    }
    
    launch_next()
  })
  
  
  # ── run_one_plate_future ──────────────────────────────────────────────────────
  # All mutable state lives in `bs` (the env passed in). No <<- needed.
  run_one_plate_future <- function(i,
                                   pairs_val,
                                   params,
                                   root_path,
                                   bs,
                                   session,
                                   progress,
                                   n,
                                   launch_next_fn,
                                   maybe_finish_fn) {
    future_globals <- list(
      i         = i,
      pairs_val = pairs_val,
      params    = params,
      root_path = root_path,
      region    = region_selected()
    )
    
    prom <- promises::future_promise(expr = {
      # ✅ Define quiet wrapper INSIDE worker
      gc_run_quiet <- if (!isTRUE(getOption("gc.dev_mode"))) {
        function(expr) {
          suppressWarnings(suppressMessages(expr))
        }
      } else {
        function(expr)
          expr
      }
      
      if (exists("gc_log") && isTRUE(getOption("gc.dev_mode"))) {
        try(gc_log(paste("Worker starting plate", i)), silent = TRUE)
      }
      
      tryCatch({
        source("growthcurve_system.R")
        source("growthcurve_functions.R")
        
        fname     <- basename(pairs_val$data_file[i])
        plate_tag <- tools::file_path_sans_ext(fname)
        plate_dir   <- file.path(root_path, plate_tag)
        plots_dir   <- file.path(plate_dir, "Plots")
        summary_dir <- file.path(plate_dir, "Summaries")
        
        # ── Paths defined above, but NO dir.create() yet ──
        
        res <- tryCatch({
          gc_run_quiet(
            run_gc(
              rawdatafile = pairs_val$data_file[i],
              designfile  = pairs_val$design_file[i],
              hrs         = params$hrs,
              interval    = params$interval,
              minod       = params$minod,
              maxod       = params$maxod,
              instrument  = params$instrument,
              blank_mode  = params$blank_mode,
              batch       = TRUE,
              prefix      = plate_tag,
              region      = region
            )
          )
        }, error = function(e) {
          list(
            success = FALSE,
            message = if (inherits(e, "gc_error")) {
              gc_get_message(e)
            } else {
              paste("Unexpected error:", gc_get_message(e))
            },
            plate   = pairs_val$data_file[i]
          )
        })
        
        if (!is.list(res) || is.null(res$plots)) {
          return(
            list(
              success = FALSE,
              message = res$message %||% "Run failed before producing valid output",
              plate   = pairs_val$data_file[i]
            )
          )
        }
        
        dir.create(root_path,
                   recursive = TRUE,
                   showWarnings = FALSE)
        
        # ── Analysis succeeded — now safe to create directories ──
        dir.create(plots_dir,
                   recursive = TRUE,
                   showWarnings = FALSE)
        dir.create(summary_dir,
                   recursive = TRUE,
                   showWarnings = FALSE)
        
        gc_save_plots(res$plots, plots_dir)
        gc_write_summaries(
          core        = res$core,
          params      = res$params,
          instrument  = res$instrument,
          summary_dir = summary_dir,
          region      = region
        )
        
        list(success = TRUE)
        
      }, error = function(e) {
        list(
          success = FALSE,
          message = paste("Fatal worker error:", conditionMessage(e)),
          plate   = pairs_val$data_file[i]
        )
      })
      
    },
    globals = future_globals,
    seed = TRUE)
    
    # ── then: plate finished (success or reported failure) ─────────────────────
    prom <- promises::then(prom, function(result) {
      if (exists("gc_log_block")) {
        try(gc_log_block(paste("Plate finished", i)), silent = TRUE)
      }
      
      tryCatch({
        bs$running   <- bs$running - 1L
        bs$completed <- bs$completed + 1L
        
        if (!isTRUE(result$success)) {
          # Latch abort, drain queue, record failure — all synchronous
          bs$aborted <- TRUE
          bs$queue   <- list()
          bs$failures <- c(bs$failures,
                           paste0("Plate ", i, ": ", result$message %||% "unknown error"))
          gc_log_block(paste("BATCH FAILURE plate", i), result$message)
        }
        
        tryCatch(
          progress$set(
            value  = bs$completed,
            detail = paste("Completed", bs$completed, "of", n)
          ),
          error = function(e)
            NULL
        )
        
        # Either launch the next plate or finish up
        if (!bs$aborted) {
          launch_next_fn()
        } else {
          maybe_finish_fn()
        }
        
      }, error = function(e) {
        gc_log_block("THEN HANDLER ERROR", conditionMessage(e))
        bs$aborted  <- TRUE
        bs$queue    <- list()
        bs$running  <- bs$running - 1L
        bs$failures <- c(bs$failures, paste0("Plate ", i, ": then-handler crash"))
        maybe_finish_fn()
      })
    })
    
    # ── catch: promise itself rejected (system/async error) ───────────────────
    prom <- promises::catch(prom, function(e) {
      gc_log_block(paste("ASYNC ERROR plate", i), conditionMessage(e))
      
      tryCatch({
        bs$running   <- bs$running - 1L
        bs$completed <- bs$completed + 1L
        bs$aborted   <- TRUE
        bs$queue     <- list()
        bs$failures  <- c(bs$failures,
                          paste0("Plate ", i, ": async system error — ", conditionMessage(e)))
        gc_log_block(paste("ASYNC SYSTEM ERROR plate", i),
                     conditionMessage(e))
        maybe_finish_fn()
      }, error = function(e2) {
        gc_log_block("CATCH HANDLER ERROR", conditionMessage(e2))
      })
    })
    
    invisible(prom)
  }
  
  observeEvent(input$prev_stage, {
    retreat_stage()
  })
  
  observeEvent(input$batch_design_select, {
    info <- input$batch_design_select
    i <- info$row
    v <- info$value
    
    df <- batch_pairs()
    
    new_path <- if (nzchar(v)) {
      file.path(input$batch_design_dir, v)
    } else {
      NA_character_
    }
    
    df$design_file[i] <- new_path
    batch_pairs(df)
  })
  
  
  observeEvent(input$how_to_stop, {
    showModal(
      modalDialog(
        title = "How to stop a running batch",
        tagList(
          p(
            "Once a batch has started, it cannot be cancelled from within the app. ",
            "The analysis will run to completion even if you close the browser tab."
          ),
          tags$hr(),
          p(strong("To stop a running batch:")),
          tags$ol(
            tags$li(
              "In RStudio, go to ",
              tags$strong("Session → Terminate R"),
              " to kill the process immediately."
            ),
            tags$li(
              "Alternatively, click the ",
              tags$strong("Stop"),
              " button (🟥) in the RStudio Console toolbar."
            ),
            tags$li(
              "As a last resort, press ",
              tags$strong("Ctrl+C"),
              " (Windows/Linux) or ",
              tags$strong("Cmd+C"),
              " (Mac) in the Console."
            )
          ),
          tags$hr(),
          p(
            style = "font-size: 0.9em; color: #888;",
            "Note: Any plates that finished before termination will have their ",
            "output files intact. Only the plate that was actively running at ",
            "the time of termination may be incomplete."
          )
        ),
        easyClose = TRUE,
        footer = modalButton("Close")
      )
    )
  })
  
  gc_disable_navigation <- function() {
    shinyjs::disable("prev_stage")
    shinyjs::disable("next_stage")
  }
  
  gc_enable_navigation <- function() {
    shinyjs::enable("prev_stage")
    shinyjs::enable("next_stage")
  }
  
  observeEvent(input$export_files, {
    req(analysis_result())
    res <- analysis_result()
    
    APP_CONFIG$region <- region_selected()
    
    gc_disable_navigation()
    
    try(on.exit(gc_enable_navigation(), add = TRUE), silent = TRUE)
    
    f <- res$params
    
    # Build output directories explicitly
    dirs <- make_export_dirs(wd = wd_path(), prefix = f$prefix)
    
    # Derive plate name from raw file
    fname <- tools::file_path_sans_ext(input$raw_file)
    
    # Nest inside per-plate folder
    analysis_dir <- file.path(dirs$analysis_dir, fname)
    
    plots_dir   <- file.path(analysis_dir, "Plots")
    summary_dir <- file.path(analysis_dir, "Summaries")
    
    last_export_dir(dirs$analysis_dir)
    
    # --- Safety: never overwrite an existing analysis ---
    if (dir.exists(plots_dir) || dir.exists(summary_dir)) {
      showModal(modalDialog(
        title = "Export aborted",
        tagList(
          p("An export with this prefix already exists."),
          tags$code(basename(plots_dir))
        ),
        easyClose = TRUE
      ))
      return()
    }
    
    withProgress(message = "Exporting analysis files", value = 0, {
      incProgress(0.2, "Creating directories")
      
      dir.create(plots_dir,
                 recursive = TRUE,
                 showWarnings = FALSE)
      dir.create(summary_dir,
                 recursive = TRUE,
                 showWarnings = FALSE)
      
      incProgress(0.5, "Saving plots")
      
      gc_save_plots(plots     = res$plots, plots_dir = plots_dir)
      
      incProgress(0.8, "Writing summary tables")
      
      gc_write_summaries(
        core        = res$core,
        params      = res$params,
        instrument  = res$instrument,
        summary_dir = summary_dir,
        region      = region_selected()
      )
      
      incProgress(1)
    })
    
    pretty_path <- tryCatch(
      pretty_export_path(analysis_dir),
      error = function(e)
        analysis_dir
    )
    
    showModal(
      modalDialog(
        title = "Export complete",
        tagList(
          p("Analysis files were written to:"),
          tags$div(
            style = "margin-top: 6px;",
            tags$code(style = "color: #1f78b4; font-size: 0.95em;", pretty_path)
          )
        ),
        easyClose = TRUE,
        footer = tagList(
          actionButton("open_export_dir", "📂 Open export folder", class = "btn-primary"),
          modalButton("Close")
        )
      )
    )
  })
  
  observeEvent(input$open_export_dir, {
    req(last_export_dir())
    
    success <- open_folder(last_export_dir())
    
    if (!isTRUE(success)) {
      showNotification("Could not open folder automatically. Please open it manually.",
                       type = "warning")
    }
  })
  
  observe({
    if (!is.null(analysis_result())) {
      shinyjs::disable("run")
      shinyjs::disable("hrs")
      shinyjs::disable("interval_min")
      shinyjs::disable("minod")
      shinyjs::disable("maxod")
      shinyjs::disable("prefix")
      shinyjs::disable("design_vars")
      shinyjs::disable("blank_mode")
      shinyjs::disable("raw_file")
      shinyjs::disable("design_file")
      shinyjs::disable("instrument")
    }
  })
  
  observe({
    ready <-
      wd_set() &&
      nzchar(input$raw_file %||% "") &&
      nzchar(input$design_file %||% "") &&
      !identical(input$raw_file, input$design_file) &&
      length(input$design_vars %||% character(0)) > 0 &&
      is.null(analysis_result())
    
    if (ready) {
      shinyjs::enable("run")
    } else {
      shinyjs::disable("run")
    }
    
  })
  
  observeEvent(input$run_aggregate, {
    req(selected_runs())
    
    withProgress(message = "Combining runs...", value = 0, {
      incProgress(0.2, "Collecting files...")
      
      df <- selected_runs()
      dup_map <- duplicate_info()$duplicate_map
      
      if (length(dup_map) > 0) {
        showModal(
          modalDialog(
            title = "Overlapping plate data detected",
            
            tagList(
              p("Some selected runs contain overlapping plate data."),
              p("This may result in duplicated observations."),
              
              p(strong("Overlapping plates across runs:")),
              
              tags$ul(lapply(names(dup_map), function(plate) {
                tags$li(tagList(tags$strong(plate), tags$ul(lapply(
                  dup_map[[plate]], tags$li
                ))))
                
              })),
              
              p("Consider excluding one of the overlapping runs.")
            ),
            
            easyClose = TRUE
          )
        )
      }
      
      incProgress(0.5, "Reading summaries...")
      
      combined <- combine_tidy_files(df)
      
      if (is.null(combined) || nrow(combined) == 0) {
        showModal(
          modalDialog(
            title = "No data found",
            "No plate_tidy.csv files were detected in the selected runs.",
            easyClose = TRUE
          )
        )
        
        return()
      }
      
      incProgress(0.9, "Finalizing...")
      
      agg_result(combined)
      
      incProgress(1)
    })
    
  })
  
  observeEvent(input$export_agg, {
    req(agg_result(), input$agg_dir)
    
    APP_CONFIG$region <- region_selected()
    
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    
    out_file <- file.path(input$agg_dir,
                          paste0("combined_tidy_", timestamp, ".csv"))
    
    write_csv_safe(agg_result(), out_file, region = region_selected())
    
    pretty_path <- tryCatch(
      pretty_export_path(out_file),
      error = function(e)
        out_file
    )
    
    showModal(
      modalDialog(
        title = "Export complete",
        
        tagList(
          p("Combined dataset was written to:"),
          tags$div(
            style = "margin-top: 6px;",
            tags$code(style = "color: #1f78b4; font-size: 0.95em;", pretty_path)
          )
        ),
        
        easyClose = TRUE,
        
        footer = tagList(
          actionButton("open_agg_dir", "📂 Open containing folder", class = "btn-primary"),
          modalButton("Close")
        )
      )
    )
  })
  
}


app <- shiny::shinyApp(ui = ui, server = server)
app
