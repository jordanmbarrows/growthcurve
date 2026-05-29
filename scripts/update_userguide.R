# ------------------------------------------------------------
# Update USERGUIDE.md from template
# ------------------------------------------------------------

# Get version
version <- paste("Version", as.character(utils::packageVersion("growthcurve")))

# Paths
input_file  <- "USERGUIDE_source.md"
output_file <- "USERGUIDE.md"

# Read source
lines <- readLines(input_file, warn = FALSE)

# Replace placeholder
lines <- gsub("\\{\\{VERSION\\}\\}", version, lines)

# Write final file
writeLines(lines, output_file)

cat("USERGUIDE.md updated with", version, "\n")
