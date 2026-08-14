//! Dynamic, session-frozen provider routing.
//!
//! Two live inputs feed this: (1) OpenRouter's `/models/.../endpoints` API,
//! polled periodically for the current quantization of each provider (the
//! one thing that endpoint actually reports live), and (2) our own rolling
//! per-provider latency/throughput observations, built by looking up
//! `/generation?id=...` after every completed request — OpenRouter does not
//! expose live latency/throughput via the public endpoints API, so this is
//! the only source of real performance data.
//!
//! The combined "fp8-or-better AND currently at least as fast as our
//! baseline" allowlist is computed fresh only when a *new* session_id is
//! seen, then frozen for that session's lifetime so a mid-conversation stats
//! update can never bump a session off the provider holding its warm prompt
//! cache. New sessions always see the latest data; running sessions never
//! change providers underneath themselves.

use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::{Duration, Instant};
use tracing::warn;

/// How often the rolling stats get snapshotted to disk. Small window on
/// purpose: a service restart between saves loses at most this much of the
/// most recent data, not the whole learned picture.
const PERSIST_INTERVAL: Duration = Duration::from_secs(60);

/// Require this many observations before a provider's rolling average is
/// trusted enough to exclude it. Below this, an untested or barely-tested
/// provider gets the benefit of the doubt rather than being blocked from
/// ever proving itself.
const MIN_SAMPLES_TO_JUDGE: usize = 3;
/// Rolling window size per provider; oldest observation drops off.
const MAX_SAMPLES_PER_PROVIDER: usize = 10;
/// A session with no traffic for this long is forgotten — its next request
/// (if any) is treated as a new session and gets a freshly computed list.
const SESSION_IDLE_EVICT: Duration = Duration::from_secs(2 * 60 * 60);

const GOOD_QUANTIZATIONS: &[&str] = &["fp8", "bf16", "fp16", "fp32"];
/// Below this many completion tokens, generation_time is dominated by fixed
/// connection/TTFT overhead rather than sustained per-token speed — the
/// resulting throughput number is noise, not signal, and would wrongly
/// penalize a genuinely fast provider that happened to answer briefly
/// (e.g. a tool-call-only turn). Skip recording entirely below this floor.
const MIN_COMPLETION_TOKENS_FOR_OBSERVATION: f64 = 40.0;

#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub(crate) struct Observation {
    latency_ms: f64,
    throughput_tps: f64,
}

#[derive(Default)]
struct ProviderStats {
    samples: HashMap<String, Vec<Observation>>,
}

impl ProviderStats {
    fn record(&mut self, tag: &str, obs: Observation) {
        let entries = self.samples.entry(tag.to_string()).or_default();
        entries.push(obs);
        if entries.len() > MAX_SAMPLES_PER_PROVIDER {
            entries.remove(0);
        }
    }

    /// No data yet, or not enough of it: benefit of the doubt (true).
    /// Enough data: compare the rolling average against the floor.
    fn passes_bar(&self, tag: &str, min_throughput: f64, max_latency_ms: f64) -> bool {
        match self.samples.get(tag) {
            None => true,
            Some(v) if v.len() < MIN_SAMPLES_TO_JUDGE => true,
            Some(v) => {
                let n = v.len() as f64;
                let avg_latency_ms: f64 = v.iter().map(|o| o.latency_ms).sum::<f64>() / n;
                let avg_throughput: f64 = v.iter().map(|o| o.throughput_tps).sum::<f64>() / n;
                avg_latency_ms <= max_latency_ms && avg_throughput >= min_throughput
            }
        }
    }
}

struct SessionEntry {
    allowed_tags: Vec<String>,
    last_used: Instant,
}

pub struct RoutingState {
    stats: Mutex<ProviderStats>,
    fp8_tags: Mutex<Vec<String>>,
    name_to_tag: Mutex<HashMap<String, String>>,
    sessions: Mutex<HashMap<String, SessionEntry>>,
    pub tracking_model: String,
    pub min_throughput: f64,
    pub max_latency_ms: f64,
    pub api_key: Option<String>,
}

impl RoutingState {
    pub fn new(
        tracking_model: String,
        min_throughput: f64,
        max_latency_ms: f64,
        api_key: Option<String>,
    ) -> Self {
        Self {
            stats: Mutex::new(ProviderStats::default()),
            fp8_tags: Mutex::new(Vec::new()),
            name_to_tag: Mutex::new(HashMap::new()),
            sessions: Mutex::new(HashMap::new()),
            tracking_model,
            min_throughput,
            max_latency_ms,
            api_key,
        }
    }

    fn set_fp8_tags(&self, tags: Vec<String>) {
        *self.fp8_tags.lock().unwrap() = tags;
    }

    fn set_name_to_tag(&self, map: HashMap<String, String>) {
        *self.name_to_tag.lock().unwrap() = map;
    }

    fn tag_for_provider_name(&self, name: &str) -> Option<String> {
        self.name_to_tag.lock().unwrap().get(name).cloned()
    }

    pub fn record_observation(&self, tag: &str, latency_ms: f64, throughput_tps: f64) {
        self.stats.lock().unwrap().record(
            tag,
            Observation {
                latency_ms,
                throughput_tps,
            },
        );
    }

    /// A cheap, cloneable snapshot of the current rolling samples, for
    /// writing to disk. Not the session map or the fp8 tag cache — those
    /// are refreshed fast enough at startup (one HTTP call) that persisting
    /// them isn't worth the complexity; the rolling performance data is the
    /// only thing expensive (real traffic, over time) to rebuild.
    fn snapshot_samples(&self) -> HashMap<String, Vec<Observation>> {
        self.stats.lock().unwrap().samples.clone()
    }

    /// Replace the rolling samples wholesale — used once at startup to
    /// restore a prior run's data. Caps are already enforced in whatever
    /// was persisted (each Vec was capped at MAX_SAMPLES_PER_PROVIDER when
    /// saved), so no re-validation needed here.
    fn restore_samples(&self, samples: HashMap<String, Vec<Observation>>) {
        self.stats.lock().unwrap().samples = samples;
    }

    /// Frozen-per-session allowlist. `None` means "no restriction" — either
    /// dynamic routing isn't configured, or the first `/endpoints` refresh
    /// hasn't completed yet (fail open rather than blocking all traffic).
    pub fn allowed_tags_for(&self, session_id: Option<&str>) -> Option<Vec<String>> {
        let fp8_tags = self.fp8_tags.lock().unwrap();
        if fp8_tags.is_empty() {
            return None;
        }

        let Some(sid) = session_id else {
            // No session to freeze against — compute fresh every time.
            let stats = self.stats.lock().unwrap();
            return Some(
                fp8_tags
                    .iter()
                    .filter(|tag| stats.passes_bar(tag, self.min_throughput, self.max_latency_ms))
                    .cloned()
                    .collect(),
            );
        };

        let mut sessions = self.sessions.lock().unwrap();
        if let Some(entry) = sessions.get_mut(sid) {
            entry.last_used = Instant::now();
            return Some(entry.allowed_tags.clone());
        }

        let computed = {
            let stats = self.stats.lock().unwrap();
            fp8_tags
                .iter()
                .filter(|tag| stats.passes_bar(tag, self.min_throughput, self.max_latency_ms))
                .cloned()
                .collect::<Vec<_>>()
        };
        sessions.insert(
            sid.to_string(),
            SessionEntry {
                allowed_tags: computed.clone(),
                last_used: Instant::now(),
            },
        );
        Some(computed)
    }

    pub fn evict_idle_sessions(&self) {
        let mut sessions = self.sessions.lock().unwrap();
        sessions.retain(|_, e| e.last_used.elapsed() < SESSION_IDLE_EVICT);
    }
}

/// Background task: refresh the fp8+ tag list and provider-name→tag map
/// every 10 minutes. Errors are logged and retried on the next tick — a
/// transient failure just means sessions starting in that window use
/// slightly stale data, not that the proxy stops working.
pub async fn refresh_loop(state: std::sync::Arc<RoutingState>, client: reqwest::Client) {
    loop {
        if let Err(err) = refresh_once(&state, &client).await {
            warn!("Failed to refresh provider endpoint data: {}", err);
        }
        tokio::time::sleep(Duration::from_secs(600)).await;
    }
}

async fn refresh_once(state: &RoutingState, client: &reqwest::Client) -> anyhow::Result<()> {
    let url = format!(
        "https://openrouter.ai/api/v1/models/{}/endpoints",
        state.tracking_model
    );
    let mut req = client.get(&url);
    if let Some(ref key) = state.api_key {
        req = req.header("Authorization", format!("Bearer {}", key));
    }
    let body: Value = req.send().await?.error_for_status()?.json().await?;

    let endpoints = body["data"]["endpoints"]
        .as_array()
        .cloned()
        .unwrap_or_default();

    let mut fp8_tags = Vec::new();
    let mut name_to_tag = HashMap::new();

    for endpoint in &endpoints {
        let tag = endpoint["tag"].as_str().unwrap_or_default().to_string();
        let name = endpoint["provider_name"]
            .as_str()
            .unwrap_or_default()
            .to_string();
        if tag.is_empty() || name.is_empty() {
            continue;
        }
        name_to_tag.insert(name, tag.clone());

        let quant = endpoint["quantization"].as_str().unwrap_or_default();
        if GOOD_QUANTIZATIONS.contains(&quant) {
            fp8_tags.push(tag);
        }
    }

    tracing::info!(
        "Provider endpoint refresh: {} fp8+ tags out of {} total endpoints",
        fp8_tags.len(),
        endpoints.len()
    );

    state.set_fp8_tags(fp8_tags);
    state.set_name_to_tag(name_to_tag);
    Ok(())
}

/// Background task: forget sessions that have gone idle, so the map doesn't
/// grow without bound over a long-running proxy process.
pub async fn eviction_loop(state: std::sync::Arc<RoutingState>) {
    loop {
        tokio::time::sleep(Duration::from_secs(300)).await;
        state.evict_idle_sessions();
    }
}

/// Load a prior run's rolling stats from disk, if present. Called once at
/// startup, before the persist loop starts — a missing or corrupt file just
/// means starting cold (same as a first-ever run), not a startup failure.
pub fn load_state_from_disk(path: &Path) -> Option<HashMap<String, Vec<Observation>>> {
    let contents = std::fs::read_to_string(path).ok()?;
    match serde_json::from_str(&contents) {
        Ok(samples) => Some(samples),
        Err(err) => {
            warn!(
                "Ignoring unreadable provider-stats state file {}: {}",
                path.display(),
                err
            );
            None
        }
    }
}

pub fn restore_state(state: &RoutingState, samples: HashMap<String, Vec<Observation>>) {
    state.restore_samples(samples);
}

/// Atomic write: a save interrupted mid-write can never leave a corrupt
/// file in place — worst case, the rename never happens and the previous
/// good snapshot on disk survives untouched.
fn save_state_to_disk(
    path: &Path,
    samples: &HashMap<String, Vec<Observation>>,
) -> anyhow::Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let tmp_path = path.with_extension("json.tmp");
    let json = serde_json::to_string(samples)?;
    std::fs::write(&tmp_path, json)?;
    std::fs::rename(&tmp_path, path)?;
    Ok(())
}

/// Background task: periodically snapshot the rolling stats to disk so a
/// service restart (a `nrs` rebuild, a crash, a reboot) doesn't throw away
/// everything the proxy has learned from real traffic.
pub async fn persist_loop(state: std::sync::Arc<RoutingState>, path: PathBuf) {
    loop {
        tokio::time::sleep(PERSIST_INTERVAL).await;

        let snapshot = state.snapshot_samples();
        let path_for_task = path.clone();
        let result = tokio::task::spawn_blocking(move || save_state_to_disk(&path_for_task, &snapshot)).await;

        match result {
            Ok(Ok(())) => {}
            Ok(Err(err)) => warn!("Failed to persist provider stats: {}", err),
            Err(err) => warn!("Provider-stats persist task panicked: {}", err),
        }
    }
}

/// Fire-and-forget: look up the real latency/throughput for one completed
/// generation and fold it into that provider's rolling average. Retried a
/// few times with backoff because OpenRouter's generation endpoint can 404
/// for a few seconds after the response finishes streaming.
pub async fn record_observation_from_generation(
    state: std::sync::Arc<RoutingState>,
    client: reqwest::Client,
    api_key: Option<String>,
    generation_id: String,
) {
    let delays_secs = [2u64, 3, 5];

    for (attempt, delay) in delays_secs.iter().enumerate() {
        tokio::time::sleep(Duration::from_secs(*delay)).await;

        let url = format!("https://openrouter.ai/api/v1/generation?id={}", generation_id);
        let mut req = client.get(&url);
        if let Some(ref key) = api_key {
            req = req.header("Authorization", format!("Bearer {}", key));
        }

        let resp = match req.send().await {
            Ok(r) if r.status().is_success() => r,
            Ok(_) if attempt + 1 < delays_secs.len() => continue,
            Ok(_) => return,
            Err(_) if attempt + 1 < delays_secs.len() => continue,
            Err(_) => return,
        };

        let body: Value = match resp.json().await {
            Ok(b) => b,
            Err(_) => return,
        };

        let data = &body["data"];
        let Some(provider_name) = data["provider_name"].as_str() else {
            return;
        };
        let latency_ms = data["latency"].as_f64().unwrap_or(0.0);
        let generation_time_ms = data["generation_time"].as_f64().unwrap_or(0.0);
        let completion_tokens = data["native_tokens_completion"].as_f64().unwrap_or(0.0);

        if generation_time_ms <= 0.0 || completion_tokens < MIN_COMPLETION_TOKENS_FOR_OBSERVATION {
            return;
        }
        let throughput_tps = completion_tokens / (generation_time_ms / 1000.0);

        if let Some(tag) = state.tag_for_provider_name(provider_name) {
            state.record_observation(&tag, latency_ms, throughput_tps);
        }
        return;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn state_survives_a_save_load_round_trip() {
        let dir = std::env::temp_dir().join(format!(
            "anthropic-proxy-routing-test-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let path = dir.join("provider-stats.json");

        let state = RoutingState::new("deepseek/deepseek-v4-flash-20260731".to_string(), 66.0, 870.0, None);
        for _ in 0..MIN_SAMPLES_TO_JUDGE {
            state.record_observation("gmicloud/fp8", 2361.0, 30.6);
        }
        state.record_observation("baseten/fp8", 370.0, 86.0);

        save_state_to_disk(&path, &state.snapshot_samples()).unwrap();

        let loaded = load_state_from_disk(&path).expect("state file should be readable");
        let fresh_state = RoutingState::new("deepseek/deepseek-v4-flash-20260731".to_string(), 66.0, 870.0, None);
        restore_state(&fresh_state, loaded);

        // The restored state should already judge gmicloud as failing (it
        // has 3+ persisted samples averaging well below the bar) rather
        // than giving it the untested benefit of the doubt.
        fresh_state.set_fp8_tags(vec!["gmicloud/fp8".to_string(), "baseten/fp8".to_string()]);
        let allowed = fresh_state.allowed_tags_for(None).unwrap();
        assert!(!allowed.contains(&"gmicloud/fp8".to_string()));
        assert!(allowed.contains(&"baseten/fp8".to_string()));

        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn missing_state_file_returns_none() {
        let path = std::env::temp_dir().join("anthropic-proxy-routing-test-does-not-exist.json");
        assert!(load_state_from_disk(&path).is_none());
    }

    #[test]
    fn untested_provider_passes_bar() {
        let stats = ProviderStats::default();
        assert!(stats.passes_bar("baseten/fp8", 66.0, 870.0));
    }

    #[test]
    fn provider_with_too_few_samples_passes_bar() {
        let mut stats = ProviderStats::default();
        stats.record(
            "parasail/fp8",
            Observation {
                latency_ms: 5000.0,
                throughput_tps: 1.0,
            },
        );
        assert!(stats.passes_bar("parasail/fp8", 66.0, 870.0));
    }

    #[test]
    fn provider_failing_bar_with_enough_samples_is_excluded() {
        let mut stats = ProviderStats::default();
        for _ in 0..MIN_SAMPLES_TO_JUDGE {
            stats.record(
                "parasail/fp8",
                Observation {
                    latency_ms: 1350.0,
                    throughput_tps: 54.0,
                },
            );
        }
        assert!(!stats.passes_bar("parasail/fp8", 66.0, 870.0));
    }

    #[test]
    fn provider_passing_bar_with_enough_samples_is_included() {
        let mut stats = ProviderStats::default();
        for _ in 0..MIN_SAMPLES_TO_JUDGE {
            stats.record(
                "baseten/fp8",
                Observation {
                    latency_ms: 370.0,
                    throughput_tps: 86.0,
                },
            );
        }
        assert!(stats.passes_bar("baseten/fp8", 66.0, 870.0));
    }

    #[test]
    fn rolling_window_drops_oldest_sample() {
        let mut stats = ProviderStats::default();
        // Fill with MAX_SAMPLES_PER_PROVIDER good samples, then push enough
        // bad ones to fully evict the good ones from the window.
        for _ in 0..MAX_SAMPLES_PER_PROVIDER {
            stats.record(
                "baseten/fp8",
                Observation {
                    latency_ms: 370.0,
                    throughput_tps: 86.0,
                },
            );
        }
        for _ in 0..MAX_SAMPLES_PER_PROVIDER {
            stats.record(
                "baseten/fp8",
                Observation {
                    latency_ms: 2000.0,
                    throughput_tps: 10.0,
                },
            );
        }
        assert!(!stats.passes_bar("baseten/fp8", 66.0, 870.0));
    }

    #[test]
    fn session_allowlist_is_frozen_after_first_computation() {
        let state = RoutingState::new("deepseek/deepseek-v4-flash-20260731".to_string(), 66.0, 870.0, None);
        state.set_fp8_tags(vec!["baseten/fp8".to_string(), "parasail/fp8".to_string()]);

        let first = state.allowed_tags_for(Some("session-a")).unwrap();
        assert!(first.contains(&"parasail/fp8".to_string()));

        // Now make parasail fail the bar with enough samples...
        for _ in 0..MIN_SAMPLES_TO_JUDGE {
            state.record_observation("parasail/fp8", 1350.0, 54.0);
        }

        // ...a NEW session should exclude it...
        let second = state.allowed_tags_for(Some("session-b")).unwrap();
        assert!(!second.contains(&"parasail/fp8".to_string()));

        // ...but the ORIGINAL session must stay frozen with its old list.
        let first_again = state.allowed_tags_for(Some("session-a")).unwrap();
        assert!(first_again.contains(&"parasail/fp8".to_string()));
    }

    #[test]
    fn no_session_id_recomputes_every_call() {
        let state = RoutingState::new("deepseek/deepseek-v4-flash-20260731".to_string(), 66.0, 870.0, None);
        state.set_fp8_tags(vec!["parasail/fp8".to_string()]);

        assert!(state
            .allowed_tags_for(None)
            .unwrap()
            .contains(&"parasail/fp8".to_string()));

        for _ in 0..MIN_SAMPLES_TO_JUDGE {
            state.record_observation("parasail/fp8", 1350.0, 54.0);
        }

        assert!(!state
            .allowed_tags_for(None)
            .unwrap()
            .contains(&"parasail/fp8".to_string()));
    }

    #[test]
    fn no_fp8_tags_yet_returns_none() {
        let state = RoutingState::new("deepseek/deepseek-v4-flash-20260731".to_string(), 66.0, 870.0, None);
        assert!(state.allowed_tags_for(Some("session-a")).is_none());
        assert!(state.allowed_tags_for(None).is_none());
    }
}
