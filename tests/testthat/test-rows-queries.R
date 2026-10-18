# What the wrappers send and how they read the reply, checked against the
# shapes SeaTable actually returns. Bodies are compared as the JSON httr2
# writes, not as R lists: a one-element vector and a one-element list look
# alike in R and differ on the wire.

as_wire_json <- function(body) {
  # The arguments .hb_request() hands to httr2::req_body_json().
  as.character(jsonlite::toJSON(
    body,
    auto_unbox = TRUE, digits = 22, null = "null", na = "null"
  ))
}

empty_sql_reply <- function() list(metadata = list(), results = list())

# --- hb_query(): joins ------------------------------------------------------

# SeaTable's reply to an implicit join (FROM a, b WHERE ...): it ignores
# convert_keys and keys every cell by the column's key, so the names are
# only in the metadata.
join_reply <- function(is_join = TRUE) {
  reply <- list(
    success = TRUE, error_message = "",
    metadata = list(
      list(key = "rLfY", name = "product", type = "text"),
      list(key = "kz15", name = "customer_name", type = "text"),
      list(key = "q7Wn", name = "quantity", type = "number")
    ),
    results = list(
      list(rLfY = "Widget", kz15 = "Alice", q7Wn = 2),
      list(rLfY = "Gizmo", kz15 = "Alice", q7Wn = 5)
    )
  )
  reply$is_join_stmt <- is_join
  reply
}

join_sql <- paste(
  "select o.product, c.customer_name, o.quantity from o, c",
  "where o.cid = c.cid limit 10"
)

test_that("a join's cells are read by key, under the reported names", {
  cl <- mock_client()
  with_mocked_request(
    out <- hb_query(cl, join_sql),
    response = join_reply()
  )
  expect_named(out, c("product", "customer_name", "quantity", "_id"))
  expect_identical(out$product, c("Widget", "Gizmo"))
  expect_identical(out$customer_name, c("Alice", "Alice"))
  expect_identical(out$quantity, c(2, 5))
  # A joined row is no single row of either table.
  expect_identical(out[["_id"]], c(NA_character_, NA_character_))
})

test_that("cells keyed only by column key are read by key without the flag", {
  cl <- mock_client()
  with_mocked_request(
    out <- hb_query(cl, join_sql),
    response = join_reply(is_join = NULL)
  )
  expect_identical(out$product, c("Widget", "Gizmo"))
  expect_identical(out$quantity, c(2, 5))
})

test_that("a join whose cells arrive by name is read by name", {
  cl <- mock_client()
  reply <- join_reply()
  reply$results <- list(
    list(product = "Widget", customer_name = "Alice", quantity = 2)
  )
  with_mocked_request(out <- hb_query(cl, join_sql), response = reply)
  expect_identical(out$product, "Widget")
  expect_identical(out$quantity, 2)
})

test_that("a join column without a key is looked up by its name", {
  cl <- mock_client()
  reply <- join_reply()
  reply$metadata[[3L]]$key <- NULL
  reply$results <- list(list(rLfY = "Widget", kz15 = "Alice", quantity = 2))
  with_mocked_request(out <- hb_query(cl, join_sql), response = reply)
  expect_identical(out$product, "Widget")
  expect_identical(out$quantity, 2)
})

test_that("an ordinary query is still read by name", {
  cl <- mock_client()
  # Concentration is empty in every row, so no cell carries it; the names
  # that are there keep the reply on the by-name path.
  reply <- list(
    is_join_stmt = FALSE,
    metadata = list(
      list(key = "0000", name = "Name", type = "text"),
      list(key = "k2", name = "Concentration", type = "number")
    ),
    results = list(
      list(`_id` = "r1", Name = "a"),
      list(`_id` = "r2", Name = "b")
    )
  )
  with_mocked_request(
    out <- hb_query(cl, "select Name, Concentration from Samples limit 5"),
    response = reply
  )
  expect_named(out, c("Name", "Concentration", "_id"))
  expect_identical(out$Name, c("a", "b"))
  expect_identical(out$Concentration, c(NA_real_, NA_real_))
  expect_identical(out[["_id"]], c("r1", "r2"))
})

test_that("convert_keys = FALSE still names a join's columns by key", {
  cl <- mock_client()
  with_mocked_request(
    out <- hb_query(cl, join_sql, convert_keys = FALSE),
    response = join_reply()
  )
  expect_named(out, c("rLfY", "kz15", "q7Wn", "_id"))
  expect_identical(out$rLfY, c("Widget", "Gizmo"))
})

# --- hb_query(): the missing-LIMIT warning ----------------------------------

test_that("the LIMIT check ignores the word in strings and quoted names", {
  lacks <- harbouR:::.hb_sql_lacks_limit
  expect_true(lacks("select * from Samples"))
  expect_true(lacks("select * from Labs where Flag = 'above limit'"))
  expect_true(lacks("select * from Labs where Flag = 'it''s a limit'"))
  expect_true(lacks('select * from Labs where Flag = "no limit"'))
  expect_true(lacks('select * from Labs where Flag = "a ""limit"""'))
  expect_true(lacks("select Analyte, `Upper limit` from Labs"))
  expect_true(lacks("select * from `Credit limit`"))

  expect_false(lacks("select * from Samples limit 5"))
  expect_false(lacks("SELECT * FROM Samples LIMIT 5"))
  expect_false(lacks("select * from Samples where Notes = 'it''s' limit 5"))
  expect_false(lacks("select `Limit` from Samples limit 3"))
  expect_false(lacks("select * from Samples\nLIMIT\n10"))
})

test_that("the LIMIT check reads text that is not valid UTF-8", {
  lacks <- harbouR:::.hb_sql_lacks_limit
  # Latin-1 bytes in an unmarked string, as a script read in the wrong
  # encoding has them. The check must still answer rather than fail.
  name <- rawToChar(as.raw(c(0x4d, 0xfc, 0x6c, 0x6c, 0x65, 0x72)))
  sql <- paste0("select * from Samples where Name = '", name, "'")
  expect_true(lacks(sql))
  expect_false(lacks(paste(sql, "limit 5")))
})

test_that("hb_query warns when 'limit' is only inside a quoted string", {
  cl <- mock_client()
  withr::local_options(rlib_warning_verbosity = "verbose")
  expect_warning(
    with_mocked_request(
      hb_query(cl, "select * from Labs where Flag = 'above limit'"),
      response = empty_sql_reply()
    ),
    class = "harbour_warning_query_limit"
  )
  expect_no_warning(
    with_mocked_request(
      hb_query(cl, "select `Limit` from Samples limit 3"),
      response = empty_sql_reply()
    )
  )
})

test_that("each LIMIT-less query is warned about, though not each repeat", {
  cl <- mock_client()
  # rlang's default verbosity applies the rate limit, which is the point:
  # a loop running one query must not repeat the warning, and that query
  # must not silence the next one. The queries are unique to this run, so
  # an earlier run in the same session cannot have used up their warning.
  withr::local_options(rlib_warning_verbosity = "default")
  tag <- basename(tempfile("run"))
  first <- sprintf("select * from Samples where Name = '%s-1'", tag)
  second <- sprintf("select * from Samples where Name = '%s-2'", tag)
  run <- function(sql) {
    with_mocked_request(hb_query(cl, sql), response = empty_sql_reply())
  }
  expect_warning(run(first), class = "harbour_warning_query_limit")
  expect_warning(run(second), class = "harbour_warning_query_limit")
  expect_no_warning(run(first))
})

test_that("a long query without LIMIT is warned about, not refused", {
  cl <- mock_client()
  withr::local_options(rlib_warning_verbosity = "default")
  # A generated IN list easily runs past 10000 characters, and the rate
  # limit is kept per query: it must not fail on a query that long.
  tag <- basename(tempfile("run"))
  values <- paste0("'", tag, "-", seq_len(1000L), "'", collapse = ", ")
  sql <- paste0("select * from Samples where Name in (", values, ")")
  expect_gt(nchar(sql, type = "bytes"), 10000L)
  expect_warning(
    with_mocked_request(hb_query(cl, sql), response = empty_sql_reply()),
    class = "harbour_warning_query_limit"
  )
})

# --- request bodies: arrays stay arrays -------------------------------------

test_that("named row ids are sent as an array", {
  cl <- mock_client()
  # vapply() over a named list of rows gives named ids, and a named vector
  # is written as a JSON object.
  ids <- c(first = "Qtf7AAAA", second = "Bx9zBBBB")
  rec <- with_mocked_request({
    hb_lock_rows(cl, "Samples", ids)
    hb_unlock_rows(cl, "Samples", ids)
    hb_lock_rows(cl, "Samples", unname(ids))
  }, response = list())
  wire <- vapply(rec$calls, function(call) as_wire_json(call$body), "")
  expect_match(wire[[1L]], '"row_ids":["Qtf7AAAA","Bx9zBBBB"]', fixed = TRUE)
  expect_match(wire[[2L]], '"row_ids":["Qtf7AAAA","Bx9zBBBB"]', fixed = TRUE)
  # and unnamed ids send exactly what they always did
  expect_identical(wire[[1L]], wire[[3L]])
})

test_that("named query parameters are sent as an array", {
  cl <- mock_client()
  sql <- "select * from Samples where Name = ? limit 5"
  rec <- with_mocked_request({
    hb_query(cl, sql, parameters = list(name = "S1"))
    hb_query(cl, sql, parameters = c(name = "S1"))
    hb_query(cl, sql, parameters = list("S1"))
  }, response = empty_sql_reply())
  wire <- vapply(rec$calls, function(call) as_wire_json(call$body), "")
  for (json in wire) {
    expect_match(json, '"parameters":["S1"]', fixed = TRUE)
  }
  expect_identical(wire[[1L]], wire[[3L]])
})

test_that("one hidden column is sent as an array of keys", {
  cl <- mock_client()
  sent <- function(settings) {
    rec <- with_mocked_request(
      hb_update_view(cl, "Samples", "Lab", settings = settings),
      response = list()
    )
    as_wire_json(rec$calls[[1L]]$body)
  }
  expect_identical(
    sent(list(hidden_columns = "k2")), '{"hidden_columns":["k2"]}'
  )
  expect_identical(
    sent(list(hidden_columns = c("k2", "k3"))),
    '{"hidden_columns":["k2","k3"]}'
  )
  expect_identical(
    sent(list(hidden_columns = list("k2"))), '{"hidden_columns":["k2"]}'
  )
  expect_identical(
    sent(list(hidden_columns = character())), '{"hidden_columns":[]}'
  )
  # A named vector, and the list around one vector that hb_get_view()
  # returns, are sent as the same flat array.
  expect_identical(
    sent(list(hidden_columns = c(Concentration = "k2"))),
    '{"hidden_columns":["k2"]}'
  )
  expect_identical(
    sent(list(hidden_columns = list(c("k2", "k3")))),
    '{"hidden_columns":["k2","k3"]}'
  )
  # The other fields are left as they were.
  expect_identical(
    sent(list(filter_conjunction = "And", hidden_columns = "k2")),
    '{"filter_conjunction":"And","hidden_columns":["k2"]}'
  )
})

# --- hb_read_table(): views -------------------------------------------------

# Samples gains a view that hides Concentration (k2) and Status (k3). The
# fake server honours view_name as SeaTable does, leaving the hidden
# columns out of every row.
hidden_view_client <- function() {
  cl <- mock_client()
  meta <- hb_example_metadata()
  meta$tables[[1L]]$views <- c(meta$tables[[1L]]$views, list(list(
    `_id` = "Ab12", name = "Lab", type = "table",
    hidden_columns = list("k2", "k3")
  )))
  cl$.metadata <- meta
  cl
}

view_server <- function(path, method, query, body) {
  rows <- list(
    list(`_id` = "r1", Name = "S1", Concentration = 1.5, Status = "draft"),
    list(`_id` = "r2", Name = "S2", Concentration = 2.5, Status = "Done")
  )
  if (!is.null(query$view_name)) {
    rows <- lapply(rows, function(row) {
      row[setdiff(names(row), c("Concentration", "Status"))]
    })
  }
  list(rows = rows)
}

test_that("a server view names the hidden columns that read as NA", {
  cl <- hidden_view_client()
  expect_warning(
    with_mocked_request(
      out <- hb_read_table(cl, "Samples", view = "Lab"),
      response = view_server
    ),
    class = "harbour_warning_hidden_columns"
  )
  expect_warning(
    with_mocked_request(
      hb_read_table(cl, "Samples", view = "Lab"),
      response = view_server
    ),
    regexp = "Concentration.*Status"
  )
  # The tibble keeps the table's shape; only a warning is added.
  with_mocked_request(
    all_rows <- hb_read_table(cl, "Samples"),
    response = view_server
  )
  expect_identical(names(out), names(all_rows))
  expect_identical(out$Name, c("S1", "S2"))
  expect_identical(out$Concentration, c(NA_real_, NA_real_))
  expect_identical(out$Status, c(NA_character_, NA_character_))
  expect_identical(all_rows$Concentration, c(1.5, 2.5))
})

test_that("a view with nothing hidden, or one not in the cache, is quiet", {
  cl <- hidden_view_client()
  expect_no_warning(with_mocked_request(
    hb_read_table(cl, "Samples", view = "Default"),
    response = view_server
  ))
  # A view created since the metadata was read: the read still succeeds.
  expect_no_warning(with_mocked_request(
    out <- hb_read_table(cl, "Samples", view = "Created later"),
    response = view_server
  ))
  expect_identical(nrow(out), 2L)
  # No rows came back, so no value is missing.
  expect_no_warning(with_mocked_request(
    hb_read_table(cl, "Samples", view = "Lab"),
    response = list(rows = list())
  ))
})

test_that("a hidden column the server still sends is not reported", {
  cl <- hidden_view_client()
  sends_status <- function(path, method, query, body) {
    rows <- view_server(path, method, query, body)$rows
    list(rows = lapply(rows, function(row) c(row, list(Status = "Done"))))
  }
  expect_warning(
    with_mocked_request(
      out <- hb_read_table(cl, "Samples", view = "Lab"),
      response = sends_status
    ),
    regexp = "hides 1 column"
  )
  expect_identical(out$Status, c("Done", "Done"))
})

# --- hb_read_table(): paging ------------------------------------------------

# A listRows that pages through `n` rows as SeaTable does: it honours
# start and limit, and the page after the last row is empty.
paging_server <- function(n) {
  function(path, method, query, body) {
    from <- query$start + 1
    to <- min(query$start + query$limit, n)
    ids <- if (from <= to) seq(from, to) else integer()
    list(rows = lapply(ids, function(i) list(`_id` = paste0("r", i))))
  }
}

# One text column keeps a read of ten thousand rows cheap.
narrow_client <- function() {
  cl <- mock_client()
  cl$.metadata <- new_harbour_metadata(
    list(tables = list(list(
      name = "T",
      columns = list(list(name = "Name", type = "text", key = "0000"))
    ))),
    base_name = "b"
  )
  cl
}

test_that("a small page_size does not cut a large table short", {
  # The guard allowed 1000 requests whatever their size, so with
  # page_size = 10 any table over 10,000 rows was an error.
  cl <- narrow_client()
  rec <- with_mocked_request(
    out <- hb_read_table(cl, "T", page_size = 10L),
    response = paging_server(10005L)
  )
  expect_identical(nrow(out), 10005L)
  expect_identical(length(rec$calls), 1001L)
  expect_identical(out[["_id"]][c(1L, 10005L)], c("r1", "r10005"))
})

test_that("the page cap is set in rows, not requests", {
  max_pages <- harbouR:::.hb_max_pages
  expect_identical(max_pages(1000L), 10000L)
  expect_identical(max_pages(10L), 1000000L)
})

test_that("a read that ends exactly on the page cap is complete", {
  cl <- narrow_client()
  testthat::local_mocked_bindings(
    .hb_max_pages = function(page_size) 3L,
    .package = "harbouR"
  )
  rec <- with_mocked_request(
    out <- hb_read_table(cl, "T", page_size = 10L),
    response = paging_server(30L)
  )
  expect_identical(nrow(out), 30L)
  # Three full pages, then one more request to see that nothing follows.
  expect_identical(length(rec$calls), 4L)

  expect_error(
    with_mocked_request(
      hb_read_table(cl, "T", page_size = 10L),
      response = paging_server(31L)
    ),
    class = "harbour_error_http"
  )
})

test_that("a server that repeats a page is stopped at the repeat", {
  # A cursor that does not advance returns the same page for ever. Waiting
  # for the cap would read millions of duplicates first; with n_max set,
  # the duplicates came back as if they were the table.
  cl <- narrow_client()
  # A low cap keeps this quick if the repeat ever goes unnoticed: the read
  # would then end at the cap, after more than two requests.
  testthat::local_mocked_bindings(
    .hb_max_pages = function(page_size) 5L,
    .package = "harbouR"
  )
  same_page <- function(path, method, query, body) {
    list(rows = lapply(1:10, function(i) list(`_id` = paste0("r", i))))
  }
  rec <- new_request_recorder(same_page)
  expect_error(
    with_mocked_request(
      hb_read_table(cl, "T", page_size = 10L),
      recorder = rec
    ),
    class = "harbour_error_http",
    regexp = "same 10 rows"
  )
  expect_identical(length(rec$calls), 2L)

  expect_error(
    with_mocked_request(
      hb_read_table(cl, "T", page_size = 10L, n_max = 50),
      response = same_page
    ),
    class = "harbour_error_http"
  )

  # A server that honours limit but ignores start, on a read that n_max
  # ends part-way through a page: the short last page repeats the start
  # of the one before it.
  start_ignored <- function(path, method, query, body) {
    list(rows = lapply(seq_len(query$limit), function(i) {
      list(`_id` = paste0("r", i))
    }))
  }
  expect_error(
    with_mocked_request(
      hb_read_table(cl, "T", page_size = 10L, n_max = 15),
      response = start_ignored
    ),
    class = "harbour_error_http"
  )
  # A server that ignores limit as well sends more than the short page
  # asked for, starting with the same rows.
  expect_error(
    with_mocked_request(
      hb_read_table(cl, "T", page_size = 10L, n_max = 15),
      response = same_page
    ),
    class = "harbour_error_http"
  )
})

# --- hb_get_row() -----------------------------------------------------------

test_that("an unknown row is a not_found error, not an empty result", {
  cl <- mock_client()
  # The server answers a missing row with a 404 and this body. Mocking the
  # transport rather than .hb_request() runs the real error translation.
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      stop(make_http_cond(404L, '{"error_message":"row _id not exits"}'))
    },
    .package = "httr2"
  )
  expect_error(
    hb_get_row(cl, "Samples", "AAAAAAAAAAAAAAAAAAAAAA"),
    class = "harbour_error_not_found"
  )
})

# --- hb_update_column() -----------------------------------------------------

test_that("column_data alone sends the server's current type", {
  # The cache says single-select; a collaborator has since made the column
  # multiple-select. Naming the cached type would convert it back.
  cl <- mock_client()
  server <- function(path, method, query, body) {
    if (identical(method, "GET")) {
      list(columns = list(
        list(name = "Status", type = "multiple-select", key = "k3")
      ))
    } else {
      list(success = TRUE)
    }
  }
  rec <- with_mocked_request(
    hb_update_column(cl, "Samples", "Status",
                     column_data = list(options = list(list(name = "a")))),
    response = server
  )
  expect_identical(
    vapply(rec$calls, function(call) call$method, ""), c("GET", "PUT")
  )
  expect_match(rec$calls[[1L]]$path, "/columns/$")
  expect_identical(rec$calls[[1L]]$query$table_name, "Samples")
  expect_identical(rec$calls[[2L]]$body$new_column_type, "multiple-select")
})

test_that("the type lookup reads the cache unless asked to refresh", {
  # hb_attach_file() relies on the cached lookup and its single request.
  cl <- mock_client()
  rec <- with_mocked_request(
    type <- harbouR:::.hb_column_type(cl, "Samples", "Status"),
    response = list()
  )
  expect_identical(type, "single-select")
  expect_length(rec$calls, 0L)
})
