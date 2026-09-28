# 🗺️ NalaNetra Nationwide Scaling Roadmap & Pilot Validation

> **Smart India Hackathon 2026 | Problem Statement 26085**  
> **Team Flood Busters | Sponsoring Agency: MoES • NCMRWF**  
> **Target Municipality:** Municipal Corporation of Gurugram (MCG), Haryana

---

## 📈 3-Phase Phased Implementation Strategy

```
  ┌──────────────────────────────────────────────────────────────────┐
  │ PHASE 1: PILOT WARD (Months 1–3)                                 │
  │ • Focus: Gurugram Ward 14 & NH-48 Corridor                       │
  │ • Ingestion: IMD Aya Nagar DWR & MCG Drainage GIS                │
  │ • Calibration: P-Score weights & 150m DBSCAN grouping           │
  │ • Milestone: Verified baseline dispatch-to-arrival response time │
  └────────────────────────────────┬─────────────────────────────────┘
                                   │ Validation Gate
  ┌────────────────────────────────▼─────────────────────────────────┐
  │ PHASE 2: CITY-WIDE EXPANSION (Months 4–8)                        │
  │ • Focus: All 35 Wards of Municipal Corporation Gurugram (MCG)   │
  │ • Routing: Flood-aware OSRM route updates with GMDA traffic data │
  │ • Coordination: Gurugram Traffic Police & Hospital corridors     │
  │ • Milestone: 80% response acceleration & 0% ghost closures       │
  └────────────────────────────────┬─────────────────────────────────┘
                                   │ Validation Gate
  ┌────────────────────────────────▼─────────────────────────────────┐
  │ PHASE 3: NATIONAL SCALING (Months 9–18)                          │
  │ • Focus: MoES / NDMA Priority Cities (Mumbai, Bengaluru, Chennai)│
  │ • Adaptability: Local DEM & municipal drainage onboarding        │
  │ • Open Ecosystem: Standardized REST APIs & AMRUT 2.0 alignment   │
  │ • Milestone: Multi-city cloud federation under NCMRWF            │
  └──────────────────────────────────────────────────────────────────┘
```

---

## 1. Detailed Phase Breakdown

### Phase 1: Pilot Ward (Months 1–3) • Gurugram Ward 14
- **Pilot Geographic Scope:** Ward 14, Sector 14 underpass corridor, and NH-48 arterial interchange (Hero Honda Chowk & Rajiv Chowk).
- **Core Objectives:**
  1. *Confirm Data Feeds:* Establish secure API conduits with IMD Aya Nagar Doppler Weather Radar and GMDA GIS drainage layers.
  2. *Ground-Truth Reporting:* Deploy Citizen Portal to Ward 14 RWA federations and local commuters.
  3. *Forecast Calibration:* Validate 1D kinematic pipe surcharge modeling against physical street water levels.
  4. *Benchmark Response Times:* Record pre-NalaNetra municipal baseline response metrics (typically 120–180 minutes).

### Phase 2: City-Wide Expansion (Months 4–8) • Municipal Corporation Gurugram
- **Scope:** Scale across all 35 MCG wards, covering over 12,450 manholes and 8,920 stormwater culverts.
- **Core Objectives:**
  1. *Dynamic OSRM Integration:* Connect live edge-weight exclusion with GMDA Intelligent Traffic Management System (ITMS).
  2. *Emergency Corridor Protection:* Prioritize green-corridor routes to Medanta, Artemis, and Civil Hospital Sector 10.
  3. *Staff Training & Capacity Building:* Train 120+ MCG junior engineers and field pump unit operators on the mobile verification workflow.
  4. *Contractor Audit Enforcement:* Enforce Section 65B SHA-256 before/after photographic proof for all municipal desilting contracts.

### Phase 3: National Scaling (Months 9–18) • Multi-City Replication
- **Scope:** Replicate across top flood-vulnerable urban centers (e.g. Mumbai Municipal Corporation, BBMP Bengaluru, Greater Chennai Corporation).
- **Core Objectives:**
  1. *Modular Ingestion Engine:* Onboard localized Cartosat DEMs and city-specific drainage networks via automated GIS converters.
  2. *Open API Architecture:* Publish standardized OpenAPI/Swagger endpoints for integration into national NDMA / Smart Cities Command Centers.
  3. *Policy & Budget Integration:* Align with AMRUT 2.0 (Atal Mission for Rejuvenation and Urban Transformation) and 15th Finance Commission Disaster Management Grants.

---

## 2. Key Target Impact & Verification Metrics

| # | Impact Dimension | Pilot Target | Verification Method | Statutory Standard |
|:---:|:---|:---:|:---|:---|
| **1** | **Rapid Response** | **80% Faster** | Compare median dispatch-to-arrival timestamp against pre-pilot baseline. | NDMA Urban Flooding Guidelines |
| **2** | **Proof-Linked Closures** | **100% Verified** | On-site $\le 50\text{m}$ geofenced Before/After photo with SHA-256 cryptographic check. | Section 65B Indian Evidence Act |
| **3** | **Optimized Logistics** | **-70% Redundant Trips** | 150m radius / 6-hour DBSCAN spatial grouping of duplicate citizen reports. | MCG Fleet GPS Telemetry |
| **4** | **Early Warning Horizon** | **Up to 3 Hours** | Evaluate rainfall-runoff-drainage coupling lead time on held-out cloudburst events. | IMD Nowcast Validation Protocol |

> *Note: Impact figures represent institutional pilot targets subject to field calibration and municipal data feed availability.*
