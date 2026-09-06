library(shiny)
library(shinydashboard)
library(leaflet)
library(dplyr)
library(DT)
library(scales)

load("cleaned_paris_restaurants.RData")

restaurant_data <- cleaned_paris_restaurants %>%
  mutate(
    cuisine_category = if_else(is.na(cuisine_category), "Uncategorized", cuisine_category),
    cuisine_subcategory = if_else(is.na(cuisine_subcategory), "Uncategorized", cuisine_subcategory),
    price_level = if_else(is.na(price_level), "Unknown", price_level),
    awards = if_else(is.na(awards) | awards == "", "N", awards),
    vegetarian_friendly = if_else(!is.na(vegetarian_friendly) & vegetarian_friendly == "Y", "Y", "N"),
    gluten_free = if_else(!is.na(gluten_free) & gluten_free == "Y", "Y", "N"),
    recommendation_score = avg_rating * 20 +
      log1p(total_reviews_count) * 8 +
      if_else(awards != "N", 10, 0)
  )

category_choices <- sort(unique(restaurant_data$cuisine_category))
price_choices <- sort(unique(restaurant_data$price_level))

ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = "Paris Restaurants"),
  dashboardSidebar(
    width = 300,
    sidebarMenu(
      id = "tabs",
      menuItem("Overview", tabName = "overview", icon = icon("bar-chart")),
      menuItem("Map", tabName = "map", icon = icon("map-marker")),
      menuItem("Restaurant List", tabName = "restaurant_list", icon = icon("table"))
    ),
    tags$hr(),
    div(
      class = "filter-panel",
      selectInput(
        "cuisine_category",
        "Cuisine category",
        choices = c("All", category_choices),
        selected = "All"
      ),
      selectInput(
        "cuisine_subcategory",
        "Cuisine subcategory",
        choices = "All",
        selected = "All"
      ),
      selectInput(
        "price_level",
        "Price level",
        choices = c("All", price_choices),
        selected = "All"
      ),
      sliderInput(
        "rating",
        "Rating range",
        min = 0,
        max = 5,
        value = c(3, 5),
        step = 0.1
      ),
      checkboxInput("vegetarian", "Vegetarian-friendly only", value = FALSE),
      checkboxInput("gluten_free", "Gluten-free options only", value = FALSE),
      checkboxInput("has_awards", "Restaurants with awards only", value = FALSE),
      selectInput(
        "sort_by",
        "Sort results by",
        choices = c(
          "Rating" = "avg_rating",
          "Review count" = "total_reviews_count",
          "Popularity rank" = "popularity_generic"
        ),
        selected = "avg_rating"
      )
    )
  ),
  dashboardBody(
    tags$head(
      tags$style(HTML("
        body, .content-wrapper {
          background: #f7f9fb;
          font-family: Arial, sans-serif;
        }

        .main-header .logo, .main-header .navbar {
          background-color: #1f4f7a !important;
        }

        .skin-blue .main-sidebar {
          background-color: #17324d;
        }

        .skin-blue .sidebar-menu > li.active > a,
        .skin-blue .sidebar-menu > li:hover > a {
          background-color: #246a9b;
          border-left-color: #f4b942;
        }

        .filter-panel {
          padding: 0 16px 16px;
        }

        .filter-panel label,
        .filter-panel .checkbox label {
          color: #f7f9fb;
        }

        .content-header > h1 {
          font-size: 26px;
          font-weight: 700;
        }

        .box {
          border-radius: 6px;
          border-top: 3px solid #1f4f7a;
        }

        .small-box {
          border-radius: 6px;
        }

        .leaflet-container {
          border-radius: 6px;
        }
      "))
    ),
    tabItems(
      tabItem(
        tabName = "overview",
        fluidRow(
          valueBoxOutput("total_restaurants", width = 3),
          valueBoxOutput("avg_rating", width = 3),
          valueBoxOutput("award_count", width = 3),
          valueBoxOutput("avg_reviews", width = 3)
        ),
        fluidRow(
          box(
            title = "Top Cuisine Categories",
            width = 6,
            status = "primary",
            solidHeader = TRUE,
            DTOutput("category_table")
          ),
          box(
            title = "Price Distribution",
            width = 6,
            status = "primary",
            solidHeader = TRUE,
            DTOutput("price_table")
          ),
          box(
            title = "Top Recommended Restaurants",
            width = 12,
            status = "primary",
            solidHeader = TRUE,
            DTOutput("recommended_table")
          )
        )
      ),
      tabItem(
        tabName = "map",
        fluidRow(
          box(
            title = "Restaurant Map",
            width = 12,
            status = "primary",
            solidHeader = TRUE,
            leafletOutput("restaurant_map", height = 620)
          )
        )
      ),
      tabItem(
        tabName = "restaurant_list",
        fluidRow(
          box(
            title = "Restaurant List",
            width = 12,
            status = "primary",
            solidHeader = TRUE,
            DTOutput("restaurant_table")
          )
        )
      )
    )
  )
)

server <- function(input, output, session) {
  observeEvent(input$cuisine_category, {
    subcategories <- restaurant_data

    if (!is.null(input$cuisine_category) && input$cuisine_category != "All") {
      subcategories <- subcategories %>%
        filter(cuisine_category == input$cuisine_category)
    }

    updateSelectInput(
      session,
      "cuisine_subcategory",
      choices = c("All", sort(unique(subcategories$cuisine_subcategory))),
      selected = "All"
    )
  }, ignoreInit = FALSE)

  filtered_data <- reactive({
    data <- restaurant_data

    if (input$cuisine_category != "All") {
      data <- data %>% filter(cuisine_category == input$cuisine_category)
    }

    if (input$cuisine_subcategory != "All") {
      data <- data %>% filter(cuisine_subcategory == input$cuisine_subcategory)
    }

    if (input$price_level != "All") {
      data <- data %>% filter(price_level == input$price_level)
    }

    data <- data %>%
      filter(
        !is.na(avg_rating),
        avg_rating >= input$rating[1],
        avg_rating <= input$rating[2]
      )

    if (isTRUE(input$vegetarian)) {
      data <- data %>% filter(vegetarian_friendly == "Y")
    }

    if (isTRUE(input$gluten_free)) {
      data <- data %>% filter(gluten_free == "Y")
    }

    if (isTRUE(input$has_awards)) {
      data <- data %>% filter(awards != "N")
    }

    if (input$sort_by == "popularity_generic") {
      data %>% arrange(.data[[input$sort_by]], desc(avg_rating), restaurant_name)
    } else {
      data %>% arrange(desc(.data[[input$sort_by]]), restaurant_name)
    }
  })

  output$total_restaurants <- renderValueBox({
    valueBox(
      comma(nrow(filtered_data())),
      "Restaurants",
      icon = icon("cutlery"),
      color = "blue"
    )
  })

  output$avg_rating <- renderValueBox({
    avg <- mean(filtered_data()$avg_rating, na.rm = TRUE)
    valueBox(
      if_else(is.nan(avg), "N/A", number(avg, accuracy = 0.01)),
      "Average rating",
      icon = icon("star"),
      color = "yellow"
    )
  })

  output$award_count <- renderValueBox({
    valueBox(
      comma(sum(filtered_data()$awards != "N")),
      "With awards",
      icon = icon("trophy"),
      color = "green"
    )
  })

  output$avg_reviews <- renderValueBox({
    reviews <- mean(filtered_data()$total_reviews_count, na.rm = TRUE)
    valueBox(
      if_else(is.nan(reviews), "N/A", comma(round(reviews))),
      "Average reviews",
      icon = icon("comments"),
      color = "purple"
    )
  })

  output$category_table <- renderDT({
    filtered_data() %>%
      count(cuisine_category, sort = TRUE, name = "restaurants") %>%
      datatable(
        rownames = FALSE,
        options = list(dom = "t", pageLength = 10)
      )
  })

  output$price_table <- renderDT({
    filtered_data() %>%
      count(price_level, sort = TRUE, name = "restaurants") %>%
      mutate(share = percent(restaurants / sum(restaurants), accuracy = 0.1)) %>%
      datatable(
        rownames = FALSE,
        options = list(dom = "t", pageLength = 10)
      )
  })

  output$recommended_table <- renderDT({
    filtered_data() %>%
      arrange(desc(recommendation_score), desc(avg_rating), desc(total_reviews_count)) %>%
      transmute(
        Restaurant = restaurant_name,
        Cuisine = paste(cuisine_category, cuisine_subcategory, sep = " - "),
        Rating = avg_rating,
        Reviews = total_reviews_count,
        Price = price_level,
        Awards = if_else(awards == "N", "No", "Yes")
      ) %>%
      head(10) %>%
      datatable(
        rownames = FALSE,
        options = list(dom = "t", pageLength = 10)
      )
  })

  output$restaurant_map <- renderLeaflet({
    map_data <- filtered_data() %>%
      filter(!is.na(latitude), !is.na(longitude))

    validate(
      need(nrow(map_data) > 0, "No restaurants match the current filters.")
    )

    leaflet(map_data) %>%
      addTiles() %>%
      addCircleMarkers(
        lng = ~longitude,
        lat = ~latitude,
        radius = ~pmax(6, avg_rating * 1.8),
        stroke = TRUE,
        weight = 2,
        opacity = 1,
        fillOpacity = 0.88,
        color = "#ffffff",
        fillColor = "#e85d04",
        clusterOptions = markerClusterOptions(),
        label = ~restaurant_name,
        labelOptions = labelOptions(
          direction = "auto",
          textOnly = FALSE,
          opacity = 0.9
        ),
        popup = ~paste0(
          "<strong>", restaurant_name, "</strong><br>",
          "Rating: ", avg_rating, "<br>",
          "Price: ", price_level, "<br>",
          "Cuisine: ", cuisine_category, " - ", cuisine_subcategory, "<br>",
          "Reviews: ", total_reviews_count, "<br>",
          "Awards: ", awards
        )
      ) %>%
      addLegend(
        position = "bottomright",
        colors = "#e85d04",
        labels = "Restaurant marker; larger circles indicate higher ratings",
        opacity = 0.88
      )
  })

  output$restaurant_table <- renderDT({
    filtered_data() %>%
      select(
        Restaurant = restaurant_name,
        Category = cuisine_category,
        Subcategory = cuisine_subcategory,
        Rating = avg_rating,
        Price = price_level,
        Reviews = total_reviews_count,
        Popularity = popularity_generic,
        Awards = awards,
        Vegetarian = vegetarian_friendly,
        GlutenFree = gluten_free
      ) %>%
      datatable(
        rownames = FALSE,
        filter = "top",
        options = list(
          pageLength = 20,
          autoWidth = TRUE,
          scrollX = TRUE,
          order = list(list(3, "desc"))
        )
      )
  })
}

shinyApp(ui, server)
