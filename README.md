# Dental PMS

A multi-tenant SaaS web application for dental clinics to manage patients, appointments, dental imaging with AI analysis, pharmacy inventory, prescriptions, billing, and manual payment logging.

## Tech Stack

- **Frontend** — React 19, Vite, Bootstrap 5, React Router v7
- **Backend / API** — Supabase Edge Functions (Deno)
- **Database** — PostgreSQL via Supabase (Row-Level Security)
- **Auth** — Supabase Auth (email/password)
- **File Storage** — Supabase Storage (signed URLs only)
- **AI** — OpenAI GPT-4o Vision API
- **Error Tracking** — Sentry

---

## Prerequisites

Make sure the following are installed on your Windows machine before you begin:

| Tool | Version | Download |
|------|---------|----------|
| **Node.js** | v18 or higher | [nodejs.org](https://nodejs.org/) |
| **npm** | Comes with Node.js | — |
| **Git** | Latest | [git-scm.com](https://git-scm.com/download/win) |

> **Tip:** After installing, open a new terminal and verify with:
> ```
> node -v
> npm -v
> git --version
> ```

---

## Getting Started

### 1. Clone the Repository

Open **PowerShell**, **Command Prompt**, or **Git Bash** and run:

```bash
git clone https://github.com/PranavJ6210/pms.git
cd pms
```

### 2. Install Dependencies

```bash
npm install
```

This will install all packages listed in `package.json` (React, Bootstrap, Supabase, Sentry, etc.).

### 3. Set Up Environment Variables

Copy the example env file and fill in your Supabase credentials:

```bash
copy .env.example .env
```

Then open `.env` in any text editor and fill in the values:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
VITE_OPENAI_API_KEY=your-openai-key-here
```

> **Where to find these:**
> - **Supabase URL & Anon Key** — Go to your [Supabase Dashboard](https://app.supabase.com/) → select your project → **Settings** → **API**
> - **OpenAI API Key** — Go to [platform.openai.com/api-keys](https://platform.openai.com/api-keys)

### 4. Run the Dev Server

```bash
npm run dev
```

The app will start at **http://localhost:5173/**. Open this URL in your browser.

---

## Project Structure

```
dental-pms/
├── public/
├── src/
│   ├── components/       # Shared reusable components
│   ├── context/          # AuthContext (user, role, clinicId)
│   ├── hooks/            # Custom React hooks
│   ├── lib/              # Supabase client, helpers
│   ├── pages/
│   │   ├── patients/     # Patient Records (Doctor only)
│   │   ├── appointments/ # Appointments (Doctor + Receptionist)
│   │   ├── imaging/      # Dental Imaging & AI (Doctor only)
│   │   ├── inventory/    # Inventory & Pharmacy
│   │   ├── prescriptions/# Prescriptions & Billing
│   │   ├── payments/     # Payments
│   │   ├── Dashboard.jsx
│   │   └── Login.jsx
│   ├── styles/           # Global CSS, print.css
│   ├── App.jsx           # Router & route guards
│   ├── main.jsx          # Entry point
│   └── index.css
├── supabase/
│   └── migrations/       # SQL migration files
├── .env.example
├── package.json
└── vite.config.js
```

---

## Database Setup

The full schema is in `supabase/migrations/001_initial_schema.sql`. To apply it:

1. Install the [Supabase CLI](https://supabase.com/docs/guides/cli/getting-started)
2. Link your project:
   ```bash
   supabase link --project-ref your-project-ref
   ```
3. Push the migration:
   ```bash
   supabase db push
   ```

Alternatively, you can copy the contents of `001_initial_schema.sql` and run it in the **Supabase Dashboard → SQL Editor**.

---

## Available Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start the Vite dev server with HMR |
| `npm run build` | Build for production |
| `npm run preview` | Preview the production build locally |
| `npm run lint` | Run ESLint |

---

## Roles

There are exactly two roles — no others should be created:

- **Doctor** — Full access to all modules. Can create patients, upload images, trigger AI analysis.
- **Receptionist** — Can access Appointments, Inventory, Prescriptions & Billing, and Payments. **Cannot** access Patient Records or Dental Imaging.

---

## Troubleshooting

### `npm install` fails
- Make sure you're using Node.js v18+. Run `node -v` to check.
- Delete `node_modules` and `package-lock.json`, then run `npm install` again.

### Dev server won't start
- Check that `.env` exists and has valid `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` values.
- Make sure port 5173 isn't in use. You can kill it with:
  ```bash
  npx kill-port 5173
  ```

### Login doesn't work
- Ensure your Supabase project has **Email/Password** auth enabled under **Authentication → Providers**.
- Make sure the `users` table exists in your database (run the migration first).
