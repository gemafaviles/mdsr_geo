# options(bookdown.clean_book = TRUE)
# bookdown::clean_book()

styler::style_dir(filetype = ".Rmd")
styler::style_dir(filetype = ".R")

bookdown::render_book("index.Rmd", clean = TRUE, envir = new.env())
bookdown::render_book("index.Rmd",
  output_format = "bookdown::pdf_book",
  envir = new.env()
)

# bookdown::render_book("index.Rmd", output_format = "bookdown::epub_book", envir = new.env())
