# harbouR: R Client for SeaTable Collaborative Databases

An unofficial R client for the SeaTable REST API. Connect to a SeaTable
server, read and write rows as tidy tibbles, manage
tables/columns/views, upload and attach files, and explore bases
interactively with the bundled Shiny app.

## Details

harbouR was shaped by the needs, field testing and data of Paul
Elsinghorst, Wiebke Derz, Matthias Ring, Gerhard Achatz and Vinzent
Forstmeier.

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

For accuracy, SeaTable Server is not fully open source - `dtable-server`
is proprietary - but the API specification, the clients and SDKs, the
integrations and the documentation are openly licensed, and that is the
part harbouR depends on.

SeaTable is developed by Seafile Ltd. (Beijing); SeaTable GmbH (Mainz)
handles sales, support and SeaTable Cloud. Thanks are owed to both.

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
