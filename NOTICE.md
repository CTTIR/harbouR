# Trademarks, affiliation and acknowledgement

## harbouR is an independent, third-party client

harbouR is developed and published independently by its authors. It is
**not** affiliated with, endorsed by, sponsored by, certified by, or in
any way officially connected to SeaTable GmbH.

No statement in this package, its documentation, or its website should
be read as suggesting that SeaTable GmbH has reviewed, approved,
supported or warranted harbouR. Requests for support with harbouR belong
at <https://github.com/CTTIR/harbouR/issues>, not with SeaTable GmbH.

## Trademarks

SeaTable is a trademark of

> SeaTable GmbH 117er Ehrenhof 5, 55118 Mainz, Germany Amtsgericht
> Mainz, HRB 49723

All trademarks, service marks, trade names and product names referred to
in this package are the property of their respective owners.

harbouR uses the name “SeaTable” solely to describe, truthfully and
accurately, the service that this software communicates with. That is
nominative use: the name identifies SeaTable GmbH’s product, it is used
no more than is necessary to do so, and nothing about the use suggests
sponsorship or endorsement. harbouR claims no right, title or interest
in the mark.

harbouR does not distribute, bundle, or reproduce any logo, wordmark,
icon, colour scheme or other brand asset belonging to SeaTable GmbH. The
harbouR logo is an original work by the package’s authors.

## Relationship to the SeaTable service

harbouR is a client library. It contains no SeaTable server code and
redistributes no SeaTable software. It communicates with a SeaTable
server exclusively through the public REST API that SeaTable GmbH
documents at <https://api.seatable.com/> and provides for third-party
applications.

Using harbouR does not grant you any right to use SeaTable. Your use of
the SeaTable service, whether hosted by SeaTable GmbH or self-hosted, is
governed entirely by your own agreement with SeaTable GmbH and by their
terms, and is a matter between you and them. harbouR neither modifies
nor supplements those terms.

harbouR is licensed under the MIT licence and is provided **without
warranty of any kind**; see `LICENSE`. That disclaimer covers harbouR
only. It says nothing about the SeaTable service.

## Acknowledgement

harbouR is a client. Everything it does rests on work SeaTable GmbH and
Seafile Ltd. did first, and on a series of decisions they made about how
open that work would be. Those decisions are the reason an independent
client like this one could be written at all, so they are worth naming.

**They publish the API contract itself, not just a description of it.**
The OpenAPI 3.0 specification is a public repository
([seatable/openapi](https://github.com/seatable/openapi)) covering 387
operations, and it is the source the reference documentation, the PHP
client and the tooling are generated from. It is kept on one branch per
server version, from v4.0 to v6.2, so the contract a given release
promised stays available after that release is gone. Their CI refuses a
specification whose operations lack a summary, a description, a tag or a
declared security scheme.

**The documentation is open to everyone.** The full reference at
<https://api.seatable.com/> reads without an account, a registration or
a payment. The admin and developer manuals are public repositories that
invite pull requests. They also publish `llms.txt` and `llms-full.txt`,
so the documentation is legible to machines as well as people.

**They write down what they break.** SeaTable keeps a public API
changelog by server version, and it records removals as plainly as
additions: `/dtable-server` and `/dtable-db` were marked deprecated in
5.2 and removed in 5.3, with dates. harbouR was pointed at exactly those
endpoints. Without that changelog the package would still be aimed at an
API that no longer exists — this is not a hypothetical benefit.

**They support people building on top.** Official client libraries for
Python and PHP are Apache-2.0, as are the `dtable-sdk` and the HTML-page
SDK; the n8n integration nodes are MIT. The community forum has a
Developer Talk category for API questions, and the API reference points
there for help.

**They make it possible to build without paying first.** SeaTable Cloud
has a permanently free tier that includes API access, and SeaTable
Server can be self-hosted — the Developer Edition needs no licence key
and is described as being for “developers and small teams using SeaTable
as a database backend via APIs and scripts”, which is precisely the use
case harbouR serves.

A note on accuracy, because an acknowledgement should not overstate:
SeaTable Server is **not** fully open source. `dtable-web` and
`dtable-events` are Apache-2.0 and `seaf-server` is AGPLv3, but
`dtable-server` — the component that holds the tables — is proprietary.
What is openly licensed is the API specification, the official clients
and SDKs, the integrations and the documentation. That is the part
harbouR depends on, and it is more than most vendors publish.

SeaTable is developed by Seafile Ltd. (Beijing), which grew it out of
the Seafile project and holds half of the joint venture; SeaTable GmbH
(Mainz), founded in July 2020 by Dr. Ralf Dyllick-Brenzinger and
Christoph Dyllick-Brenzinger, handles sales, support and SeaTable Cloud.
Thanks are owed to both.

If SeaTable is useful to you, support the people who build it:
<https://seatable.com/>.
