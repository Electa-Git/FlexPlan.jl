# Modeling assumptions

## Multiple-year models

When preparing data for problems spanning a multi-year horizon (here the word _year_ indicates an investment period: different investment decisions can be made in different years), investment candidates must adhere to the following two assumptions:

1. If a candidate exists in a year, then it exists in all subsequent years and is defined in the same row of the corresponding table in the input data files.
2. Each candidate has the same parameters in all the years in which it exists, except for the cost which may vary with the years.

These assumptions are used not only when parsing input data files, but also in some variables/constraints where an investment candidate must be tracked along years.
