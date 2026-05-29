# ------------------------------------------------------------
# Update USERGUIDE.md from template
# ------------------------------------------------------------

# Get version
version <- paste("Version", as.character(utils::packageVersion("growthcurve")))

# Paths
input_file  <- "dev/USERGUIDE_source.md"
output_file <- "USERGUIDE.md"

# Read source
lines <- readLines(input_file, warn = FALSE)

# Replace placeholder
lines <- gsub("\\{\\{VERSION\\}\\}", version, lines)

# Add header
header <- c(
  "<!--",
  "This file is auto-generated from dev/USERGUIDE_source.md",
  "Do not edit manually.",
  "-->",
  ""
)

# Write final file
writeLines(c(header, lines), output_file)

cat("USERGUIDE.md updated with", version, "\n")
