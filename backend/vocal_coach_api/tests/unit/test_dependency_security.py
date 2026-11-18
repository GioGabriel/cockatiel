"""Keep both deployment manifests above reviewed multipart/parser advisories."""
from pathlib import Path
import tomllib

import pytest
from packaging.requirements import Requirement

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize("manifest", ["requirements.txt", "pyproject.toml"])
@pytest.mark.parametrize(
    ("package", "unsafe", "reviewed"),
    [
        ("starlette", ["0.52.1", "1.3.0"], "1.9.0"),
        ("python-multipart", ["0.0.9", "0.0.22", "0.0.29"], "0.0.32"),
    ],
)
def test_parser_dependencies_exclude_reviewed_vulnerable_versions(manifest, package, unsafe, reviewed):
    path = ROOT / manifest
    if path.suffix == ".toml":
        lines = tomllib.loads(path.read_text())["project"]["dependencies"]
    else:
        lines = [line for line in path.read_text().splitlines() if line and not line.startswith("#")]
    requirements = {requirement.name: requirement for requirement in map(Requirement, lines)}
    assert package in requirements, f"{manifest} must explicitly constrain {package}"
    specifier = requirements[package].specifier
    for version in unsafe:
        assert version not in specifier, f"{manifest} permits vulnerable {package} {version}"
    assert reviewed in specifier
