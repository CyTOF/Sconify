% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/process.files.R
\name{QuantNormalize}
\alias{QuantNormalize}
\title{Performs quantile normalization on the data frame (patient)
of interest}
\usage{
QuantNormalize(df)
}
\arguments{
\item{df}{a data frame with rows as cells and columns as features}
}
\value{
a data frame where the columns have been quantile normalized
}
\description{
Credit goes to:
http://davetang.org/muse/2014/07/07/quantile-normalisation-in-r/
for this function
}
