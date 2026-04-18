# Dental PMS — Claude Code Project Context

## Project Overview

A multi-tenant SaaS web application for dental clinics to manage patients, appointments,
dental imaging with AI analysis, pharmacy inventory, prescriptions, billing, and manual
payment logging. Each clinic is a fully isolated tenant.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React 18, Vite, Bootstrap 5, React Router v6 |
| Backend / API | Supabase Edge Functions (Deno) |
| Database | PostgreSQL via Supabase (with Row-Level Security) |
| Auth | Supabase Auth — email/password |
| File Storage | Supabase Storage — signed URLs only, never public |
| AI | OpenAI GPT-4o Vision API |
| Hosting | Netlify or Vercel |
| CI/CD | GitHub Actions |
| Error Tracking | Sentry |

---

## Roles

There are exactly **two roles** within each clinic. Never create a third role.

### Doctor
- Full access to all modules
- Only role that can create patient records
- Only role that can upload dental images and trigger AI analysis
- Is always the clinic account owner (created at signup)
- Can invite Receptionists

### Receptionist
- **Cannot** access Patient Records module
- **Cannot** access Dental Imaging & AI module
- Can access: Appointments, Inventory, Prescriptions & Billing, Payments

### Role Enforcement Rules
- Role is stored on the `users` table as `role ENUM('doctor', 'receptionist')`
- Every API route and Supabase Edge Function must check `role` server-side — never trust frontend-only guards
- Supabase RLS policies enforce role and clinic isolation at the database layer
- Frontend route guards are secondary protection only — never the sole guard

---

## Multi-Tenancy Rules

- Every table has a `clinic_id UUID NOT NULL` foreign key referencing `clinics.id`
- Supabase RLS is ENABLED on every table — no exceptions
- RLS policies must filter by `clinic_id = auth.jwt() ->> 'clinic_id'`
- Cross-clinic data access must be impossible at the query level
- Never write a query without a `clinic_id` filter
- The `clinic_id` is embedded in the Supabase JWT on login — do not pass it as a parameter from the frontend

---

## Database Schema

### clinics
```sql
id          UUID PRIMARY KEY DEFAULT gen_random_uuid()
name        TEXT NOT NULL
created_at  TIMESTAMPTZ DEFAULT now()
```

### users
```sql
id          UUID PRIMARY KEY REFERENCES auth.users(id)
clinic_id   UUID NOT NULL REFERENCES clinics(id)
email       TEXT NOT NULL
role        TEXT NOT NULL CHECK (role IN ('doctor', 'receptionist'))
created_at  TIMESTAMPTZ DEFAULT now()
```

### patients
```sql
id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
clinic_id       UUID NOT NULL REFERENCES clinics(id)
name            TEXT NOT NULL
dob             DATE
contact         TEXT
medical_history TEXT
allergies       TEXT
created_at      TIMESTAMPTZ DEFAULT now()
```

### appointments
```sql
id            UUID PRIMARY KEY DEFAULT gen_random_uuid()
clinic_id     UUID NOT NULL REFERENCES clinics(id)
patient_id    UUID NOT NULL REFERENCES patients(id)
user_id       UUID NOT NULL REFERENCES users(id)
scheduled_at  TIMESTAMPTZ NOT NULL
status        TEXT NOT NULL CHECK (status IN ('scheduled','confirmed','completed','cancelled'))
reason        TEXT
created_at    TIMESTAMPTZ DEFAULT now()
```

### clinical_notes
```sql
id          UUID PRIMARY KEY DEFAULT gen_random_uuid()
clinic_id   UUID NOT NULL REFERENCES clinics(id)
patient_id  UUID NOT NULL REFERENCES patients(id)
created_by  UUID NOT NULL REFERENCES users(id)
note        TEXT NOT NULL
created_at  TIMESTAMPTZ DEFAULT now()
```

### dental_images
```sql
id          UUID PRIMARY KEY DEFAULT gen_random_uuid()
clinic_id   UUID NOT NULL REFERENCES clinics(id)
patient_id  UUID NOT NULL REFERENCES patients(id)
url         TEXT NOT NULL
image_type  TEXT NOT NULL CHECK (image_type IN ('xray','photo','panoramic'))
uploaded_at TIMESTAMPTZ DEFAULT now()
```

### ai_analysis
```sql
id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
image_id        UUID NOT NULL REFERENCES dental_images(id)
findings_json   JSONB NOT NULL
doctor_notes    TEXT
created_at      TIMESTAMPTZ DEFAULT now()
```

### inventory
```sql
id                UUID PRIMARY KEY DEFAULT gen_random_uuid()
clinic_id         UUID NOT NULL REFERENCES clinics(id)
name              TEXT NOT NULL
category          TEXT
quantity          INT NOT NULL DEFAULT 0
reorder_threshold INT NOT NULL DEFAULT 10
unit_price        NUMERIC(10,2) NOT NULL
```

### restock_log
```sql
id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
clinic_id       UUID NOT NULL REFERENCES clinics(id)
inventory_id    UUID NOT NULL REFERENCES inventory(id)
quantity_added  INT NOT NULL
restocked_at    TIMESTAMPTZ DEFAULT now()
```

### prescriptions
```sql
id            UUID PRIMARY KEY DEFAULT gen_random_uuid()
clinic_id     UUID NOT NULL REFERENCES clinics(id)
patient_id    UUID NOT NULL REFERENCES patients(id)
created_by    UUID NOT NULL REFERENCES users(id)
total_amount  NUMERIC(10,2) NOT NULL DEFAULT 0
status        TEXT NOT NULL CHECK (status IN ('draft','billed'))
created_at    TIMESTAMPTZ DEFAULT now()
```

### prescription_items
```sql
id               UUID PRIMARY KEY DEFAULT gen_random_uuid()
prescription_id  UUID NOT NULL REFERENCES prescriptions(id)
inventory_id     UUID NOT NULL REFERENCES inventory(id)
name             TEXT NOT NULL
dosage           TEXT
quantity         INT NOT NULL
unit_price       NUMERIC(10,2) NOT NULL
line_total       NUMERIC(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED
```

### payments
```sql
id               UUID PRIMARY KEY DEFAULT gen_random_uuid()
clinic_id        UUID NOT NULL REFERENCES clinics(id)
patient_id       UUID NOT NULL REFERENCES patients(id)
prescription_id  UUID REFERENCES prescriptions(id)
amount           NUMERIC(10,2) NOT NULL
method           TEXT NOT NULL CHECK (method IN ('cash','upi'))
status           TEXT NOT NULL CHECK (status IN ('paid','partial','pending'))
notes            TEXT
paid_at          TIMESTAMPTZ DEFAULT now()
```

---

## Module Boundaries

### Patient Records — Doctor only
- CRUD for patient profiles: name, DOB, contact, medical history, allergies
- Clinical notes per visit
- Document attachments stored in Supabase Storage
- Outstanding payment balance visible on patient profile

### Appointments — Doctor + Receptionist
- Create, update, cancel, confirm appointments
- Link appointment to a patient and a doctor (user)
- Statuses: `scheduled` → `confirmed` → `completed` | `cancelled`
- List view filterable by date, status, doctor
- Daily/weekly calendar view

### Dental Imaging & AI — Doctor only
- Drag-and-drop image upload (JPEG/PNG only — no DICOM)
- Files stored in Supabase Storage with signed URLs — never public URLs
- Metadata saved to `dental_images` on upload
- On upload, call OpenAI GPT-4o Vision API with the dental analysis prompt
- Store AI response in `ai_analysis.findings_json`
- Doctor can add `doctor_notes` to supplement or override AI findings
- AI findings are advisory only — never present them as clinical diagnosis

### Inventory & Pharmacy — Doctor + Receptionist
- Item list: name, category, quantity, reorder threshold, unit price
- Add/edit items
- Restock log with quantity added and date
- Show low-stock alert badge when `quantity <= reorder_threshold`
- On prescription bill confirmation, deduct `prescription_items.quantity` from `inventory.quantity`

### Prescriptions & Billing — Doctor + Receptionist
- Create prescription linked to a patient
- Add items from inventory — auto-populate `unit_price` from inventory
- `line_total` is computed (`quantity * unit_price`) — never manually set
- `prescriptions.total_amount` = sum of all `line_total` values — recalculate on every item change
- Status flow: `draft` → `billed` (one-way — a billed prescription cannot be edited)
- On status change to `billed`: deduct stock from inventory
- Printable bill layout: clinic name, patient name, date, itemised list, grand total
- Print via browser native print dialog using a `@media print` stylesheet
- Print layout must hide all navigation, buttons, and background colours

### Payments — Doctor + Receptionist
- Manual entry only — no payment gateway, no Stripe, no online processing
- Payment methods: `cash` or `upi` only
- Statuses: `paid`, `partial`, `pending`
- Partial payments: log amount paid, show remaining balance = `prescriptions.total_amount - SUM(payments.amount)`
- Outstanding balance shown on patient profile
- End-of-day report: sum of cash payments and sum of UPI payments for the day

---

## OpenAI Integration

### Model
- Always use `gpt-4o` with vision capability
- Pass image as base64 or signed URL — prefer signed URL to avoid large payloads

### System Prompt Template
```
You are a dental imaging analysis assistant. Analyse the provided dental image and return
a structured JSON response. Be precise and conservative — only report findings that are
clearly visible. Do not speculate. Your findings are advisory only and will be reviewed
by a qualified dentist before any clinical decision is made.

Return JSON in this exact structure:
{
  "image_type": "xray | photo | panoramic",
  "findings": [
    {
      "area": "string — tooth number or region (e.g. upper left molar)",
      "observation": "string — what is visible",
      "severity": "normal | watch | attention"
    }
  ],
  "summary": "string — 1-2 sentence overall summary",
  "confidence": "high | medium | low"
}
```

### Rules
- Always validate the JSON response before saving to `ai_analysis.findings_json`
- If OpenAI returns an error or invalid JSON, save `{ "error": true, "message": "..." }` and surface the error to the doctor
- Never display raw JSON to the user — always render it as structured UI
- Log every call — model used, image_id, timestamp — for audit purposes

---

## Supabase Conventions

### Queries
- Always use the Supabase JS client (`@supabase/supabase-js`)
- Always include `.eq('clinic_id', clinicId)` on every query — even when RLS covers it, be explicit
- Use `select()` with explicit column lists — never `select('*')` in production queries
- Use `.order('created_at', { ascending: false })` as the default sort

### Storage
- Bucket: `dental-images` — private, no public access
- File path: `{clinic_id}/{patient_id}/{timestamp}-{filename}`
- Always generate a signed URL with a short expiry (1 hour) for display — never expose the raw storage path

### Auth
- On login, fetch the `users` record to get `role` and `clinic_id`
- Store `role` and `clinic_id` in React context — never in localStorage
- On logout, clear all context and navigate to `/login`

### Migrations
- All schema changes go through Supabase migration files — never edit the database manually in production
- Migration files live in `supabase/migrations/`
- Run `supabase db push` to apply — never use the Supabase dashboard SQL editor for schema changes

---

## Frontend Conventions

### Project Structure
```
src/
  components/       # Shared reusable components
  pages/            # One file per route/page
    patients/
    appointments/
    imaging/
    inventory/
    prescriptions/
    payments/
  hooks/            # Custom React hooks (usePatients, useAppointments, etc.)
  lib/              # supabase.js client, openai.js client, helpers
  context/          # AuthContext with user, role, clinicId
  styles/           # Global CSS, print.css
```

### Component Rules
- One component per file
- Use Bootstrap 5 utility classes — do not write custom CSS unless absolutely necessary
- All data fetching lives in custom hooks, not inside components
- All forms use controlled inputs with explicit validation before submission
- Never hardcode clinic_id, user_id, or role — always read from AuthContext

### Role Guards
```jsx
// Use this pattern for role-protected sections
import { useAuth } from '../context/AuthContext'

const { role } = useAuth()
if (role !== 'doctor') return <Navigate to="/dashboard" />
```

### Error Handling
- All Supabase calls must handle the `error` return — never assume success
- Display user-friendly error messages using Bootstrap alerts — never raw error objects
- Log errors to Sentry in catch blocks

---

## Print Stylesheet Rules

Every printable page (prescription bills) must:
- Include `id="printable"` on the print container
- Use `@media print` in a `print.css` file imported on that page
- Print styles must: hide `nav`, `header`, `footer`, `.btn`, `.no-print`; remove background colours; set font to 12pt serif; show full content without truncation

---

## Payments — Hard Rules

- **No payment gateway. No Stripe. No online processing. Ever.**
- Payment is always entered manually by Receptionist or Doctor
- Methods are strictly `cash` or `upi` — no other options
- Amount is entered as a plain numeric input in INR
- Partial payments are allowed — track remaining balance, never delete a payment record

---

## Business Rules

- A prescription in `billed` status cannot be edited or deleted
- Stock deduction happens exactly once — when prescription status changes to `billed`
- A payment cannot exceed the total prescription amount (validate before save)
- Appointments can only be created for existing patients
- A Doctor can do everything a Receptionist can do — but a Receptionist cannot do what a Doctor can
- The first user of a clinic is always a Doctor — there is no super-admin role above Doctor
- AI analysis findings must always show a disclaimer: "These findings are AI-generated and must be reviewed by a qualified dentist."

---

## What NOT to Build

Do not build or suggest any of the following — they are explicitly out of scope:

- Patient-facing portal or login
- Online payment / payment gateway integration
- SMS or email appointment reminders
- Multi-branch or multi-location support
- DICOM image format support
- Insurance claims or insurance billing
- Super-admin dashboard across clinics
- Multi-currency support (INR only)
- Any third role beyond `doctor` and `receptionist`

---

## Implementation Phases (Current Progress)

| Phase | Name | Status |
|---|---|---|
| 1 | Project Setup & Infrastructure | Not started |
| 2 | Database Schema Design | Not started |
| 3 | Authentication & Access Control | Not started |
| 4 | Patient Records Module | Not started |
| 5 | Appointment Module | Not started |
| 6 | Dental Imaging & AI Analysis | Not started |
| 7 | Inventory & Pharmacy | Not started |
| 8 | Prescription & Billing | Not started |
| 9 | Payments Module | Not started |
| 10 | Testing & Quality | Not started |
| 11 | Deployment & Launch | Not started |

Update the Status column as phases complete.

---

## Key Decisions Already Made

- **No DICOM** — JPEG and PNG only for dental images
- **No payment gateway** — all payments are manual Cash or UPI entries
- **Bootstrap 5** — not Tailwind, not MUI, not any other CSS framework
- **Vite** — not Create React App, not Next.js
- **Supabase** — for auth, database, and storage (not Firebase, not PlanetScale)
- **OpenAI GPT-4o** — for dental image analysis (not a custom model, not another provider)
- **Two roles only** — Doctor and Receptionist, no others
- **INR only** — single currency, no formatting needed beyond Indian number formatting
- **Browser print dialog** — no PDF generation library, no server-side PDF rendering
