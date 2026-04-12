import { useEffect, useMemo, useState } from "react";

type Tab = "labour" | "equipment" | "pending";

type LabourAd = {
  id: string;
  name: string;
  location: string;
  labour_type: string;
  skill_level: string;
  hourly_rate: number;
  rating: number;
  jobs_completed: number;
  experience_years: number;
  available_day: string;
  available_time: string;
};

type EquipmentAd = {
  id: string;
  equipment_type: string;
  for_crop: string;
  location: string;
  hourly_rate: number;
  daily_rate: number;
  rating: number;
  past_bookings: number;
  owner_name: string;
  available_day: string;
  available_time: string;
  condition: string;
};

/** Dev: use Vite proxy `/api` → backend. Prod: set VITE_API_BASE_URL or default localhost. */
function getApiBaseUrl(): string {
  const fromEnv = import.meta.env.VITE_API_BASE_URL;
  if (fromEnv && String(fromEnv).trim()) {
    return String(fromEnv).replace(/\/+$/, "");
  }
  if (import.meta.env.DEV) {
    return "/api";
  }
  return "http://localhost:5003/api";
}

const API_BASE_URL = getApiBaseUrl();

const FETCH_TIMEOUT_MS = 90_000;

async function fetchJsonWithTimeout<T>(
  url: string,
  init: RequestInit
): Promise<T> {
  const controller = new AbortController();
  const timer = window.setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const response = await fetch(url, { ...init, signal: controller.signal });
    if (!response.ok) {
      const text = await response.text();
      let detail = "";
      try {
        const j = JSON.parse(text) as { error?: string };
        detail = j.error ? ` — ${j.error}` : "";
      } catch {
        if (text) detail = ` — ${text.slice(0, 200)}`;
      }
      throw new Error(`HTTP ${response.status}${detail}`);
    }
    return (await response.json()) as T;
  } catch (e) {
    if (e instanceof Error) {
      if (e.name === "AbortError") {
        throw new Error(
          "Request timed out. The backend may be stuck on Firestore (check serviceAccountKey.json / network), or the server is not on port 5003."
        );
      }
      if (e.message.includes("Failed to fetch") || e.name === "TypeError") {
        throw new Error(
          "Cannot reach API. Start the Flask backend (python app.py) and use npm run dev so /api is proxied, or set VITE_API_BASE_URL."
        );
      }
    }
    throw e;
  } finally {
    window.clearTimeout(timer);
  }
}

async function fetchLabourAds(): Promise<LabourAd[]> {
  const data = await fetchJsonWithTimeout<{ items?: LabourAd[] }>(
    `${API_BASE_URL}/labour/search`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ query: "", top_k: 500 }),
    }
  );
  return data.items ?? [];
}

async function fetchEquipmentAds(): Promise<EquipmentAd[]> {
  const data = await fetchJsonWithTimeout<{ items?: EquipmentAd[] }>(
    `${API_BASE_URL}/equipment/search`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ query: "", top_k: 500 }),
    }
  );
  return data.items ?? [];
}

async function fetchPendingLabour(): Promise<LabourAd[]> {
  const data = await fetchJsonWithTimeout<{ items?: LabourAd[] }>(
    `${API_BASE_URL}/labour/pending`,
    { method: "GET" }
  );
  return data.items ?? [];
}

async function fetchPendingEquipment(): Promise<EquipmentAd[]> {
  const data = await fetchJsonWithTimeout<{ items?: EquipmentAd[] }>(
    `${API_BASE_URL}/equipment/pending`,
    { method: "GET" }
  );
  return data.items ?? [];
}

async function moderateLabour(
  id: string,
  action: "approve" | "reject"
): Promise<void> {
  await fetchJsonWithTimeout<{ ok?: boolean }>(
    `${API_BASE_URL}/labour/${encodeURIComponent(id)}/moderate`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action }),
    }
  );
}

async function moderateEquipment(
  id: string,
  action: "approve" | "reject"
): Promise<void> {
  await fetchJsonWithTimeout<{ ok?: boolean }>(
    `${API_BASE_URL}/equipment/${encodeURIComponent(id)}/moderate`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action }),
    }
  );
}

function money(value: number): string {
  return new Intl.NumberFormat("en-LK", {
    style: "currency",
    currency: "LKR",
    maximumFractionDigits: 0,
  }).format(value || 0);
}

export default function App() {
  const [tab, setTab] = useState<Tab>("labour");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [labourAds, setLabourAds] = useState<LabourAd[]>([]);
  const [equipmentAds, setEquipmentAds] = useState<EquipmentAd[]>([]);
  const [pendingLabour, setPendingLabour] = useState<LabourAd[]>([]);
  const [pendingEquipment, setPendingEquipment] = useState<EquipmentAd[]>([]);
  const [actingKey, setActingKey] = useState("");

  const statLabel =
    tab === "pending" ? "Awaiting review" : "Listings on this page";
  const statValue =
    tab === "pending"
      ? pendingLabour.length + pendingEquipment.length
      : tab === "labour"
        ? labourAds.length
        : equipmentAds.length;

  const title = useMemo(() => {
    if (tab === "labour") return "Labour Ads";
    if (tab === "equipment") return "Equipment Ads";
    return "Pending approval";
  }, [tab]);

  const subtitle = useMemo(
    () =>
      tab === "pending"
        ? "Newly posted ads are hidden from search until you approve them."
        : "Review approved labour and equipment listings (public search).",
    [tab]
  );

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      setError("");
      try {
        if (tab === "labour") {
          setLabourAds(await fetchLabourAds());
          return;
        }
        if (tab === "equipment") {
          setEquipmentAds(await fetchEquipmentAds());
          return;
        }
        const [l, e] = await Promise.all([
          fetchPendingLabour(),
          fetchPendingEquipment(),
        ]);
        setPendingLabour(l);
        setPendingEquipment(e);
      } catch (err) {
        const msg = err instanceof Error ? err.message : "Failed to load ads";
        setError(msg);
      } finally {
        setLoading(false);
      }
    };

    void load();
  }, [tab]);

  async function handleModerate(
    kind: "labour" | "equipment",
    id: string,
    action: "approve" | "reject"
  ) {
    const key = `${kind}:${id}:${action}`;
    setActingKey(key);
    setError("");
    try {
      if (kind === "labour") {
        await moderateLabour(id, action);
        setPendingLabour((rows) => rows.filter((r) => r.id !== id));
      } else {
        await moderateEquipment(id, action);
        setPendingEquipment((rows) => rows.filter((r) => r.id !== id));
      }
    } catch (err) {
      const msg =
        err instanceof Error ? err.message : "Could not update moderation";
      setError(msg);
    } finally {
      setActingKey("");
    }
  }

  return (
    <div className="app-shell">
      <aside className="sidebar" aria-label="Main navigation">
        <div className="sidebar-brand">
          <span className="sidebar-logo">YieldSync</span>
          <span className="sidebar-sub">Admin</span>
        </div>
        <nav className="sidebar-nav">
          <button
            type="button"
            className={`sidebar-link${tab === "labour" ? " active" : ""}`}
            onClick={() => setTab("labour")}
            aria-current={tab === "labour" ? "page" : undefined}
          >
            Labour Ads
          </button>
          <button
            type="button"
            className={`sidebar-link${tab === "equipment" ? " active" : ""}`}
            onClick={() => setTab("equipment")}
            aria-current={tab === "equipment" ? "page" : undefined}
          >
            Equipment Ads
          </button>
          <button
            type="button"
            className={`sidebar-link${tab === "pending" ? " active" : ""}`}
            onClick={() => setTab("pending")}
            aria-current={tab === "pending" ? "page" : undefined}
          >
            Pending
          </button>
        </nav>
      </aside>

      <main className="main-area">
        <div className="container">
          <header className="header">
            <div>
              <h1>{title}</h1>
              <p>{subtitle}</p>
            </div>
            <div className="stats">
              <span>{statLabel}</span>
              <strong>{statValue}</strong>
            </div>
          </header>

          <section className="view-toggle" aria-label="Switch ad type">
            <button
              type="button"
              className={tab === "labour" ? "active" : ""}
              onClick={() => setTab("labour")}
            >
              Labour Ads
            </button>
            <button
              type="button"
              className={tab === "equipment" ? "active" : ""}
              onClick={() => setTab("equipment")}
            >
              Equipment Ads
            </button>
            <button
              type="button"
              className={tab === "pending" ? "active" : ""}
              onClick={() => setTab("pending")}
            >
              Pending
            </button>
          </section>

          <section className="panel">
            <div className="panel-head">
              <h2>{title}</h2>
            </div>

            {loading && (
              <p className="status">
                {tab === "pending"
                  ? "Loading pending ads…"
                  : `Loading ${title.toLowerCase()}…`}
              </p>
            )}
            {error && <p className="status error">{error}</p>}

            {!loading && !error && tab === "labour" && (
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>Type</th>
                      <th>Location</th>
                      <th>Rate</th>
                      <th>Rating</th>
                      <th>Jobs</th>
                      <th>Experience</th>
                      <th>Availability</th>
                    </tr>
                  </thead>
                  <tbody>
                    {labourAds.map((ad) => (
                      <tr key={ad.id}>
                        <td>{ad.name || "-"}</td>
                        <td>{ad.labour_type || "-"}</td>
                        <td>{ad.location || "-"}</td>
                        <td>{money(ad.hourly_rate)}/hr</td>
                        <td>{ad.rating?.toFixed(1) ?? "0.0"}</td>
                        <td>{ad.jobs_completed ?? 0}</td>
                        <td>{ad.experience_years ?? 0} yrs</td>
                        <td>
                          {ad.available_day || "-"} | {ad.available_time || "-"}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {!labourAds.length && <p className="empty">No labour ads found.</p>}
              </div>
            )}

            {!loading && !error && tab === "equipment" && (
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>Type</th>
                      <th>Crop</th>
                      <th>Location</th>
                      <th>Hourly</th>
                      <th>Daily</th>
                      <th>Rating</th>
                      <th>Bookings</th>
                      <th>Owner</th>
                      <th>Condition</th>
                    </tr>
                  </thead>
                  <tbody>
                    {equipmentAds.map((ad) => (
                      <tr key={ad.id}>
                        <td>{ad.equipment_type || "-"}</td>
                        <td>{ad.for_crop || "-"}</td>
                        <td>{ad.location || "-"}</td>
                        <td>{money(ad.hourly_rate)}</td>
                        <td>{money(ad.daily_rate)}</td>
                        <td>{ad.rating?.toFixed(1) ?? "0.0"}</td>
                        <td>{ad.past_bookings ?? 0}</td>
                        <td>{ad.owner_name || "-"}</td>
                        <td>{ad.condition || "-"}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {!equipmentAds.length && (
                  <p className="empty">No equipment ads found.</p>
                )}
              </div>
            )}

            {!loading && !error && tab === "pending" && (
              <div className="pending-sections">
                <div className="pending-block">
                  <h3 className="pending-heading">Labour — pending</h3>
                  <div className="table-wrap">
                    <table>
                      <thead>
                        <tr>
                          <th>Name</th>
                          <th>Type</th>
                          <th>Location</th>
                          <th>Rate</th>
                          <th>Rating</th>
                          <th>Availability</th>
                          <th className="th-actions">Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {pendingLabour.map((ad) => (
                          <tr key={ad.id}>
                            <td>{ad.name || "-"}</td>
                            <td>{ad.labour_type || "-"}</td>
                            <td>{ad.location || "-"}</td>
                            <td>{money(ad.hourly_rate)}/hr</td>
                            <td>{ad.rating?.toFixed(1) ?? "0.0"}</td>
                            <td>
                              {ad.available_day || "-"} |{" "}
                              {ad.available_time || "-"}
                            </td>
                            <td>
                              <div className="action-cell">
                                <button
                                  type="button"
                                  className="btn-approve"
                                  disabled={
                                    !!actingKey &&
                                    actingKey.startsWith(`labour:${ad.id}:`)
                                  }
                                  onClick={() =>
                                    void handleModerate(
                                      "labour",
                                      ad.id,
                                      "approve"
                                    )
                                  }
                                >
                                  Approve
                                </button>
                                <button
                                  type="button"
                                  className="btn-reject"
                                  disabled={
                                    !!actingKey &&
                                    actingKey.startsWith(`labour:${ad.id}:`)
                                  }
                                  onClick={() =>
                                    void handleModerate(
                                      "labour",
                                      ad.id,
                                      "reject"
                                    )
                                  }
                                >
                                  Reject
                                </button>
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                    {!pendingLabour.length && (
                      <p className="empty">No labour ads awaiting review.</p>
                    )}
                  </div>
                </div>

                <div className="pending-block">
                  <h3 className="pending-heading">Equipment — pending</h3>
                  <div className="table-wrap">
                    <table>
                      <thead>
                        <tr>
                          <th>Type</th>
                          <th>Crop</th>
                          <th>Location</th>
                          <th>Hourly</th>
                          <th>Daily</th>
                          <th>Owner</th>
                          <th>Condition</th>
                          <th className="th-actions">Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {pendingEquipment.map((ad) => (
                          <tr key={ad.id}>
                            <td>{ad.equipment_type || "-"}</td>
                            <td>{ad.for_crop || "-"}</td>
                            <td>{ad.location || "-"}</td>
                            <td>{money(ad.hourly_rate)}</td>
                            <td>{money(ad.daily_rate)}</td>
                            <td>{ad.owner_name || "-"}</td>
                            <td>{ad.condition || "-"}</td>
                            <td>
                              <div className="action-cell">
                                <button
                                  type="button"
                                  className="btn-approve"
                                  disabled={
                                    !!actingKey &&
                                    actingKey.startsWith(`equipment:${ad.id}:`)
                                  }
                                  onClick={() =>
                                    void handleModerate(
                                      "equipment",
                                      ad.id,
                                      "approve"
                                    )
                                  }
                                >
                                  Approve
                                </button>
                                <button
                                  type="button"
                                  className="btn-reject"
                                  disabled={
                                    !!actingKey &&
                                    actingKey.startsWith(`equipment:${ad.id}:`)
                                  }
                                  onClick={() =>
                                    void handleModerate(
                                      "equipment",
                                      ad.id,
                                      "reject"
                                    )
                                  }
                                >
                                  Reject
                                </button>
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                    {!pendingEquipment.length && (
                      <p className="empty">
                        No equipment ads awaiting review.
                      </p>
                    )}
                  </div>
                </div>
              </div>
            )}
          </section>
        </div>
      </main>
    </div>
  );
}
