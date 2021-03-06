#' @import Rtsne ggplot2
NULL

# ..count.. is part of the histogram syntax in ggplot2
utils::globalVariables("..count..")

#' @title Add tSNE to your results.
#'
#' @description This function gives the user the option to add t-SNE to the
#' final output, using the same input features used in KNN, eg. surface
#' markers, as input for t-SNE.
#' @param dat matrix of cells by features, that contain all features needed
#' for tSNE analysis
#' @param input the features to be used as input for tSNE,usually the same
#' for knn generation
#' @return result: dat, with tSNE1 and tSNE2 attached
AddTsne <- function(dat, input) {
    result <- Rtsne(X = dat[,input],
                    dims = 2,
                    pca = FALSE,
                    verbose = TRUE)$Y %>%
        as.tibble
    names(result) <- c("bh-SNE1", "bh-SNE2")
    result <- bind_cols(dat, result)
    return(result)
}

#' @title Subsample data and run tSNE
#'
#' @description  A wrapper for Rtsne that takes final SCONE output, and runs
#' tSNE on it after subsampling. This is specifically for SCONE runs that
#' contain large numbers of cells that tSNE would either be too time-consuming
#' or messy for. Regarding the latter, tSNE typically appears less clean
#' in the range of 10^5 cells
#' @param dat tibble of original input data, and scone-based additions.
#' @param input the markers used in the original knn computation, which are
#' typically surface markers
#' @param numcells the number of cells to be downsampled to
#' @return a subsampled tibble that contains tSNE values
#' @examples
#' SubsampleAndTsne(wand.combined, input.markers, 500)
#' @export
SubsampleAndTsne <- function(dat, input, numcells) {
    dat <- dat[sample(nrow(dat), numcells),]
    dat <- AddTsne(dat, input)
    return(dat)
}


#' @title Log transform the q values
#'
#' @description Takes all p values from the data and does a log10 transform
#' for easier visualization.
#' @param dat tibble containing cells x features, with orignal expression,
#' p values, and raw change
#' @param negative boolean value to determine whether to multiple transformed
#' p values by -1
#' @return result: tibble of cells x features with all p values log10
#' transformed
LogTransformQ <- function(dat, negative) {

    # Split the input
    qvalue <- dat[,grep("qvalue$", colnames(dat))]
    rest <- dat[, !(colnames(dat) %in% colnames(qvalue))]
    qvalue <- apply(qvalue, 2, log10) %>% as.tibble()

    # Inverse sometimes better for visualization
    if(negative == TRUE) {
        qvalue <- apply(qvalue, 2, function(x) x*-1) %>% as.tibble()
    }

    # Note that the order will be slightly different that the original "final"
    result <- bind_cols(rest, qvalue)
    return(result)
}

#' @title Transform strings to numbers.
#'
#' @description Takes a vector of strings and outputs simple numbers. This
#' takes care of the case where conditions are listed as strings (basal, IL7),
#' in which case they are converted to numbers (1, 2)
#' @param strings vector of strings
#' @return strings: same vector with each unique element converted to a number
#' @examples
#' ex.string <- c("unstim", "unstim", "stim", "stim", "stim")
#' StringToNumbers(ex.string)
#' @export
StringToNumbers <- function(strings) {
    elements <- unique(strings)
    for(i in seq_len(length(elements))) {
        strings <- ifelse(strings == elements[i], i, strings)
    }
    return(as.numeric(strings))
}


#' @title Post-processing for scone analysks.
#'
#' @description Performs final processing and transformations on the scone data
#' @export
#' @param scone.output tibble of the output of the given scone analysis
#' @param cell.data the tibble used as input for the scone.values function
#' @param input the input markers used for the knn calculation (to be used
#' for tsne here)
#' @param tsne boolean value to indicate whether tSNE is to be done
#' @param log.transform.qvalue boolean to indicate whether log transformation
#' of all q values is to be done
#' @return result: the concatenated original input data with the scone derived
#' data, with the option of the q values being inverse log10 transformed, and
#' two additional tSNE columns being added to the data (from the Rtsne package)
#' @examples
#' PostProcessing(wand.scone, wand.combined, input.markers, tsne = FALSE)
#' @export
PostProcessing <- function(scone.output,
                           cell.data,
                           input,
                           tsne = TRUE,
                           log.transform.qvalue = TRUE) {
    # Generic pre-processing
    result <- bind_cols(cell.data, scone.output) %>% na.omit()
    result$condition <- StringToNumbers(result$condition)

    # Adding two tSNE columns
    if(tsne == TRUE) {
        result <- AddTsne(dat = result, input = input)
    }

    # Doing an inverse log transformation of the q value
    if(log.transform.qvalue == TRUE) {
        result <- LogTransformQ(dat = result, negative = TRUE)
    }

    return(result)
}


#' @title make.hist
#'
#' @description Makes a histogram of the data that is inputted
#'
#' @param dat tibble consisting both of original markers and the appended
#' values from scone
#' @param k the binwidth, set to 1/k
#' @param column.label the label in the tibble's columns the function will
#' search for
#' @param x.label the label that the x axis will be labeled as
#' @return a histogram of said vector in ggplot2 form
#' @examples
#' MakeHist(wand.final, 100, "IL7.fraction.cond.2", "fraction IL7")
#' @export
MakeHist <- function(dat,
                      k,
                      column.label,
                      x.label) {
    ggplot(data = dat, aes(x = dat[[grep(column.label, colnames(dat))]])) +
        geom_histogram(aes(y = ..count..), binwidth = 1/k) +
        xlim(c(0, 1)) +
        theme(text = element_text(size = 20)) +
        xlab(x.label)
}

#' @title Plot a tSNE map colored by a marker of interest
#'
#' @description Wrapper for ggplot2 based plotting of a tSNE map to color
#' by markers from the post-processed file if tSNE was set to TRUE in
#' the post-processing function.
#'
#' @param final The tibble of cells by features outputted from the
#' post.processing function. These features encompass both regular markers
#' from the original data and the KNN statistics processed markers
#' @param marker String that matches the marker name in the final data object
#' exactly.
#' @param label a string that indicates the name of the color label in the
#' ensuing plot. Set to the marker string as default.
#' @return A plot of bh-SNE1 x bh-SNE2 colored by the specified marker.
#' @examples
#' TsneVis(wand.final, "pSTAT5(Nd150)Di.IL7.change", "pSTAT5 change")
#' @export
TsneVis <- function(final, marker, label = marker) {

    # Edge case: make sure marker is in the column names of the final data
    if(is.na(match(marker, colnames(final)))) {
        stop("Marker not found in column names")
    # Otherwise set the greph label to the marker name
    } else {

        # Set up the ggplot object
        p <- qplot(final[["bh-SNE1"]],
                   final[["bh-SNE2"]],
                   color = final[[marker]],
                   xlab = "bh-SNE1",
                   ylab = "bh-SNE2") +
            labs(color = paste(label)) +
            scale_color_gradientn(colors = c("black", "yellow"))
    }
    return(p)
}

