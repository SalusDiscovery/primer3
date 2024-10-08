
#' @useDynLib primer3
#' @importFrom Rcpp sourceCpp
NULL

#' Thermodynamic calculations with Primer3
#' 
#' These functions allow direct access to the Primer3 thermodynamic libraries via Rcpp.
#' For all functions besides \code{calculate_tm}, Primer3 requires initialization to
#' load the thermodynamic configuration data. The initialization will happen automatically
#' (and only once for each session) when a function that needs initialization is called.
#' (Or, the user can initialize manually by calling \code{primer3_init}, although there is
#' no advantage to this.) To avoid memory leaks, users should call \code{primer3_free} at
#' the end of the program to free memory allocated during initialization. Calling 
#' \code{primer3_free} after every call to a function will slow performance, since the 
#' configuration files will need to be reloaded during subsequent calls.
#' 
#' @param oligos Character vector of oligos. Calling once with multiple oligos is faster 
#' than repeated calls with single oligos.
#' @param salt_conc Monovalent salt concentration in mM.
#' @param divalent_conc Divalent ion concentration in mM.
#' @param dntp_conc dNTP concentration in mM.
#' @param dna_conc DNA concentration in nM.
#' @param nn_max_len Tm for oligos up to this length will be calculated using a nearest-neighbor
#' method. Beyond this length, the Tm is extrapolated based on GC content.
#' @param tm_method Method for Tm calculations. Options include "Breslauer" and "SantaLucia". 
#' As with \code{salt_correction}, this package uses the recommended Primer3
#' method ("SantaLucia"), not the Primer3 default method ("Schildkraut").
#' @param salt_correction Method for salt correction calculations. Options include "Schildkraut", 
#' "SantaLucia", "Owczarzy". As with \code{tm_method}, this package uses the recommended Primer3
#' method ("SantaLucia"), not the Primer3 default method ("Schildkraut").
#' @param maxloop Maximum length of loop structures. Not available for \code{calculate_tm}.
#' @param temp_c Temperature in degrees Celsius. Not available for \code{calculate_tm}.
#' @param print_output If \code{TRUE}, print alignment or secondary structure to terminal. 
#' When \code{TRUE}, no output is returned. Not available for \code{calculate_tm}.
#' 
#' @return For \code{calculate_tm}, a numeric vector with the melting temperature [C] for each
#' input oligo. For the other functions, a named list of vectors indicating if a structure was 
#' found (\code{structure_found}); the changes in entropy (\code{ds}), enthalpy (\code{dh}), 
#' and Gibbs free energy (\code{dg}); and the alignment locations for each end (\code{align_end_1}
#' and \code{align_end_2}). Note that if \code{print_output} is \code{TRUE}, the functions return
#' \code{NULL}.
#' 
#' @seealso \code{\link{primer3_free}}
#' 
#' @name thermo
NULL

TM_METHODS <- c("Breslauer", "SantaLucia")
SALT_CORRECTION_METHODS <- c("Schildkraut", "SantaLucia", "Owczarzy")

toLower <- function(x)
{
  # print(x)
  ret <- tryCatch(tolower(x),
                  error=function(cond){
                    print(x)
                    browser()
                    return(NULL)
                  })
  return(ret)
}

toUpper <- function(x)
{
  # print(x)
  ret <- tryCatch(toupper(x),
                  error=function(cond){
                    print(x)
                    browser()
                    return(NULL)
                  })
  return(ret)
}

#' @rdname thermo
#' @export
calculate_tm <- function(oligos, 
                         salt_conc=50.0, 
                         divalent_conc=0.0, 
                         dntp_conc=0.0, 
                         dna_conc=50.0,
                         nn_max_len=60,
                         tm_method="SantaLucia",
                         salt_correction="SantaLucia") {
  tm_method <- pmatch(toLower(tm_method), toLower(TM_METHODS)) - 1L
  salt_correction <- pmatch(toLower(salt_correction), toLower(SALT_CORRECTION_METHODS)) - 1L
  if (is.na(tm_method) || is.na(salt_correction)) {
    stop("Invalid Tm or salt correction method.")
  }
  call_seq_tm(oligos, salt_conc, divalent_conc, dntp_conc, dna_conc, as.integer(nn_max_len), tm_method, salt_correction)
}

#' Loading Primer3 configuration files
#' 
#' For all functions besides \code{calculate_tm}, Primer3 requires initialization to
#' load the thermodynamic configuration data. The initialization will happen automatically
#' (and only once for each session) when a function that needs initialization is called.
#' (Or, the user can initialize manually by calling \code{primer3_init}, although there is
#' no advantage to this.) To avoid memory leaks, users should call \code{primer3_free} at
#' the end of the program to free memory allocated during initialization. Calling 
#' \code{primer3_free} after every call to a function will slow performance, since the 
#' configuration files will need to be reloaded during subsequent calls.
#' 
#' @param config_path Path to Primer3 configuration files. These are installed by default with
#' this package. The path must not end with a "\code{/}".
#' 
#' @name init
NULL

#' @rdname init
#' @export
primer3_init <- function(config_path=system.file("extdata/primer3_config", package="primer3")) {
  invisible(call_thal_init(paste0(config_path, .Platform$file.sep)))
}

#' @rdname init
#' @export
primer3_free <- function() {
  call_thal_free()
}

thal <- function(oligo1, oligo2, 
                 alignment_type = 1L,
                 maxloop = 30L,
                 mv = 50.0,
                 dv = 0.0,
                 dntp = 0.0,
                 dna = 50.0,
                 temp_c = 37.0,
                 debug = FALSE,
                 temp_only = FALSE,
                 dimer = FALSE,
                 print_output = FALSE) {
  if (!is_thal_init()) {
    primer3_init()
  }
  temp <- temp_c + 273.15  # temp must be absolute
  print_output <- as.integer(print_output)
  results <- call_thal(oligo1, oligo2, as.integer(debug), alignment_type, maxloop, mv, dv, dntp, dna, temp, as.integer(temp_only), as.integer(dimer), as.integer(print_output))
  
  if (print_output) {
    # the return values are messed up when printing; call twice
    return(NULL)
  } else {
    return(results)
  }
}

#' @rdname thermo
#' @export
calculate_hairpin <- function(oligo, ...) {
  n <- calcLen(oligo)
  if(n > 47) # max size allowed by primer3
  {
    return(list(structure_found=F, temp=0, dg=0, structure=''))
  }
  else
  {
    ret <- thal(oligo, oligo, ..., alignment_type = 4L)
    
    # print(ret$seq1)
    ret$structure <- paste(normalizeHpString(ret$seq1, n), collapse='')
    ret$seq1 <- NULL
    ret$seq2 <- NULL
    ret$seq3 <- NULL
    ret$seq4 <- NULL
    return(ret)
  }
}

calcLen <- function(oligo)
{
  return(ifelse(length(oligo)==1, nchar(oligo), length(oligo)))
}

#' @rdname thermo
#' @export
calculate_homodimer <- function(oligo, ...) {
  return(calculate_dimer(oligo, oligo, ...))
}


normalizeHpString <- function(x, n)
{
  normalizeString(x, n=n, allowedChars=c('-','(',')'))
}

normalizeDimerString <- function(x)
{
  normalizeString(x, n=NULL, allowedChars=c('A','G','T','C','-',' ','&'))
}

normalizeString <- function(x, n, allowedChars=c('-','(',')'))
{
  # Post-process structure results in R
  temp <- s2c(x)
  # Catch and remove odd characters
  temp <- temp[validUTF8(temp)]
  temp <- temp[temp %in% allowedChars]
  if(!is.null(n) && length(temp) > n)
  {
    temp <- temp[1:n]
  }
  return(temp)
}

#' @rdname thermo
#' @importFrom seqinr s2c
#' @export
calculate_dimer <- function(oligo1, oligo2, ...) {
  if(calcLen(oligo1) > 47 || calcLen(oligo2) > 47)
  {
    return(list(structure_found=F, temp=0, dg=0, structure=''))
  }
  else
  {
    ret <- thal(oligo1, oligo2, ..., alignment_type = 1L)
    
    # # Post-process structure results in R
    # print(ret$seq1)
    # print(ret$seq4)
    # print(ret$seq2)
    # print(ret$seq3)
    # browser()
    ret$oligo1 <- toLower(normalizeDimerString(ret$seq1))
    ret$oligo2 <- toLower(normalizeDimerString(ret$seq4))
    ret$seq2 <- normalizeDimerString(ret$seq2)
    ret$seq3 <- normalizeDimerString(ret$seq3)
    uppers1 <- ret$seq2 %in% c('A','G','T','C')
    uppers2 <- ret$seq3 %in% c('A','G','T','C')
    ret$oligo1[uppers1] <- ret$seq2[uppers1]
    ret$oligo2[uppers2] <- ret$seq3[uppers2]
    ret$oligo1 <- ret$oligo1[validUTF8(ret$oligo1)]
    ret$oligo2 <- ret$oligo2[validUTF8(ret$oligo2)]
    ret$structure <- paste(c(paste(ret$oligo1, collapse=''), '&', paste(ret$oligo2, collapse='')), collapse='')
    ret$oligo1 <- NULL
    ret$oligo2 <- NULL
    ret$seq1 <- NULL
    ret$seq2 <- NULL
    ret$seq3 <- NULL
    ret$seq4 <- NULL
    return(ret)
  }
}

#' @export
run_primer3 <- function(input, path=".", exec="primer3_core", temp="TEMP_input.txt") {
  boulderio::write_boulder(input, file=temp)
  prev <- getwd()
  full_temp <- file.path(prev, temp)
  setwd(path)
  output <- system(paste(exec, "<", full_temp), intern=TRUE)
  
  setwd(prev)
  file.remove(temp)
  
  return(boulderio::parse_boulder(output))
}
