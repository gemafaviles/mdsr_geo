# options(bookdown.clean_book = TRUE)
# bookdown::clean_book()

styler::style_dir(filetype = ".Rmd")
styler::style_dir(filetype = ".R")

# Esto crea el libro en html
bookdown::render_book("index.Rmd",
  clean = TRUE, envir = new.env()
)

# Esto cambia References por Referencias en el html
html <- list.files("book_geodatos", pattern = ".html$", full.names = TRUE)

for (file in html) {
  n <- readLines(file)
  n <- gsub("References", "Referencias", n)
  writeLines(n, file)
  rm("n")
}

# # Esto crea un pdf
# bookdown::render_book("index.Rmd",
#   output_format = "bookdown::pdf_book",
#   envir = new.env()
# )

# Esto crea un epub
bookdown::render_book("index.Rmd",
  output_format = "bookdown::epub_book",
  envir = new.env()
)


if (!dir.exists("book_geodatos/aplicaciones/")) dir.create("book_geodatos/aplicaciones/", recursive = TRUE)
# Esto crea las aplicaciones
# Por algún motivo ¿? en mi ordenador es necesario correrlo
# a partir de una session nueva (Session>Restart)
rmarkdown::render("99-aplicaciones.Rmd",
  output_format = "bookdown::html_document2",
  output_file = "book_geodatos/aplicaciones/index.html"
)

# Extrae código
knitr::purl("99-aplicaciones.Rmd",
            "book_geodatos/aplicaciones/aplicaciones.R")


knitr::pu
# rmd_files: ["index.Rmd", "01-rev_geodatos.Rmd", "02-geocomp.Rmd","03-formatos.Rmd", "04-est_esp.Rmd","05-anexo.Rmd"]

# bookdown::render_book("index.Rmd", output_format = "bookdown::epub_book", envir = new.env())
