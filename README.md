# Paris Restaurant Recommendation Dashboard

This project is an interactive R Shiny dashboard for exploring restaurant recommendations in Paris. It was converted from an R Notebook into a deployable Shiny script so the app can be run directly and hosted as a finished product.

## Features

- Filter restaurants by cuisine category, cuisine subcategory, price level, rating range, vegetarian-friendly options, gluten-free options, and awards.
- View summary metrics in a dedicated overview tab.
- Explore restaurants on an interactive Leaflet map.
- Search, sort, and paginate the restaurant table with DT.

## Project Structure

```text
.
├── app.R
├── cleaned_paris_restaurants.RData
├── R_app.Rmd
├── Programming_R_App_Lin TONG.pdf
└── README.md
```

## How to Run

Install the required R packages:

```r
install.packages(c("shiny", "shinydashboard", "leaflet", "dplyr", "DT", "scales"))
```

Run the application from this project folder:

```r
shiny::runApp()
```

Or from the terminal:

```bash
Rscript -e "shiny::runApp('.', launch.browser = TRUE)"
```

## Deployment

The app can be deployed to shinyapps.io with:

```r
rsconnect::deployApp()
```

The main deployable file is `app.R`; the notebook is kept only as the original development version.
