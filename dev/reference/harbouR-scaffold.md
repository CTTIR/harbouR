# Scaffolded endpoints (later releases)

These functions cover the Tier 2 and Tier 3 SeaTable endpoints (links,
big data, comments, snapshots, bases, import/export, sharing,
integrations, admin, team, scheduler). They are intentionally stubbed in
0.1.0: the signatures and documentation are stable, but each one raises
a clear `not yet implemented` error so callers can discover the surface
without surprises. They will be filled in opportunistically in later
minor releases.

## Usage

``` r
hb_list_links(...)

hb_create_link(...)

hb_update_link(...)

hb_delete_link(...)

hb_auto_link(...)

hb_bigdata_add_rows(...)

hb_bigdata_move_in(...)

hb_bigdata_move_out(...)

hb_list_comments(...)

hb_get_comment(...)

hb_delete_comment(...)

hb_create_snapshot(...)

hb_list_snapshots(...)

hb_restore_snapshot(...)

hb_list_bases(...)

hb_create_base(...)

hb_update_base(...)

hb_delete_base(...)

hb_base_size(...)

hb_import_base(...)

hb_export_base(...)

hb_import_table(...)

hb_export_table(...)

hb_append_from_file(...)

hb_share_base(...)

hb_share_view(...)

hb_list_shares(...)

hb_list_webhooks(...)

hb_create_webhook(...)

hb_delete_webhook(...)

hb_admin_list_users(...)

hb_admin_list_bases(...)

hb_admin_list_groups(...)

hb_admin_system_info(...)

hb_team_info(...)

hb_team_list_users(...)

hb_team_list_bases(...)

hb_scheduler_list(...)

hb_scheduler_run(...)
```

## Arguments

- ...:

  Arguments forwarded to the future implementation.

## Value

Each function errors with a `lifecycle`-style message; the eventual
return shape is documented per group.
