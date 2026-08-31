-- ============================================================================
-- NalaNetra FloodGrid - PostGIS Database Schema
-- Spatial Hydrological & Municipal Dispatch Database for SIH 2026 (PS 26085)
-- Targeted for Gurugram Municipal Corporation (MCG) Pilot (Ward 14)
-- ============================================================================

-- Enable PostGIS spatial extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. DRAINAGE HYDRAULIC NETWORK: Manholes (Graph Nodes)
CREATE TABLE IF NOT EXISTS drainage_nodes (
    node_id VARCHAR(50) PRIMARY KEY,
    ward_number INT NOT NULL DEFAULT 14,
    elevation_meters NUMERIC(6, 2) NOT NULL,
    invert_level_meters NUMERIC(6, 2) NOT NULL,
    manhole_type VARCHAR(30) DEFAULT 'STANDARD_CIRCULAR',
    geom GEOMETRY(Point, 4326) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Spatial index for sub-second nearest-node lookup
CREATE INDEX IF NOT EXISTS idx_drainage_nodes_geom 
    ON drainage_nodes USING GIST (geom);

-- 2. DRAINAGE HYDRAULIC NETWORK: Stormwater Pipes & Conduits (Graph Edges)
CREATE TABLE IF NOT EXISTS drainage_conduits (
    conduit_id VARCHAR(50) PRIMARY KEY,
    start_node_id VARCHAR(50) REFERENCES drainage_nodes(node_id),
    end_node_id VARCHAR(50) REFERENCES drainage_nodes(node_id),
    diameter_mm INT NOT NULL DEFAULT 600,
    material VARCHAR(40) DEFAULT 'REINFORCED_CONCRETE',
    slope_gradient NUMERIC(5, 4) NOT NULL,
    max_flow_capacity_cumecs NUMERIC(6, 2) NOT NULL,
    current_surcharge_ratio NUMERIC(3, 2) DEFAULT 0.00, -- 0.00 (empty) to 1.00 (surcharged)
    geom GEOMETRY(LineString, 4326) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_drainage_conduits_geom 
    ON drainage_conduits USING GIST (geom);

-- 3. MUNICIPAL WATERLOGGING INCIDENTS
CREATE TABLE IF NOT EXISTS waterlogging_incidents (
    incident_id VARCHAR(50) PRIMARY KEY,
    location_name VARCHAR(255) NOT NULL,
    ward_number INT NOT NULL DEFAULT 14,
    reported_severity VARCHAR(20) NOT NULL CHECK (reported_severity IN ('ankle', 'knee', 'waist', 'submerged')),
    calculated_priority_score NUMERIC(5, 2) NOT NULL,
    priority_band VARCHAR(20) NOT NULL CHECK (priority_band IN ('LOW', 'MODERATE', 'HIGH', 'CRITICAL')),
    status VARCHAR(40) NOT NULL DEFAULT 'TRIAGE_COMPLETED',
    witness_count INT DEFAULT 1,
    is_emergency_route BOOLEAN DEFAULT FALSE,
    nearest_drain_node_id VARCHAR(50) REFERENCES drainage_nodes(node_id),
    geom GEOMETRY(Point, 4326) NOT NULL,
    photo_hash VARCHAR(64),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    sla_due_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_incidents_geom 
    ON waterlogging_incidents USING GIST (geom);

-- 4. FIELD CREW DISPATCH & PROOF-GATED VERIFIED CLOSURES
CREATE TABLE IF NOT EXISTS crew_dispatch_records (
    dispatch_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_id VARCHAR(50) REFERENCES waterlogging_incidents(incident_id),
    crew_team_id VARCHAR(50) NOT NULL,
    officer_signoff_id VARCHAR(50) NOT NULL,
    dispatched_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    arrived_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    before_photo_url TEXT,
    after_photo_url TEXT,
    after_photo_sha256_hash VARCHAR(64) NOT NULL,
    is_verified_closed BOOLEAN DEFAULT FALSE,
    pump_deployed BOOLEAN DEFAULT FALSE,
    choke_cause VARCHAR(100) -- e.g. 'SOLID_PLASTIC_WASTE', 'SILT_ACCUMULATION'
);

-- Seed Sample Data for Gurugram Ward 14 Hotspots
INSERT INTO drainage_nodes (node_id, ward_number, elevation_meters, invert_level_meters, geom)
VALUES 
    ('MH-GGM-1401', 14, 218.40, 215.10, ST_SetSRID(ST_MakePoint(77.0125, 28.4356), 4326)),
    ('MH-GGM-1402', 14, 219.10, 216.00, ST_SetSRID(ST_MakePoint(77.0435, 28.4712), 4326))
ON CONFLICT (node_id) DO NOTHING;
