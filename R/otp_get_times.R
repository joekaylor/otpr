#' Queries OTP for the time or detailed itinerary for a trip between an origin
#' and destination
#'
#' In its simplest use case the function returns the time in minutes between an origin
#' and destination by the specified mode(s) for the top itinerary returned by OTP. If
#' \code{detail} is set to TRUE one or more detailed trip itineraries are returned,
#' including the time by each mode (if a multimodal trip), waiting time and the
#' number of transfers. Optionally, the details of each journey leg for each itinerary
#' can also be returned.
#'
#' @param otpcon An OTP connection object produced by \code{\link{otp_connect}}.
#' @param fromPlace Numeric vector, Latitude/Longitude pair, e.g. `c(53.48805, -2.24258)`
#' @param toPlace Numeric vector, Latitude/Longitude pair, e.g. `c(53.36484, -2.27108)`
#' @param mode Character vector, mode(s) of travel. Valid values are: WALK, BICYCLE,
#' CAR, TRANSIT, BUS, RAIL, TRAM, SUBWAY OR 'c("TRANSIT", "BICYCLE")'. TRANSIT will use all
#' available transit modes. Default is CAR. WALK mode is automatically
#' added for TRANSIT, BUS, RAIL, TRAM, and SUBWAY.
#' @param date Character, must be in the format mm-dd-yyyy. This is the desired date of travel.
#' Only relevant for transit modes. Default is the current system date.
#' @param time Character, must be in the format hh:mm:ss.
#' If \code{arriveBy} is FALSE (the default) this is the desired departure time, otherwise the
#' desired arrival time. Only relevant for transit modes. Default is the current system time.
#' @param arriveBy Logical. Whether a trip should depart (FALSE) or arrive (TRUE) at the specified
#' date and time. Default is FALSE.
#' @param maxWalkDistance Numeric. The maximum distance (in meters) that the user is
#' willing to walk. Default is NULL (the parameter is not passed to the API and the OTP
#' default of unlimited takes effect).
#' This is a soft limit in OTPv1 and is ignored if the mode is WALK only. In OTPv2
#' this parameter imposes a hard limit on WALK, CAR and BICYCLE modes (see:
#' \url{http://docs.opentripplanner.org/en/latest/OTP2-MigrationGuide/#router-config}).
#' @param walkReluctance A single numeric value. A multiplier for how bad walking is
#' compared to being in transit for equal lengths of time. Default = 2.
#' @param waitReluctance A single numeric value. A multiplier for how bad waiting for a
#' transit vehicle is compared to being on a transit vehicle. This should be greater
#' than 1 and less than \code{walkReluctance} (see API docs). Default = 1.
#' @param transferPenalty Integer. An additional penalty added to boardings after
#' the first. The value is in OTP's internal weight units, which are roughly equivalent to seconds.
#' Set this to a high value to discourage transfers. Default is 0.
#' @param minTransferTime Integer. The minimum time, in seconds, between successive
#' trips on different vehicles. This is designed to allow for imperfect schedule
#' adherence. This is a minimum; transfers over longer distances might use a longer time.
#' Default is 0.
#' @param detail Logical. When set to FALSE a single trip time is returned.
#' When set to TRUE one or more detailed trip itineraries are returned (dependent on \code{maxItineraries}).
#' Default is FALSE.
#' @param includeLegs Logical. Determines whether or not details of each
#' journey leg are returned. If TRUE then a nested dataframe of journeys legs will be returned
#' for each itinerary if \code{detail} is also TRUE. Default is FALSE.
#' @param maxItineraries Integer. Controls the number of trip itineraries that
#' are returned when \code{detail} is set to TRUE. This is not an OTP parameter.
#' All suggested itineraries are allowed to be returned by the OTP server. The function
#' will return them to the user in the order they were provided by OTP up to the maximum
#' specified by this parameter. Default is 1. This is an alternative to using the
#' OTP \code{maxNumItineraries} parameter which has problematic behaviour.
#' @param extra.params A list of any other parameters accepted by the OTP API PlannerResource entry point. For
#' advanced users. Be aware that otpr will carry out no validation of these additional
#' parameters. They will be passed directly to the API.
#' @return Returns a list of three or four elements. The first element in the list is \code{errorId}.
#' This is "OK" if OTP has not returned an error. Otherwise it is the OTP error code. The second element of list
#' varies:
#' \itemize{
#' \item If OTP has returned an error then \code{errorMessage} contains the OTP error message.
#' \item If there is no error and \code{detail} is FALSE then the \code{duration} in minutes is
#' returned as an integer. This is the duration of the top itinerary returned by the OTP server.
#'
#' \item If there is no error and \code{detail} is TRUE then \code{itineraries} as a dataframe.
#' }
#' The third element of the list is \code{query}. This is a character string containing the URL
#' that was submitted to the OTP API.
#' @details
#' If you plan to use the function in simple-mode - where just the duration of the top itinerary is returned -
#' it is advisable to first review several detailed itineraries to ensure that the parameters
#' you have set are producing sensible results.
#'
#' If requested using \code{includeLegs}, the itineraries dataframe will contain a column called 'legs'
#' which has a nested legs dataframe for each itinerary. Each legs dataframe will contain
#' a set of core columns that are consistent across all queries. However, as the OTP
#' API does not consistently return the same attributes for legs, there will be some variation
#' in columns returned. You should bare this in mind if your post processing
#' uses these columns (e.g. by checking for column existence).
#' @examples \dontrun{
#' otp_get_times(otpcon, fromPlace = c(53.48805, -2.24258), toPlace = c(53.36484, -2.27108))
#'
#' otp_get_times(otpcon, fromPlace = c(53.48805, -2.24258), toPlace = c(53.36484, -2.27108),
#' mode = "BUS", date = "03-26-2019", time = "08:00:00")
#'
#' otp_get_times(otpcon, fromPlace = c(53.48805, -2.24258), toPlace = c(53.36484, -2.27108),
#' mode = "BUS", date = "03-26-2019", time = "08:00:00", detail = TRUE)
#'}
#' @importFrom rlang .data
#' @importFrom dplyr any_of
#' @export
otp_get_times <-
  function(otpcon,
           fromPlace,
           toPlace,
           mode = "CAR",
           date = format(Sys.Date(), "%m-%d-%Y"),
           time = format(Sys.time(), "%H:%M:%S"),
           maxWalkDistance = NULL,
           walkReluctance = 2,
           waitReluctance = 1,
           arriveBy = FALSE,
           transferPenalty = 0,
           minTransferTime = 0,
           maxItineraries = 1,
           detail = FALSE,
           includeLegs = FALSE,
           extra.params = list())
  {
    # get the OTP parameters ready to pass to check function
    call <- sys.call()
    call[[1]] <- as.name('list')
    params <- eval.parent(call)
    params <-
      params[names(params) %in% c("mode", "detail", "includeLegs", "maxItineraries", "extra.params") == FALSE]
    
    # Check for required arguments
    if (missing(otpcon)) {
      stop("otpcon argument is required")
    } else if (missing(fromPlace)) {
      stop("fromPlace argument is required")
    } else if (missing(toPlace)) {
      stop("toPlace argument is required")
    }
    
    # function specific argument checks
    args.coll <- checkmate::makeAssertCollection()
    checkmate::assert_list(extra.params)
    checkmate::assert_logical(detail, add = args.coll)
    checkmate::assert_integerish(maxItineraries,
                                 lower = 1,
                                 add = args.coll)
    checkmate::reportAssertions(args.coll)
    
    # process mode
    mode <- otp_check_mode(mode)
    
    # OTP API parameter checks
    do.call(otp_check_params,
            params)
    
    # Construct URL
    routerUrl <- paste0(make_url(otpcon)$router, "/plan")
    
    # Collapse fromPlace and toPlace
    fromPlace <- paste(fromPlace, collapse = ",")
    toPlace <- paste(toPlace, collapse = ",")
    
    # Construct query list
    query <- list(
      fromPlace = fromPlace,
      toPlace = toPlace,
      mode = mode,
      date = date,
      time = time,
      maxWalkDistance = maxWalkDistance,
      walkReluctance = walkReluctance,
      waitReluctance = waitReluctance,
      arriveBy = arriveBy,
      transferPenalty = transferPenalty,
      minTransferTime = minTransferTime
    )

    # append extra.params to query if present
    if (length(extra.params) > 0) {
      msg <- paste("Unknown parameters were passed to the OTP API without checks:", paste(sapply(names(extra.params), paste), collapse=", "))
      warning(paste(msg), call. = FALSE)
      query <- append(query, extra.params)
    }
    
    # Use GET from the httr package to make API call and place in req - returns json by default.
    req <- httr::GET(routerUrl,
                     query = query)
    
    # decode URL for return
    url <- urltools::url_decode(req$url)
    
    # convert response content into text
    text <- httr::content(req, as = "text", encoding = "UTF-8")
    # parse text to json
    asjson <- jsonlite::fromJSON(text, flatten = TRUE)
    
    # Check for errors
    # Note that OTPv1 and OTPv2 use a different node name for the error message.
    if (!is.null(asjson$error$id)) {
      response <-
        list(
          "errorId" = asjson$error$id,
          "errorMessage" = ifelse(
            otpcon$version == 1,
            asjson$error$msg,
            asjson$error$message
          ),
          "query" = url
        )
      return (response)
    } else {
      error.id <- "OK"
    }
    
    # OTPv2 does not return an error when there is no itinerary - for
    # example if WALK mode and maxWalkDistance is too low. So now also check that
    # there is at least 1 itinerary present.
    if (length(asjson$plan$itineraries) == 0) {
      response <-
        list(
          "errorId" = -9999,
          "errorMessage" = "No itinerary returned. If using OTPv2 the maxWalkDistance parameter (default 800m) might be too restrictive. It 
          is applied by OTPv2 to BICYCLE and CAR modes in addition to WALK",
          "query" = url
        )
      return (response)
    }
    
    # check if we need to return detailed response
    if (detail == TRUE) {
      # Return up to maxItineraries
      num_itin <-
        pmin(maxItineraries, nrow(asjson$plan[["itineraries"]]))
      df <- asjson$plan$itineraries[c(1:num_itin),]
      # convert times from epoch format
      df$start <-
        otp_from_epoch(df$startTime, otpcon$tz)
      df$end <-
        otp_from_epoch(df$endTime, otpcon$tz)
      df$timeZone <- attributes(df$start)$tzone[1]
      # If legs are required we process the nested legs dataframes preserving
      # structure using rrapply
      if (isTRUE(includeLegs)) {
        # clean-up colnnames
        legs <-
          rrapply::rrapply(
            df$legs,
            f = function(x)
              janitor::clean_names(x, case = "lower_camel"),
            classes = "data.frame"
          )
        # convert from epoch times
        legs <-
          rrapply::rrapply(
            legs,
            condition = function(x, .xname)
              .xname %in% c("startTime", "endTime", "fromDeparture", "fromArrival"),
              f = function(x)
                otp_from_epoch(x, otpcon$tz)
          )
  
        
         # calculate departureWait - not relevant for one leg itineraries
        # (e.g. WALK only trip) where there won't be a fromArrival
        # However, for ease of processing of returned data we set departureWait
        # to zero for these.
        legs <-
          rrapply::rrapply(
            legs,
            f = function(x)
              if (nrow(x) > 1)
                dplyr::mutate(x, departureWait = round(abs((as.numeric(
                  .data$fromArrival - .data$fromDeparture
                )) / 60
                ), 2))
            else
              dplyr::mutate(x, departureWait = 0) ,
            classes = "data.frame"
          )
        # if departureWait is NA (usually for first leg of multi-leg trip) replace with 0
        legs <-
          rrapply::rrapply(
            legs,
            condition = function(x, .xname)
              .xname == "departureWait",
            f = function(x)    
            replace(x, is.na(x), 0)
          )
        # Update duration column to minutes
        legs <-
          rrapply::rrapply(
            legs,
            condition = function(x, .xname)
              .xname == "duration",
            f = function(x)  
              round(x / 60, 2)
          )
        # Add timezone column
        legs <-
          rrapply::rrapply(
            legs,
            f = function(x)
              dplyr::mutate(x, timeZone = attributes(x$startTime)$tzone[1]),
            classes = "data.frame"
          )
        # select required columns in legs using %in% as sometimes columns are missing
        # for example routeShortName. Also there are fewer columns when just a WALK,
        # BICYCLE or CAR leg is returned.
        leg_columns <- c(
          'startTime',
          'endTime',
          'timeZone',
          'mode',
          'departureWait',
          'duration',
          'distance',
          'routeType',
          'routeId',
          'routeShortName',
          'routeLongName',
          'headsign',
          'agencyName',
          'agencyUrl',
          'agencyId',
          'fromName',
          'fromLon',
          'fromLat',
          'fromStopId',
          'fromStopCode',
          'toName',
          'toLon',
          'toLat',
          'toStopId',
          'toStopCode'
        )
        # Select columns
        legs <-
          rrapply::rrapply(
            legs,
            f = function(x)
              dplyr::select(x, which(colnames(x) %in%
                                       leg_columns)),
            classes = "data.frame"
          )
        # change column order using relocate
        legs <- rrapply::rrapply(
          legs,
          f = function(x)
            dplyr::relocate(x, any_of(leg_columns)),
          classes = "data.frame"
        )
      } # end legs processing
      # subset the dataframe ready to return
      ret.df <-
        dplyr::select(
          df,
          c(
            'start',
            'end',
            'timeZone',
            'duration',
            'walkTime',
            'transitTime',
            'waitingTime',
            'transfers'
          )
        )
      # Insert processed legs if required
      if (isTRUE(includeLegs)) {
        ret.df$legs <- legs
      }
      # convert seconds into minutes where applicable
      ret.df[, 4:7] <- round(ret.df[, 4:7] / 60, digits = 2)
      # rename walkTime column as appropriate - this a mistake in OTP
      if (mode == "CAR") {
        names(ret.df)[names(ret.df) == 'walkTime'] <- 'driveTime'
      } else if (mode == "BICYCLE") {
        names(ret.df)[names(ret.df) == 'walkTime'] <- 'cycleTime'
      }
      response <-
        list("errorId" = error.id,
             "itineraries" = ret.df,
             "query" = url)
      return (response)
    } else {
      # detail not needed - just return travel time in minutes from the first itinerary
      response <-
        list(
          "errorId" = error.id,
          "duration" = round(asjson$plan$itineraries[1, "duration"] / 60, digits = 2),
          "query" = url
        )
      return (response)
    }
  }
