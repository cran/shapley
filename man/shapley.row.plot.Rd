% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/shapley.row.plot.R
\name{shapley.row.plot}
\alias{shapley.row.plot}
\title{Weighted mean SHAP values computed at subject level}
\usage{
shapley.row.plot(
  shapley,
  row_index,
  features = NULL,
  plot = TRUE,
  print = FALSE
)
}
\arguments{
\item{shapley}{object of class 'shapley', as returned by the 'shapley' function}

\item{row_index}{subject or row number in a wide-format dataset to be visualized}

\item{features}{character vector, specifying the feature to be plotted.}

\item{plot}{logical. if TRUE, the plot is visualized.}

\item{print}{logical. if TRUE, the WMSHAP summary table for the given row is printed}
}
\value{
a list including the GGPLOT2 object, the data frame of SHAP values,
        and performance metric of all models, as well as the model IDs.
}
\description{
Weighted mean of SHAP values and weighted SHAP confidence intervals
             provide a measure of feature importance for a grid of fine-tuned models
             or base-learners of a stacked ensemble model at subject level,
             showing that how each feature influences the prediction made for
             a row in the dataset and to what extend different models agree
             on that effect. If the 95% confidence interval crosses the
             vertical line at 0.00, then it can be concluded that the feature
             does not significantly influences the subject, when variability
             across models is taken into consideration.
}
\examples{

\dontrun{
# load the required libraries for building the base-learners and the ensemble models
library(h2o)            #shapley supports h2o models
library(shapley)

# initiate the h2o server
h2o.init(ignore_config = TRUE, nthreads = 2, bind_to_localhost = FALSE,
         insecure = TRUE)

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

                 seed = 2023, nfolds = 10,
                 keep_cross_validation_predictions = TRUE)

### call 'shapley' function to compute the weighted mean and weighted confidence intervals
### of SHAP values across all trained models.
### Note that the 'newdata' should be the testing dataset!
result <- shapley(models = aml, newdata = prostate,
                  performance_metric = "aucpr", plot = TRUE)

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

result2 <- shapley(models = grid, newdata = prostate,
                   performance_metric = "aucpr", plot = TRUE)

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

#plot all important features
shapley.row.plot(shapley, row_index = 11)

#plot only the given features
shapPlot <- shapley.row.plot(shapley, row_index = 11, features = c("PSA", "AGE"))

# inspect the computed data for the row 11
ptint(shapPlot$rowSummarySHAP)
}
}
\author{
E. F. Haghish
}
