styler::style_dir(filetype = ".Rmd")
rmarkdown::render("Apuntes_Master_File.Rmd")
rmarkdown::render("Apuntes_Master_File.Rmd", 
                  output_format = bookdown::pdf_document2(latex_engine = "xelatex",
                                                          toc = TRUE,
                                                          toc_depth =  2,
                                                          number_sections = TRUE,
                                                          global_numbering = TRUE))


bookdown::pd

