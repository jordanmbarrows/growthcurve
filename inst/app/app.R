# ============================================================
# app.R
# Growth Curve Shiny App - UI and Server Orchestration
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
# [!]  CSV PARSING RULE
#
# All CSV reading MUST go through read_csv_safe().
# No direct read.csv(), read.table(), or delimiter detection allowed.
#
# All CSV output MUST go through write_csv_safe().
# Do NOT use write.csv() or write.table() directly,
# or regional formatting will break.
# ============================================================

library(growthcurve)

guide_summary_style <- function() {
  "
  cursor: pointer;
  padding: 6px 8px;
  margin-top: 6px;
  border-radius: 4px;
  font-weight: 600;
  "
}

guide_body_style <- function() {
  "padding: 10px 4px;"
}

guide_note_style <- function() {
  "font-size: 0.9em; color: inherit;"
}

# ---- UI ----
ui <- shiny::fluidPage(
  shinyjs::useShinyjs(),
  theme = bslib::bs_theme(version = 3),
  
  tags$head(
    tags$style(HTML("
    /* ---- Details summary (light/dark) ---- */
      details summary {
        background-color: rgba(0,0,0,0.04);
        padding: 6px 8px;
        border-radius: 4px;
      }
      details summary:hover { background-color: rgba(0,0,0,0.12); }

      /* bslib data-bs-theme dark */
      :root[data-bs-theme='dark'] details summary       { background-color: rgba(255,255,255,0.12); }
      :root[data-bs-theme='dark'] details summary:hover { background-color: rgba(255,255,255,0.18); }

      /* html.dark-mode class (set via JS) */
      html.dark-mode details summary       { background-color: #3c3c3c !important; }
      html.dark-mode details summary:hover { background-color: #4e4e4e !important; }

    /* ---- Details spacing ---- */
      details { margin-bottom: 16px; }

    /* ---- Shiny progress ---- */
      .shiny-progress .modal-dialog { max-width: 300px; }

    /* ---- Stage nav buttons ---- */
      .stage-nav .btn { margin-right: 6px; min-width: 110px; }
      .stage-nav .btn.disabled, .stage-nav .btn:disabled { opacity: 0.5; cursor: not-allowed; }

    /* ---- DT select inputs ---- */
      .dataTables_wrapper select.form-control {
        border-radius: 4px; border: 1px solid #ccc;
      }
      .dataTables_wrapper select.form-control:focus {
        border-color: #66afe9; outline: 0;
        box-shadow: inset 0 1px 1px rgba(0,0,0,.075), 0 0 8px rgba(102,175,233,.6);
      }

    /* ---- Batch design select ---- */
      .batch-design-select {
        width: 100%; padding: 4px 6px; font-size: 12px;
        border: 1px solid rgba(100,100,100,0.5); border-radius: 4px;
        background-color: inherit; color: inherit;
        transition: border-color 0.2s, box-shadow 0.2s;
      }
      .batch-design-select:hover { border-color: #999; }
      .batch-design-select:focus {
        border-color: #66afe9; outline: 0;
        box-shadow: inset 0 1px 1px rgba(0,0,0,.075), 0 0 6px rgba(102,175,233,.6);
        background-color: #f8fbff;
      }
      .batch-design-select:disabled { background-color: #f5f5f5; color: #999; cursor: not-allowed; }
      .batch_match_table td { padding-top: 6px !important; padding-bottom: 6px !important; }
      html.dark-mode .batch-design-select {
        background-color: #2d2d2d !important; color: #d4d4d4 !important;
        border: 1px solid rgba(255,255,255,0.5); border-color: #555 !important;
      }

    /* ---- Column header tooltips ---- */
      th span[title] { cursor: help; text-decoration: underline dotted; }

    /* ---- Batch flex layout ---- */
      .batch-flex { display: flex; min-width: 0; align-items: stretch; gap: 24px; margin-bottom: 40px; }
      .batch-left { flex: 1 1 0; min-width: 0; max-width: 100%; overflow: visible; }      
      .batch-left .dataTables_wrapper { width: 100% !important; overflow-x: auto; }
      @media (max-width: 1200px) {
        .batch-flex { flex-direction: column; align-items: stretch; }
        .batch-left { min-width: 100%; max-width: 100%; overflow: visible; }
        .batch-right { max-width: 100%; flex: 0 0 auto; }
      }

    /* ---- Aggregate runs table ---- */
      #agg_runs_table_outer {
        width: 100%;
        max-height: 600px;
        overflow-x: auto;
        overflow-y: auto;
      }
      #agg_runs_table_container {
        min-width: max-content;
        overflow: visible;
      }
      #agg_runs_table table.dataTable { table-layout: auto !important; }
      #agg_runs_table th:first-child, #agg_runs_table td:first-child {
        width: 60px !important; min-width: 60px !important; max-width: 60px !important;
        text-align: left !important; padding-left: 8px !important;
      }
      #agg_runs_table th:nth-child(2), #agg_runs_table td:nth-child(2) {
        min-width: 300px !important;
      }
      #agg_runs_table th:nth-child(3), #agg_runs_table td:nth-child(3) {
        min-width: 220px !important; white-space: nowrap; font-family: monospace;
      }
     
      .dup-hover:hover + .dup-tooltip {
        display: block;
      }
      .dup-tooltip {
        display: none;
        position: absolute;
        z-index: 1000;
        background: #1e1e1e;
        color: #d4d4d4;
        padding: 10px;
        border-radius: 6px;
        border: 1px solid #444;
        max-width: 600px;
        overflow-x: auto;
        white-space: pre;   /* NO wrapping */
        font-size: 12px;
      }
      table.dataTable {
        width: auto !important;
      }
      table.dataTable td {
        white-space: nowrap;
      }

    /* ---- Guide / user guide styles ---- */
      .guide-container { max-width: 900px; margin: 0; padding: 20px; }
      .guide-container pre { background: #f6f8fa; padding: 12px; border-radius: 8px; overflow-x: auto; font-family: monospace; font-size: 13px; }
      .guide-container h3 { margin-top: 28px; }
      #user_guide_ui h3 { margin-top: 20px; }
      #user_guide_ui hr { margin-top: 10px; margin-bottom: 15px; }
      .guide-note { opacity: 0.8; }
      :root[data-bs-theme='dark'] .guide-note { opacity: 0.9; }
      html.dark-mode .guide-container pre { background: #2d2d2d !important; }

    /* ---- Design example table ---- */
      #design_example_table table { table-layout: fixed; }
      #design_example_table td { min-width: 70px; text-align: center; }

    /* ---- Preview table ---- */
      .preview-table table {
        font-size: 12px; border-collapse: collapse; table-layout: fixed !important;
        white-space: nowrap; width: max-content;
      }
      .preview-table td, .preview-table th {
        padding: 4px 6px; min-width: 70px; max-width: 70px;
        text-align: center; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
      }
      .preview-table table.expanding td, .preview-table table.expanding th {
        min-width: 90px; max-width: none;
      }
      .preview-table-fixed-rows table tr { height: 24px; }
      html.dark-mode .preview-table table { background-color: #252526; }

    /* ---- Design preview table (dark mode gridlines) ---- */
      :root[data-bs-theme='dark'] .design-preview-table td,
      :root[data-bs-theme='dark'] .design-preview-table th {
        border-color: rgba(255,255,255,0.15) !important;
      }
      :root[data-bs-theme='dark'] .design-preview-table tr {
        border-top-color: rgba(255,255,255,0.25) !important;
      }

    /* ---- Tabs ---- */
      .nav-tabs > li > a { background-color: transparent; color: inherit; }
      .nav-tabs > li.active > a, .nav-tabs > li.active > a:hover {
        background-color: rgba(0,0,0,0.08); color: inherit;
      }
      html.dark-mode .nav-tabs > li.active > a { background-color: rgba(255,255,255,0.08); }

    /* ---- Well panel ---- */
      .well { background-color: rgba(0,0,0,0.03); border: 1px solid rgba(0,0,0,0.1); }
      html.dark-mode .well { background-color: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.1); }

    /* ---- Dark mode: fix hardcoded color styles ---- */
      html.dark-mode .text-muted,
      html.dark-mode p[style*='color'],
      html.dark-mode span[style*='color'] { color: inherit !important; }

    /* ---- Dark mode: modals, DT, tooltips ---- */
      html.dark-mode .modal-content { background-color: #252526; color: #d4d4d4; }
      html.dark-mode .dataTables_wrapper { color: #d4d4d4; }
      html.dark-mode .dataTables_wrapper .dataTables_paginate .paginate_button { color: #d4d4d4 !important; }
      html.dark-mode .tooltip-inner { background-color: #333; color: #fff; }

    /* ---- Dark toggle ---- */
      .dark-toggle { display: flex; align-items: center; gap: 6px; cursor: pointer; user-select: none; }
      .dark-toggle input[type='checkbox'] {
        display: block; margin-top: 2px;
        appearance: none; width: 36px; height: 18px;
        background: #ccc; border-radius: 10px;
        position: relative; outline: none; cursor: pointer; transition: background 0.2s;
      }
      .dark-toggle input[type='checkbox']::after {
        content: ''; width: 14px; height: 14px; background: white;
        border-radius: 50%; position: absolute; top: 2px; left: 2px; transition: transform 0.2s;
      }
      .dark-toggle input[type='checkbox']:checked { background: #4fc1ff; }
      .dark-toggle input[type='checkbox']:checked::after { transform: translateX(18px); }
      .toggle-label { font-size: 13px; }
    ")),
    tags$script(HTML("
  Shiny.addCustomMessageHandler('set_dark_class', function(on) {
    if (on) {
      document.documentElement.classList.add('dark-mode');
    } else {
      document.documentElement.classList.remove('dark-mode');
    }
  });
"))
  ),
  
  
  
  shiny::tagList(if (!gc_backend_ready()) {
    shiny::verbatimTextOutput("startup_error")
    
  } else {
    shiny::tagList(
      titlePanel(
        div(
          style = "display:flex; justify-content: space-between; align-items: center;",
          
          div(
            "Growth Curve Analysis",
            uiOutput("dev_badge")
          ),
          div(
            class = "dark-toggle",
            
            tags$input(
              type = "checkbox",
              id = "dark_mode"
            ),
            
            tags$label(
              `for` = "dark_mode",
              class = "toggle-label",
              HTML("&#127769;&#65039; Dark")
            )
          )
        )
      )
      ,
      
      wellPanel(
        h4("Working directory"),
        textInput(
          "wd",
          "Working directory path",
          value = if (gc_dev_mode())
            "C:/Users/Jordan/Desktop/UmU/Lind Lab/Shiny app development/Old stuff/dev/Dummy data"
          else
            ""
        ),
        actionButton("set_wd", "Set working directory"),
        actionButton("refresh_files", "Refresh files"),
        shiny::verbatimTextOutput("wd_txt"),
        
        tags$details(
          tags$summary(
            style = guide_summary_style(),
           HTML("&#8505;&#65039; What folder should I select?")
          ),
          tags$div(
            style = "padding: 8px 4px;",
            tags$ul(
              tags$li(strong("RStudio:"), HTML(" Files tab -> &#9881;&#65039; -> Copy Path to Clipboard")),
              tags$li(
                strong("Windows:"),
                " Address bar -> Ctrl + C (or Shift + Right-click -> Copy as path)"
              ),
              tags$li(strong("macOS:"), " Option + Right-click -> Copy as Pathname"),
              tags$li(strong("Linux:"), " Right-click -> Copy Path / Copy Location")
            ),
            tags$p(
              "Paste the path above and click ",
              tags$strong("Set working directory"),
              ". Quoted paths are OK."
            )
          )
        ),
        
        tags$hr(),
        
        h4("Export format"),
        
        radioButtons(
          "region_override",
          label = NULL,
          choices = c(
            "US (1.23, CSV uses comma)" = "US",
            "European (1,23, CSV uses semicolon)" = "EU"
          ),
          selected = gc_app_config()$region,
          inline = TRUE
        ),
        
        tags$p(
          style = guide_note_style(),
          class = "guide-note",
          "Controls how preview tables are displayed and how exported CSV files and plots are formatted."
        ),
        
        tags$p(
          style = guide_note_style(),
          class = "guide-note",
          "Note: Decimal points in preview are converted based on the selected format and may also affect numeric-looking identifiers."
        )
      ),
      
      tabsetPanel(
        tabPanel("User Guide", div(uiOutput("user_guide_ui"))),
        tabPanel("Single Plate", uiOutput("single_ui")),
        tabPanel(
          "Batch Processing",
          
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
              tags$summary(style = guide_summary_style(), HTML("&#8505;&#65039; Directory requirements")),
              tags$div(style = guide_body_style(), tags$ul(
                tags$li("Each raw data file must match exactly one design file."),
                tags$li("Matching is based on a shared identifier in filenames."),
                tags$li("Each pair is processed independently."),
                tags$li("If one plate fails, others will still complete.")
              ))
            ),
            
            selectInput("batch_data_dir", "Raw data directory", choices = NULL),
            
            tags$details(
              tags$summary(style = guide_summary_style(), HTML("&#128065; Preview raw data (first file)")),
              tags$div(
                style = guide_body_style(),
                textOutput("batch_preview_label"),
                uiOutput("batch_raw_preview_ui")
              )
            ),
            
            selectInput("batch_design_dir", "Design file directory", choices = NULL),
            
            tags$details(
              tags$summary(style = guide_summary_style(), HTML("&#129516; Preview design file (first pair)")),
              tags$div(style = guide_body_style(), div(
                class = "preview-table", uiOutput("batch_design_preview")
              ))
            ),
          ),
          
          uiOutput("batch_ui")  # rest of UI
        ),
        tabPanel(
          "Aggregate Results",
          
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
      # Debug panel (dev mode only)
      uiOutput("debug_panel"),
      
      # ---- App version footer ----
      div(
        style = "
    position: fixed;
    bottom: 6px;
    right: 10px;
    font-size: 11px;
    color: #888;
    z-index: 9999;
    cursor: default;
  ",
        paste0("GrowthCurve v", gc_app_version())
      )
    )
  }))

# ---- server ----
server <- function(input, output, session) {
  
  # =========================================================
  # growthcurve namespace aliases (stability layer)
  # =========================================================
  
  # --- Data ---
  gc_instrument_defaults <- growthcurve:::gc_instrument_defaults
  
  # --- Logging ---
  gc_log_block    <- growthcurve:::gc_log_block
  gc_log          <- growthcurve:::gc_log
  gc_get_message  <- growthcurve:::gc_get_message
  gc_format_error <- growthcurve:::gc_format_error
  
  # --- Runtime ---
  gc_dev_mode       <- growthcurve:::gc_dev_mode
  gc_check_packages <- growthcurve:::gc_check_packages
  
  # --- Core analysis ---
  run_gc             <- growthcurve:::run_gc
  gc_save_report     <- growthcurve:::gc_save_report
  gc_write_summaries <- growthcurve:::gc_write_summaries
  
  # --- File I/O ---
  read_csv_safe     <- growthcurve:::read_csv_safe
  write_csv_safe    <- growthcurve:::write_csv_safe
  read_preview_file <- growthcurve:::read_preview_file
  
  # --- Parsing / preview ---
  extract_design_blocks <- growthcurve:::extract_design_blocks
  build_preview         <- growthcurve:::build_preview
  build_preview_label   <- growthcurve:::build_preview_label
  
  # --- Utilities ---
  pretty_export_path       <- growthcurve:::pretty_export_path
  open_folder              <- growthcurve:::open_folder
  gc_abort                 <- growthcurve:::gc_abort
  enforce_blank_mode_state <- growthcurve:::enforce_blank_mode_state
  gc_app_version           <- growthcurve:::gc_app_version
  
  
  light_theme <- bslib::bs_theme(
    version = 3,
    bg = "#ffffff",
    fg = "#222222",
    primary = "#337ab7"
  )
  
  dark_theme <- bslib::bs_theme(
    version = 3,
    bg = "#1e1e1e",
    fg = "#d4d4d4",
    primary = "#5fd7ff",   # slightly brighter
    success = "#4caf50",   # brighten green
    warning = "#ffb74d",   # optional
    danger  = "#ef5350"    # optional
  )
  
  gc_run_quiet <- function(expr) {
    if (gc_dev_mode()) return(expr)
    
    zz <- file(tempfile(), open = "wt")
    sink(zz)
    sink(zz, type = "message")
    
    on.exit({
      sink(type = "message")
      sink()
      close(zz)
    }, add = TRUE)
    
    withCallingHandlers(
      suppressWarnings(suppressMessages(expr)),
      warning = function(w) invokeRestart("muffleWarning"),
      message = function(m) invokeRestart("muffleMessage")
    )
  }
  
  gc_silent <- function(expr) {
    if (gc_dev_mode()) return(expr)
    
    sink(tempfile())
    on.exit(sink(), add = TRUE)
    
    suppressWarnings(suppressMessages(expr))
  }
  
  quiet <- function(expr) {
    if (gc_dev_mode()) expr else suppressWarnings(suppressMessages(expr))
  }
  
  `%||%` <- function(a, b)
    if (!is.null(a))
      a
  else
    b
  
  output$startup_error <- shiny::renderText({
    if (exists("gc_startup_error", envir = .GlobalEnv)) {
      paste("Startup error:\n", gc_startup_error)
    } else {
      ""
    }
  })
  
  observe({
    session$sendCustomMessage(
      "set_dark_class",
      isTRUE(input$dark_mode)
    )
  })
  
  #Debug panel; add options here as desired
  
  output$debug_panel <- renderUI({
    if (!gc_dev_mode()) return(NULL)
    
    tags$div(
      style = "
      margin-top: 20px;
      padding: 12px;
      background-color: #f5f5f5;
      border: 1px solid #ccc;
      border-radius: 6px;
      font-size: 12px;
    ",
      
      tags$h4(HTML("&#128295; Debug Panel")),
      
      tags$strong("Working directory:"), br(),
      verbatimTextOutput("dbg_wd"),
      
      tags$strong("Dev mode:"), br(),
      verbatimTextOutput("dbg_dev"),
      
      tags$strong("Selected files:"), br(),
      verbatimTextOutput("dbg_files")
    )
  })
  
  output$dbg_wd <- renderPrint({
    wd_path()
  })
  
  output$dbg_dev <- renderPrint({
    getOption("gc.dev_mode")
  })
  
  output$dbg_files <- renderPrint({
    list(
      raw = input$raw_file,
      design = input$design_file
    )
  })
  
  output$dev_badge <- renderUI({
    if (!gc_dev_mode()) return(NULL)
    
    tags$div(
      "DEV MODE",
      style = "
      color: white;
      background-color: #d9534f;
      padding: 4px 8px;
      border-radius: 4px;
      font-size: 12px;
      display: inline-block;
      margin-left: 10px;
    "
    )
  })
  
  options(
    shiny.error = function(e = NULL) {
      
      msg <- tryCatch(
        if (!is.null(e)) conditionMessage(e) else "Unknown shiny error (no condition)",
        error = function(...) "Failed to extract error message"
      )
      
      gc_silent(
        gc_log_block(
          "SHINY ERROR",
          list(
            message   = msg,
            callstack = try(sys.calls(), silent = TRUE)
          )
        )
      )
    }
  )
  
  options(
    promises.onRejected = function(e = NULL) {
      
      msg <- tryCatch(
        if (!is.null(e)) conditionMessage(e) else "Unknown async error (no condition)",
        error = function(...) "Failed to extract error message"
      )
      
      gc_log_block(
        "GLOBAL PROMISE REJECTION",
        list(
          message   = msg,
          callstack = try(sys.calls(), silent = TRUE)
        )
      )
      
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
  
  region_selected <- reactive({input$region_override %||% gc_app_config()$region})
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
  
  observe({
    session$setCurrentTheme(
      if (isTRUE(input$dark_mode)) dark_theme else light_theme
    )
  })
  
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
  
  output$region_detected_txt <- shiny::renderText({
    region <- region_selected()
    
    if (region == "EU") {
      "European (semicolon, decimal comma)"
    } else {
      "US (comma, decimal point)"
    }
  })
  
  shiny::observe({
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
      enforce_blank_mode_state(session, input$batch_instrument, "batch")
    }
    
  })
  
  shiny::observe({
    req(input$instrument)
    enforce_blank_mode_state(session, input$instrument)
  })
  
  shiny::observe({
    req(input$batch_instrument)
    enforce_blank_mode_state(session, input$batch_instrument, "batch")
  })
  
  shiny::observe({
    if (wd_set()) {
      shinyjs::show("batch_controls")
      shinyjs::show("aggregate_controls")
    } else {
      shinyjs::hide("batch_controls")
      shinyjs::hide("aggregate_controls")
    }
  })
  
  output$batch_gate <- shiny::renderUI({
    if (wd_set())
      return(NULL)
    
    tags$div(style = "padding: 20px; border-radius: 6px;",
             h4("Batch processing"),
             p("Please set a working directory to continue."))
    
  })
  
  output$aggregate_gate <- shiny::renderUI({
    if (wd_set())
      return(NULL)
    
    tags$div(style = "padding: 20px; border-radius: 6px;",
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
  
  format_preview_df <- function(df, region) {
    
    if (is.null(df) || !is.data.frame(df)) {
      return(df)
    }
    
    df_out <- df
    
    df_out[] <- lapply(df_out, function(col) {
      
      # ---- STEP 1: convert EVERYTHING to character safely ----
      
      if (is.numeric(col)) {
        
        # force decimal representation (NO scientific notation)
        col_chr <- format(
          col,
          scientific = FALSE,
          trim = TRUE
        )
        
      } else {
        col_chr <- as.character(col)
      }
      
      # ---- STEP 2: apply EU decimal conversion ----
      
      if (region == "EU") {
        col_chr <- gsub(
          "(?<=\\d)\\.(?=\\d)",
          ",",
          col_chr,
          perl = TRUE
        )
      }
      
      col_chr
    })
    
    df_out
  }
  
  observeEvent(TRUE, {
    later::later(function() {
      shiny::withReactiveDomain(session, {
        current_version <- gc_app_version()
        
        info <- tryCatch(
          suppressWarnings(
            check_for_updates(current_version, "jordanmbarrows/growthcurve")
          ),
          error = function(e) NULL
        )
        
        if (!is.null(info) && info$has_update) {
          showModal(modalDialog(
            title = paste0("Update available (v", info$latest, ")"),
            tags$p("A new version of growthcurve is available."),
            tags$ol(
              tags$li("Dismiss this dialog and close the app."),
              tags$li(HTML("Restart your R session: in RStudio, click <strong>Session</strong> in the top menu, then <strong>Restart R</strong>. If you are not using RStudio, close and reopen R.")),
              tags$li("Paste the following into your R console and press Enter:"),
              tags$pre(sprintf(
                'if (!requireNamespace("remotes", quietly = TRUE))\n  install.packages("remotes")\nremotes::install_github("jordanmbarrows/growthcurve@v%s")',
                info$latest
              )),
              tags$li(HTML("Initialize the package by running: <code>library(growthcurve)</code>")),
              tags$li(HTML("Relaunch the app by running: <code>run_growthcurve()</code>"))
            ),
            footer = modalButton("Dismiss"),
            easyClose = TRUE
          ))
        }
      })
    }, delay = 2)
  }, once = TRUE)
  
  unwrap_preview <- function(res) {
    if (is.null(res))
      return(NULL)
    
    # NEW: detect backend preview_message
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
  
  preview_warning_box <- function(message) {
    div(
      style = "
        padding: 12px;
        background-color: #fef3cd;
        border: 1px solid #f0c040;
        border-radius: 6px;
        color: #5a4000;
        max-width: 600px;
      ",
      strong(HTML("&#9888; ")),
      message
    )
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
      analysis_dir = analysis_dir
    )
  }
  
  get_cancel_file <- function(root_path) {
    file.path(root_path, "_CANCEL_BATCH")
  }
  
  create_cancel_file <- function(root_path) {
    path <- get_cancel_file(root_path)
    file.create(path)
  }
  
  cancel_requested <- function(root_path) {
    file.exists(get_cancel_file(root_path))
  }
  
  clear_cancel_file <- function(root_path) {
    path <- get_cancel_file(root_path)
    if (file.exists(path)) file.remove(path)
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
                           all_failed,
                           successes,
                           all_plate_names,
                           region,
                           cancelled) {
    shiny::withReactiveDomain(session, {
      
      # --- determine status ----
      status <- "Yes"
      
      if (isTRUE(cancelled)) {
        status <- "Cancelled"
      } else if (isTRUE(all_failed)) {
        status <- "Failed"
      } else if (length(failures) > 0) {
        status <- "Completed with errors"
      }
      
      label_success <- if (status == "Cancelled") {
        "Processed before cancellation:"
      } else {
        "Successfully processed plate(s):"
      }
      
      processed <- unique(successes)
      not_processed <- setdiff(all_plate_names, processed)
      
      completed_str <- paste0(completed_val, " of ", n)
      
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
      
      clean_failures <- gsub("Unexpected error:\\s*", "", failures)
      
      # --- Build failure UI OUTSIDE modal ---
      failure_ui <- shiny::tagList()
      
      # successes
      if (length(successes) > 0) {
        failure_ui <- tagAppendChildren(
          failure_ui,
          p(strong(label_success)),
          tags$ul(lapply(successes, tags$li))
        )
      }
      
      label_remaining <- if (status == "Cancelled") {
        "Remaining plate(s):"
      } else {
        HTML(paste0(
          "The analysis could not be completed for the following plate(s). Please check that:
          <br><br>",
          "1. You have selected the correct instrument.<br>",
          "2. You have selected the correct input files.<br>",
          "3. Your input files are formatted correctly."
        ))
      }
      
      # failures
      if (length(not_processed) > 0) {
        failure_ui <- tagAppendChildren(
          failure_ui,
          tags$hr(),
          p(strong(label_remaining)),
          tags$ul(
            lapply(not_processed, function(x) {
              tags$li(tags$span(style = "color: #555;", x))
            })
          )
        )
      }
      
      if (length(successes) == 0) {
        if (completed_val > 0) {
          failure_ui <- tagList(
            p(
              HTML(paste0(
                "The analysis could not be completed. Please check that:
                <br><br>",
                "1. You have selected the correct instrument.<br>",
                "2. You have selected the correct input files.<br>",
                "3. Your input files are formatted correctly."
              ))
            )
          )
        } else {
          failure_ui <- p("No plates were processed.")
        }
      }
      
      pretty_path <- tryCatch(
        pretty_export_path(root_path),
        error = function(e = NULL)
          root_path
      )
      
      list_sep <- " | "
      
      processed_str <- if (length(successes) > 0)
        paste(successes, collapse = list_sep)
      else
        ""
      
      not_processed_str <- if (length(not_processed) > 0)
        paste(not_processed, collapse = list_sep)
      else
        ""
      
      # ---- write batch summary ----
      summary_df <- data.frame(
        Variable = c("Completed?", "Completed plates", "Successfully processed plates", "Not processed plates"),
        Value = c(status, completed_str, processed_str, not_processed_str),
        stringsAsFactors = FALSE
      )
      
      tryCatch({
        write_csv_safe(
          summary_df,
          file.path(root_path, "batch_run_summary.csv"),
          region = region
        )
      }, error = function(e) {
        gc_log_block("FAILED TO WRITE BATCH SUMMARY", conditionMessage(e))
      })
      
      if (status == "Cancelled") {
        label_success <- "Processed before cancellation:"
      } else {
        label_success <- "Successfully processed plates:"
      }
      
      showModal(
        modalDialog(
          title = switch(
            status,
            "Cancelled" = "Batch cancelled",
            "Failed"    = "Batch failed",
            "Completed with errors" = "Batch completed with errors",
            "Batch analysis complete"
          ),
          
          shiny::tagList(
            failure_ui,
            
            tags$hr(),
            
            p(paste("Total runtime:", elapsed_str)),
            
            if (!all_failed && dir.exists(root_path))
              shiny::tagList(
                p("Results were written to:"),
                tags$div(
                  style = "margin-top: 6px;",
                  tags$code(style = "color: #1f78b4; font-size: 0.95em;", pretty_path)
                )
              )
          ),
          
          easyClose = TRUE,
          
          footer = shiny::tagList(if (!all_failed &&
                                      dir.exists(root_path)) {
            actionButton("open_batch_dir", HTML("&#128193; Open output folder"), class = "btn-primary")
          }, modalButton("Close"))
        )
      )
      
      clear_cancel_file(root_path)
      
      # --- Restore future plan ---
      if (!is.null(old_plan) &&
          requireNamespace("future", quietly = TRUE)) {
        future::plan(old_plan)
      }
      
    })
  }
  
  open_folder_or_warn <- function(path) {
    success <- open_folder(path)
    if (!isTRUE(success))
      showNotification("Could not open folder automatically. Please open it manually.", type = "warning")
  }
  
  shiny::observeEvent(input$open_batch_dir, {
    req(batch_root())
    open_folder_or_warn(batch_root())
  })
  
  shiny::observeEvent(input$open_agg_dir, {
    req(input$agg_dir)
    open_folder_or_warn(input$agg_dir)
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
  
  get_plate_folder <- function(file_path) {
    d1 <- basename(dirname(file_path))
    
    # Old structure: immediate parent is something generic (e.g., Summaries/)
    # New structure: immediate parent IS the plate
    
    if (tolower(d1) %in% c("outputs", "output", "results", "summaries", "plots")) {
      return(basename(dirname(dirname(file_path))))
    } else {
      return(d1)
    }
  }
  
  get_run_folder <- function(file_path) {
    d1 <- basename(dirname(file_path))
    
    if (tolower(d1) %in% c("outputs", "output", "results", "summaries", "plots")) {
      return(basename(dirname(dirname(dirname(file_path)))))
    } else {
      return(basename(dirname(dirname(file_path))))
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
        error = function(e = NULL)
          NULL
      )
      if (is.null(df))
        return(NULL)
      
      # FIX: normalize column types BEFORE anything else
      df[] <- lapply(df, as.character)
      
      # EXISTING metadata
      df$source_file <- basename(f)
      df$plate_ <- get_plate_folder(f)
      df$run_name <- get_run_folder(f)
      df$prefix <- if ("prefix" %in% names(df)) df$prefix else ""
      
      meta_cols <- c("source_file", "run_name", "prefix", "instrument", "plate_", "Well")
      
      other_cols <- setdiff(names(df), meta_cols)
      
      df <- df[, c(meta_cols, other_cols), drop = FALSE]
      
      df
    })
    
    data_list <- Filter(Negate(is.null), data_list)
    
    if (length(data_list) == 0) {
      return(NULL)
    }
    
    df <- dplyr::bind_rows(data_list, .id = "file_index")
    
    core_cols <- c(
      "file_index",
      "source_file",
      "run_name",
      "prefix",
      "instrument",
      "plate_",
      "Well",
      "Measurement",
      "Value",
      "Replicate",
      "QC_flag",
      "QC_reason"
    )
    
    extra_cols <- setdiff(names(df), core_cols)
    
    pre_well <- setdiff(core_cols, c("Well", "Measurement", "Value", "Replicate", "QC_flag", "QC_reason"))
    pre_well <- intersect(pre_well, names(df))
    
    post_core <- intersect(c("Measurement", "Value", "Replicate", "QC_flag", "QC_reason"), names(df))
    
    new_order <- c(
      pre_well,
      "Well",
      extra_cols,
      post_core
    )
    
    df <- df[, new_order, drop = FALSE]
    
    df
    
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
      
      plate_folder <- vapply(files, get_plate_folder, character(1))
      
      tmp <- data.frame(
        run_name     = run_name,
        plate_file   = basename(files),
        plate_folder = plate_folder,
        size         = info$size,
        stringsAsFactors = FALSE
      )
      
      # --- Extract prefix from run_name ---
      extract_prefix <- function(run_name) {
        parts <- unlist(strsplit(run_name, "_", fixed = TRUE))
        
        # Remove empty pieces (handles double underscores)
        parts <- parts[nzchar(parts)]
        
        # Remove trailing type
        if (length(parts) > 0 && tail(parts, 1) %in% c("single", "batch")) {
          parts <- head(parts, -1)
        }
        
        # If only timestamp remains → no prefix
        if (length(parts) <= 2) {
          return("")
        }
        
        paste(parts[3:length(parts)], collapse = "_")
      }
      
      tmp$prefix <- extract_prefix(run_name)
      
      tmp$label <- ifelse(
        nzchar(tmp$prefix),
        paste(tmp$run_name, ">", tmp$plate_folder, "(", tmp$prefix, ")"),
        paste(tmp$run_name, ">", tmp$plate_folder)
      )
      
      clean_plate <- function(x) {
        x <- tolower(trimws(x))
        x <- sub(" - copy$", "", x)
        x <- gsub("\\s+", " ", x)   # collapse weird spacing
        x
      }
      
      tmp$group_key <- paste0(
        clean_plate(tmp$plate_folder),
        "||",
        tolower(trimws(tmp$prefix))
      )
      
      plate_records <- rbind(plate_records, tmp)
    }
    
    if (nrow(plate_records) == 0) {
      return(list(
        run_flags = setNames(rep(FALSE, nrow(run_df)), run_df$run_name),
        duplicate_plates = character(0)
      ))
    }
    
    # ---- Detect duplicated plates ----
    
    dup_idx <- duplicated(plate_records$group_key) |
      duplicated(plate_records$group_key, fromLast = TRUE)
    
    plate_records$duplicate_plate <- dup_idx
    
    duplicate_map <- split(
      plate_records$label[dup_idx],
      plate_records$group_key[dup_idx]
    )
    
    # Keep only true duplicates (appear in >1 place)
    duplicate_map <- duplicate_map[sapply(duplicate_map, length) > 1]
    
    duplicate_map <- lapply(duplicate_map, unique)
    
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
  
  output$design_example_table <- shiny::renderTable({
    df <- design_example()
    req(df)
    df <- format_preview_df(df, region_selected())
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
        error = function(e = NULL)
          character(0)
      )
      
      inferred_vars[[i]] <- vars
      design_ok[i] <- length(vars) > 0
    }
    
    # ---- Status logic ----
    status <- character(n)
    
    missing_data   <- is.na(df$data_file)   | df$data_file == ""
    missing_design <- is.na(df$design_file) | df$design_file == ""
    
    status[missing_data | missing_design] <- HTML("&#10060; unmatched")
    status[!missing_design & !design_ok]  <- HTML("&#10060; invalid design")
    
    dup_design <- duplicated(df$design_file) & !missing_design
    dup_design <- dup_design |
      duplicated(df$design_file, fromLast = TRUE)
    status[dup_design] <- HTML("&#9888;&#65039; duplicate design")
    
    status[status == ""] <- HTML("&#9989; matched")
    
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
    
    # DEBUG (safe: no side effects)
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
  
  shiny::observeEvent(input$install_no, {
    stopApp()
  })
  
  shiny::observeEvent(input$close_app_after_failed_install, {
    stopApp()
  })
  
  shiny::observeEvent(input$install_yes, {
    removeModal()
    
    pkgs_before <- gc_check_packages()
    missing <- c(pkgs_before$missing, pkgs_before$broken)
    
    tryCatch({
      install.packages(missing)
      
      # Re-check after installation attempt
      pkgs_after <- gc_check_packages()
      still_missing <- c(pkgs_after$missing, pkgs_after$broken)
      
      if (length(still_missing) == 0) {
        # SUCCESS
        showModal(
          modalDialog(
            title = "Installation complete",
            
            shiny::tagList(
              p(
                "All required packages have been installed successfully."
              ),
              p(
                "The application will now close. Please restart it to continue."
              )
            ),
            
            footer = shiny::tagList(actionButton(
              "close_app_after_install", "Close app"
            )),
            
            easyClose = FALSE
          )
        )
        
      } else {
        # FAILURE
        showModal(
          modalDialog(
            title = "Installation incomplete",
            
            shiny::tagList(
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
            
            footer = shiny::tagList(
              actionButton("close_app_after_failed_install", "Close app", class = "btn-danger")
            ),
            
            easyClose = FALSE
          )
        )
      }
      
    }, error = function(e = NULL) {
      showModal(
        modalDialog(
          title = "Installation failed",
          
          shiny::tagList(
            p("We couldn't install the required packages."),
            p(paste(
              "Technical error:", gc_get_message(e)
            )),
            p("Please check your internet connection and try again."),
            p("The application cannot continue.")
          ),
          
          footer = shiny::tagList(
            actionButton("close_app_after_failed_install", "Close app", class = "btn-danger")
          ),
          
          easyClose = FALSE
        )
      )
    })
  })
  
  shiny::observeEvent(input$close_app_after_install, {
    stopApp()
  })
  
  shiny::observeEvent(input$set_wd, {
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
    
    output$wd_txt <- shiny::renderText({
      paste("Working directory:", wd_path())
    })
  })
  
  shiny::observeEvent(input$refresh_files, {
    file_refresh(file_refresh() + 1)
  })
  
  session$onFlushed(function() {
    pkgs <- gc_check_packages()
    missing <- c(pkgs$missing, pkgs$broken)
    
    if (length(missing) > 0) {
      showModal(
        modalDialog(
          title = "Missing required packages",
          
          shiny::tagList(
            p(
              "The following packages are required but are not properly installed:"
            ),
            tags$ul(lapply(missing, tags$li)),
            p("Would you like to install them now?")
          ),
          
          footer = shiny::tagList(
            actionButton("install_yes", "Yes"),
            actionButton("install_no", "No")
          ),
          easyClose = FALSE
        )
      )
    }
  }, once = TRUE)
  
  shiny::observe({
    if (is.null(analysis_result()) ||
        current_stage() == stage_order[1]) {
      shinyjs::disable("prev_stage")
    } else {
      shinyjs::enable("prev_stage")
    }
  })
  
  shiny::observe({
    req(input$next_stage)
    req(current_stage())
    
    if (current_stage() == tail(stage_order, 1)) {
      shinyjs::disable("next_stage")
      updateActionButton(session, "next_stage", label = "Final stage")
    } else {
      shinyjs::enable("next_stage")
      updateActionButton(session, "next_stage", label = "Continue ->")
    }
  })
  
  shiny::observe({
    if (!is.null(analysis_result())) {
      shinyjs::enable("export_files")
      shinyjs::enable("reset_analysis")
    } else {
      shinyjs::disable("export_files")
      shinyjs::disable("reset_analysis")
    }
  })
  
  shiny::observe({
    # FIRST: handle directory readiness (no req yet)
    dir_ready <-
      !is.null(input$batch_data_dir) &&
      nzchar(input$batch_data_dir) &&
      !is.null(input$batch_design_dir) &&
      nzchar(input$batch_design_dir)
    
    # If directories not ready -> always disable
    if (!dir_ready) {
      shinyjs::disable("run_batch")
      return()
    }
    
    # ONLY now require the pairs
    req(batch_pairs())
    
    df <- validated_pairs_cached()
    
    ok <- nrow(df) > 0 &&
      all(df$status == HTML("&#9989; matched"))
    
    if (ok) {
      shinyjs::enable("run_batch")
    } else {
      shinyjs::disable("run_batch")
    }
  })
  
  build_design_preview_table <- function(df) {
    block_starts <- which(df[[1]] != "" & !is.na(df[[1]]))
    n_blocks <- length(block_starts)
    row_block_id <- rep(NA, nrow(df))
    for (k in seq_along(block_starts)) {
      start <- block_starts[k]
      end   <- if (k < n_blocks) block_starts[k + 1] - 1 else nrow(df)
      row_block_id[start:end] <- k
    }
    rows <- lapply(seq_len(min(30, nrow(df))), function(i) {
      is_block_header <- (i - 1) %% 10 == 0
      cells <- lapply(seq_len(ncol(df)), function(j) {
        val <- df[i, j]
        if (is.na(val)) val <- ""
        style_parts <- c("border: 1px solid rgba(120,120,120,0.2);")
        if (j == 1 && is_block_header)
          style_parts <- c(style_parts, "font-weight: bold; border: 2px solid rgba(80,80,80,0.4);")
        if (is_block_header && j > 1)
          style_parts <- c(style_parts, "font-weight: bold;")
        if (j == 1 && !is_block_header)
          style_parts <- c(style_parts, "font-weight: 500;")
        tags$td(style = paste(style_parts, collapse = " "), val)
      })
      row_style <- if (is_block_header && i != 1) "border-top: 4px solid rgba(80,80,80,0.5);" else ""
      tags$tr(style = row_style, cells)
    })
    needs_expand <- any(nchar(unlist(df)) > 10, na.rm = TRUE)
    tags$table(
      class = paste("design-preview-table", if (needs_expand) "expanding" else ""),
      style = "border-collapse: collapse;",
      tags$tbody(rows)
    )
  }
  
  shiny::observeEvent(list(wd_set(), file_refresh()), {
    req(wd_set(), wd_path())
    
    dirs <- list.dirs(path = wd_path(), recursive = FALSE, full.names = TRUE)
    names(dirs) <- basename(dirs)
    
    current_data   <- isolate(input$batch_data_dir)
    current_design <- isolate(input$batch_design_dir)
    current_agg    <- isolate(input$agg_dir)
    
    updateSelectInput(session, "batch_data_dir",
                      choices  = dirs,
                      selected = if (!is.null(current_data) && current_data %in% dirs) current_data else character(0)
    )
    updateSelectInput(session, "batch_design_dir",
                      choices  = dirs,
                      selected = if (!is.null(current_design) && current_design %in% dirs) current_design else character(0)
    )
    updateSelectInput(session, "agg_dir",
                      choices  = dirs,
                      selected = if (!is.null(current_agg) && current_agg %in% dirs) current_agg else character(0)
    )
  }, ignoreInit = TRUE)
  
  shiny::observe({
    if (app_locked()) {
      shinyjs::enable("cancel_batch")
    } else {
      shinyjs::disable("cancel_batch")
    }
  })
  
  shiny::observeEvent(input$agg_select_all, {
    req(agg_runs())
    
    value <- if (isTRUE(input$agg_select_all))
      "true"
    else
      "false"
    
    session$sendCustomMessage("toggle_all_checkboxes", value)
  })
  
  output$blank_info <- shiny::renderText({
    res <- analysis_result()
    validate(need(!is.null(res), ""))
    
    bm <- res$blank_mode %||% "none"
    
    if (bm == "plate") {
      paste(
        "Blank correction: plate-based blanks.",
        "\nMedian t\u2080; blank OD =",
        signif(analysis_result()$blankmed, 4)
      )
    } else if (bm == "per_well") {
      "Blank correction: per-well internal baseline (t\u2080; subtraction)."
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
  
  output$user_guide_ui <- shiny::renderUI({
    
    version <- paste("Version", growthcurve:::gc_app_version())
    
    shiny::tagList(
      h3("User guide"),
      
      tags$p(
        style = "margin-bottom: 12px;",
        class = "guide-note",
        "Guidance on data preparation, file structure, and common pitfalls."
      ),
      
      tags$p(
        style = "font-style: italic;",
        class = "guide-note",
        "New to this app? Start with a single plate before running batch analysis."
      ),
      
      tags$div(
        style = "
    padding: 12px;
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
      # INPUT PARAMETERS
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), HTML("&#9881;&#65039;  Analysis parameters (what do these mean?)")),
        tags$div(
          style = guide_body_style(),
          
          tags$p(
            "These parameters control how the growth curves are analyzed. ",
            "Most can be left at their default values, but it is important ",
            "to understand how they influence the results."
          ),
          
          tags$p(
            style = guide_note_style(),
            class = "guide-note",
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
            class = "guide-note",
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
            class = "guide-note",
            "Typical values are around 0.03-0.08 for plate reader data, and ~0.01 for oCelloscope data due to lower baseline noise."
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
          
          tags$p(
            style = guide_note_style(),
            class = "guide-note",
            HTML(
              "You can run analyses on the same data multiple times using different settings. 
    Each run is saved with a unique timestamp, so files are never overwritten. 
    However, using a descriptive output prefix (e.g., 'minOD05', 'alt_interval') is 
    strongly recommended to help identify and compare runs later, especially when combining results."
            )
          ),
          
          tags$p("If provided, output folders will be named like:"),
          
          tags$pre(
            "yyyymmdd_hhmmss_myanalysis_single\nyyyymmdd_hhmmss_myanalysis_batch"
          ),
          
          tags$p(
            style = guide_note_style(),
            class = "guide-note",
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
            class = "guide-note",
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
            class = "guide-note",
            "For oCelloscope data, blank correction is not applied because values are already normalized during acquisition."
          ),
          
        ),
        
      ),
      
      
      # =========================================================
      # RAW DATA - PLATE READER
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), HTML("&#128196; Raw data (Plate reader)")),
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
            tags$li("Use File -> Save As and save it again as a CSV file")
          ),
          
          tags$p(
            style = guide_note_style(),
            class = "guide-note",
            "This does not change your data. It ensures correct delimiter and encoding."
          ),
          
          tags$hr(),
          
          p("Expected structure:"),
          
          tags$ul(
            tags$li("96-well plate layout (rows A-H, columns 1-12)"),
            tags$li("May contain multiple reads (kinetic measurements)"),
            tags$li(
              "Includes header/metadata rows (these are handled automatically)"
            )
          ),
          
          tags$p(
            style = guide_note_style(),
            class = "guide-note",
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
      # RAW DATA - OCELLOSCOPE
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), HTML("&#128300; Raw data (oCelloscope)")),
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
            tags$li("Use File -> Save As and save it as a CSV file"),
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
            class = "guide-note",
            "The app automatically extracts the correct TANormalized block and formats it for analysis."
          )
        )
      ),
      
      # =========================================================
      # DESIGN FILE
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), HTML("&#129516; Design file format")),
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
            class = "guide-note",
            "Think of it as a stack of identical 96-well plates, each labeling a different attribute."
          ),
          
          hr(),
          
          h4("Structure rules"),
          
          tags$ul(
            tags$li("Each variable is one block (e.g., Strain, Treatment)."),
            tags$li("Each block must be a complete 96-well layout (A-H, 1-12)."),
            tags$li("The top-left cell of each block contains the variable name.",
              tags$ul(
                tags$li("Design variable names should not end with _ (e.g., Strain_), as names ending with _ are reserved for internal use during analysis and aggregation.")
              )      
                    ),
            tags$li(
              "Each block must contain one header row followed by eight rows (A-H)."
            ),
            tags$li("All blocks must have identical dimensions and alignment."),
            tags$li("Each block must be separated by one completely empty row."),
            tags$li(
              "The 'Well_type' variable must always be included as the first block."
            ),
            tags$li(
              "The reserved names 'Well_type' and 'Blank' are case-sensitive and must be written exactly like this for the analysis to work."
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
            "Empty wells must remain completely empty and must not contain any text."
          ),
          
          tags$p(
            style = "color: #b22222; font-weight: 600;",
            "Important: 'Well_type' and 'Blank' must be written exactly as shown (including capitalization). These are interpreted specially by the analysis. All other names and values are read as-is."
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
            class = "guide-note",
            "Every position (e.g., B3) must correspond across all blocks."
          ),
          
          tags$p(
            style = guide_note_style(),
            class = "guide-note",
            "The example and preview use different plate layouts and values. Only the structure (block format and alignment) must match - the contents will depend on your experiment."
          ),
          
          hr(),
          
          div(class = "preview-table-fixed-rows", tableOutput("design_example_table")),
          
          tags$p(
            style = guide_note_style(),
            class = "guide-note",
            "This preview shows how blocks are stacked and aligned."
          )
        )
      ),
      
      # =========================================================
      # TEMPLATES
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), HTML("&#128229; Download templates")),
        tags$div(
          style = guide_body_style(),
          
          p(
            "Templates provide a ready-to-use design file with the correct structure."
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
              "To add a variable, copy a full block, paste it below, and rename it. Remember to leave one empty row between blocks."
            ),
            tags$li(
              "Blank wells only need to be defined in the Well_type block; other blocks can leave these cells empty."
            )
          ),
          
          tags$p(
            style = "color: #b22222; font-weight: 600;",
            "Do not change the layout of a block (do not insert, delete, or move rows or columns). Only modify the values inside existing cells."
          ),
          
          tags$p(
            style = "color: #b22222; font-weight: 600;",
            "The reserved names 'Well_type' and 'Blank' are case-sensitive and must be written exactly like this for the analysis to work."
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
            class = "guide-note",
            "Tip: Start by editing the template rather than creating a file from scratch."
          ),
          
          hr(),
          
          tags$p(
            style = guide_note_style(),
            class = "guide-note",
            "Download the template matching your regional CSV format."
          ),
          
          fluidRow(
            column(6, downloadButton("download_template_us", "US format (comma)")),
            column(6, downloadButton("download_template_eu", "European format (semicolon)"))
          )
        )
      ),
      
      # =========================================================
      # BATCH STRUCTURE
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), HTML("&#128193; Batch processing structure")),
        tags$div(
          style = guide_body_style(),
          
          tags$pre(
            "my_experiment/
|-- data/
|   |-- plate1.csv
|   |-- plate2.csv
|-- design/
    |-- plate1_design.csv
    |-- plate2_design.csv"
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
      # AGGREGATE MODE
      # =========================================================
      tags$details(
        tags$summary(
          style = guide_summary_style(),
          HTML("&#128202; Aggregate results")
        ),
        
        tags$div(
          style = guide_body_style(),
          
          tags$p(
            "Aggregate Results combines outputs from multiple analyses ",
            "into a single dataset for downstream statistical analysis."
          ),
          
          tags$p(
            strong("Think of this step as:"),
            " merging multiple completed runs into one unified results table."
          ),
          
          tags$hr(),
          
          h4("What this does"),
          
          tags$ul(
            tags$li("Searches selected directories recursively for all plate_tidy.csv files."),
            tags$li("Combines detected files into a single dataset."),
            tags$li("Harmonizes column structure (missing columns are filled with NA)."),
            tags$li("Exports a single combined CSV file with a timestamped name.")
          ),
          
          tags$pre(
            "combined_tidy_YYYYMMDD_HHMMSS.csv"
          ),
          
          tags$hr(),
          
          h4("Expected folder structure"),
          
          tags$pre(
            "Analysis/
|-- run_1/
|-- run_2/
|-- run_3/"
          ),
          
          tags$ul(
            tags$li("Each run folder contains one or more analyzed plates."),
            tags$li("Each plate folder contains a plate_tidy.csv file."),
            tags$li("The app scans all subfolders automatically.")
          ),
          
          tags$p(
            style = guide_note_style(),
            class = "guide-note",
            "Runs do not need to originate from the same batch. You can combine results from different experiments as needed."
          ),
          
          tags$hr(),
          
          h4("Working with multiple experiments"),
          
          tags$p(
            "If your analyses are spread across different directories, you can organize them before aggregation:"
          ),
          
          tags$ul(
            tags$li("Create a new parent folder (e.g., 'Analysis_combined')."),
            tags$li("Copy or move individual run folders into this location."),
            tags$li("Select that folder when running Aggregate Results.")
          ),
          
          tags$pre(
            "Analysis_combined/
|-- experiment_A/
|-- experiment_B/
|-- experiment_C/"
          ),
          
          tags$p(
            style = guide_note_style(),
            class = "guide-note",
            "The app treats every subfolder as a potential source of results, regardless of how it was created."
          ),
          
          tags$hr(),
          
          h4("Duplicate detection"),
          
          tags$p(
            strong("Important:"),
            " The app checks for overlapping analyses before combining results."
          ),
          
          tags$ul(
            tags$li(
              "Duplicates are defined as the same plate name AND the same prefix."
            ),
            tags$li(
              "The same plate can appear multiple times if prefixes differ."
            ),
            tags$li(
              "Duplicate groups are shown in a warning dialog before aggregation."
            )
          ),
          
          tags$p(
            style = guide_note_style(),
            class = "guide-note",
            "Using descriptive prefixes (e.g., 'minOD05', 'alt_interval') helps distinguish multiple analyses of the same data."
          ),
          
          tags$hr(),
          
          h4("Output structure (preview)"),
          
          tags$p(
            "The combined output is a tidy dataset where each row represents one measurement for one well:"
          ),
          
          
          tags$pre(
            "[metadata]  Well  Strain  Treatment  Measurement   Value   Replicate  QC_flag
...         A1    Str1    Yes        max_growth    1.26    1          OK
...         A1    Str1    Yes        doub_time     0.55    1          OK
...         A2    Str1    No         max_growth    0.87    2          WARN        "
          ),
          
          
          tags$ul(
            tags$li("Each well contributes multiple rows (one per measurement type)."),
            tags$li("Design variables appear as columns."),
            tags$li("QC flags are preserved for downstream filtering."),
            tags$li("Missing variables across runs are filled with NA.")
          ),
          
          tags$p(
            style = guide_note_style(),
            "max_growth = maximum growth rate (per hour); doub_time = doubling time (hours)."
          ),
          
          tags$p(
            style = guide_note_style(),
            class = "guide-note",
            "The output is designed for direct use with dplyr, ggplot2, or statistical software."
          ),
          
          tags$p(
            style = "color: #b22222; font-weight: 600;",
            "Tip: Always inspect the combined dataset before downstream analysis, especially when merging results from different experiments."
          )
        )
      ),
      
      # =========================================================
      # COMMON ISSUES
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), HTML("&#9888;&#65039; Common issues")),
        tags$div(style = guide_body_style(), tags$ul(
          tags$li("Selecting a design file that does not match the raw data"),
          tags$li("Design blocks with inconsistent dimensions or missing rows"),
        ))
      ),
      
      # =========================================================
      # Troubleshooting
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), HTML("&#128736;  Troubleshooting")),
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
            class = "guide-note",
            "Most issues arise from incorrect file formatting rather than analysis errors."
          )
        )
      ),
      
      # =========================================================
      # CHECKLIST
      # =========================================================
      tags$details(
        tags$summary(style = guide_summary_style(), HTML("&#9989; Validation checklist")),
        tags$div(style = guide_body_style(), tags$ul(
          tags$li(HTML("&#9989; Files match")),
          tags$li(HTML("&#9989; Required columns present")),
          tags$li(HTML("&#9989; Correct delimiter")),
          tags$li(HTML("&#9989; No empty header rows"))
        ))
      ),
      hr(),
      
      # =========================================================
      # USER & TECHNICAL GUIDE
      # =========================================================
      tags$div(
        style = "
    padding: 12px;
    border: 1px solid #e0e0e0;
    border-left: 4px solid #4a90e2;
    border-radius: 6px;
    margin-top: 20px;
  ",
        
        tags$p(
          style = "margin-bottom: 8px;",
          "This user guide corresponds to the installed version of the application."
        ),
        
        tags$p(
          strong(version)
        ),
        
        tags$p(
          style = guide_note_style(),
          class = "guide-note",
          "For the full documentation and latest updates, visit the GitHub repository."
        ),
        
        tags$a(
          href = "https://github.com/jordanmbarrows/growthcurve",
          target = "_blank",
          "github.com/jordanmbarrows/growthcurve"
        )
      )
    )
    
  })
  
  make_template_handler <- function(filename) {
    downloadHandler(
      filename = function() filename,
      content  = function(file) {
        path <- system.file("app/templates", filename, package = "growthcurve")
        if (path == "") path <- file.path("templates", filename)
        file.copy(from = path, to = file, overwrite = TRUE)
      }
    )
  }
  
  output$download_template_us <- make_template_handler("design_template_us.csv")
  output$download_template_eu <- make_template_handler("design_template_eu.csv")
  
  output$stage_ready <- reactive({
    !is.null(analysis_result())
  })
  
  outputOptions(output, "stage_ready", suspendWhenHidden = FALSE)
  
  output$single_ui <- shiny::renderUI({
    if (!wd_set()) {
      return(tagList(
        tags$div(
          style = "padding: 20px; border-radius: 6px;",
          h4("Single plate analysis"),
          p("Please set a working directory to continue.")
        )
      ))
    }
    
    files <- wd_files()
    
    shiny::tagList(
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
        tags$summary(style = guide_summary_style(), HTML("&#128065; Preview raw data")),
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
        tags$summary(style = guide_summary_style(), HTML("&#129516; Preview design file")),
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
        HTML("&#128260; Reset analysis"),
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
          HTML("&#128193; Export analysis files"),
          class = "btn-success",
          disabled = TRUE
        )
      ),
      
      hr(),
      
      # ---- Stage counter ----
      shiny::verbatimTextOutput("stage_counter"),
      
      # ---- Navigation stays with plots ----
      div(
        style = "display:flex; gap:10px;",
        actionButton("prev_stage", "<- Back", class = "btn-secondary"),
        actionButton("next_stage", "Next ->", class = "btn-primary")
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
    
    #  Guard for oCelloscope without design
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
        error = function(e = NULL)
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
  
  output$single_raw_preview_table <- shiny::renderTable({
    
    result <- single_preview_data()
    req(result)
    
    if (is_preview_message(result)) {
      return(NULL)
    }
    
    df <- result$data
    
    df <- format_preview_df(df, region_selected())
    
    df[] <- lapply(df, as.character)
    
    df
    
  }, striped = TRUE, bordered = TRUE, spacing = "xs", colnames = TRUE, na = "")
  
  output$single_preview_label <- shiny::renderText({
    req(input$raw_file, wd_path())
    
    file <- file.path(wd_path(), input$raw_file)
    
    res <- single_preview_raw()
    
    build_preview_label(file, res, instrument = input$instrument)
  })
  
  output$single_raw_preview_ui <- shiny::renderUI({
    result <- single_preview_data()
    
    # Case 1: warning / message
    if (is_preview_message(result)) {
      return(preview_warning_box(result$message))
    }
    
    # Case 2: render table
    div(class = "preview-table",
        style = "overflow-x: auto; white-space: nowrap;",
        tableOutput("single_raw_preview_table"))
  })
  
  output$design_preview <- shiny::renderUI({
    req(input$design_file, wd_path())
    file <- file.path(wd_path(), input$design_file)
    req(file.exists(file))
    df <- read_preview_file(file, nrows = 100)
    req(df)
    df <- format_preview_df(df, region_selected())
    build_design_preview_table(df)
  })
  
  output$batch_ui <- shiny::renderUI({
    if (!wd_set())
      return(NULL)
    
    div(
      class = "batch-flex",
      
      # LEFT
      div(
        class = "batch-left",
        
        # Show table ONLY when valid pairs exist
        conditionalPanel(condition = "output.batch_has_pairs == true", DT::DTOutput("batch_match_table")),
        
        # Show placeholder when no valid pairs exist
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
          "This mode runs the full growth-curve analysis pipeline on ",
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
  
  output$batch_raw_preview_ui <- shiny::renderUI({
    req(input$batch_data_dir)
    
    files <- list.files(input$batch_data_dir, full.names = TRUE)
    if (length(files) == 0)
      return(NULL)
    
    file <- files[1]
    
    #  NEW: explicit oCelloscope guard
    if (input$batch_instrument == "ocelloscope" &&
        (is.null(input$batch_design_dir) ||
         !nzchar(input$batch_design_dir))) {
      return(preview_warning_box("Select a design directory to preview oCelloscope data."))
    }
    
    # Optional design
    design <- NULL
    if (!is.null(input$batch_design_dir) &&
        nzchar(input$batch_design_dir)) {
      df <- tryCatch(
        validated_pairs_cached(),
        error = function(e = NULL)
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
      return(preview_warning_box(result$message))
    }
    
    # Table
    # Table placeholder ONLY
    div(class = "preview-table",
        style = "overflow-x: auto; white-space: nowrap;",
        tableOutput("batch_raw_preview_table"))
  })
  
  output$batch_raw_preview_table <- shiny::renderTable({
    
    req(input$batch_data_dir)
    
    files <- list.files(input$batch_data_dir, full.names = TRUE)
    if (length(files) == 0)
      return(NULL)
    
    #  block oCelloscope without design
    if (input$batch_instrument == "ocelloscope" &&
        (is.null(input$batch_design_dir) || !nzchar(input$batch_design_dir))) {
      return(NULL)
    }
    
    result <- unwrap_preview(batch_preview_raw())
    
    if (is_preview_message(result)) {
      return(NULL)
    }
    
    df <- result$data
    
    df <- format_preview_df(
      df,
      region_selected()
    )
    
    df
    
  }, striped = TRUE, bordered = TRUE, spacing = "xs", colnames = TRUE, na = "")
    
  output$batch_preview_label <- shiny::renderText({
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
        error = function(e = NULL)
          NULL
      )
      
      if (!is.null(df) && nrow(df) > 0) {
        design <- df$design_file[1]
      }
    }
    
    res <- batch_preview_raw()
    
    build_preview_label(file, res, instrument = isolate(input$batch_instrument))
  })
  
  output$batch_design_preview <- shiny::renderUI({
    req(input$batch_design_dir)
    files <- list.files(input$batch_design_dir, full.names = TRUE)
    if (length(files) == 0) return(NULL)
    file <- files[1]
    req(!is.na(file), file.exists(file))
    df <- read_preview_file(file, nrows = 100)
    req(df)
    
    print("=== BEFORE FORMATTING ===")
    print(df)
    print(sapply(df, class))
    
    df2 <- format_preview_df(df, region_selected())
    
    print("=== AFTER FORMATTING ===")
    print(df2)
    
    df2
    
    df <- format_preview_df(df, region_selected())
    build_design_preview_table(df)
  })
  
  output$aggregate_ui <- shiny::renderUI({
    if (!wd_set())
      return(NULL)
    
    div(
      class = "batch-flex",
      
      # LEFT
      div(
        class = "batch-left",
        
        tags$details(
          tags$summary(
            style = guide_summary_style(),
            HTML("&#8505;&#65039;  What folder should I select?")
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
        
        div(
          id = "agg_runs_table_outer",
          div(
            id = "agg_runs_table_container",
            DT::DTOutput("agg_runs_table")
          )
        ),
        
        hr(),
        
        actionButton("run_aggregate", HTML("&#128202; Combine summaries"), class = "btn-success"),
        
        hr(),
        
        h4("Preview"),
        
        DT::DTOutput("agg_preview"),
        
        hr(),
        
        actionButton("export_agg", HTML("&#128193; Export combined file"), class = "btn-primary")
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
    
    df$status <- "..."   # placeholder
    
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
        pageLength = nrow(df),
        dom = "t",
        ordering = FALSE,
        autoWidth = FALSE,
        scrollX = FALSE,
        scrollY = FALSE,
        fixedHeader = TRUE
      ), width = "auto",
      callback = htmlwidgets::JS(
        "
      table.on('draw.dt', function() {
        Shiny.bindAll(table.table().node());
        table.columns.adjust();
      });
    "
      )
    )
    
  }, server = TRUE)
  
  shiny::observe({
    req(agg_runs())
    
    df <- agg_runs()
    
    dup_info <- duplicate_info()
    
    # build status column
    df$status <- vapply(df$run_name, function(run) {
      
      # ---- check if run is selected ----
      safe_name <- gsub("[^a-zA-Z0-9_]", "_", run)
      is_selected <- isTRUE(input[[paste0("agg_include_", safe_name)]])
      
      # ---- Case 1: NOT selected → EMPTY CELL ----
      if (!is_selected) {
        return("")   # ← this is the key change
      }
      
      # ---- check duplicate status ----
      is_dup <- run %in% names(dup_info$run_flags) &&
        isTRUE(dup_info$run_flags[[run]])
      
      # ---- Case 2: selected + no duplicates ----
      if (!is_dup) {
        return(as.character(HTML("&#9989; unique")))
      }
      
      # ---- Case 3: selected + duplicates ----
      involved <- lapply(dup_info$duplicate_map, function(entries) {
        entries[grepl(paste0("^", run, " >"), entries)]
      })
      
      involved <- Filter(length, involved)
      
      if (length(involved) == 0) {
        return(as.character(HTML("&#9989; unique")))  # safety fallback
      }
      
      plates <- names(involved)
      
      tooltip <- paste(
        unlist(dup_info$duplicate_map[plates]),
        collapse = "\n"
      )
      
      as.character(
        tags$div(
          style = "position: relative; display: inline-block;",
          
          tags$span(
            class = "dup-hover",
            HTML("&#9888;&#65039; duplicate plate data detected (same plate and prefix across runs)")
          ),
          
          tags$div(
            class = "dup-tooltip",
            HTML(paste0("<pre>", tooltip, "</pre>"))
          )
        )
      )
      
    }, character(1))
    
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
    
    # drop unwanted column if present
    df <- df[, setdiff(names(df), "source_file"), drop = FALSE]
    
    # APPLY FORMAT HERE
    df <- format_preview_df(
      df,
      region_selected()
    )
    
    DT::datatable(
      head(df, 100),
      options = list(pageLength = 10, scrollX = TRUE),
      rownames = FALSE
    )
  })
  
  output$batch_param_section <- shiny::renderUI({
    req(wd_set())
    
    shiny::tagList(
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
          "Higher values often slow down disk-heavy analyses."
        )
      ),
      
      hr(),
      
      div(
        style = "display: flex; align-items: center; gap: 8px;",
        
        shiny::tagList(
          actionButton(
            "run_batch",
            HTML("&#128640; Run batch analysis"),
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
        
        actionButton(
          "cancel_batch",
          "Cancel batch",
          class = "btn-warning",
          disabled = TRUE
        ),
        
      ),
      
      tags$p(
        style = "font-size: 0.9em; color: #666; margin-top: 6px;",
        "Note: Cancelling a batch will stop the analysis after the current plate finishes processing."
      )
    )
  })
  
  shiny::observeEvent(list(
    input$batch_data_dir,
    input$batch_design_dir,
    file_refresh()
  ),
  {
    # Only proceed if BOTH are selected AND non-empty
    req(
      !is.null(input$batch_data_dir),
      nzchar(input$batch_data_dir),
      !is.null(input$batch_design_dir),
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
  
  output$design_section <- shiny::renderUI({
    shiny::tagList(
      selectInput(
        "design_vars",
        "Design variables",
        choices  = character(0),
        selected = character(0),
        multiple = TRUE
      ),
      
      div(id = "blank_mode_container", shiny::tagList(
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
      
      tags$div(style = "margin-top: 8px;", shiny::verbatimTextOutput("blank_info"))
    )
  })
  
  shiny::observeEvent(input$design_file, {
    req(wd_path(), input$design_file)
    
    file <- file.path(wd_path(), input$design_file)
    
    vars <- tryCatch(
      extract_design_blocks(file),
      error = function(e = NULL)
        character(0)
    )
    
    updateSelectInput(session,
                      "design_vars",
                      choices  = vars,
                      selected = vars)
    
  })
  
  output$stage_ui <- shiny::renderUI({
    req(analysis_result(), current_stage())
    
    if (current_stage() == "blank_linear") {
      shiny::tagList(
        plotOutput("plot_blank_linear", height = "500px"),
        p(
          "Inspect blank wells and confirm that non-blank wells ",
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
      shiny::tagList(
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
      shiny::tagList(
        plotOutput("plot_mean_curves", height = "500px"),
        p(
          "Inspect group-averaged growth curves and confidence intervals. ",
          "Check that trends align with expectations and that variability ",
          "looks reasonable."
        )
      )
      
    } else if (current_stage() == "perwell_linear") {
      shiny::tagList(
        plotOutput("plot_perwell_linear", height = "500px"),
        p(
          "Inspect individual wells for anomalies such as contamination, ",
          "edge effects, or failed growth. Look for wells that clearly ",
          "deviate from others in the same condition."
        )
      )
      
    } else if (current_stage() == "perwell_log") {
      shiny::tagList(
        plotOutput("plot_perwell_log", height = "500px"),
        p(
          "Inspect individual wells on a log scale to assess early ",
          "exponential growth behavior and subtle deviations between wells."
        )
      )
      
    } else if (current_stage() == "deriv_raw") {
      shiny::tagList(
        plotOutput("plot_deriv_raw", height = "500px"),
        p(
          "Inspect raw growth-rate derivatives per well. ",
          "Look for excessive noise, spikes, or discontinuities ",
          "that could indicate unreliable numerical differentiation."
        )
      )
      
    } else if (current_stage() == "deriv_percap") {
      shiny::tagList(
        plotOutput("plot_deriv_percap", height = "500px"),
        p(
          "Inspect fitted per-capita growth-rate derivatives. ",
          "These curves drive the maximum growth rate and ",
          "doubling-time estimates used in downstream summaries."
        )
      )
      
    } else if (current_stage() == "fitted_percap") {
      shiny::tagList(
        plotOutput("plot_fitted_percap", height = "500px"),
        p(
          "Inspect the fitted per-capita growth-rate curves with the ",
          "detected maximum marked. Confirm that the peak corresponds ",
          "to a biologically plausible region of the curve."
        )
      )
      
    } else if (current_stage() == "od_with_maxgc") {
      shiny::tagList(
        plotOutput("plot_od_with_maxgc", height = "500px"),
        p(
          "Inspect OD curves with the time of maximum per-capita growth ",
          "rate overlaid. The marked timepoint should occur during ",
          "exponential growth, not during lag or saturation."
        )
      )
      
    } else if (current_stage() == "doubling_time") {
      shiny::tagList(
        plotOutput("plot_doubling_time", height = "500px"),
        p(
          "Inspect per-well doubling times grouped by condition. ",
          "Look for biologically implausible values or unusually ",
          "large variation within groups."
        )
      )
      
    } else if (current_stage() == "max_growth_rate") {
      shiny::tagList(
        plotOutput("plot_max_growth_rate", height = "500px"),
        p(
          "Inspect maximum per-capita growth rates by condition. ",
          "These values are central to downstream interpretation ",
          "and should be checked carefully."
        )
      )
      
    } else {
      p("Next stage coming...")
      
    }
  })
  
  output$plot_blank_linear <- shiny::renderPlot({
    analysis_result()$plots$blank_linear
  })
  
  output$plot_blank_log <- shiny::renderPlot({
    analysis_result()$plots$blank_log
  })
  
  output$plot_mean_curves <- shiny::renderPlot({
    analysis_result()$plots$mean_curves
  })
  
  output$plot_perwell_linear <- shiny::renderPlot({
    analysis_result()$plots$perwell_linear
  })
  
  output$plot_perwell_log <- shiny::renderPlot({
    analysis_result()$plots$perwell_log
  })
  
  output$plot_deriv_raw <- shiny::renderPlot({
    analysis_result()$plots$deriv_raw
  })
  
  output$plot_deriv_percap <- shiny::renderPlot({
    analysis_result()$plots$deriv_percap
  })
  
  output$plot_fitted_percap <- shiny::renderPlot({
    analysis_result()$plots$fitted_percap
  })
  
  output$plot_od_with_maxgc <- shiny::renderPlot({
    analysis_result()$plots$od_with_maxgc
  })
  
  output$plot_doubling_time <- shiny::renderPlot({
    analysis_result()$plots$doubling_time
  })
  
  output$plot_max_growth_rate <- shiny::renderPlot({
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
  
  shiny::observeEvent(input$run, {
    if (requireNamespace("future", quietly = TRUE)) {
      future::plan(future::sequential)
    }
    
    region <- region_selected()
    
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
                 detail  = "Importing data and generating plots...",
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
                     
                   }, error = function(e = NULL) {
                     gc_log_block(
                       "SINGLE RUN INTERNAL ERROR",
                       list(
                         error = e$message,
                         class = class(e)[1]
                       )
                     )
                     
                     err <- gc_format_error(e)
                     
                     msg <- err$user_message
                     
                     showModal(modalDialog(
                       title = "Analysis failed",
                       p(
                         HTML(paste0(
                         "The analysis could not be completed. Please check that:
                          <br><br>",
                         "1. You have selected the correct instrument.<br>",
                         "2. You have selected the correct input files.<br>",
                         "3. Your input files are formatted correctly."
                        ))
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
                       shiny::tagList(
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
  
  shiny::observeEvent(input$reset_analysis, {
    showModal(
      modalDialog(
        title = "Reset analysis?",
        "This will clear the current results.",
        footer = shiny::tagList(
          modalButton("Cancel"),
          actionButton("confirm_reset", "Reset", class = "btn-danger")
        )
      )
    )
    
  })
  
  shiny::observeEvent(input$confirm_reset, {
    removeModal()
    
    analysis_result(NULL)
    current_stage("not_run")
    
    shinyjs::enable("hrs")
    shinyjs::enable("interval_min")
    shinyjs::enable("minod")
    shinyjs::enable("maxod")
    shinyjs::enable("prefix")
    shinyjs::enable("design_vars")
    shinyjs::enable("raw_file")
    shinyjs::enable("design_file")
    shinyjs::enable("instrument")
    enforce_blank_mode_state(session, input$instrument)
    
    shinyjs::disable("export_files")
    
  })
  
  shiny::observeEvent(input$batch_instrument, {
    
    apply_instrument_defaults(
      session,
      prefix = "batch",
      instrument = input$batch_instrument
    )
    
    enforce_blank_mode_state(
      session,
      input$batch_instrument,
      prefix = "batch"
    )
    
  }, ignoreNULL = TRUE)
  
  shiny::observeEvent(input$agg_dir, {
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
  
  shiny::observeEvent(input$next_stage, {
    req(current_stage() != "not_run")
    advance_stage()
  })
  
  shiny::observeEvent(input$instrument, {
    
    # 1. Apply defaults FIRST
    apply_instrument_defaults(
      session,
      prefix = "",
      instrument = input$instrument
    )
    
    # 2. Enforce blank mode rules SECOND
    enforce_blank_mode_state(
      session,
      input$instrument
    )
    
  }, ignoreNULL = TRUE)
  
  # -- run_one_plate_future ------------------------------------------------------
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
                                   maybe_finish_fn,
                                   region) {
    
    plate_name <- basename(pairs_val$data_file[i])
    
    future_globals <- list(
      i         = i,
      pairs_val = pairs_val,
      params    = params,
      root_path = root_path,
      region    = region
    )
    
    prom <- promises::future_promise(expr = {
      
      library(growthcurve)
      
      # Worker-safe version (no sinks / handlers)
      gc_run_quiet_worker <- function(expr) {
        if (isTRUE(getOption("gc.dev_mode"))) return(expr)
        
        suppressWarnings(suppressMessages(expr))
      }
      
      if (exists("gc_log") && gc_dev_mode()) {
        try(gc_log(paste("Worker starting plate", i)), silent = TRUE)
      }
      
      tryCatch({
        
        fname     <- basename(pairs_val$data_file[i])
        plate_tag <- tools::file_path_sans_ext(fname)
        plate_dir   <- file.path(root_path, plate_tag)
        
        # -- Paths defined above, but NO dir.create() yet --
        
        res <- tryCatch({
          gc_run_quiet_worker(
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
        }, error = function(e = NULL) {
          
          err <- gc_format_error(e, dev = gc_dev_mode())
          
          list(
            success = FALSE,
            message = err$user_message,
            debug   = err$debug,
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
        
        # --- cancellation check before writing outputs ----
        if (file.exists(file.path(root_path, "_CANCEL_BATCH"))) {
          return(list(
            success = FALSE,
            message = "Cancelled by user",
            plate   = pairs_val$data_file[i]
          ))
        }
        
        dir.create(root_path,
                   recursive = TRUE,
                   showWarnings = FALSE)
        
        dir.create(plate_dir, recursive = TRUE, showWarnings = FALSE)
        
        report_file <- file.path(plate_dir, "plate_report.pdf")
        gc_save_report(res$plots, report_file, plate_name = plate_tag)
        gc_write_summaries(
          core        = res$core,
          params      = res$params,
          instrument  = res$instrument,
          out_dir     = plate_dir,
          region      = region
        )
        
        list(success = TRUE)
        
      }, error = function(e = NULL) {
        list(
          success = FALSE,
          message = paste("Fatal worker error:", conditionMessage(e)),
          plate   = pairs_val$data_file[i]
        )
      })
      
    },
    globals = future_globals,
    seed = TRUE)
    
    start_cancellation_monitor <- function(root_path, bs, maybe_finish_fn) {
      monitor <- function() {
        if (cancel_requested(root_path)) {
          bs$aborted <- TRUE
          bs$cancelled <- TRUE
          bs$queue   <- list()  # <- DRAIN THE QUEUE IMMEDIATELY
          gc_log("CANCELLATION DETECTED MID-PLATE")
          # Queue will drain naturally when this plate finishes
          maybe_finish_fn()  # Trigger finish check
          return()  # Stop monitoring
        }
        later::later(monitor, delay = 1)  # Check every second
      }
      later::later(monitor, delay = 1)
    }
    
    start_cancellation_monitor(root_path, bs, maybe_finish_fn)
    
    # -- then: plate finished (success or reported failure) ---------------------
    prom <- promises::then(
      prom, local({
        plate_name <- plate_name   # force capture
        
        function(result) {
          
          if (isTRUE(result$success)) {
            bs$successes <- c(bs$successes, plate_name)
          }
          
          if (exists("gc_log_block")) {
            try(gc_log_block(paste("Plate finished", i)), silent = TRUE)
          }
          
          tryCatch({
            
            # Update counters FIRST
            bs$running   <- bs$running - 1L
            bs$completed <- bs$completed + 1L
            
            if (!isTRUE(batch_state$progress_open)) {
              maybe_finish_fn()
              return()
            }
            
            # Progress update (safe)
              if (isTRUE(batch_state$progress_open)) {
                tryCatch(
                  {
                    current_plate <- min(bs$completed + 1L, n)
                    
                    progress$set(
                      value  = bs$completed,
                      detail = paste("Running plate", current_plate, "of", n)
                    )
                  },
                  error = function(e = NULL) NULL
                )
              }
            
            # Handle failure -> record failure without exiting analysis
            if (!isTRUE(result$success)) {
              bs$failures <- c(
                bs$failures,
                paste0("Plate ", i, ": ", result$message %||% "unknown error")
              )
              
              gc_log_block(
                paste("BATCH FAILURE plate", i),
                list(
                  message = result$message,
                  debug   = result$debug
                )
              )
            }

            # UNIFIED cancellation check (IMPORTANT)
            cancel_hit <- cancel_requested(root_path)
            
            if (cancel_hit) {
              bs$aborted <- TRUE
              bs$cancelled <- TRUE
              bs$queue   <- list()
              
              gc_log_block("BATCH CANCEL DETECTED (post-plate)", list(
                completed = bs$completed
              ))
            }
            
            # FINAL CONTROL FLOW (single decision point)
            if (isTRUE(bs$cancelled)) {
              maybe_finish_fn()
            } else {
              launch_next_fn()
            }
            
            
          }, error = function(e = NULL) {
            
            gc_log_block("THEN HANDLER ERROR", conditionMessage(e))
            
            # Ensure consistent state even on crash
            bs$aborted  <- TRUE
            bs$queue    <- list()
            bs$running  <- max(0L, bs$running - 1L)
            
            bs$failures <- c(
              bs$failures,
              paste0("Plate ", i, ": then-handler crash")
            )
            
            maybe_finish_fn()
            })
          }
        })
      )

    # -- catch: promise itself rejected (system/async error) -------------------
    prom <- promises::catch(prom, function(e) {
      
      err <- gc_format_error(e)
      
      gc_log_block(
        paste("ASYNC ERROR plate", i),
        list(
          message = err$user_message
        )
      )
      
      tryCatch({
        bs$running   <- bs$running - 1L
        bs$completed <- bs$completed + 1L
        bs$aborted   <- TRUE
        bs$queue     <- list()
        bs$failures  <- c(bs$failures,
                          paste0("Plate ", i, ": ", err$user_message)
                          )
        gc_log_block(paste("ASYNC SYSTEM ERROR plate", i),
                     conditionMessage(e))
        maybe_finish_fn()
      }, error = function(e2) {
        gc_log_block("CATCH HANDLER ERROR", conditionMessage(e2))
      })
    })
    
    invisible(prom)
  }
  
  run_batch_async <- function(pairs_val, n, root_path, batch_start_time, region, params, old_plan) {
    
    max_workers <- if (isTRUE(params$parallel)) 2L else 1L
    
    batch_abort(FALSE)
    batch_failures(character(0))
    
    bs <- new.env(parent = emptyenv())
    bs$queue <- as.list(seq_len(n))
    bs$running <- 0L
    bs$completed <- 0L
    bs$aborted <- FALSE
    bs$failures <- character(0)
    bs$successes <- character(0)
    bs$finished <- FALSE
    bs$cancelled <- FALSE
    
    all_plate_names <- basename(pairs_val$data_file)
    
    progress <- Progress$new(session, min = 0, max = n)
    
    progress$set(
      value = 0,
      message = "Running batch analysis...",
      detail = paste("Running plate 1 of", n)
    )
    
    batch_state$progress_open <- TRUE
    
    maybe_finish <- function() {
      if (isTRUE(bs$finished)) {
        return()
      }
      
      if (bs$completed == n || bs$aborted) {
        bs$finished <- TRUE   # lock it
        
        finish_batch(
          completed_val = bs$completed,
          n = n,
          root_path = root_path,
          batch_start_time = batch_start_time,
          progress = progress,
          old_plan = old_plan,
          failures = bs$failures,
          all_failed = length(bs$failures) == n,
          all_plate_names = all_plate_names,
          successes = bs$successes,
          region = region,
          cancelled = isTRUE(bs$cancelled)
        )
      }
    }
    
    launch_next <- function() {
      
      # CHECK CANCEL FIRST (before doing anything)
      if (cancel_requested(root_path)) {
        bs$aborted <- TRUE
        bs$cancelled <- TRUE
        
        gc_log("Batch cancellation detected before launching next job")
        
        maybe_finish()
        return()
      }
      
      # If nothing left to do -> finish
      if (length(bs$queue) == 0) {
        maybe_finish()
        return()
      }
      
      i <- bs$queue[[1]]
      bs$queue <- bs$queue[-1]
      bs$running <- bs$running + 1L
      
      run_one_plate_future(
        i = i,
        pairs_val = pairs_val,
        params = params,
        root_path = root_path,
        bs = bs,
        session = session,
        progress = progress,
        n = n,
        launch_next_fn = launch_next,
        maybe_finish_fn = maybe_finish,
        region = region
      )
    }
    
    for (k in seq_len(max_workers)) {
      launch_next()
    }
  }
  
  observeEvent(input$run_batch, {
    req(validated_pairs_cached(), nrow(validated_pairs_cached()) > 0)
    
    pairs_val <- validated_pairs_cached()
    n <- nrow(pairs_val)
    batch_start_time <- Sys.time()
    
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    
    batch_tag <- if (nzchar(input$batch_prefix %||% "")) {
      paste0(timestamp, "_", input$batch_prefix, "_batch")
    } else {
      paste0(timestamp, "_batch")
    }
    
    root_path <- file.path(wd_path(), "Analysis", batch_tag)
    
    dir.create(root_path, recursive = TRUE, showWarnings = FALSE)
    
    batch_root(root_path)
    clear_cancel_file(root_path)
    app_locked(TRUE)
    
    old_plan <- NULL
    
    if (requireNamespace("future", quietly = TRUE)) {
      old_plan <- future::plan()
      
      if (isTRUE(input$batch_parallel)) {
        future::plan(future::multisession, workers = 2)
      } else {
        future::plan(future::sequential)
      }
    }
    
    # CAPTURE REACTIVE VALUES HERE
    region_val <- region_selected()
    
    params <- list(
      hrs        = input$batch_hrs,
      interval   = input$batch_interval / 60,
      minod      = input$batch_minod,
      maxod      = input$batch_maxod,
      instrument = input$batch_instrument,
      blank_mode = input$batch_blank_mode,
      prefix     = input$batch_prefix,
      parallel   = input$batch_parallel
    )
    
    later::later(function() {
      run_batch_async(
        pairs_val = pairs_val,
        n = n,
        root_path = root_path,
        batch_start_time = batch_start_time,
        region = region_val,
        params = params,
        old_plan = old_plan
      )
    }, delay = 0)
  })
  
  shiny::observeEvent(input$prev_stage, {
    retreat_stage()
  })
  
  shiny::observeEvent(input$batch_design_select, {
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
  
  
  observeEvent(input$cancel_batch, {
    
    gc_log_block("CANCEL BUTTON CLICKED", list(
      batch_root_val = batch_root(),
      root_exists = dir.exists(batch_root())
    ))
    
    req(batch_root())
    
    root <- batch_root()
    
    create_cancel_file(root)
    
  })
  
  gc_disable_navigation <- function() {
    shinyjs::disable("prev_stage")
    shinyjs::disable("next_stage")
  }
  
  gc_enable_navigation <- function() {
    shinyjs::enable("prev_stage")
    shinyjs::enable("next_stage")
  }
  
  shiny::observeEvent(input$export_files, {
    req(analysis_result())
    res <- analysis_result()
    
    region <- region_selected()
    
    gc_disable_navigation()
    
    try(on.exit(gc_enable_navigation(), add = TRUE), silent = TRUE)
    
    f <- res$params
    
    # Build output directories explicitly
    dirs <- make_export_dirs(wd = wd_path(), prefix = f$prefix)
    
    # Derive plate name from raw file
    fname <- tools::file_path_sans_ext(input$raw_file)
    
    # Nest inside per-plate folder
    plate_dir <- file.path(dirs$analysis_dir, fname)
    
    last_export_dir(plate_dir)
    
    # --- Safety: never overwrite an existing analysis ---
    if (dir.exists(plate_dir)) {
      showModal(modalDialog(
        title = "Export aborted",
        shiny::tagList(
          p("An export with this prefix already exists.")
        ),
        easyClose = TRUE
      ))
      return()
    }
    
    withProgress(message = "Exporting analysis files", value = 0, {
      incProgress(0.2, "Creating directories")
      
      dir.create(plate_dir, recursive = TRUE, showWarnings = FALSE)
      
      incProgress(0.5, "Saving plots")
      
      report_file <- file.path(plate_dir, "plate_report.pdf")
      gc_save_report(plots = res$plots, file = report_file, plate_name = fname)
      
      incProgress(0.8, "Writing summary tables")
      
      gc_write_summaries(
        core        = res$core,
        params      = res$params,
        instrument  = res$instrument,
        out_dir     = plate_dir,
        region      = region_selected()
      )
      
      incProgress(1)
    })
    
    pretty_path <- tryCatch(
      pretty_export_path(plate_dir),
      error = function(e = NULL)
        plate_dir
    )
    
    showModal(
      modalDialog(
        title = "Export complete",
        shiny::tagList(
          p("Analysis files were written to:"),
          tags$div(
            style = "margin-top: 6px;",
            tags$code(style = "color: #1f78b4; font-size: 0.95em;", pretty_path)
          )
        ),
        easyClose = TRUE,
        footer = shiny::tagList(
          actionButton("open_export_dir", HTML("&#128193; Open export folder"), class = "btn-primary"),
          modalButton("Close")
        )
      )
    )
  })
  
  shiny::observeEvent(input$open_export_dir, {
    req(last_export_dir())
    open_folder_or_warn(last_export_dir())
  })
  
  shiny::observe({
    if (!is.null(analysis_result())) {
      shinyjs::disable("run")
      shinyjs::disable("hrs")
      shinyjs::disable("interval_min")
      shinyjs::disable("minod")
      shinyjs::disable("maxod")
      shinyjs::disable("prefix")
      shinyjs::disable("design_vars")
      shinyjs::disable("raw_file")
      shinyjs::disable("design_file")
      shinyjs::disable("instrument")
    }
  })
  
  shiny::observe({
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
  
  shiny::observeEvent(input$run_aggregate, {
    req(selected_runs())
    
    withProgress(message = "Combining runs...", value = 0, {
      incProgress(0.2, "Collecting files...")
      
      df <- selected_runs()
      dup_map <- duplicate_info()$duplicate_map
      
      if (length(dup_map) > 0) {
        
        # --- format names for display ---
        format_group_name <- function(key) {
          parts <- strsplit(key, "\\|\\|")[[1]]
          
          plate  <- parts[1]
          prefix <- parts[2]
          
          if (nzchar(prefix)) {
            paste0(prefix, " — ", plate)
          } else {
            paste0("(no prefix) — ", plate)
          }
        }
        
        display_names <- vapply(names(dup_map), format_group_name, character(1))
        
        showModal(
          modalDialog(
            title = "Overlapping plate data detected",
            
            tagList(
              p("Some selected runs contain overlapping plate data."),
              p("This may result in duplicated observations."),
              
              p(strong("Overlapping plates (grouped by prefix + plate):")),
              
              tags$ul(lapply(seq_along(dup_map), function(i) {
                tags$li(
                  tagList(
                    tags$strong(display_names[i]),
                    tags$ul(lapply(dup_map[[i]], tags$li))
                  )
                )
              })),
              
              p("Consider excluding one or more of the overlapping runs.")
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
  
  shiny::observeEvent(input$export_agg, {
    req(agg_result(), input$agg_dir)
    
    region <- region_selected()
    
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    
    out_file <- file.path(input$agg_dir,
                          paste0("combined_tidy_", timestamp, ".csv"))
    
    write_csv_safe(agg_result(), out_file, region = region_selected())
    
    pretty_path <- tryCatch(
      pretty_export_path(out_file),
      error = function(e = NULL)
        out_file
    )
    
    showModal(
      modalDialog(
        title = "Export complete",
        
        shiny::tagList(
          p("Combined dataset was written to:"),
          tags$div(
            style = "margin-top: 6px;",
            tags$code(style = "color: #1f78b4; font-size: 0.95em;", pretty_path)
          )
        ),
        
        easyClose = TRUE,
        
        footer = shiny::tagList(
          actionButton("open_agg_dir", HTML("&#128193; Open containing folder"), class = "btn-primary"),
          modalButton("Close")
        )
      )
    )
  })
  
}

# ---- app ----
app <- shiny::shinyApp(ui = ui, server = server)
app
