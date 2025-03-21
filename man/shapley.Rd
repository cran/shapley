% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/shapley.R
\name{shapley}
\alias{shapley}
\title{Weighted Mean SHAP Ratio and Confidence Interval for a ML Grid
       of Fine-Tuned Models or Base-Learners of a Stacked Ensemble Model}
\usage{
shapley(
  models,
  newdata,
  plot = TRUE,
  performance_metric = "r2",
  standardize_performance_metric = FALSE,
  performance_type = "xval",
  minimum_performance = 0,
  method = "mean",
  cutoff = 0.01,
  top_n_features = NULL,
  n_models = 10,
  sample_size = nrow(newdata)
)
}
\arguments{
\item{models}{h2o search grid, autoML grid, or a character vector of H2O model IDs.}

\item{newdata}{An \code{h2o} frame (or \code{data.frame}) already uploaded to the
\code{h2o} server. This data will be used for computing SHAP
contributions for each model, alongside model's performance
weights.}

\item{plot}{logical. if TRUE, the weighted mean and confidence intervals of
the SHAP values are plotted. The default is TRUE.}

\item{performance_metric}{Character specifying which performance metric to use
as weights. The default is \code{"r2"}, which can
be used for both regression and classification.
For binary classification, other options include:
\code{"aucpr"} (area under the precision-recall curve),
\code{"auc"} (area under the ROC curve),
and \code{"f2"} (F2 score).}

\item{standardize_performance_metric}{Logical, indicating whether to standardize
the performance metric used as weights so
their sum equals the number of models. The
default is \code{FALSE}.}

\item{performance_type}{Character. Specify which performance metric should be
reported: \code{"train"} for training data, \code{"valid"}
for validation, or \code{"xval"} for cross-validation (default).}

\item{minimum_performance}{Numeric. Specify the minimum performance metric
for a model to be included in calculating weighted
mean SHAP ratio Models below this threshold receive
zero weight. The default is \code{0}.}

\item{method}{Character. Specify the method for selecting important features
based on their weighted mean SHAP ratios. The default is
\code{"mean"}, which selects features whose weighted mean shap ratio (WMSHAP)
exceeds the \code{cutoff}. The alternative is
\code{"lowerCI"}, which selects features whose lower bound of confidence
interval exceeds the \code{cutoff}.}

\item{cutoff}{numeric, specifying the cutoff for the method used for selecting
the top features.}

\item{top_n_features}{integer. if specified, the top n features with the
highest weighted SHAP values will be selected, overrullung
the 'cutoff' and 'method' arguments. specifying top_n_feature
is also a way to reduce computation time, if many features
are present in the data set. The default is NULL, which means
the shap values will be computed for all features.}

\item{n_models}{minimum number of models that should meet the 'minimum_performance'
criterion in order to compute WMSHAP and CI. If the intention
is to compute global summary SHAP values (at feature level) for
a single model, set n_models to 1. The default is 10.}

\item{sample_size}{integer. number of rows in the \code{newdata} that should
be used for SHAP assessment. By default, all rows are used,
which is the recommended procedure for scientific analyses.
However, SHAP analysis is time consuming and in the process
of code development, lower values can be used for quicker
shapley analyses.}
}
\value{
a list including the GGPLOT2 object, the data frame of SHAP values,
        and performance metric of all models, as well as the model IDs.
}
\description{
Calculates weighted mean SHAP ratios and confidence intervals to assess feature importance
across a collection of models (e.g., a grid of fine-tuned models or base-learners
in a stacked ensemble). Rather than reporting relative SHAP contributions for
only a single model, this function accounts for variability in feature importance
across multiple models. Each model's performance metric is used as a weight.
The function also provides a plot of weighted SHAP values with confidence intervals.
Currently, only models trained by the \code{h2o} machine learning platform,
\code{autoEnsemble}, and the \code{HMDA} R packages are supported.
}
\details{
The function works as follows:
   \enumerate{
     \item SHAP contributions are computed at the individual level (row) for each model for the given "newdata".
     \item Each model's feature-level SHAP ratios (i.e., share of total SHAP) are computed.
     \item The performance metrics of the models are used as weights.
     \item Using the weights vector and shap ratio of features for each model,
           the weighted mean SHAP ratios and their confidence intervals are computed.
   }
}
\examples{

\dontrun{
# load the required libraries for building the base-learners and the ensemble models
library(h2o)            #shapley supports h2o models
library(shapley)

# initiate the h2o server
h2o.init(ignore_config = TRUE, nthreads = 2, bind_to_localhost = FALSE, insecure = TRUE)

# upload data to h2o cloud
prostate_path <- system.file("extdata", "prostate.csv", package = "h2o")
prostate <- h2o.importFile(path = prostate_path, header = TRUE)

set.seed(10)

### H2O provides 2 types of grid search for tuning the models, which are
### AutoML and Grid. Below, I demonstrate how weighted mean shapley values
### can be computed for both types.

#######################################################
### PREPARE AutoML Grid (takes a couple of minutes)
#######################################################
# run AutoML to tune various models (GBM) for 60 seconds
y <- "CAPSULE"
prostate[,y] <- as.factor(prostate[,y])  #convert to factor for classification
aml <- h2o.automl(y = y, training_frame = prostate, max_runtime_secs = 120,
                 include_algos=c("GBM"),

                 # this setting ensures the models are comparable for building a meta learner
                 seed = 2023, nfolds = 10,
                 keep_cross_validation_predictions = TRUE)

### call 'shapley' function to compute the weighted mean and weighted confidence intervals
### of SHAP values across all trained models.
### Note that the 'newdata' should be the testing dataset!
result <- shapley(models = aml, newdata = prostate, performance_metric = "aucpr", plot = TRUE)

#######################################################
### PREPARE H2O Grid (takes a couple of minutes)
#######################################################
# make sure equal number of "nfolds" is specified for different grids
grid <- h2o.grid(algorithm = "gbm", y = y, training_frame = prostate,
                 hyper_params = list(ntrees = seq(1,50,1)),
                 grid_id = "ensemble_grid",

                 # this setting ensures the models are comparable for building a meta learner
                 seed = 2023, fold_assignment = "Modulo", nfolds = 10,
                 keep_cross_validation_predictions = TRUE)

result2 <- shapley(models = grid, newdata = prostate, performance_metric = "aucpr", plot = TRUE)

#######################################################
### PREPARE autoEnsemble STACKED ENSEMBLE MODEL
#######################################################

### get the models' IDs from the AutoML and grid searches.
### this is all that is needed before building the ensemble,
### i.e., to specify the model IDs that should be evaluated.
library(autoEnsemble)
ids    <- c(h2o.get_ids(aml), h2o.get_ids(grid))
autoSearch <- ensemble(models = ids, training_frame = prostate, strategy = "search")
result3 <- shapley(models = autoSearch, newdata = prostate,
                   performance_metric = "aucpr", plot = TRUE)


}
}
\author{
E. F. Haghish
}
