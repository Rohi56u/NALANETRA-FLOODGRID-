-- NalaNetra v2: generated from backend/database.py. Apply to an empty database.

BEGIN;

CREATE EXTENSION IF NOT EXISTS postgis;


CREATE TABLE users (
	id SERIAL NOT NULL, 
	name VARCHAR(100) NOT NULL, 
	email VARCHAR(254) NOT NULL, 
	phone VARCHAR(24) NOT NULL, 
	role VARCHAR(16) NOT NULL, 
	staff_id VARCHAR(40), 
	password_hash TEXT NOT NULL, 
	verified BOOLEAN NOT NULL, 
	failed_logins INTEGER NOT NULL, 
	locked_until TIMESTAMP WITH TIME ZONE, 
	PRIMARY KEY (id), 
	UNIQUE (email), 
	UNIQUE (staff_id)
)

;


CREATE TABLE audit_events (
	id SERIAL NOT NULL, 
	actor_id INTEGER NOT NULL, 
	incident_id VARCHAR(40), 
	action VARCHAR(60) NOT NULL, 
	details JSON NOT NULL, 
	at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(actor_id) REFERENCES users (id)
)

;


CREATE TABLE auth_challenges (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	code_hash VARCHAR(64) NOT NULL, 
	expires_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	attempts INTEGER NOT NULL, 
	consumed BOOLEAN NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
)

;


CREATE TABLE auth_sessions (
	id VARCHAR(36) NOT NULL, 
	user_id INTEGER NOT NULL, 
	refresh_hash VARCHAR(64) NOT NULL, 
	expires_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	revoked BOOLEAN NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id), 
	UNIQUE (refresh_hash)
)

;

CREATE INDEX ix_auth_sessions_user_id ON auth_sessions (user_id);


CREATE TABLE devices (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	token VARCHAR(4096) NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id), 
	UNIQUE (token)
)

;


CREATE TABLE incidents (
	id VARCHAR(40) NOT NULL, 
	location VARCHAR(200) NOT NULL, 
	lat FLOAT NOT NULL, 
	lon FLOAT NOT NULL, 
	severity VARCHAR(16) NOT NULL, 
	status VARCHAR(32) NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	verified_by INTEGER, 
	factors JSON NOT NULL, 
	factor_sources JSON NOT NULL, 
	priority FLOAT NOT NULL, 
	band VARCHAR(16) NOT NULL, 
	sla_minutes INTEGER NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(verified_by) REFERENCES users (id)
)

;

CREATE INDEX ix_incidents_status ON incidents (status);


CREATE TABLE evidence (
	id VARCHAR(40) NOT NULL, 
	incident_id VARCHAR(40) NOT NULL, 
	uploaded_by INTEGER NOT NULL, 
	kind VARCHAR(16) NOT NULL, 
	sha256 VARCHAR(64) NOT NULL, 
	pixel_hash VARCHAR(64) NOT NULL, 
	filename VARCHAR(80) NOT NULL, 
	media_type VARCHAR(30) NOT NULL, 
	lat FLOAT NOT NULL, 
	lon FLOAT NOT NULL, 
	accuracy_m FLOAT, 
	capture_source VARCHAR(20) NOT NULL, 
	captured_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	screening JSON NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(incident_id) REFERENCES incidents (id), 
	FOREIGN KEY(uploaded_by) REFERENCES users (id)
)

;

CREATE INDEX ix_evidence_incident_id ON evidence (incident_id);


CREATE TABLE notifications (
	id SERIAL NOT NULL, 
	user_id INTEGER NOT NULL, 
	incident_id VARCHAR(40) NOT NULL, 
	title VARCHAR(160) NOT NULL, 
	body TEXT NOT NULL, 
	at TIMESTAMP WITH TIME ZONE NOT NULL, 
	push_status VARCHAR(30) NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id), 
	FOREIGN KEY(incident_id) REFERENCES incidents (id)
)

;

CREATE INDEX ix_notifications_user_id ON notifications (user_id);


CREATE TABLE jobs (
	incident_id VARCHAR(40) NOT NULL, 
	crew_id INTEGER NOT NULL, 
	before_id VARCHAR(40), 
	after_id VARCHAR(40), 
	dispatched_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	closed_at TIMESTAMP WITH TIME ZONE, 
	work_note TEXT NOT NULL, 
	PRIMARY KEY (incident_id), 
	FOREIGN KEY(incident_id) REFERENCES incidents (id), 
	FOREIGN KEY(crew_id) REFERENCES users (id), 
	FOREIGN KEY(before_id) REFERENCES evidence (id), 
	FOREIGN KEY(after_id) REFERENCES evidence (id)
)

;

CREATE INDEX ix_jobs_crew_id ON jobs (crew_id);

CREATE UNIQUE INDEX one_active_job_per_crew ON jobs (crew_id) WHERE closed_at IS NULL;


CREATE TABLE reports (
	id VARCHAR(40) NOT NULL, 
	user_id INTEGER NOT NULL, 
	client_id VARCHAR(80) NOT NULL, 
	incident_id VARCHAR(40) NOT NULL, 
	lat FLOAT NOT NULL, 
	lon FLOAT NOT NULL, 
	notes TEXT NOT NULL, 
	depth_tag VARCHAR(16) NOT NULL, 
	evidence_id VARCHAR(40) NOT NULL, 
	grouping_candidates JSON NOT NULL, 
	created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT report_idempotency UNIQUE (user_id, client_id), 
	FOREIGN KEY(user_id) REFERENCES users (id), 
	FOREIGN KEY(incident_id) REFERENCES incidents (id), 
	FOREIGN KEY(evidence_id) REFERENCES evidence (id)
)

;

CREATE INDEX ix_reports_incident_id ON reports (incident_id);

CREATE INDEX ix_reports_user_id ON reports (user_id);

CREATE INDEX incidents_geography_idx ON incidents USING GIST ((ST_SetSRID(ST_MakePoint(lon,lat),4326)::geography));

CREATE VIEW incident_geometry AS SELECT id, status, ST_SetSRID(ST_MakePoint(lon,lat),4326) AS geom FROM incidents;

CREATE TABLE flood_polygons (
 id BIGSERIAL PRIMARY KEY, geom geometry(MultiPolygon,4326) NOT NULL,
 source TEXT NOT NULL, observed_at TIMESTAMPTZ NOT NULL, valid_until TIMESTAMPTZ NOT NULL,
 synthetic BOOLEAN NOT NULL, CHECK(valid_until > observed_at)
);

CREATE INDEX flood_polygons_geom_idx ON flood_polygons USING GIST(geom);

COMMIT;
