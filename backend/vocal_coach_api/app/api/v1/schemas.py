from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


SessionMode = Literal["karaoke", "training"]
TrainingDifficulty = Literal["beginner", "intermediate", "advanced"]
KaraokeDifficulty = Literal["beginner", "intermediate", "advanced"]
AccessTier = Literal["guest", "registered", "premium"]
VocalRange = Literal["soprano", "mezzo-soprano", "alto", "tenor", "baritone", "bass"]
TrainingGoal = Literal[
  "pitch_improvement",
  "breath_control",
  "tone_quality",
  "range_extension",
  "general_skill_building",
]


class TrainingSessionConfigIn(BaseModel):
  difficulty: TrainingDifficulty = "beginner"
  key: str | None = Field(default=None, min_length=1, max_length=2)
  octave: int | None = Field(default=None, ge=2, le=6)
  target_pattern: str | None = Field(default=None, min_length=1, max_length=64)
  max_attempts: int | None = Field(default=None, ge=1, le=10)
  duration_sec: int | None = Field(default=None, ge=10, le=300)


class VoiceTrainingAttemptMetricSummaryIn(BaseModel):
  model_config = ConfigDict(extra="forbid")

  metric_mode: Literal["voice"] = "voice"
  sample_count: int = Field(default=1, ge=1)
  pitch_accuracy: float = Field(ge=0, le=100)
  timing_accuracy: float = Field(ge=0, le=100)
  breath_control: float = Field(ge=0, le=100)
  pitch_stability: float = Field(ge=0, le=100)
  vibrato_consistency: float = Field(ge=0, le=100)
  note_transition_smoothness: float = Field(ge=0, le=100)


class BreathingTrainingAttemptMetricSummaryIn(BaseModel):
  model_config = ConfigDict(extra="forbid")

  metric_mode: Literal["breathing"] = "breathing"
  sample_count: int = Field(default=1, ge=1)
  phase_completion_rate: float = Field(ge=0, le=100)
  pace_adherence: float = Field(ge=0, le=100)
  cycle_consistency: float = Field(ge=0, le=100)
  completion_rate: float = Field(ge=0, le=100)
  interruption_count: int = Field(default=0, ge=0, le=20)


class TrainingAttemptCreateIn(BaseModel):
  attempt_index: int = Field(ge=1, le=10)
  difficulty: TrainingDifficulty
  duration_sec: int = Field(ge=10, le=300)
  metric_summary: VoiceTrainingAttemptMetricSummaryIn | BreathingTrainingAttemptMetricSummaryIn


class VoiceTrainingAttemptMetricSummaryOut(BaseModel):
  metric_mode: Literal["voice"] = "voice"
  sample_count: int = Field(ge=1)
  pitch_accuracy: float = Field(ge=0, le=100)
  timing_accuracy: float = Field(ge=0, le=100)
  breath_control: float = Field(ge=0, le=100)
  pitch_stability: float = Field(ge=0, le=100)
  vibrato_consistency: float = Field(ge=0, le=100)
  note_transition_smoothness: float = Field(ge=0, le=100)
  overall_score: float = Field(ge=0, le=100)


class BreathingTrainingAttemptMetricSummaryOut(BaseModel):
  metric_mode: Literal["breathing"] = "breathing"
  sample_count: int = Field(ge=1)
  phase_completion_rate: float = Field(ge=0, le=100)
  pace_adherence: float = Field(ge=0, le=100)
  cycle_consistency: float = Field(ge=0, le=100)
  completion_rate: float = Field(ge=0, le=100)
  interruption_count: int = Field(ge=0, le=20)
  overall_score: float = Field(ge=0, le=100)


class TrainingAttemptOut(BaseModel):
  attempt_id: str
  attempt_index: int = Field(ge=1)
  difficulty: TrainingDifficulty
  duration_sec: int = Field(ge=10, le=300)
  score: float = Field(ge=0, le=100)
  metric_summary: VoiceTrainingAttemptMetricSummaryOut | BreathingTrainingAttemptMetricSummaryOut
  score_breakdown: dict[str, Any] | None = None
  strongest_metric: str | None = None
  weakest_metric: str | None = None
  passed_threshold: bool | None = None
  saved_at: int = Field(ge=0)
  is_best: bool


class CanonicalMetric(BaseModel):
  session_id: str = Field(min_length=1)
  timestamp_ms: int = Field(ge=0)
  exercise_type: str = Field(min_length=1)
  pitch_accuracy: float = Field(ge=0, le=100)
  timing_accuracy: float = Field(ge=0, le=100)
  breath_control: float = Field(ge=0, le=100)
  pitch_stability: float = Field(ge=0, le=100)
  vibrato_consistency: float = Field(ge=0, le=100)
  note_transition_smoothness: float = Field(ge=0, le=100)


class MetricBatchIn(BaseModel):
  metrics: list[CanonicalMetric] = Field(min_length=1)


class SessionCreateIn(BaseModel):
  mode: SessionMode
  exercise_type: str = Field(min_length=1)
  training_config: TrainingSessionConfigIn | None = None


class SessionCreateOut(BaseModel):
  session_id: str
  status: str


class AIJobOut(BaseModel):
  job_id: str
  session_id: str
  state: Literal["queued", "processing", "completed", "failed"]
  attempt: int = Field(ge=0)
  max_attempts: int = Field(ge=1)
  queued_at: int = Field(ge=0)
  updated_at: int = Field(ge=0)
  started_at: int | None = Field(default=None, ge=0)
  completed_at: int | None = Field(default=None, ge=0)
  last_error: str | None = None
  mode: SessionMode
  exercise_type: str


class CoachingFeedback(BaseModel):
  session_id: str
  overall_score: float = Field(ge=0, le=100)
  strengths: list[str]
  improvements: list[str]
  next_exercises: list[str]
  summary: str | None = None
  model_used: str
  prompt_version: str
  latency_ms: int = Field(ge=0)


class SessionOut(BaseModel):
  session_id: str
  user_id: str
  mode: SessionMode
  exercise_type: str
  category_id: str | None = None
  exercise_id: str | None = None
  exercise_spec: dict[str, Any] | None = None
  training_config: dict[str, Any] | None = None
  runtime_plan: dict[str, Any] | None = None
  attempt_policy: dict[str, Any] | None = None
  attempts: list[TrainingAttemptOut] | None = None
  selected_best_attempt_id: str | None = None
  best_attempt_score: float | None = None
  status: Literal["started", "processing", "completed", "failed"]
  overall_score: float | None = None
  feedback: CoachingFeedback | None = None
  failure_reason: str | None = None
  ai_job: AIJobOut | None = None


class MetricsAcceptedOut(BaseModel):
  session_id: str
  accepted_count: int
  status: str


class FinalizeOut(BaseModel):
  session_id: str
  status: Literal["processing", "completed"]
  feedback: CoachingFeedback | None = None
  job_id: str | None = None


class TrainingAttemptSavedOut(BaseModel):
  session_id: str
  attempt: TrainingAttemptOut
  selected_best_attempt_id: str
  best_attempt_score: float = Field(ge=0, le=100)


class TrainingAttemptPolicyOut(BaseModel):
  max_attempts: int = Field(ge=1)
  duration_sec_by_difficulty: dict[TrainingDifficulty, int]


class TrainingSuccessThresholdsOut(BaseModel):
  overall_score: float = Field(ge=0, le=100)
  metric_floors: dict[str, float]


class TrainingCoachCuesOut(BaseModel):
  ready: str
  too_soft: str
  on_pitch: str
  low_pitch: str
  high_pitch: str


class TrainingPatternStageTemplateOut(BaseModel):
  stage_id: str
  title: str
  target_label: str
  solfege: str | None = None
  instruction: str
  beats: int = Field(ge=1)


class TrainingPatternTemplateOut(BaseModel):
  pattern_id: str
  pattern_type: str
  summary: str
  stages: list[TrainingPatternStageTemplateOut]


class TrainingExerciseOut(BaseModel):
  exercise_id: str
  name: str
  description: str
  objective: str
  what_you_do: str
  requires_microphone: bool
  exercise_mode: Literal["voice", "breathing_timer"]
  instructions: list[str]
  ai_focus: str
  default_difficulty: TrainingDifficulty
  recommended_order: int = Field(ge=1)
  focus_metrics: list[str]
  metric_weights: dict[str, float]
  success_thresholds: TrainingSuccessThresholdsOut
  coach_cues: TrainingCoachCuesOut
  patterns_by_difficulty: dict[TrainingDifficulty, TrainingPatternTemplateOut]


class TrainingCategoryOut(BaseModel):
  category_id: str
  title: str
  subtitle: str
  description: str
  exercises: list[TrainingExerciseOut]


class TrainingCatalogOut(BaseModel):
  module_id: str
  title: str
  subtitle: str
  description: str
  attempt_policy: TrainingAttemptPolicyOut
  categories: list[TrainingCategoryOut]


class TrainingExerciseProgressOut(BaseModel):
  exercise_id: str
  exercise_name: str
  category_id: str
  sessions_completed: int = Field(ge=0)
  avg_score: float = Field(ge=0, le=100)
  best_score: float = Field(ge=0, le=100)
  last_score: float = Field(ge=0, le=100)
  last_completed_at: int = Field(ge=0)


class TrainingProgressOut(BaseModel):
  user_id: str
  generated_at: int = Field(ge=0)
  items: list[TrainingExerciseProgressOut]


class TrainingRecommendationOut(BaseModel):
  exercise_id: str
  exercise_name: str
  category_id: str
  reason: str
  priority: float = Field(ge=0)


class TrainingRecommendationsOut(BaseModel):
  user_id: str
  generated_at: int = Field(ge=0)
  items: list[TrainingRecommendationOut]


class UserOut(BaseModel):
  uid: str
  email: str
  name: str


class AnalyticsPrimaryMetricOut(BaseModel):
  metric_key: str
  label: str
  avg_value: float = Field(ge=0, le=100)
  session_count: int = Field(ge=0)


class AnalyticsRangeOut(BaseModel):
  session_count: int = Field(ge=0)
  avg_score: float = Field(ge=0, le=100)
  avg_pitch_accuracy: float = Field(ge=0, le=100)
  avg_timing_accuracy: float = Field(ge=0, le=100)
  avg_breath_control: float = Field(ge=0, le=100)
  primary_metric_mode: Literal["voice", "breathing"] | None = None
  primary_metrics: list[AnalyticsPrimaryMetricOut] = Field(default_factory=list)


class AnalyticsDashboardOut(BaseModel):
  user_id: str
  total_completed_sessions: int = Field(ge=0)
  streak_days: int = Field(ge=0)
  avg_score_7d: float = Field(ge=0, le=100)
  last_session_at: int | None = Field(default=None, ge=0)
  ranges: dict[str, AnalyticsRangeOut]
  generated_at: int = Field(ge=0)


class AnalyticsTrendPointOut(BaseModel):
  date: str
  session_count: int = Field(ge=0)
  avg_score: float = Field(ge=0, le=100)
  avg_pitch_accuracy: float = Field(ge=0, le=100)
  avg_timing_accuracy: float = Field(ge=0, le=100)
  avg_breath_control: float = Field(ge=0, le=100)
  primary_metric_mode: Literal["voice", "breathing"] | None = None
  primary_metrics: list[AnalyticsPrimaryMetricOut] = Field(default_factory=list)


class AnalyticsTrendsOut(BaseModel):
  user_id: str
  range: Literal["7d", "30d", "90d"]
  points: list[AnalyticsTrendPointOut]
  generated_at: int = Field(ge=0)


class AudioSnippetCreateIn(BaseModel):
  audio_base64: str = Field(min_length=1)
  content_type: str = Field(min_length=3, max_length=64)
  duration_sec: float = Field(gt=0, le=120)
  sample_rate_hz: int | None = Field(default=None, ge=8000, le=96000)
  channel_count: int | None = Field(default=None, ge=1, le=2)
  recorded_at_ms: int | None = Field(default=None, ge=0)


class AudioSnippetOut(BaseModel):
  snippet_id: str
  user_id: str
  session_id: str
  content_type: str
  duration_sec: float = Field(gt=0, le=120)
  sample_rate_hz: int | None = Field(default=None, ge=8000, le=96000)
  channel_count: int | None = Field(default=None, ge=1, le=2)
  recorded_at_ms: int | None = Field(default=None, ge=0)
  storage_backend: str
  storage_path: str
  size_bytes: int = Field(ge=0)
  created_at: int = Field(ge=0)
  expires_at: int = Field(ge=0)


class AudioSnippetListOut(BaseModel):
  session_id: str
  snippets: list[AudioSnippetOut]


class AudioSnippetCleanupOut(BaseModel):
  checked_count: int = Field(ge=0)
  removed_count: int = Field(ge=0)
  failed_count: int = Field(ge=0)
  cutoff_ms: int = Field(ge=0)


class AIHealthOut(BaseModel):
  status: Literal["ok", "degraded", "disabled"]
  detail: str
  openrouter_enabled: bool
  ai_async_enabled: bool
  openrouter_model: str
  openrouter_timeout_s: int = Field(ge=1)
  reachable: bool
  latency_ms: int | None = Field(default=None, ge=0)


class VocalPreferencesIn(BaseModel):
  model_config = ConfigDict(extra="forbid")

  vocal_range: VocalRange
  preferred_categories: list[str] = Field(min_length=1, max_length=3)
  training_goal: TrainingGoal


class VocalPreferencesOut(BaseModel):
  vocal_range: VocalRange
  preferred_categories: list[str]
  training_goal: TrainingGoal


class UserProfileOut(BaseModel):
  uid: str
  email: str
  name: str
  access_tier: AccessTier
  vocal_preferences: VocalPreferencesOut | None = None
  premium_expires_at: int | None = Field(default=None, ge=0)


# --- Karaoke Catalog Schemas ---


class MelodyNote(BaseModel):
  note: str = Field(min_length=1)
  start_beat: float = Field(ge=0)
  duration_beats: float = Field(gt=0)


class KaraokeDrillOut(BaseModel):
  drill_id: str
  title: str
  style_category: str
  difficulty: KaraokeDifficulty
  duration_sec: int = Field(ge=30, le=180)
  tempo_bpm: int = Field(ge=40, le=220)
  vocal_range: dict[str, str]
  objective: str
  performance_tips: list[str] = Field(min_length=1)
  melody_reference: list[MelodyNote] = Field(min_length=1)
  instrumental_url: str = ""
  pitch_map_url: str = ""
  artist_name: str = ""


class KaraokeCategoryOut(BaseModel):
  category_id: str
  style_label: str
  description: str
  drills: list[KaraokeDrillOut] = Field(min_length=1)


class KaraokeCatalogOut(BaseModel):
  module_id: str
  title: str
  description: str
  categories: list[KaraokeCategoryOut] = Field(min_length=3)


class KaraokeCategoryPreviewOut(BaseModel):
  category_id: str
  style_label: str
  drill_count: int = Field(ge=0)


class KaraokeCatalogPreviewOut(BaseModel):
  module_id: str
  title: str
  description: str
  category_count: int = Field(ge=0)
  total_drills: int = Field(ge=0)
  categories: list[KaraokeCategoryPreviewOut]
