-- Dental PMS — Initial Schema Migration
-- All 12 tables with CHECK constraints, foreign keys, and RLS enabled.

-- ============================================================
-- 1. clinics
-- ============================================================
CREATE TABLE clinics (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE clinics ENABLE ROW LEVEL SECURITY;

-- clinics does not have clinic_id on itself; policy uses id directly
CREATE POLICY "clinic_isolation" ON clinics
  USING (id::text = auth.jwt() ->> 'clinic_id');


-- ============================================================
-- 2. users
-- ============================================================
CREATE TABLE users (
  id          UUID PRIMARY KEY REFERENCES auth.users(id),
  clinic_id   UUID NOT NULL REFERENCES clinics(id),
  email       TEXT NOT NULL,
  role        TEXT NOT NULL CHECK (role IN ('doctor', 'receptionist')),
  created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "clinic_isolation" ON users
  USING (clinic_id::text = auth.jwt() ->> 'clinic_id');


-- ============================================================
-- 3. patients
-- ============================================================
CREATE TABLE patients (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id       UUID NOT NULL REFERENCES clinics(id),
  name            TEXT NOT NULL,
  dob             DATE,
  contact         TEXT,
  medical_history TEXT,
  allergies       TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE patients ENABLE ROW LEVEL SECURITY;

CREATE POLICY "clinic_isolation" ON patients
  USING (clinic_id::text = auth.jwt() ->> 'clinic_id');


-- ============================================================
-- 4. appointments
-- ============================================================
CREATE TABLE appointments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id     UUID NOT NULL REFERENCES clinics(id),
  patient_id    UUID NOT NULL REFERENCES patients(id),
  user_id       UUID NOT NULL REFERENCES users(id),
  scheduled_at  TIMESTAMPTZ NOT NULL,
  status        TEXT NOT NULL CHECK (status IN ('scheduled','confirmed','completed','cancelled')),
  reason        TEXT,
  created_at    TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "clinic_isolation" ON appointments
  USING (clinic_id::text = auth.jwt() ->> 'clinic_id');


-- ============================================================
-- 5. clinical_notes
-- ============================================================
CREATE TABLE clinical_notes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id   UUID NOT NULL REFERENCES clinics(id),
  patient_id  UUID NOT NULL REFERENCES patients(id),
  created_by  UUID NOT NULL REFERENCES users(id),
  note        TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE clinical_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "clinic_isolation" ON clinical_notes
  USING (clinic_id::text = auth.jwt() ->> 'clinic_id');


-- ============================================================
-- 6. dental_images
-- ============================================================
CREATE TABLE dental_images (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id   UUID NOT NULL REFERENCES clinics(id),
  patient_id  UUID NOT NULL REFERENCES patients(id),
  url         TEXT NOT NULL,
  image_type  TEXT NOT NULL CHECK (image_type IN ('xray','photo','panoramic')),
  uploaded_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE dental_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "clinic_isolation" ON dental_images
  USING (clinic_id::text = auth.jwt() ->> 'clinic_id');


-- ============================================================
-- 7. ai_analysis
-- ============================================================
-- ai_analysis does not have its own clinic_id column in the schema.
-- Access is controlled through the dental_images foreign key.
CREATE TABLE ai_analysis (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  image_id        UUID NOT NULL REFERENCES dental_images(id),
  findings_json   JSONB NOT NULL,
  doctor_notes    TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE ai_analysis ENABLE ROW LEVEL SECURITY;

-- ai_analysis uses a join-based policy through dental_images
CREATE POLICY "clinic_isolation" ON ai_analysis
  USING (
    EXISTS (
      SELECT 1 FROM dental_images
      WHERE dental_images.id = ai_analysis.image_id
        AND dental_images.clinic_id::text = auth.jwt() ->> 'clinic_id'
    )
  );


-- ============================================================
-- 8. inventory
-- ============================================================
CREATE TABLE inventory (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id         UUID NOT NULL REFERENCES clinics(id),
  name              TEXT NOT NULL,
  category          TEXT,
  quantity          INT NOT NULL DEFAULT 0,
  reorder_threshold INT NOT NULL DEFAULT 10,
  unit_price        NUMERIC(10,2) NOT NULL
);

ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "clinic_isolation" ON inventory
  USING (clinic_id::text = auth.jwt() ->> 'clinic_id');


-- ============================================================
-- 9. restock_log
-- ============================================================
CREATE TABLE restock_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id       UUID NOT NULL REFERENCES clinics(id),
  inventory_id    UUID NOT NULL REFERENCES inventory(id),
  quantity_added  INT NOT NULL,
  restocked_at    TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE restock_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "clinic_isolation" ON restock_log
  USING (clinic_id::text = auth.jwt() ->> 'clinic_id');


-- ============================================================
-- 10. prescriptions
-- ============================================================
CREATE TABLE prescriptions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id     UUID NOT NULL REFERENCES clinics(id),
  patient_id    UUID NOT NULL REFERENCES patients(id),
  created_by    UUID NOT NULL REFERENCES users(id),
  total_amount  NUMERIC(10,2) NOT NULL DEFAULT 0,
  status        TEXT NOT NULL CHECK (status IN ('draft','billed')),
  created_at    TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "clinic_isolation" ON prescriptions
  USING (clinic_id::text = auth.jwt() ->> 'clinic_id');


-- ============================================================
-- 11. prescription_items
-- ============================================================
-- prescription_items does not have its own clinic_id column in the schema.
-- Access is controlled through the prescriptions foreign key.
CREATE TABLE prescription_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prescription_id  UUID NOT NULL REFERENCES prescriptions(id),
  inventory_id     UUID NOT NULL REFERENCES inventory(id),
  name             TEXT NOT NULL,
  dosage           TEXT,
  quantity         INT NOT NULL,
  unit_price       NUMERIC(10,2) NOT NULL,
  line_total       NUMERIC(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED
);

ALTER TABLE prescription_items ENABLE ROW LEVEL SECURITY;

-- prescription_items uses a join-based policy through prescriptions
CREATE POLICY "clinic_isolation" ON prescription_items
  USING (
    EXISTS (
      SELECT 1 FROM prescriptions
      WHERE prescriptions.id = prescription_items.prescription_id
        AND prescriptions.clinic_id::text = auth.jwt() ->> 'clinic_id'
    )
  );


-- ============================================================
-- 12. payments
-- ============================================================
CREATE TABLE payments (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clinic_id        UUID NOT NULL REFERENCES clinics(id),
  patient_id       UUID NOT NULL REFERENCES patients(id),
  prescription_id  UUID REFERENCES prescriptions(id),
  amount           NUMERIC(10,2) NOT NULL,
  method           TEXT NOT NULL CHECK (method IN ('cash','upi')),
  status           TEXT NOT NULL CHECK (status IN ('paid','partial','pending')),
  notes            TEXT,
  paid_at          TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "clinic_isolation" ON payments
  USING (clinic_id::text = auth.jwt() ->> 'clinic_id');
