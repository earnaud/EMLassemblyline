#' Validate metadata template content
#'
#' @description
#'     Validate the content of `EMLassembline` metadata templates.
#'
#' @param fun.name
#'     (character) Function name passed to `validate_x` with 
#'     `as.character(match.call()[[1]])`.
#' @param x
#'     (named list) Use \code{template_arguments()} to create \code{x}.
#'
#' @details
#'     Validation checks are function specific.
#'
validate_templates <- function(fun.name, x){
  
  # Parameterize --------------------------------------------------------------
  
  attr_tmp <- read_template_attributes()
  
  if (fun.name == 'make_eml'){

    # make_eml() - abstract ---------------------------------------------------
    
    # Missing
    
    missing_abstract <- !any(
      stringr::str_detect(
        names(x$template), 
        attr_tmp$regexpr[attr_tmp$template_name == "abstract"]))
    if (isTRUE(missing_abstract)) {
      warning("An abstract is recommended.", call. = FALSE)
    }

    # FIXME: Report non-utf-8 encoded characters (generalize this function for 
    # TextType templates)
    
    # make_eml() - additional_info --------------------------------------------
    
    # FIXME: Report non-utf-8 encoded characters (generalize this function for 
    # TextType templates)
    
    # make_eml() - attributes -------------------------------------------------
    
    if (!is.null(x$data.table)) {
      
      # attributes.txt - attributes.txt should be present for each data table
      # otherwise the data table will be dropped from further processing.
      
      r <- unlist(
        lapply(
          names(x$data.table),
          function(k) {
            use_i <- stringr::str_detect(
              names(x$template), 
              paste0("attributes_", tools::file_path_sans_ext(k), ".txt"))
            if (!any(use_i)) {
              x$data.table[[k]] <<- NULL
              paste0(k, " is missing attributes metadata.")
            }
          }))
      if (!is.null(r)) {
        warning(paste(r, collapse = "\n"), call. = FALSE)
      }
      
      # attributeName - All table columns are listed as attributeName
      
      r <- unlist(
        lapply(
          names(x$data.table),
          function(k) {
            use_i <- colnames(x$data.table[[k]]$content) %in% 
              x$template[[
                paste0("attributes_", tools::file_path_sans_ext(k), ".txt")
                ]]$content$attributeName
            if (!all(use_i)) {
              paste0(k, " has columns that are not listed in ", 
                     "attributes_", tools::file_path_sans_ext(k), ".txt.",
                     " Add these columns:\n",
                     paste(colnames(x$data.table[[k]]$content)[!use_i], 
                           collapse = ", "))
            }
          }
        )
      )
      if (!is.null(r)) {
        stop(paste(r, collapse = "\n"), call. = F)
      }
      
      # attributeName - Names follow best practices
      
      check_table(
        x = x, 
        template.name = "attributes", 
        column.a = "attributeName", 
        column.b = "", 
        column.ref = "attributeName",
        test.expression = paste0(
          '(x$template[[k]]$content[[column.a]] != "") & ',
          'stringr::str_detect(x$template[[k]]$content[[column.a]], ',
          '"(%|[:blank:]|([:punct:]^_))")'),
        message.text = paste0(
          " contains attributes that don't follow best practices. ",
          "Consider revising these attributes to contain only alphanumeric ",
          "characters and underscores:"),
        error = F)
      
      # definition - Each attribute has a definition
      
      check_table(
        x = x,
        template.name = "attributes",
        column.a = "attributeName",
        column.b = "attributeDefinition",
        column.ref = "attributeName",
        test.expression = paste0(
          '(x$template[[k]]$content[[column.a]] != "") & ',
          '(x$template[[k]]$content[[column.b]] == "")'),
        message.text = paste0(
          " contains attributes without definition. ",
          "Add definitions to these attributes:"))
      
      
      # class - Each attribute has a class
      
      check_table(
        x = x, 
        template.name = "attributes", 
        column.a = "attributeName", 
        column.b = "class", 
        column.ref = "attributeName",
        test.expression = paste0(
          '(x$template[[k]]$content[[column.a]] != "") & ',
          '(x$template[[k]]$content[[column.b]] == "")'),
        message.text = paste0(
          " contains attributes without a class. ",
          "Add a class to these attributes:"))
      
      # class - Each class is numeric, Date, character, or categorical
      
      check_table(
        x = x, 
        template.name = "attributes", 
        column.a = "attributeName", 
        column.b = "class", 
        column.ref = "attributeName",
        test.expression = paste0(
          '(x$template[[k]]$content[[column.a]] != "") & ',
          '!stringr::str_detect(x$template[[k]]$content[[column.b]],',
          ' "numeric|Date|character|categorical")'),
        message.text = paste0(
          " contains attributes with unsupported classes. ",
          "Accepted classes are 'numeric', 'character', 'Date', and ",
          "'categorical'. Fix the class of these attributes:"))
      
      # class - Each Date class has a dateTimeformatString
      
      check_table(
        x = x, 
        template.name = "attributes", 
        column.a = "class", 
        column.b = "dateTimeFormatString", 
        column.ref = "attributeName",
        test.expression = paste0(
          '(tolower(x$template[[k]]$content[[column.a]]) == "date") & ',
          '(x$template[[k]]$content[[column.b]] == "")'),
        message.text = paste0(
          " has attributes classified as 'Date' without a corresponding date ",
          "time format string. Add a format string to these attributes:"))
      
      # class - Attributes specified by the user as numeric should contain no 
      # characters other than listed under missingValueCode of the table 
      # attributes template.
      
      invisible(
        lapply(
          names(x$data.table),
          function(table) {
            template <- paste0(
              "attributes_", tools::file_path_sans_ext(table), ".txt")
            use_i <- x$template[[template]]$content$class == "numeric"
            if (any(use_i)) {
              for (i in which(use_i)) {
                x$data.table[[table]]$content[ , i][
                  x$data.table[[table]]$content[ , i] == 
                    x$template[[template]]$content$missingValueCode[i]] <- NA
                na_before <- sum(is.na(x$data.table[[table]]$content[ , i]))
                na_after <- suppressWarnings(
                  sum(is.na(as.numeric(x$data.table[[table]]$content[ , i]))))
                if (na_before < na_after) {
                  warning(
                    "The attribute '",
                    x$template[[template]]$content$attributeName[i],
                    "' in the table '", table, "' is specified as numeric but ",
                    "contains character values other than listed under the ",
                    "missingValueCode column of the '", template, 
                    "' template. Defaulting '", 
                    x$template[[template]]$content$attributeName[i],
                    "' to 'character' class.", call. = F)
                  x$template[[template]]$content$class[i] <<- "character"
                  x$template[[template]]$content$unit[i] <<- ""
                }
              }
            }
          }))
      
      # class - Numeric classed attributes have units and units should be from 
      # the dictionary or defined in custom_units.txt
      # FIXME: This check should report all invalid content for all attributes.txt
      # templates, not just the first violation encountered.
      
      use_i <- stringr::str_detect(names(x$template), "attributes_.*.txt")
      if (any(use_i)) {
        u <- EML::get_unitList()$units$id
        if (is.data.frame(x$template$custom_units.txt$content)) {
          u <- c(u, x$template$custom_units.txt$content$id)
        }
        for (i in names(x$template)[use_i]) {
          a <- x$template[[i]]$content
          if (any((a$class == "numeric") & (a$unit == ""))) {
            stop(
              paste0(
                "Numeric classed attributes require a corresponding unit. The ",
                "attributes '",
                paste(
                  a$attributeName[(a$class == "numeric") & (a$unit == "")],
                  collapse = ", "
                ),
                "' in the file '",
                i,
                "' are missing units. Please reference the unit dictionary to ",
                "define these (run view_unit_dictionary() to access it) or ",
                "use the custom_units.txt template to define units that can't ",
                "be found in the dictionary."
              ),
              call. = FALSE)
          }
          if (!all(unique(a$unit[a$unit != ""]) %in% u)) {
            missing_units <- unique(a$unit[a$unit != ""])[
              !unique(a$unit[a$unit != ""]) %in% u
              ]
            stop(
              paste0(
                "All units require definition. The units '",
                paste(missing_units, collapse = ", "),
                "' cannot be found in the standard unit dictionary or the ",
                "custom_units.txt template. Please reference the unit ",
                "dictionary to define these (run view_unit_dictionary() to",
                " access it) or use the custom_units.txt ",
                "template to define units that can't be found in the ",
                "dictionary."
              ),
              call. = FALSE)
          }
        }
      }
      
      # dateTimeFormatString - Remaining dateTimeFormatString prompts have been 
      # removed
      # FIXME: Update this to look for characters not from the date and time 
      # format string character set (e.g. YMD hms)? (implement this in the metadata 
      # quality check functions to be developed? See GitHub issue #46)
      
      check_table(
        x = x, 
        template.name = "attributes", 
        column.a = "attributeName", 
        column.b = "dateTimeFormatString", 
        column.ref = "attributeName",
        test.expression = paste0(
          '(x$template[[k]]$content[[column.a]] != "") & ',
          'stringr::str_detect(x$template[[k]]$content[[column.b]], "^!.*!$")'),
        message.text = paste0(
          " contains invalid date time format strings. Check the format ",
          "strings of these attributes:"))
      
      # missingValueCode - Each missingValueCode has a 
      # missingValueCodeExplanation
      
      check_table(
        x = x, 
        template.name = "attributes", 
        column.a = "missingValueCode", 
        column.b = "missingValueCodeExplanation", 
        column.ref = "attributeName",
        test.expression = paste0(
          '(x$template[[k]]$content[[column.a]] != "") & ',
          '(x$template[[k]]$content[[column.b]] == "")'),
        message.text = paste0(
          " has missing value codes without explanation. ",
          "Add missing value code explanations for these attributes:"))
      
      # missingValueCode - Each missingValueCode only has 1 entry per column
      
      check_table(
        x = x, 
        template.name = "attributes", 
        column.a = "missingValueCode", 
        column.b = "", 
        column.ref = "attributeName",
        test.expression = paste0(
          "stringr::str_count(x$template[[k]]$content[[column.a]], ",
          "'[,]|[\\\\s]') > 0"),
        message.text = paste0(
          " has attributes with more than one missing value code. ",
          "Only one missing value code per attribute is allowed. ",
          "Remove extra mising value codes for these attributes:"))
      
      # missingValueCodeExplanation - Each missingValueCodeExplanation has a 
      # non-blank missingValueCode
      
      check_table(
        x = x, 
        template.name = "attributes", 
        column.a = "missingValueCodeExplanation", 
        column.b = "missingValueCode", 
        column.ref = "attributeName",
        test.expression = paste0(
          '(x$template[[k]]$content[[column.a]] != "") & ',
          '(x$template[[k]]$content[[column.b]] == "")'),
        message.text = paste0(
          " has missing value code explanations without a missing value codes. ",
          "Add missing value codes for these attributes:"))
      
    }
    
    # make_eml() - catvars ----------------------------------------------------
    
    if (!is.null(x$data.table)) {
      
      # catvars.txt - Required when table attributes are listed as 
      # "categorical"
      
      use_i <- stringr::str_detect(
        names(x$template),
        attr_tmp$regexpr[attr_tmp$template_name == "attributes"])
      if (any(use_i)) {
        r <- unlist(
          lapply(
            names(x$template)[use_i],
            function(k) {
              if (any(x$template[[k]]$content$class == "categorical")) {
                use_i <- stringr::str_detect(
                  names(x$template),
                  stringr::str_replace(k, "attributes", "catvars"))
                if (!any(use_i)) {
                  paste0(k, " contains categorical attributes but no categorical ",
                         "variables template can be found. Create one with the ",
                         "template_categorical_variables() function.")
                }
              }
            }
          )
        )
        if (!is.null(r)) {
          stop(paste(r, collapse = "\n"), call. = F)
        }
      }
      
      # codes - All codes require definition
      
      check_table(
        x = x,
        template.name = "catvars",
        column.a = "code",
        column.b = "definition",
        column.ref = "attributeName",
        test.expression = paste0(
          '(x$template[[k]]$content[[column.a]] != "") & ',
          '(x$template[[k]]$content[[column.b]] == "")'),
        message.text = paste0(
          " contains codes without definition. ",
          "Add codes for these attributes:"))
      
      # FIXME: codes - All codes in a table column are listed
      
    }
    
    # make_eml() - geographic_coverage ----------------------------------------
    
    # bounding_boxes.txt - This template is deprecated
    
    if (any(names(x$template) == "bounding_boxes.txt")) {
      warning(
        paste0(
          "Template 'bounding_boxes.txt' is deprecated; please use ", 
          "'geographic_coverage.txt' instead."),
        call. = F)
    }
    
    # template options - Only one geographic coverage template is allowed
    
    use_i <- stringr::str_detect(names(x$template), "bounding_boxes.txt|geographic_coverage.txt")
    if (sum(use_i) > 1) {
      stop(
        paste0(
          "Only one geographic coverage template is allowed. Please remove ",
          "one of these:\n", paste(names(x$template)[use_i], collapse = ",")),
        call. = F)
    }
    
    if (any(names(x$template) == "geographic_coverage.txt")) {
      
      # geographicDescription - Each entry requires a north, south, east, and west 
      # bounding coordinate
      
      check_table(
        x = x,
        template.name = "geographic_coverage",
        column.a = "geographicDescription",
        column.b = "",
        column.ref = "geographicDescription",
        test.expression = paste0(
          '(x$template[[k]]$content[[column.a]] != "") & ',
          'as.logical(rowSums(x$template[[k]]$content[ , ',
          'c("northBoundingCoordinate", "southBoundingCoordinate", ',
          '"eastBoundingCoordinate", "westBoundingCoordinate")] == ""))'),
        message.text = paste0(
          " contains missing coordinates. ",
          "Add missing coordinates for these geographic descriptions:"))
      
      # coordinates - Decimal degree is expected
      
      check_table(
        x = x,
        template.name = "geographic_coverage",
        column.a = "geographicDescription",
        column.b = "",
        column.ref = "geographicDescription",
        test.expression = paste0(
          'suppressWarnings((x$template[[k]]$content[[column.a]] != "") & ',
          'is.na(as.numeric(x$template[[k]]$content$northBoundingCoordinate)) | ',
          'is.na(as.numeric(x$template[[k]]$content$southBoundingCoordinate)) | ',
          'is.na(as.numeric(x$template[[k]]$content$eastBoundingCoordinate)) | ',
          'is.na(as.numeric(x$template[[k]]$content$westBoundingCoordinate)))'),
        message.text = paste0(
          " contains non-numeric coordinates. ",
          "Check coordinates of these geographic descriptions:"))

    }
    
    # make_eml() - intellectual_rights ----------------------------------------
    
    # Missing
    
    missing_intellectual_rights <- !any(
      stringr::str_detect(
        names(x$template), 
        attr_tmp$regexpr[attr_tmp$template_name == "intellectual_rights"]))
    if (isTRUE(missing_intellectual_rights)) {
      warning("An intellectual rights license is recommended.", call. = FALSE)
    }
    
    # FIXME: Report non-utf-8 encoded characters (generalize this function for 
    # TextType templates)
    
    # make_eml() - keywords ---------------------------------------------------
    
    # Missing
    
    missing_keywords <- !any(
      stringr::str_detect(
        names(x$template), 
        attr_tmp$regexpr[attr_tmp$template_name == "keywords"]))
    if (isTRUE(missing_keywords)) {
      warning("Keywords are recommended.", call. = FALSE)
    }
    
    # make_eml() - methods ----------------------------------------------------
    
    # Missing
    
    missing_methods <- !any(
      stringr::str_detect(
        names(x$template), 
        attr_tmp$regexpr[attr_tmp$template_name == "methods"]))
    if (isTRUE(missing_methods)) {
      warning("Methods are recommended.", call. = FALSE)
    }
    
    # FIXME: Report non-utf-8 encoded characters (generalize this function for 
    # TextType templates)
    
    # make_eml() - personnel --------------------------------------------------
    
    # Missing
    
    missing_personnel <- !any(
      stringr::str_detect(
        names(x$template), 
        attr_tmp$regexpr[attr_tmp$template_name == "personnel"]))
    if (isTRUE(missing_personnel)) {
      warning(
        "Personnel are required (i.e. creator, contact, etc.).", 
        call. = FALSE)
    }
    
    if (any(names(x$template) == "personnel.txt")) {

      # role - At least one creator and contact is listed
      
      use_i <- tolower(x$template$personnel.txt$content$role) == "creator"
      if (!any(use_i)) {
        warning("A creator is required.", call. = FALSE)
      }
      use_i <- tolower(x$template$personnel.txt$content$role) == "contact"
      if (!any(use_i)) {
        warning("A contact is required.", call. = FALSE)
      }
      
      # role - All personnel have roles
      
      use_i <- x$template$personnel.txt$content$role == ""
      if (any(use_i)) {
        warning(
          paste0("Each person must have a 'role'."), call. = FALSE)
      }
      
      # Principal Investigator and project info is recommended
      
      use_i <- tolower(x$template$personnel.txt$content$role) == "pi"
      if (!any(use_i)) {
        warning(
          "A principal investigator and project info are recommended.", 
          call. = FALSE)
      }
      
      # projectTitle, fundingAgency, fundingNumber - Project info is associated 
      # with first listed PI
      
      use_i <- tolower(x$template$personnel.txt$content$role) == "pi"
      if (any(use_i)) {
        pis <- x$template$personnel.txt$content[use_i, ]
        pi_proj <- pis[ , c("projectTitle", "fundingAgency", "fundingNumber")]
        if ((sum(pi_proj != "") > 0) & (sum(pi_proj[1, ] == "") == 3)) {
          stop(
            paste0(
              "The first Principal Investigator listed is ",
              "missing a projectTitle, fundingAgency, or fundingNumber. The ",
              "first listed PI represents the major project and requires ",
              "this."),
            call. = FALSE)
        }
      }
      
      # publisher - Only one publisher is allowed and the first will be used.
      
      use_i <- tolower(x$template$personnel.txt$content$role) == "publisher"
      if (sum(use_i) > 1) {
        warning(
          "personnel.txt has more than one 'publisher'. Only the first will ",
          "be used.", call. = FALSE)
        use_i <- min(which(x$template$personnel.txt$content$role == "publisher"))
        use_i <- which(x$template$personnel.txt$content$role == "publisher")[
          which(x$template$personnel.txt$content$role == "publisher") != use_i]
        x$template$personnel.txt$content <- x$template$personnel.txt$content[-c(use_i), ]
      }

    }
    
    # Return templates --------------------------------------------------------
    # Return x (with any changes made here in) back to the parent environment
    
    return(x)

  }
  
}




# Helper functions ------------------------------------------------------------




read_template_attributes <- function() {
  data.table::fread(
    system.file(
      '/templates/template_characteristics.txt',
      package = 'EMLassemblyline'), 
    fill = TRUE,
    blank.lines.skip = TRUE)
}




check_duplicate_templates <- function(path) {
  # path = Path to the directory containing metadata templates
  attr_tmp <- read_template_attributes()
  # FIXME: Remove the next line of code once table attributes and categorical 
  # variables have been consolidated into their respective single templates
  # (i.e. "table_attributes.txt" and "table_categorical_variables.txt").
  attr_tmp <- attr_tmp[
    !stringr::str_detect(attr_tmp$template_name, "attributes|catvars"), ]
  for (i in 1:length(attr_tmp$template_name)) {
    use_i <- stringr::str_detect(
      list.files(path), 
      attr_tmp$regexpr[
        attr_tmp$template_name == attr_tmp$template_name[i]])
    if (sum(use_i) > 1) {
      stop(
        paste0(
          "Duplicate '", 
          attr_tmp$template_name[i], 
          "' templates found. There can be only one."),
        call. = F)
    }
  }
}




check_table <- function(x, template.name, column.a, column.b, column.ref, test.expression, message.text, error = T) {
  # Function to test table criteria among rows
  # x = template_arguments()$x
  # template.name = Short name of the template being checked
  # column.a = Primary column
  # column.b = Secondary column
  # column.ref = Column (attribute) the users will be directed
  # test.expression = Expression that will be evaluated to index rows with issues
  # message.text = Error text to return to the user, prefixed with the table name
  #                and followed by the values of the secondary column that are 
  #                indexed by test.expression.
  attr_tmp <- read_template_attributes()
  use_i <- stringr::str_detect(
    names(x$template), 
    attr_tmp$regexpr[attr_tmp$template_name == template.name])
  if (any(use_i)) {
    r <- unlist(
      lapply(
        seq(length(use_i))[use_i],
        function(k) {
          use_i2 <- eval(parse(text = test.expression))
          if (any(use_i2)) {
            paste0(names(x$template[k]), message.text, "\n",
                   paste(
                     unique(x$template[[k]]$content[[column.ref]][use_i2]),
                     collapse = ", "))
          }
        }))
    if (!is.null(r)) {
      if (isTRUE(error)) {
        stop(paste(r, collapse = "\n"), call. = F)
      } else if (!isTRUE(error)) {
        warning(paste(r, collapse = "\n"), call. = F)
      }
    }
  }
}




remove_empty_templates <- function(x) {
  # Removes empty templates (NULL, data frames with 0 rows, or TextType of 0 
  # characters) from the list object created by template_arguments().
  # x = template_arguments()$x
  attr_tmp <- read_template_attributes()
  use_i <- rep(F, length(x$template))
  for (i in 1:length(x$template)) {
    if (is.null(x$template[[i]]$content)) {
      use_i[i] <- T
    } else {
      if (any(attr_tmp$template_name == 
              tools::file_path_sans_ext(names(x$template[i])))) {
        if ((attr_tmp$type[
          attr_tmp$template_name == 
          tools::file_path_sans_ext(names(x$template[i]))]) == "text") {
          if (sum(nchar(unlist(x$template[[i]]))) == 0) {
            use_i[i] <- T
          }
        } else if ((attr_tmp$type[
          attr_tmp$template_name == 
          tools::file_path_sans_ext(names(x$template[i]))]) == "xml") {
          if (length(x$template[[i]]$content$taxonomicClassification) == 0) {
            use_i[i] <- T
          }
        } else {
          if (nrow(x$template[[i]]$content) == 0) {
            use_i[i] <- T
          }
        }
      }
    }
  }
  if (all(use_i)) {
    x["template"] <-list(NULL)
  } else {
    x$template[use_i] <- NULL
  }
  x
}




# FIXME: Create function to remove user supplied NA from templates (a common 
# issue). EMLassemblyline should be smart enough to ignore these.
