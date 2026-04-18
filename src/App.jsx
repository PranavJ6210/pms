import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './context/AuthContext'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'

// Placeholder components for the 6 modules
function Patients() {
  return <div className="container py-4"><h1>Patient Records</h1><p className="text-muted">Coming soon.</p></div>
}
function Appointments() {
  return <div className="container py-4"><h1>Appointments</h1><p className="text-muted">Coming soon.</p></div>
}
function Imaging() {
  return <div className="container py-4"><h1>Dental Imaging & AI</h1><p className="text-muted">Coming soon.</p></div>
}
function Inventory() {
  return <div className="container py-4"><h1>Inventory & Pharmacy</h1><p className="text-muted">Coming soon.</p></div>
}
function Prescriptions() {
  return <div className="container py-4"><h1>Prescriptions & Billing</h1><p className="text-muted">Coming soon.</p></div>
}
function Payments() {
  return <div className="container py-4"><h1>Payments</h1><p className="text-muted">Coming soon.</p></div>
}

/**
 * ProtectedRoute — redirects to /login if there is no authenticated session.
 */
function ProtectedRoute({ children }) {
  const { user, loading } = useAuth()

  if (loading) {
    return (
      <div className="d-flex align-items-center justify-content-center vh-100">
        <div className="spinner-border text-primary" role="status">
          <span className="visually-hidden">Loading…</span>
        </div>
      </div>
    )
  }

  if (!user) {
    return <Navigate to="/login" replace />
  }

  return children
}

/**
 * RoleGuard — if the user's role is not 'doctor', silently redirects to /dashboard.
 * Used to protect /patients and /imaging routes.
 */
function RoleGuard({ children }) {
  const { role } = useAuth()

  if (role !== 'doctor') {
    return <Navigate to="/dashboard" replace />
  }

  return children
}

function AppRoutes() {
  return (
    <Routes>
      {/* Public route */}
      <Route path="/login" element={<Login />} />

      {/* Protected routes */}
      <Route
        path="/dashboard"
        element={
          <ProtectedRoute>
            <Dashboard />
          </ProtectedRoute>
        }
      />

      {/* Doctor-only routes */}
      <Route
        path="/patients"
        element={
          <ProtectedRoute>
            <RoleGuard>
              <Patients />
            </RoleGuard>
          </ProtectedRoute>
        }
      />
      <Route
        path="/imaging"
        element={
          <ProtectedRoute>
            <RoleGuard>
              <Imaging />
            </RoleGuard>
          </ProtectedRoute>
        }
      />

      {/* Shared routes (Doctor + Receptionist) */}
      <Route
        path="/appointments"
        element={
          <ProtectedRoute>
            <Appointments />
          </ProtectedRoute>
        }
      />
      <Route
        path="/inventory"
        element={
          <ProtectedRoute>
            <Inventory />
          </ProtectedRoute>
        }
      />
      <Route
        path="/prescriptions"
        element={
          <ProtectedRoute>
            <Prescriptions />
          </ProtectedRoute>
        }
      />
      <Route
        path="/payments"
        element={
          <ProtectedRoute>
            <Payments />
          </ProtectedRoute>
        }
      />

      {/* Catch-all: redirect to login */}
      <Route path="*" element={<Navigate to="/login" replace />} />
    </Routes>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </BrowserRouter>
  )
}
