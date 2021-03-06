#' kgraph
#'
#' Obtains Google Knowledge Graph Search entities details for a given keyword or
#' set of entitiy ID's.
#'
#' \code{kgraph} can be used to obtain Google Knowledge Graph search entities
#' (\url{https://www.google.com/intl/es419/insidesearch/features/search/knowledge.html})
#' for any given keyword. The obtained \dQuote{kg-id} can then be used to obtain
#' Google Trends information based on Google's Topic Search, e.g. with the
#' package gtrendsR. This is a set of combined search queries for any language.
#' For example the topic search query for \dQuote{London the capital of
#' England}, will not only cover searches for the keyword \dQuote{London} but
#' also for \dQuote{Londres} in Spanish. Details between the differences of
#' search over terms and topics are highlighted here
#' \url{https://support.google.com/trends/answer/4359550}.
#'
#' @param keyword A character vector with the actual Google Knowledge Graph
#'   Search query keyword. Note that only one keyword is allowed a time.
#'
#' @param token A character string containing your Google API access token.
#'
#' @param ids A vector of entity ID(s) to obtain the Knowledge Graph details.
#'   Provide in the form of \dQuote{/m/062s4}.
#'
#' @param hl A vector specifying the ISO 639 language codes (e.g. \dQuote{en} or
#'   \dQuote{fr}). Default is English.
#'
#' @param types A vector of character strings which restricts the returned
#'   entities. For example, you can specify Person to restrict the results to
#'   entities representing people. If multiple types are specified, returned
#'   entities will contain one or more of these types. Full list of schemas
#'   types is availabe (\url{http://schema.org/docs/full.html})
#'
#' @param prefix If set to \dQuote{TRUE} prefix (initial substring) match
#'   against names and aliases of entities is allowed. For example, a prefix
#'   \dQuote{Jung} will match entities and aliases such as \dQuote{Jung},
#'   \dQuote{Jungle}, and \dQuote{Jung-ho Kang}. Default is \dQuote{FALSE}.
#'
#' @param limit Sets the maximum of returned entities per call. Default is
#'   \dQuote{10}, maximum allowed by the API is \dQuote{20}.
#'
#' @return Returns an object of class \dQuote{kgraph}. It contains a list with
#'   the returned entities in descending order to their relevance score.
#'
#' @note When using \code{types} often \dQuote{Error:400} is returned since not
#'   all schemas are available, i.e. \dQuote{Vehicle}. In this case it is
#'   advisable to play around with the types categories to find out the ones
#'   working.
#'
#'   Provided token has limited quota. Please create and use your own token for
#'   large queries. Details on how to obtain your access token can be found here
#'   (\url{https://developers.google.com/knowledge-graph/how-tos/authorizing}).
#'
#' @examples
#' \donttest{
#' kg <- kgraph("Myst", types = "VideoGame")
#' # get google trends for the first entity using gtrendsR package
#' topicsearch <- gtrends(kg$entities[[1]]$id, time = "all")
#' }
#'
#' @author Oliver Schaer, \email{info@@oliverschaer.ch}
#'
#' @export

kgraph <- function(keyword = "", token = "", ids = "", hl = "en",
                   types = "", prefix = FALSE, limit = 10){

  # Error handling
  if (limit > 20) {
    warning("Limit of returns are 20 entities")
    limit <- 20
  }

  if (length(keyword) > 1){
    warning("Only one keyword allowed per query")
    keyword <- keyword[1]
  }

  if (all(keyword != "") & all(ids != "")) {
    stop("Keyword and ids can not be obtained simultaneously")
  }

  if (!is.logical(prefix)) {
    stop("Prefix needs to be logical")
  }

  if (all(token == "")) {
    message("Using internal token. Please consider own token for large queries.")
    token <- "AIzaSyDFyQjvAMgga3_Oe86iXPxQRj_FkUQeRF0"
  }

  # Create ids string if needed. Requires to be in the form of ?ids=A&ids=B
  if (length(types) > 1) {
    types <- paste(types, collapse = "&types=")
  }

  if (any(hl == "")) {
    stop("language code (hl) needs to be specified.")
  }

  # Create language string if multiple languages. in the form ?languages=en&languages=de
  if (length(hl) > 1) {
    hl <- paste(hl, collapse = "&languages=")
  }

  # urlencode ids seperatly since they contain reserved values, i.e. /m/065qh
  ids <- as.vector(sapply(ids, URLencode, reserve = T))
  # Create ids string. Need to be in the form of ?ids=A&ids=B
  if (length(ids) > 1) {
    ids <- paste(ids, collapse = "&ids=")
  }

  # Query building needs to better IMO. There is a problem with "" characters in
  # ids and types. Best solution would be to only include filled values. I don't
  # know yet how to implement this best without having many if-statements
  if (any(ids == "") & any(types =="")) {
    url <- paste0("https://kgsearch.googleapis.com/v1/entities:search?",
                  "&query=", keyword, "&key=", token, "&languages=", hl,
                  "&prefix=", tolower(prefix), "&limit=", limit, "&indent=false")
  } else if (any(ids == "")) {
    url <- paste0("https://kgsearch.googleapis.com/v1/entities:search?",
                  "&query=", keyword, "&key=", token, "&languages=", hl,
                  "&types=", types, "&prefix=", tolower(prefix), "&limit=",
                  limit, "&indent=false")
  } else if (any(types == "")) {
    url <- paste0("https://kgsearch.googleapis.com/v1/entities:search?",
                  "&query=", keyword, "&key=", token, "&ids=", ids,
                  "&languages=", hl, "&prefix=", tolower(prefix),
                  "&limit=", limit, "&indent=false")
  } else {
    url <- paste0("https://kgsearch.googleapis.com/v1/entities:search?",
                  "&query=", keyword, "&key=", token, "&ids=", ids,
                  "&languages=", hl, "&types=", types,
                  "&prefix=", tolower(prefix), "&limit=", limit, "&indent=false")
  }

  # overview of query parameters available here:
  # https://developers.google.com/knowledge-graph/reference/rest/v1/
  # Query building can also be evaluated using Google API Explorer:
  # https://developers.google.com/apis-explorer/#p/kgsearch/v1/kgsearch.entities.search
  curlReturn <- curl::curl_fetch_memory(URLencode(url))


  # error handling and return error from query
  if (curlReturn$status_code != 200) {
    content <- jsonlite::fromJSON(rawToChar(curlReturn$content), simplifyVector = F)
    stop(paste0("Google API Error:", content[[1]][[1]][1], " ", content[[1]][[2]][1]))
  }

  # Prepare output
  callUrl <- curlReturn$url

  # tyding up the returns
  content <- jsonlite::fromJSON(rawToChar(curlReturn$content), simplifyVector = F)

  entities <- list()

  # make sure result is returned
  if (length(content$itemListElement) != 0) {

    ct <- 1

    for (entity in content[[3]]) {

      id <- strsplit(entity$result$`@id`, "kg:")[[1]][2] # ID
      name <- entity$result$name # Name
      type <- unlist(entity$result$`@type`) # type(s)
      description <- entity$result$description # description
      if (any(names(entity$result) == "detailedDescription")) {
        detailedDescription <- entity$result$detailedDescription # only article body used
      } else {
        detailedDescription <- NA
      }
      score <- entity$resultScore # score

      entities[[ct]] <-
        list("id" = id, "name" = name, "type" = type, "description" = description,
             "detailedDescription" = detailedDescription, "score" = score)

      ct <- ct + 1
    }
  }
  return(structure(
    list("type" = "kgraph", "call" = sys.call(), "callUrl" = callUrl,
      "entities" = entities), class = "kgraph"))
}
