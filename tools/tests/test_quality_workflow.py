from pathlib import Path

import yaml


def test_android_build_uses_a_pinned_compatible_jdk() -> None:
  workflow = Path(__file__).resolve().parents[2] / ".github/workflows/quality.yml"
  steps = yaml.safe_load(workflow.read_text())["jobs"]["flutter"]["steps"]
  java_index = next((i for i, step in enumerate(steps) if step.get("uses", "").startswith("actions/setup-java@")), None)
  assert java_index is not None, "Runner default Java can exceed the Gradle wrapper's supported version"
  assert steps[java_index]["with"]["distribution"] == "temurin"
  assert str(steps[java_index]["with"]["java-version"]) == "17"
  build_index = next(i for i, step in enumerate(steps) if "flutter build apk" in step.get("run", ""))
  assert java_index < build_index
  assert any('flutter config --jdk-dir="$JAVA_HOME"' in step.get("run", "") for step in steps[java_index:build_index])
