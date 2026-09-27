# NalaNetra FloodGrid — Data Sources & Ingestion Pipeline Specification

This document details the exact geospatial, meteorological, topological, and crowdsourced data feeds ingested by the **NalaNetra FloodGrid** engine for real-time urban flood nowcasting in Municipal Corporation Gurugram (MCG).

---

## 🗺️ Geospatial & Meteorological Data Architecture

NalaNetra utilizes a hybrid data pipeline combining **macro-scale atmospheric precipitation feeds**, **meso-scale topographic elevation rasters**, and **micro-scale municipal drainage vector topologies** to bridge the resolution gap between satellite/radar forecasts and hyper-local street-level waterlogging.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          DATA INGESTION PIPELINE                                │
└─────────────────────────────────────────────────────────────────────────────────┘
         │
         ├── [1] MACRO: Atmospheric Nowcast (MoES / NCMRWF & IMD)
         │   ├── Aya Nagar & Palam Doppler Weather Radar (DWR) Reflectivity (Z)
         │   ├── NCMRWF Unified Model (UM) High-Resolution Precipitation (NetCDF)
         │   └── IMD District Nowcast Bulletin API (JSON / XML)
         │
         ├── [2] MESO: Surface Topography & Hydrology (ISRO / USGS)
         │   ├── Cartosat-1 / SRTM 10m Digital Elevation Model (DEM)
         │   ├── Slope, Aspect & Flow Accumulation Catchment Grids
         │   └── Land Use / Land Cover (LULC) Runoff Coefficients
         │
         ├── [3] MICRO: Subsurface Drainage Network (MCG GIS)
         │   ├── 12,000+ Manhole Nodes with Invert & Rim Elevations
         │   ├── Stormwater Conduit Edges (Diameter, Length, Manning's n)
         │   └── Outfall Discharge Vectors to Badshahpur / Najafgarh Drains
         │
         ├── [4] DYNAMIC: Road & Transit Network (OSM / OSRM)
         │   ├── OpenStreetMap Road Edges, Speeds & Highway Geometries
         │   └── OSRM Routing Graph with Real-Time Flooded Edge Exclusion
         │
         └── [5] GROUND TRUTH: Crowdsourced Telemetry (Citizen & Field Crew)
             ├── 1-Tap Geotagged Reports (<5m GPS Accuracy, Timestamp)
             ├── Visual Depth Triage (Ankle / Knee / Waist / Submerged)
             └── Field Crew Before/After Resolution Proof (SHA-256 EXIF)
```

---

## 1. Atmospheric Rainfall Feeds (MoES / NCMRWF & IMD)

| Data Feed | Source / Agency | Format / Protocol | Ingestion Frequency | Resolution | Purpose in NalaNetra |
|---|---|---|---|---|---|
| **Doppler Weather Radar (DWR)** | IMD (Delhi Aya Nagar / Palam Radar) | Radial Raster / HDF5 / NetCDF | Every 10–15 minutes | ~500m to 1km grid | Real-time precipitation reflectivity factor ($Z$) converted to rain rate ($R$) via Marshall-Palmer calibration ($Z = 200 R^{1.6}$). |
| **Unified Model (UM) Nowcast** | NCMRWF • MoES | NetCDF-4 / GRIB2 | Hourly cycle | 4km downscaled to 1km | Synoptic convective cloud tracking and atmospheric motion vector inputs. |
| **District Nowcast Warnings** | IMD Mausam API | REST API / GeoJSON / XML | Live on warning issue | Ward / City-level | Automated threshold triggers for emergency municipal alert broadcasts. |

### Marshall-Palmer Calibration Formula
$$\mathbf{Z = a \cdot R^b \quad \Longrightarrow \quad R = \left(\frac{Z}{200}\right)^{1/1.6}}$$
- $Z$: Radar reflectivity factor ($mm^6/m^3$)
- $R$: Ground precipitation intensity ($mm/hr$)

---

## 2. Topographic Elevation & Surface Hydrology

| Data Feed | Source | Format | Spatial Resolution | Purpose in NalaNetra |
|---|---|---|---|---|
| **Digital Elevation Model (DEM)** | ISRO Bhuvan (Cartosat-1) / USGS SRTM | GeoTIFF (32-bit Float) | 10-meter (Resampled to 5m via bilinear interpolation) | Delineates micro-watersheds, identifies natural depressions, low-lying underpasses, and surface runoff flow vectors. |
| **Hydrological Flow Accumulation** | Derived via D8 Flow Routing Algorithm | GeoTIFF | 10-meter | Quantifies accumulated overland flow volume entering each municipal stormwater inlet. |
| **LULC (Impervious Surface)** | Bhuvan / Copernicus Sentinel-2 | GeoTIFF / Vector | 10-meter | Determines surface runoff coefficient ($C$ in Rational Formula $Q = C \cdot I \cdot A$): Impervious roads ($C=0.90$) vs parks ($C=0.25$). |

---

## 3. Subsurface Stormwater Drainage Network (MCG GIS)

| Dataset | Provider | Format | Features Count | Primary Attributes |
|---|---|---|---|---|
| **Drainage Manholes (Nodes)** | MCG (Municipal Corporation Gurugram) | GeoJSON / PostGIS Point Layer | 12,450 nodes | `node_id`, `invert_elevation`, `rim_elevation`, `depth_m`, `connected_pipes`, `ward_id` |
| **Stormwater Conduits (Edges)** | MCG Engineering Division | PostGIS LineString Layer | 8,920 segments | `edge_id`, `length_m`, `diameter_mm`, `pipe_shape`, `mannings_n` ($0.013$ RCC), `slope_pct` |
| **Major Outfall Drains** | GMDA / Haryana Irrigation Dept. | PostGIS LineString Layer | 14 main outfalls | Badshahpur Drain, Sector 29 Trunk Drain, Najafgarh Basin outfall points. |

### Hydraulic Conveyance Calculation (Manning's Equation)
$$\mathbf{V = \frac{1}{n} \cdot R_h^{2/3} \cdot S^{1/2} \quad \text{and} \quad Q_{cap} = A \cdot V}$$
- When surface runoff $Q_{runoff} > Q_{cap}$, pipe surcharge occurs and water spills through the manhole onto the street.

---

## 4. Road Network & Navigation Graph (OpenStreetMap / OSRM)

| Dataset | Source | Format | Ingestion / Sync | Purpose in NalaNetra |
|---|---|---|---|---|
| **Highway & Arterial Graph** | OpenStreetMap (OSM) via Geofabrik India | `.osm.pbf` | Weekly / On-demand | Underlying road network geometry for municipal crew dispatch and citizen safety routing. |
| **Dynamic Routing Engine** | OSRM (Open Source Routing Machine) | MLD (Multi-Level Dijkstra) | Real-time dynamic updates (sub-50ms) | Penalizes road edge weights with $\infty$ when water depth exceeds $>30\text{ cm}$, rerouting ambulances and response vehicles. |

---

## 5. Crowdsourced Ground Truth (Citizen & Crew Telemetry)

| Data Stream | Capturing Interface | Payload Attributes | Verification & Security |
|---|---|---|---|
| **Citizen Waterlogging Report** | Citizen Flutter App (Hindi/English) | Lat/Lon, GPS Accuracy ($\pm 4.2\text{m}$), Visual Depth Category, Photo Bytes, Timestamp | Automated Groq AI photo validity check, 150m spatial clustering, SHA-256 server-side hash. |
| **Field Response Verification** | Field Crew App | Before/After Photo, Officer ID, Crew GPS coordinates, Time to Clear | Mandatory Geo-fence verification (crew must be $\le 50\text{m}$ from incident), immutable EXIF hash. |

---

## 6. Open IoT Telemetry Gateway (Future Ready)

While NalaNetra's core design operates **100% hardware-free** for zero capital expenditure, the FastAPI backend includes pre-configured **MQTT / REST ingestion webhooks** compatible with municipal IoT sensors:
- **Supported Sensor Types:** Ultrasonic Level Transmitters, Submersible Hydrostatic Pressure Transducers, Radar Level Sensors.
- **Protocol:** MQTT v3.1.1 / v5.0 over TLS (Port 8883) with JSON telemetry payload (`{"sensor_id": "SN-MCG-104", "depth_cm": 42.5, "battery_v": 3.6}`).
