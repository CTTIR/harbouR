#' Scaffolded endpoints (later releases)
#'
#' These functions cover the Tier 2 and Tier 3 SeaTable endpoints (links,
#' big data, comments, snapshots, bases, import/export, sharing,
#' integrations, admin, team, scheduler). They are intentionally stubbed
#' in 0.1.0: the signatures and documentation are stable, but each one
#' raises a clear `not yet implemented` error so callers can discover the
#' surface without surprises. They will be filled in opportunistically in
#' later minor releases.
#'
#' @param ... Arguments forwarded to the future implementation.
#' @return Each function errors with a `lifecycle`-style message; the
#'   eventual return shape is documented per group.
#' @keywords internal
#' @name harbouR-scaffold
#' @concept scaffolded
NULL

#' @keywords internal
#' @noRd
.hb_not_implemented <- function(fn, call = rlang::caller_env()) {
  cli::cli_abort(c(
    "{.fn {fn}} is scaffolded but not yet implemented in this release.",
    "i" = "It will land in a later minor release. See {.code NEWS.md}."
  ), call = call)
}

# Links --------------------------------------------------------------------

#' @rdname harbouR-scaffold
#' @export
hb_list_links <- function(...) .hb_not_implemented("hb_list_links")
#' @rdname harbouR-scaffold
#' @export
hb_create_link <- function(...) .hb_not_implemented("hb_create_link")
#' @rdname harbouR-scaffold
#' @export
hb_update_link <- function(...) .hb_not_implemented("hb_update_link")
#' @rdname harbouR-scaffold
#' @export
hb_delete_link <- function(...) .hb_not_implemented("hb_delete_link")
#' @rdname harbouR-scaffold
#' @export
hb_auto_link <- function(...) .hb_not_implemented("hb_auto_link")

# Big data -----------------------------------------------------------------

#' @rdname harbouR-scaffold
#' @export
hb_bigdata_add_rows <- function(...) .hb_not_implemented("hb_bigdata_add_rows")
#' @rdname harbouR-scaffold
#' @export
hb_bigdata_move_in <- function(...) .hb_not_implemented("hb_bigdata_move_in")
#' @rdname harbouR-scaffold
#' @export
hb_bigdata_move_out <- function(...) .hb_not_implemented("hb_bigdata_move_out")

# Comments -----------------------------------------------------------------

#' @rdname harbouR-scaffold
#' @export
hb_list_comments <- function(...) .hb_not_implemented("hb_list_comments")
#' @rdname harbouR-scaffold
#' @export
hb_get_comment <- function(...) .hb_not_implemented("hb_get_comment")
#' @rdname harbouR-scaffold
#' @export
hb_delete_comment <- function(...) .hb_not_implemented("hb_delete_comment")

# Snapshots ----------------------------------------------------------------

#' @rdname harbouR-scaffold
#' @export
hb_create_snapshot <- function(...) .hb_not_implemented("hb_create_snapshot")
#' @rdname harbouR-scaffold
#' @export
hb_list_snapshots <- function(...) .hb_not_implemented("hb_list_snapshots")
#' @rdname harbouR-scaffold
#' @export
hb_restore_snapshot <- function(...) .hb_not_implemented("hb_restore_snapshot")

# Bases & workspaces -------------------------------------------------------

#' @rdname harbouR-scaffold
#' @export
hb_list_bases <- function(...) .hb_not_implemented("hb_list_bases")
#' @rdname harbouR-scaffold
#' @export
hb_create_base <- function(...) .hb_not_implemented("hb_create_base")
#' @rdname harbouR-scaffold
#' @export
hb_update_base <- function(...) .hb_not_implemented("hb_update_base")
#' @rdname harbouR-scaffold
#' @export
hb_delete_base <- function(...) .hb_not_implemented("hb_delete_base")
#' @rdname harbouR-scaffold
#' @export
hb_base_size <- function(...) .hb_not_implemented("hb_base_size")

# IO -----------------------------------------------------------------------

#' @rdname harbouR-scaffold
#' @export
hb_import_base <- function(...) .hb_not_implemented("hb_import_base")
#' @rdname harbouR-scaffold
#' @export
hb_export_base <- function(...) .hb_not_implemented("hb_export_base")
#' @rdname harbouR-scaffold
#' @export
hb_import_table <- function(...) .hb_not_implemented("hb_import_table")
#' @rdname harbouR-scaffold
#' @export
hb_export_table <- function(...) .hb_not_implemented("hb_export_table")
#' @rdname harbouR-scaffold
#' @export
hb_append_from_file <- function(...) .hb_not_implemented("hb_append_from_file")

# Sharing ------------------------------------------------------------------

#' @rdname harbouR-scaffold
#' @export
hb_share_base <- function(...) .hb_not_implemented("hb_share_base")
#' @rdname harbouR-scaffold
#' @export
hb_share_view <- function(...) .hb_not_implemented("hb_share_view")
#' @rdname harbouR-scaffold
#' @export
hb_list_shares <- function(...) .hb_not_implemented("hb_list_shares")

# Integrations -------------------------------------------------------------

#' @rdname harbouR-scaffold
#' @export
hb_list_webhooks <- function(...) .hb_not_implemented("hb_list_webhooks")
#' @rdname harbouR-scaffold
#' @export
hb_create_webhook <- function(...) .hb_not_implemented("hb_create_webhook")
#' @rdname harbouR-scaffold
#' @export
hb_delete_webhook <- function(...) .hb_not_implemented("hb_delete_webhook")

# Admin (Tier 3) -----------------------------------------------------------

#' @rdname harbouR-scaffold
#' @export
hb_admin_list_users <- function(...) .hb_not_implemented("hb_admin_list_users")
#' @rdname harbouR-scaffold
#' @export
hb_admin_list_bases <- function(...) .hb_not_implemented("hb_admin_list_bases")
#' @rdname harbouR-scaffold
#' @export
hb_admin_list_groups <- function(...) .hb_not_implemented("hb_admin_list_groups")
#' @rdname harbouR-scaffold
#' @export
hb_admin_system_info <- function(...) .hb_not_implemented("hb_admin_system_info")

# Team (Tier 3) ------------------------------------------------------------

#' @rdname harbouR-scaffold
#' @export
hb_team_info <- function(...) .hb_not_implemented("hb_team_info")
#' @rdname harbouR-scaffold
#' @export
hb_team_list_users <- function(...) .hb_not_implemented("hb_team_list_users")
#' @rdname harbouR-scaffold
#' @export
hb_team_list_bases <- function(...) .hb_not_implemented("hb_team_list_bases")

# Scheduler (Tier 3) -------------------------------------------------------

#' @rdname harbouR-scaffold
#' @export
hb_scheduler_list <- function(...) .hb_not_implemented("hb_scheduler_list")
#' @rdname harbouR-scaffold
#' @export
hb_scheduler_run <- function(...) .hb_not_implemented("hb_scheduler_run")
