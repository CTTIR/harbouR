# harbouR: R Client for SeaTable Collaborative Databases

An unofficial R client for working with SeaTable data from R: read and
write a local `.dtable` export with no server at all, or connect to a
self-hosted SeaTable server over its REST API. Rows come back as tidy
tibbles; you can manage tables, columns and views, upload and attach
files, export to spreadsheet formats, and explore a base interactively
with the bundled Shiny app.

## Details

harbouR was shaped by the needs, field testing and data of Paul
Elsinghorst, Wiebke Derz, Matthias Ring, Gerhard Achatz and Vinzent
Forstmeier.

## What harbouR is for

harbouR is written for two things: reading and writing SeaTable
`.dtable` data files directly, with no server involved; and talking to a
SeaTable Server you run yourself, over its REST API. That is the
intended scope, and what the documentation, examples and tests describe.
[`hb_client()`](https://cttir.github.io/harbouR/reference/hb_client.md)
takes a server URL as an argument and makes no judgement about which
host you give it - this is a statement of what the package is built for,
not a technical restriction.

## Trademarks and affiliation

harbouR is an independent, third-party client. It is **not** affiliated
with, endorsed by, sponsored by, or officially connected to SeaTable
GmbH. Support requests belong at
<https://github.com/CTTIR/harbouR/issues>, not with SeaTable GmbH.

SeaTable is a trademark of SeaTable GmbH, 117er Ehrenhof 5, 55118 Mainz,
Germany (Amtsgericht Mainz, HRB 49723). harbouR uses the name only to
identify the service it communicates with, and claims no right in the
mark. It ships none of SeaTable GmbH's logos or brand assets.

harbouR contains no SeaTable server code. It speaks to a SeaTable server
through the public REST API documented at <https://api.seatable.com/>.
Your use of the SeaTable service is governed by your own agreement with
SeaTable GmbH, not by this package's licence.

The full notice is at
<https://github.com/CTTIR/harbouR/blob/main/NOTICE.md>.

## Acknowledgements

harbouR is a client, and rests on work SeaTable GmbH and Seafile Ltd.
did first - in particular on how open they chose to make it.

They publish the OpenAPI 3.0 specification for the REST API as a public
repository, on one branch per server version, so the contract a release
promised stays available afterwards. The full reference reads without an
account or payment, and the manuals are public repositories that accept
pull requests. The official Python and PHP clients are Apache-2.0.

They also write down what they break: the public changelog recorded that
`/dtable-server` and `/dtable-db` were deprecated in 5.2 and removed in
5.3. harbouR was aimed at exactly those endpoints, so without that entry
it would still be talking to an API that no longer exists.

For accuracy, SeaTable Server is not open source: `dtable-server` is
proprietary. The official clients and SDKs are Apache-2.0. The API
specification and reference are published publicly but carry no open
licence, and harbouR relies on none - it reproduces no documentation
prose, and relies on the exclusion of the ideas and principles
underlying a program\\s interfaces from copyright protection (Art. 1(2),
Directive 2009/24/EC; § 69a(2) UrhG; CJEU C-406/10). SeaTable\\s own
dtable-server EULA points the same way: applications using the API are
"third-party software", and the EULA\\s provisions "do not apply to any
such third-party software". This is reasoning, not legal advice; the
notice sets out its limits.

SeaTable is developed by Seafile Ltd. (Beijing); SeaTable GmbH (Mainz)
is the German company behind it. Thanks are owed to both.

## See also

Useful links:

- <https://github.com/CTTIR/harbouR>

- <https://cttir.github.io/harbouR/>

- Report bugs at <https://github.com/CTTIR/harbouR/issues>

## Author

**Maintainer**: Raban Heller <raban.heller@uni-ulm.de>
([ORCID](https://orcid.org/0000-0001-8006-9742)) \[copyright holder\]

Authors:

- Raban Heller <raban.heller@uni-ulm.de>
  ([ORCID](https://orcid.org/0000-0001-8006-9742)) \[copyright holder\]

- Paul Elsinghorst

- Wiebke Derz

- Matthias Ring

- Gerhard Achatz

- Vinzent Forstmeier
