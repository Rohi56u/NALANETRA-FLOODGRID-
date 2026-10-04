# Primary references and implementation mapping

Sources support underlying methods/API behavior, not team-specific weights, municipal deployment, accuracy or impact percentages. Links were checked during repair on 4 October 2026.

| Topic | Primary source | Implementation boundary |
|---|---|---|
| Official radar products | [IMD radar services](https://mausam.imd.gov.in/responsive/radar.php) | No authorized live ingestion or local product calibration bundled |
| Reflectivity/rain | [US NWS operational Z–R relationships](https://www.weather.gov/tae/research-zrpaper) | Empirical `Z=200R^1.6`; conversion utility requires local calibration |
| Drainage hydraulics | [US EPA SWMM](https://www.epa.gov/water-research/storm-water-management-model-swmm), [hydraulics reference](https://nepis.epa.gov/Exe/ZyPURL.cgi?Dockey=P100S9AS.txt) | Manning conveyance context; the storage experiment is simpler and does not run SWMM |
| Spatial queries | [PostGIS ST_DWithin](https://postgis.net/docs/ST_DWithin.html), [ST_Intersects](https://postgis.net/docs/ST_Intersects.html) | Spatial schema/tests; UI shows incident points |
| Road alternatives | [OSRM HTTP route service](https://project-osrm.org/docs/v26.4.0/http#route-service) | Full geometry/alternatives; post-screening does not modify edge weights or guarantee dry roads |
| Digests | [NIST FIPS 180-4](https://csrc.nist.gov/pubs/fips/180-4/upd1/final) | SHA-256 integrity, not scene truth or automatic legal admissibility |
| Push | [Firebase Admin sending](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk) | Provider acceptance differs from device delivery; automatic Flutter enrollment pending |
| Mobile security | [OWASP MASVS](https://mas.owasp.org/MASVS/) | Review categories, not a certification |
| Fonts | [Official Poppins](https://github.com/google/fonts/tree/main/ofl/poppins) | Bundled SIL Open Font License |

P weights, 80 mm/h normalization, six-hour age cap, 150 m/six-hour grouping, 50 m capture checks and 15-minute freshness are team policies requiring calibration/operational approval. These references do not validate those exact thresholds. D in triage is entered blockage/capacity loss; conduit flow in the experiment is a separate modeled quantity.

Unsupported loss/hotspot totals, municipal fraud percentages, exact response improvements, surveyed asset counts and a mismatched vision paper link were removed from the repository narrative. Submitted presentation assets remain unchanged. A hash/documentation link does not establish statutory compliance, legal admissibility or government approval; deployment requires its own review.
