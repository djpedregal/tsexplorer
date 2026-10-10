# Documentation of the example datasets.

#' Airline passengers
#'
#' Monthly totals of international airline passengers (thousands), January
#' 1949 to December 1960. Series G of Box and Jenkins.
#' @format A monthly `ts` object with 144 observations.
#' @source Box, G.E.P., Jenkins, G.M. and Reinsel, G.C. (2008). *Time Series
#'   Analysis, Forecasting and Control*. Wiley.
"airpas"

#' Nile river flow
#'
#' Annual flow of the river Nile at Aswan, 1871-1970.
#' @format An annual `ts` object with 100 observations.
#' @source Cobb, G.W. (1978). The problem of the Nile: conditional solution to
#'   a changepoint problem. *Biometrika*, 65, 243-251.
"nile"

#' Road casualties
#'
#' Monthly number of car drivers killed or seriously injured in Great
#' Britain, January 1969 to December 1984.
#' @format A monthly `ts` object with 192 observations.
#' @source Harvey, A.C. and Durbin, J. (1986). The effects of seat belt
#'   legislation on British road casualties: a case study in structural time
#'   series modelling. *Journal of the Royal Statistical Society A*, 149,
#'   187-227.
"victims"

#' US GDP
#'
#' US gross domestic product, quarterly data (without dates).
#' @format A numeric vector with 241 observations.
"usgdp"

#' Steel data
#'
#' Example series (without dates).
#' @format A numeric vector with 157 observations.
"steel"

#' Lydia Pinkham advertising and sales
#'
#' Annual advertising expenditure and sales of the Lydia E. Pinkham Medicine
#' Company, 1907-1960.
#' @format An annual `mts` object with 54 observations of `advertising` and
#'   `sales`.
#' @source Palda, K.S. (1964). *The Measurement of Cumulative Advertising
#'   Effects*. Prentice-Hall.
"lydia_pinkham"

#' Gas furnace data
#'
#' Box-Jenkins series J: output CO2 concentration and input gas rate of a gas
#' furnace, sampled every 9 seconds.
#' @format A numeric matrix with 296 rows and columns `co2` and `gas_rate`.
#' @source Box, G.E.P., Jenkins, G.M. and Reinsel, G.C. (2008). *Time Series
#'   Analysis, Forecasting and Control*. Wiley.
"furnace"

#' Gas and electricity data
#'
#' Two monthly series from January 1992 (unnamed).
#' @format A monthly `mts` object with 213 observations of `y1` and `y2`.
"gaselec"

#' Unemployment data
#'
#' Two monthly series from January 2000 (unnamed).
#' @format A monthly `mts` object with 124 observations of `y1` and `y2`.
"unemployment"

#' Electricity data
#'
#' Two high frequency series (without dates or names).
#' @format A numeric matrix with 2472 rows and columns `y1` and `y2`.
"electricity"

#' SCC data
#'
#' Three series (without dates or names).
#' @format A numeric matrix with 62 rows and columns `y1`, `y2` and `y3`.
"scc"
