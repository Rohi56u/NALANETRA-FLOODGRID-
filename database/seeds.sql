-- ==============================================================================
-- NalaNetra FloodGrid - Realistic Spatial Seed Data (Gurugram Ward 14 & NH-48)
-- EPSG:4326 (WGS 84 Coordinates)
-- ==============================================================================

-- 1. Insert Municipal Ward Boundaries
INSERT INTO municipal_wards (ward_id, ward_number, ward_name, population_density_tier, criticality_index, geom)
VALUES (
    'WARD-GGM-14',
    14,
    'Ward 14 (Sector 14 & NH-48 Arterial Corridor), Gurugram',
    'HIGH_COMMERCIAL_RESIDENTIAL',
    0.85,
    ST_GeomFromText('POLYGON((77.0350 28.4600, 77.0550 28.4600, 77.0550 28.4750, 77.0350 28.4750, 77.0350 28.4600))', 4326)
) ON CONFLICT DO NOTHING;

-- 2. Insert Vulnerable Underpass & Road Hotspots
INSERT INTO flood_hotspots (hotspot_id, location_name, ward_id, hotspot_type, depression_depth_m, is_emergency_corridor, geom)
VALUES 
(
    'HOTSPOT-SEC14',
    'Sector 14 Underpass Urban Corridor',
    'WARD-GGM-14',
    'UNDERPASS_DEPRESSION',
    6.2,
    TRUE, -- Primary transit route to Civil Hospital
    ST_SetSRID(ST_MakePoint(77.0428, 28.4682), 4326)
),
(
    'HOTSPOT-HEROHONDA',
    'Hero Honda Chowk Underpass (NH-48)',
    'WARD-GGM-14',
    'HIGHWAY_SUBMERGED_BOWL',
    7.7,
    TRUE, -- Critical national transit artery
    ST_SetSRID(ST_MakePoint(77.0142, 28.4358), 4326)
),
(
    'HOTSPOT-RAJIV',
    'Rajiv Chowk Underpass / Medanta Link',
    'WARD-GGM-14',
    'ARTERIAL_INTERCHANGE',
    4.5,
    TRUE, -- Main ambulance corridor for Medanta The Medicity
    ST_SetSRID(ST_MakePoint(77.0392, 28.4528), 4326)
) ON CONFLICT DO NOTHING;

-- 3. Insert Verified Active Flood Incidents with Cryptographic Hashes
INSERT INTO flood_incidents (
    incident_id,
    hotspot_id,
    ward_id,
    severity_level,
    depth_cm,
    priority_score,
    triage_band,
    action_sla_minutes,
    status,
    sha256_evidence_hash,
    reported_lat,
    reported_lon,
    created_at
)
VALUES
(
    'INC-1092',
    'HOTSPOT-SEC14',
    'WARD-GGM-14',
    'submerged',
    85.0,
    94.5,
    'CRITICAL',
    30,
    'RESOLVED',
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    28.4682,
    77.0428,
    NOW() - INTERVAL '45 minutes'
),
(
    'INC-1093',
    'HOTSPOT-HEROHONDA',
    'WARD-GGM-14',
    'waist',
    55.0,
    86.2,
    'CRITICAL',
    35,
    'IN_PROGRESS_DISPATCHED',
    'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e',
    28.4358,
    77.0142,
    NOW() - INTERVAL '20 minutes'
) ON CONFLICT DO NOTHING;

-- 4. Insert Verified Resolution Proof Record (Before/After)
INSERT INTO resolution_proofs (
    proof_id,
    incident_id,
    assigned_crew_unit,
    officer_signoff_id,
    geofence_distance_m,
    before_photo_sha256,
    after_photo_sha256,
    verification_status,
    verified_at
)
VALUES (
    'PROOF-REC-001092',
    'INC-1092',
    'Unit 07 (Ward 14 Depot Suction Crew)',
    'MCG-ENG-R-SHARMA',
    18.4, -- Strict <= 50m geofence compliant
    '8f434346648f6b96df89dda901c5176b10a6d83961dd3c1ac88b59b2dc327aa4',
    'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',
    'OFFICER_APPROVED_PROOF_GATED',
    NOW()
) ON CONFLICT DO NOTHING;
